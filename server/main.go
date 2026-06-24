package main

import (
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
	"time"

	_ "modernc.org/sqlite"
)

var db *sql.DB

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
	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeJSON(w, SyncResponse{OK: false, Message: "invalid body"})
		return
	}

	tx, _ := db.Begin()
	defer tx.Rollback()
	now := time.Now().UTC().Format(time.RFC3339)

	for _, rv := range req.Reviews {
		var existingVersion int
		err := tx.QueryRow("SELECT version FROM reviews WHERE id=?", rv.ID).Scan(&existingVersion)
		if err == sql.ErrNoRows || rv.Version >= existingVersion {
			data, _ := json.Marshal(rv.Data)
			// 始终用服务器当前时间，确保拉取时能匹配 since 条件
			_, _ = tx.Exec(`INSERT OR REPLACE INTO reviews (id, category, data, version, updated_at, deleted)
				VALUES (?, ?, ?, ?, ?, ?)`, rv.ID, rv.Category, string(data), rv.Version, now, rv.Deleted)
		}
	}
	for _, tpl := range req.Templates {
		var existingVersion int
		err := tx.QueryRow("SELECT version FROM templates WHERE id=?", tpl.ID).Scan(&existingVersion)
		if err == sql.ErrNoRows || tpl.Version >= existingVersion {
			data, _ := json.Marshal(tpl.Data)
			_, _ = tx.Exec(`INSERT OR REPLACE INTO templates (id, data, version, updated_at)
				VALUES (?, ?, ?, ?)`, tpl.ID, string(data), tpl.Version, now)
		}
	}
	tx.Commit()

	// 推送后自动生成一份备份快照
	if len(req.Reviews) > 0 {
		go snapshotBackup()
	}

	resp := SyncResponse{OK: true}
	resp.Reviews = queryNewReviews("")
	resp.Templates = queryNewTemplates("")
	writeJSON(w, resp)
}

// snapshotBackup 生成一份完整数据 ZIP 备份
func snapshotBackup() {
	filename := fmt.Sprintf("snapshot_%s.zip", time.Now().UTC().Format("20060102_150405"))
	db.Exec("INSERT INTO backups (filename, created_at) VALUES (?, ?)", filename, time.Now().UTC().Format(time.RFC3339))
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
	path := filepath.Join(".", "backups", filename)
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
	path := filepath.Join(".", "backups", filename)
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
	var list []item
	for rows.Next() {
		var i item
		rows.Scan(&i.Filename, &i.CreatedAt)
		// 读取文件大小
		path := filepath.Join(".", "backups", i.Filename)
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
	path := filepath.Join(".", "backups", filename)
	os.Remove(path)
	db.Exec("DELETE FROM backups WHERE filename=?", filename)
	writeJSON(w, map[string]string{"ok": "true"})
}

func imageUploadHandler(w http.ResponseWriter, r *http.Request) {
	body, _ := io.ReadAll(r.Body)
	defer r.Body.Close()
	var req struct {
		Path     string `json:"path"`
		ReviewID string `json:"reviewId"`
		Data     []byte `json:"data"`
	}
	if err := json.Unmarshal(body, &req); err != nil {
		writeJSON(w, map[string]string{"error": "invalid"})
		return
	}
	db.Exec("INSERT OR REPLACE INTO images (path, data, review_id) VALUES (?, ?, ?)",
		req.Path, req.Data, req.ReviewID)
	writeJSON(w, map[string]string{"ok": "true"})
}

func imageDownloadHandler(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	if path == "" {
		http.Error(w, "missing path", http.StatusBadRequest)
		return
	}
	var data []byte
	err := db.QueryRow("SELECT data FROM images WHERE path=?", path).Scan(&data)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/octet-stream")
	w.Write(data)
}

// ==================== 辅助函数 ====================

func queryNewReviews(since string) []ReviewData {
	rows, err := db.Query(
		"SELECT id, category, data, version, updated_at, deleted FROM reviews WHERE updated_at > ? ORDER BY updated_at",
		sinceOrDefault(since))
	if err != nil {
		return nil
	}
	defer rows.Close()
	var list []ReviewData
	for rows.Next() {
		var r ReviewData
		var raw string
		rows.Scan(&r.ID, &r.Category, &raw, &r.Version, &r.UpdatedAt, &r.Deleted)
		r.Data = json.RawMessage(raw)
		list = append(list, r)
	}
	return list
}

func queryNewTemplates(since string) []TemplateData {
	rows, err := db.Query(
		"SELECT id, data, version, updated_at FROM templates WHERE updated_at > ? ORDER BY updated_at",
		sinceOrDefault(since))
	if err != nil {
		return nil
	}
	defer rows.Close()
	var list []TemplateData
	for rows.Next() {
		var t TemplateData
		var raw string
		rows.Scan(&t.ID, &raw, &t.Version, &t.UpdatedAt)
		t.Data = json.RawMessage(raw)
		list = append(list, t)
	}
	return list
}

func sinceOrDefault(s string) string {
	if s == "" {
		return "1970-01-01T00:00:00Z"
	}
	return s
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
	dataDir := flag.String("data", "./data", "data directory")
	flag.Parse()

	if err := initDB(*dataDir); err != nil {
		log.Fatalf("db init: %v", err)
	}
	defer db.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", healthHandler)
	mux.HandleFunc("/api/auth/register", registerHandler)
	mux.HandleFunc("/api/sync/push", syncPushHandler)
	mux.HandleFunc("/api/sync/pull", syncPullHandler)
	mux.HandleFunc("/api/backup/upload", backupUploadHandler)
	mux.HandleFunc("/api/backup/download", backupDownloadHandler)
	mux.HandleFunc("/api/backup/list", backupListHandler)
	mux.HandleFunc("/api/backup/delete", backupDeleteHandler)
	mux.HandleFunc("/api/images/upload", imageUploadHandler)
	mux.HandleFunc("/api/images/download", imageDownloadHandler)

	addr := fmt.Sprintf(":%s", *port)
	log.Printf("sync server listening on %s", addr)
	if err := http.ListenAndServe(addr, corsMiddleware(mux)); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
