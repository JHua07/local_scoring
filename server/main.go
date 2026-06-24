package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

var db *sql.DB
var dataDir string // 数据目录全局引用

// ==================== 数据模型 ====================

type ReviewData struct {
	ID        string          `json:"id"`
	Category  string          `json:"category"`
	Data      json.RawMessage `json:"data"`
	Version   int             `json:"version"`
	UpdatedAt string          `json:"updatedAt"`
	Deleted   int             `json:"deleted"`
}

type TemplateData struct {
	ID        string          `json:"id"`
	Data      json.RawMessage `json:"data"`
	Version   int             `json:"version"`
	UpdatedAt string          `json:"updatedAt"`
}

type PullRequest struct {
	DeviceID string `json:"deviceId"`
	Since    string `json:"since"`
}

type PushRequest struct {
	DeviceID  string         `json:"deviceId"`
	Reviews   []ReviewData   `json:"reviews"`
	Templates []TemplateData `json:"templates"`
}

type SyncResponse struct {
	OK        bool           `json:"ok"`
	Reviews   []ReviewData   `json:"reviews,omitempty"`
	Templates []TemplateData `json:"templates,omitempty"`
	Message   string         `json:"message,omitempty"`
}

// ==================== 数据库初始化 ====================

func initDB(dataDir string) error {
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		return err
	}
	path := filepath.Join(dataDir, "sync.db")
	var err error
	db, err = sql.Open("sqlite", path+"?_journal_mode=WAL&_busy_timeout=5000")
	if err != nil {
		return err
	}
	db.SetMaxOpenConns(1)

	_, err = db.Exec(`
		CREATE TABLE IF NOT EXISTS reviews (
			id TEXT PRIMARY KEY,
			category TEXT NOT NULL DEFAULT '',
			data TEXT NOT NULL,
			version INTEGER DEFAULT 1,
			updated_at TEXT NOT NULL,
			deleted INTEGER DEFAULT 0
		);
		CREATE TABLE IF NOT EXISTS templates (
			id TEXT PRIMARY KEY,
			data TEXT NOT NULL,
			version INTEGER DEFAULT 1,
			updated_at TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS images (
			path TEXT PRIMARY KEY,
			data BLOB NOT NULL,
			review_id TEXT NOT NULL
		);
		CREATE TABLE IF NOT EXISTS backups (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			filename TEXT NOT NULL,
			created_at TEXT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_reviews_updated ON reviews(updated_at);
		CREATE INDEX IF NOT EXISTS idx_templates_updated ON templates(updated_at);
	`)
	return err
}

// ==================== Handler ====================

func healthHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, map[string]string{"status": "ok"})
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	var body struct {
		DeviceName string `json:"deviceName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, map[string]string{"error": "invalid body"})
		return
	}
	hash := sha256.Sum256([]byte(body.DeviceName + time.Now().String()))
	token := hex.EncodeToString(hash[:16])
	writeJSON(w, map[string]string{"token": token, "deviceId": token[:8]})
}

func syncPushHandler(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	defer r.Body.Close()
	if len(body) == 0 {
		writeJSON(w, map[string]string{"ok": "false", "message": "empty"})
		return
	}

	backupDir := filepath.Join(dataDir, "backups")
	os.MkdirAll(backupDir, 0755)
	now := time.Now().UTC()
	filename := fmt.Sprintf("%s.zip", now.Format("20060102_150405"))
	zipPath := filepath.Join(backupDir, filename)
	if err := os.WriteFile(zipPath, body, 0644); err != nil {
		writeJSON(w, map[string]string{"ok": "false", "message": err.Error()})
		return
	}
	db.Exec("INSERT INTO backups (filename, created_at) VALUES (?, ?)", filename, now.Format(time.RFC3339))

	importFromZIP(zipPath, now)
	extractImages(zipPath)
	cleanupOldBackups(3, backupDir)
	log.Printf("push: %s (%d bytes)", filename, len(body))
	writeJSON(w, map[string]string{"ok": "true", "filename": filename})
}

// snapshotBackup 将当前全部 reviews + templates 打包为 ZIP 备份
func snapshotBackup() {
	backupDir := filepath.Join(dataDir, "backups")
	if err := os.MkdirAll(backupDir, 0755); err != nil {
		log.Printf("snapshot mkdir: %v", err)
		return
	}
	filename := fmt.Sprintf("snapshot_%s.zip", time.Now().UTC().Format("20060102_150405"))
	path := filepath.Join(backupDir, filename)

	buf := new(bytes.Buffer)
	w := zip.NewWriter(buf)
	now := time.Now().UTC().Format(time.RFC3339)

	// reviews JSON
	rows, err := db.Query("SELECT id, category, data, version, updated_at, deleted FROM reviews")
	if err == nil {
		var reviews []map[string]any
		for rows.Next() {
			var id, cat, raw, updated string
			var ver, del int
			rows.Scan(&id, &cat, &raw, &ver, &updated, &del)
			reviews = append(reviews, map[string]any{
				"id": id, "category": cat, "data": json.RawMessage(raw),
				"version": ver, "updatedAt": updated, "deleted": del,
			})
		}
		rows.Close()
		if data, err := json.Marshal(reviews); err == nil {
			f, _ := w.Create("reviews.json")
			f.Write(data)
		}
	}

	// templates JSON
	tRows, err := db.Query("SELECT id, data, version, updated_at FROM templates")
	if err == nil {
		var tmpls []map[string]any
		for tRows.Next() {
			var id, raw, updated string
			var ver int
			tRows.Scan(&id, &raw, &ver, &updated)
			tmpls = append(tmpls, map[string]any{"id": id, "data": json.RawMessage(raw), "version": ver, "updatedAt": updated})
		}
		tRows.Close()
		if data, err := json.Marshal(tmpls); err == nil {
			f, _ := w.Create("templates.json")
			f.Write(data)
		}
	}

	w.Close()

	if err := os.WriteFile(path, buf.Bytes(), 0644); err != nil {
		log.Printf("snapshot write: %v", err)
		return
	}
	db.Exec("INSERT INTO backups (filename, created_at) VALUES (?, ?)", filename, now)
	log.Printf("snapshot created: %s (%d bytes)", filename, buf.Len())
}

func syncPullHandler(w http.ResponseWriter, r *http.Request) {
	var req PullRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, SyncResponse{OK: false, Message: "invalid body"})
		return
	}
	resp := SyncResponse{OK: true}
	resp.Reviews = queryNewReviews(req.Since)
	resp.Templates = queryNewTemplates(req.Since)
	writeJSON(w, resp)
}

func backupUploadHandler(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	defer r.Body.Close()
	if len(body) == 0 {
		writeJSON(w, map[string]string{"error": "empty body"})
		return
	}
	filename := fmt.Sprintf("backup_%s.zip", time.Now().Format("20060102_150405"))
	path := filepath.Join(dataDir, "backups", filename)
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	if err := os.WriteFile(path, body, 0644); err != nil {
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	db.Exec("INSERT INTO backups (filename, created_at) VALUES (?, ?)", filename, time.Now().UTC().Format(time.RFC3339))
	writeJSON(w, map[string]string{"ok": "true", "filename": filename})
}

func backupDownloadHandler(w http.ResponseWriter, r *http.Request) {
	filename := r.URL.Query().Get("file")
	if filename == "" {
		db.QueryRow("SELECT filename FROM backups ORDER BY id DESC LIMIT 1").Scan(&filename)
	}
	if filename == "" {
		http.Error(w, "no backup", http.StatusNotFound)
		return
	}
	path := filepath.Join(dataDir, "backups", filename)
	if _, err := os.Stat(path); os.IsNotExist(err) {
		http.Error(w, "file not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	http.ServeFile(w, r, path)
}

func backupListHandler(w http.ResponseWriter, r *http.Request) {
	rows, err := db.Query("SELECT filename, created_at FROM backups ORDER BY id DESC")
	if err != nil {
		writeJSON(w, []any{})
		return
	}
	defer rows.Close()
	type item struct {
		Filename  string `json:"filename"`
		CreatedAt string `json:"createdAt"`
	}
	var list = make([]item, 0)
	for rows.Next() {
		var i item
		rows.Scan(&i.Filename, &i.CreatedAt)
		// 读取文件大小
		path := filepath.Join(dataDir, "backups", i.Filename)
		if info, err := os.Stat(path); err == nil {
			i.CreatedAt = fmt.Sprintf("%s (%d KB)", i.CreatedAt, info.Size()/1024)
		}
		list = append(list, i)
	}
	writeJSON(w, list)
}

func backupDeleteHandler(w http.ResponseWriter, r *http.Request) {
	filename := r.URL.Query().Get("file")
	if filename == "" {
		writeJSON(w, map[string]string{"error": "missing file"})
		return
	}
	path := filepath.Join(dataDir, "backups", filename)
	if err := os.Remove(path); err != nil {
		log.Printf("backupDeleteHandler remove file: %v", err)
	}
	result, err := db.Exec("DELETE FROM backups WHERE filename=?", filename)
	if err != nil {
		log.Printf("backupDeleteHandler db delete error: %v", err)
		writeJSON(w, map[string]string{"error": err.Error()})
		return
	}
	n, _ := result.RowsAffected()
	log.Printf("backupDeleteHandler: deleted %s (%d rows)", filename, n)
	writeJSON(w, map[string]string{"ok": "true"})
}

func imageDownloadHandler(w http.ResponseWriter, r *http.Request) {
	imgPath := r.URL.Query().Get("path")
	if imgPath == "" {
		http.Error(w, "missing path", http.StatusBadRequest)
		return
	}
	fullPath := filepath.Join(dataDir, "images", imgPath)
	if _, err := os.Stat(fullPath); os.IsNotExist(err) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	http.ServeFile(w, r, fullPath)
}

// ==================== 辅助 ====================

func importFromZIP(zipPath string, now time.Time) {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		log.Printf("importZIP: %v", err)
		return
	}
	defer zr.Close()
	nowStr := now.Format(time.RFC3339)
	for _, f := range zr.File {
		rc, _ := f.Open()
		data, _ := io.ReadAll(rc)
		rc.Close()
		switch f.Name {
		case "reviews.json":
			var reviews []map[string]any
			if json.Unmarshal(data, &reviews) == nil {
				tx, _ := db.Begin()
				for _, rv := range reviews {
					id, _ := rv["id"].(string)
					cat, _ := rv["category"].(string)
					raw, _ := json.Marshal(rv)
					if id != "" {
						tx.Exec(`INSERT OR REPLACE INTO reviews (id, category, data, version, updated_at, deleted) VALUES (?, ?, ?, 1, ?, 0)`, id, cat, string(raw), nowStr)
					}
				}
				tx.Commit()
			}
		case "templates.json":
			var tmpls []map[string]any
			if json.Unmarshal(data, &tmpls) == nil {
				for _, t := range tmpls {
					id, _ := t["id"].(string)
					raw, _ := json.Marshal(t)
					if id != "" {
						db.Exec(`INSERT OR REPLACE INTO templates (id, data, version, updated_at) VALUES (?, ?, 1, ?)`, id, string(raw), nowStr)
					}
				}
			}
		}
	}
}

func extractImages(zipPath string) {
	imgDir := filepath.Join(dataDir, "images")
	os.MkdirAll(imgDir, 0755)
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return
	}
	defer zr.Close()
	for _, f := range zr.File {
		if !strings.HasPrefix(f.Name, "images/") || f.FileInfo().IsDir() {
			continue
		}
		rc, _ := f.Open()
		data, _ := io.ReadAll(rc)
		rc.Close()
		destPath := filepath.Join(imgDir, f.Name)
		os.MkdirAll(filepath.Dir(destPath), 0755)
		os.WriteFile(destPath, data, 0644)
	}
}

func cleanupOldBackups(keep int, backupDir string) {
	rows, _ := db.Query("SELECT filename FROM backups ORDER BY id DESC")
	if rows == nil {
		return
	}
	defer rows.Close()
	var files []string
	for rows.Next() {
		var fn string
		rows.Scan(&fn)
		files = append(files, fn)
	}
	for i := keep; i < len(files); i++ {
		os.Remove(filepath.Join(backupDir, files[i]))
		db.Exec("DELETE FROM backups WHERE filename=?", files[i])
	}
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(v)
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// ==================== 入口 ====================

func main() {
	port := flag.String("port", "10257", "listen port")
	data := flag.String("data", "./data", "data directory")
	flag.Parse()
	dataDir = *data

	if err := initDB(dataDir); err != nil {
		log.Fatalf("db init: %v", err)
	}
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", healthHandler)
	mux.HandleFunc("/api/auth/register", registerHandler)
	mux.HandleFunc("/api/sync/push", syncPushHandler)
	mux.HandleFunc("/api/sync/pull", syncPullHandler)
	mux.HandleFunc("/api/sync/check", syncCheckHandler)
	mux.HandleFunc("/api/backup/list", backupListHandler)
	mux.HandleFunc("/api/backup/download", backupDownloadHandler)
	mux.HandleFunc("/api/backup/delete", backupDeleteHandler)
	mux.HandleFunc("/api/images/download", imageDownloadHandler)

	addr := fmt.Sprintf(":%s", *port)
	log.Printf("sync server listening on %s", addr)
	if err := http.ListenAndServe(addr, corsMiddleware(mux)); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
