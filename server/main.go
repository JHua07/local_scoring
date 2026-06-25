package main

import (
	"archive/zip"
	"bytes"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	_ "modernc.org/sqlite"
)

const (
	backupKeep     = 3
	maxUploadBytes = 512 << 20 // 512 MB
	serverVersion  = "sync-zip-v3-20260625"
)

var db *sql.DB
var dataDir string

type backupInfo struct {
	Filename  string `json:"filename"`
	CreatedAt string `json:"createdAt"`
	Size      int64  `json:"size"`
	Sha256    string `json:"sha256,omitempty"`
}

type apiResponse map[string]any

func initDB(root string) error {
	if err := os.MkdirAll(root, 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(root, "backups"), 0755); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Join(root, "images"), 0755); err != nil {
		return err
	}

	path := filepath.Join(root, "sync.db")
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
		CREATE TABLE IF NOT EXISTS backups (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			filename TEXT NOT NULL UNIQUE,
			created_at TEXT NOT NULL
		);
		CREATE INDEX IF NOT EXISTS idx_reviews_updated ON reviews(updated_at);
		CREATE INDEX IF NOT EXISTS idx_templates_updated ON templates(updated_at);
	`)
	return err
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"status":        "ok",
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
	})
}

func registerHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	defer r.Body.Close()
	var body struct {
		DeviceName string `json:"deviceName"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "invalid body"})
		return
	}
	if body.DeviceName == "" {
		body.DeviceName = "device"
	}
	hash := sha256.Sum256([]byte(body.DeviceName + time.Now().String()))
	token := hex.EncodeToString(hash[:16])
	writeJSON(w, http.StatusOK, apiResponse{"ok": true, "token": token, "deviceId": token[:8]})
}

func syncPushHandler(w http.ResponseWriter, r *http.Request) {
	saveUploadedBackup(w, r, "push")
}

func backupUploadHandler(w http.ResponseWriter, r *http.Request) {
	saveUploadedBackup(w, r, "backup")
}

func saveUploadedBackup(w http.ResponseWriter, r *http.Request, source string) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	defer r.Body.Close()

	body, err := io.ReadAll(http.MaxBytesReader(w, r.Body, maxUploadBytes))
	if err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "read body failed: " + err.Error()})
		return
	}
	if len(body) == 0 {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "empty body"})
		return
	}
	if err := validateZipBytes(body); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "invalid zip: " + err.Error()})
		return
	}
	sha := bytesSHA256(body)

	now := time.Now()
	createdAt := now.UTC().Format(time.RFC3339)
	filename, err := nextBackupFilename(now)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	zipPath := filepath.Join(backupDir(), filename)
	if err := os.WriteFile(zipPath, body, 0644); err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	if _, err := db.Exec(
		"INSERT OR REPLACE INTO backups (filename, created_at) VALUES (?, ?)",
		filename,
		createdAt,
	); err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}

	if err := importSnapshotFromZIP(zipPath, now.UTC()); err != nil {
		log.Printf("import snapshot %s: %v", filename, err)
	}
	if err := extractImages(zipPath); err != nil {
		log.Printf("extract images %s: %v", filename, err)
	}
	cleanupOldBackups(backupKeep)

	log.Printf("%s saved: %s (%d bytes)", source, filename, len(body))
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"filename":      filename,
		"latestBackup":  filename,
		"createdAt":     createdAt,
		"size":          len(body),
		"sha256":        sha,
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
	})
}

func syncPullHandler(w http.ResponseWriter, r *http.Request) {
	serveBackupZip(w, r)
}

func backupDownloadHandler(w http.ResponseWriter, r *http.Request) {
	serveBackupZip(w, r)
}

func serveBackupZip(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	filename := backupFilenameFromRequest(r)
	var err error
	if filename == "" {
		filename, err = latestBackupFilename()
	} else {
		filename, err = sanitizeBackupFilename(filename)
	}
	if err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	if filename == "" {
		writeJSON(w, http.StatusNotFound, apiResponse{"ok": false, "message": "no backup"})
		return
	}

	path := filepath.Join(backupDir(), filename)
	info, err := os.Stat(path)
	if err != nil || info.IsDir() {
		writeJSON(w, http.StatusNotFound, apiResponse{"ok": false, "message": "file not found"})
		return
	}
	w.Header().Set("Content-Type", "application/zip")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
	w.Header().Set("Content-Length", fmt.Sprintf("%d", info.Size()))
	http.ServeFile(w, r, path)
}

func syncCheckHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	latest, err := latestBackupInfo()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	if latest == nil {
		writeJSON(w, http.StatusOK, apiResponse{
			"ok":            true,
			"hasBackup":     false,
			"serverVersion": serverVersion,
			"dataDir":       dataDir,
			"backupDir":     backupDir(),
		})
		return
	}
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"hasBackup":     true,
		"latestBackup":  latest.Filename,
		"filename":      latest.Filename,
		"createdAt":     latest.CreatedAt,
		"size":          latest.Size,
		"sha256":        latest.Sha256,
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
	})
}

func backupListHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	backups, err := listBackups()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"backups":       backups,
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
	})
}

func syncDebugHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	backups, err := listBackups()
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	files := make([]backupInfo, 0)
	entries, err := os.ReadDir(backupDir())
	if err == nil {
		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(strings.ToLower(entry.Name()), ".zip") {
				continue
			}
			filename, err := sanitizeBackupFilename(entry.Name())
			if err != nil {
				continue
			}
			info, err := entry.Info()
			if err != nil {
				continue
			}
			sha, _ := fileSHA256(filepath.Join(backupDir(), filename))
			files = append(files, backupInfo{
				Filename:  filename,
				CreatedAt: info.ModTime().UTC().Format(time.RFC3339),
				Size:      info.Size(),
				Sha256:    sha,
			})
		}
	}
	sort.SliceStable(files, func(i, j int) bool {
		if files[i].CreatedAt == files[j].CreatedAt {
			return files[i].Filename > files[j].Filename
		}
		return files[i].CreatedAt > files[j].CreatedAt
	})
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
		"backups":       backups,
		"files":         files,
	})
}

func backupDeleteHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost && r.Method != http.MethodDelete {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	filename := backupFilenameFromRequest(r)
	filename, err := sanitizeBackupFilename(filename)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": err.Error()})
		return
	}

	path := filepath.Join(backupDir(), filename)
	if err := os.Remove(path); errors.Is(err, os.ErrNotExist) {
		if _, err := db.Exec("DELETE FROM backups WHERE filename = ?", filename); err != nil {
			writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
			return
		}
		backups, _ := listBackups()
		writeJSON(w, http.StatusNotFound, apiResponse{
			"ok":            false,
			"filename":      filename,
			"message":       "backup file not found",
			"fileExisted":   false,
			"fileDeleted":   false,
			"backups":       backups,
			"serverVersion": serverVersion,
			"dataDir":       dataDir,
			"backupDir":     backupDir(),
		})
		return
	} else if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}

	result, err := db.Exec("DELETE FROM backups WHERE filename = ?", filename)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	rows, _ := result.RowsAffected()
	backups, err := listBackups()
	if err != nil {
		writeJSON(w, http.StatusOK, apiResponse{
			"ok":          true,
			"filename":    filename,
			"fileExisted": true,
			"fileDeleted": true,
			"deletedRows": rows,
		})
		return
	}
	writeJSON(w, http.StatusOK, apiResponse{
		"ok":            true,
		"filename":      filename,
		"fileExisted":   true,
		"fileDeleted":   true,
		"deletedRows":   rows,
		"backups":       backups,
		"serverVersion": serverVersion,
		"dataDir":       dataDir,
		"backupDir":     backupDir(),
	})
}

func imageDownloadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	imgPath := r.URL.Query().Get("path")
	if imgPath == "" {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "missing path"})
		return
	}
	fullPath, err := safeJoin(imageDir(), imgPath)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	if _, err := os.Stat(fullPath); err != nil {
		writeJSON(w, http.StatusNotFound, apiResponse{"ok": false, "message": "not found"})
		return
	}
	http.ServeFile(w, r, fullPath)
}

func imageUploadHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, apiResponse{"ok": false, "message": "method not allowed"})
		return
	}
	defer r.Body.Close()
	var body struct {
		Path     string `json:"path"`
		ReviewID string `json:"reviewId"`
		Data     []int  `json:"data"`
	}
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxUploadBytes)).Decode(&body); err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "invalid body"})
		return
	}
	if body.Path == "" || len(body.Data) == 0 {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "missing image"})
		return
	}
	fullPath, err := safeJoin(imageDir(), body.Path)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	bytes := make([]byte, len(body.Data))
	for i, v := range body.Data {
		if v < 0 || v > 255 {
			writeJSON(w, http.StatusBadRequest, apiResponse{"ok": false, "message": "invalid image byte"})
			return
		}
		bytes[i] = byte(v)
	}
	if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	if err := os.WriteFile(fullPath, bytes, 0644); err != nil {
		writeJSON(w, http.StatusInternalServerError, apiResponse{"ok": false, "message": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, apiResponse{"ok": true, "path": body.Path})
}

func importSnapshotFromZIP(zipPath string, now time.Time) error {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()

	nowStr := now.Format(time.RFC3339)
	tx, err := db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()

	for _, f := range zr.File {
		if f.FileInfo().IsDir() {
			continue
		}
		name := normalizeArchivePath(f.Name)
		if name == "" {
			continue
		}
		if name == "templates.json" {
			if err := importTemplatesFile(tx, f, nowStr); err != nil {
				log.Printf("import templates: %v", err)
			}
			continue
		}
		if strings.HasSuffix(name, "/data.json") {
			category := strings.TrimSuffix(name, "/data.json")
			if err := importReviewsFile(tx, f, category, nowStr); err != nil {
				log.Printf("import %s: %v", name, err)
			}
		}
	}
	return tx.Commit()
}

func importTemplatesFile(tx *sql.Tx, f *zip.File, nowStr string) error {
	data, err := readZipFile(f)
	if err != nil {
		return err
	}
	var templates []map[string]any
	if err := json.Unmarshal(data, &templates); err != nil {
		return err
	}
	for i, t := range templates {
		id := stringValue(t["id"])
		if id == "" {
			id = fmt.Sprintf("template_%d", i)
		}
		raw, _ := json.Marshal(t)
		if _, err := tx.Exec(
			`INSERT OR REPLACE INTO templates (id, data, version, updated_at) VALUES (?, ?, 1, ?)`,
			id,
			string(raw),
			nowStr,
		); err != nil {
			return err
		}
	}
	return nil
}

func importReviewsFile(tx *sql.Tx, f *zip.File, category string, nowStr string) error {
	data, err := readZipFile(f)
	if err != nil {
		return err
	}
	var reviews []map[string]any
	if err := json.Unmarshal(data, &reviews); err != nil {
		return err
	}
	for _, rv := range reviews {
		id := stringValue(rv["id"])
		if id == "" {
			continue
		}
		cat := stringValue(rv["category"])
		if cat == "" {
			cat = category
		}
		updatedAt := stringValue(rv["updatedAt"])
		if updatedAt == "" {
			updatedAt = nowStr
		}
		deleted := intValue(rv["deleted"])
		raw, _ := json.Marshal(rv)
		if _, err := tx.Exec(
			`INSERT OR REPLACE INTO reviews (id, category, data, version, updated_at, deleted) VALUES (?, ?, ?, 1, ?, ?)`,
			id,
			cat,
			string(raw),
			updatedAt,
			deleted,
		); err != nil {
			return err
		}
	}
	return nil
}

func extractImages(zipPath string) error {
	zr, err := zip.OpenReader(zipPath)
	if err != nil {
		return err
	}
	defer zr.Close()

	for _, f := range zr.File {
		if f.FileInfo().IsDir() {
			continue
		}
		name := normalizeArchivePath(f.Name)
		if name == "" {
			continue
		}
		parts := strings.Split(name, "/")
		if len(parts) < 3 || parts[len(parts)-2] != "images" {
			continue
		}
		fullPath, err := safeJoin(imageDir(), name)
		if err != nil {
			log.Printf("skip unsafe image path %q: %v", name, err)
			continue
		}
		data, err := readZipFile(f)
		if err != nil {
			return err
		}
		if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
			return err
		}
		if err := os.WriteFile(fullPath, data, 0644); err != nil {
			return err
		}
	}
	return nil
}

func validateZipBytes(body []byte) error {
	if len(body) < 4 || body[0] != 'P' || body[1] != 'K' {
		return errors.New("missing zip header")
	}
	zr, err := zip.NewReader(bytes.NewReader(body), int64(len(body)))
	if err != nil {
		return err
	}
	for _, f := range zr.File {
		name := normalizeArchivePath(f.Name)
		if name == "" && !f.FileInfo().IsDir() {
			return fmt.Errorf("unsafe archive path %q", f.Name)
		}
		if strings.HasPrefix(name, "../") || strings.Contains(name, "/../") {
			return fmt.Errorf("unsafe archive path %q", f.Name)
		}
	}
	return nil
}

func readZipFile(f *zip.File) ([]byte, error) {
	rc, err := f.Open()
	if err != nil {
		return nil, err
	}
	defer rc.Close()
	return io.ReadAll(rc)
}

func bytesSHA256(body []byte) string {
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func fileSHA256(path string) (string, error) {
	f, err := os.Open(path)
	if err != nil {
		return "", err
	}
	defer f.Close()

	h := sha256.New()
	if _, err := io.Copy(h, f); err != nil {
		return "", err
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}

func cleanupOldBackups(keep int) {
	backups, err := listBackups()
	if err != nil {
		log.Printf("cleanup list backups: %v", err)
		return
	}
	for i := keep; i < len(backups); i++ {
		filename := backups[i].Filename
		if err := os.Remove(filepath.Join(backupDir(), filename)); err != nil && !errors.Is(err, os.ErrNotExist) {
			log.Printf("cleanup remove %s: %v", filename, err)
		}
		if _, err := db.Exec("DELETE FROM backups WHERE filename = ?", filename); err != nil {
			log.Printf("cleanup delete db %s: %v", filename, err)
		}
	}
}

func listBackups() ([]backupInfo, error) {
	files, err := os.ReadDir(backupDir())
	if err != nil {
		return nil, err
	}
	list := make([]backupInfo, 0)
	for _, file := range files {
		if file.IsDir() || !strings.HasSuffix(strings.ToLower(file.Name()), ".zip") {
			continue
		}
		filename, err := sanitizeBackupFilename(file.Name())
		if err != nil {
			continue
		}
		info, err := file.Info()
		if err != nil {
			continue
		}
		createdAt := info.ModTime().UTC().Format(time.RFC3339)
		if _, err := db.Exec(
			"INSERT OR IGNORE INTO backups (filename, created_at) VALUES (?, ?)",
			filename,
			createdAt,
		); err != nil {
			log.Printf("listBackups index %s: %v", filename, err)
		}
		sha, _ := fileSHA256(filepath.Join(backupDir(), filename))
		list = append(list, backupInfo{
			Filename:  filename,
			CreatedAt: createdAt,
			Size:      info.Size(),
			Sha256:    sha,
		})
	}

	sort.SliceStable(list, func(i, j int) bool {
		if list[i].CreatedAt == list[j].CreatedAt {
			return list[i].Filename > list[j].Filename
		}
		return list[i].CreatedAt > list[j].CreatedAt
	})
	return list, nil
}

func latestBackupInfo() (*backupInfo, error) {
	backups, err := listBackups()
	if err != nil {
		return nil, err
	}
	if len(backups) == 0 {
		return nil, nil
	}
	return &backups[0], nil
}

func latestBackupFilename() (string, error) {
	latest, err := latestBackupInfo()
	if err != nil || latest == nil {
		return "", err
	}
	return latest.Filename, nil
}

func nextBackupFilename(now time.Time) (string, error) {
	if err := os.MkdirAll(backupDir(), 0755); err != nil {
		return "", err
	}
	base := fmt.Sprintf("backup_%s_%09d", now.Format("20060102_150405"), now.Nanosecond())
	for i := 0; i < 1000; i++ {
		name := base + ".zip"
		if i > 0 {
			name = fmt.Sprintf("%s_%03d.zip", base, i)
		}
		if _, err := os.Stat(filepath.Join(backupDir(), name)); errors.Is(err, os.ErrNotExist) {
			return name, nil
		}
	}
	return "", errors.New("cannot allocate backup filename")
}

func backupFilenameFromRequest(r *http.Request) string {
	for _, key := range []string{"file", "filename", "name"} {
		if value := r.URL.Query().Get(key); value != "" {
			return value
		}
	}
	if r.Method == http.MethodPost || r.Method == http.MethodDelete {
		var body map[string]any
		if err := json.NewDecoder(r.Body).Decode(&body); err == nil {
			for _, key := range []string{"file", "filename", "name"} {
				if value := stringValue(body[key]); value != "" {
					return value
				}
			}
		}
	}
	return ""
}

func sanitizeBackupFilename(filename string) (string, error) {
	filename = strings.TrimSpace(filename)
	if filename == "" {
		return "", errors.New("missing file")
	}
	if strings.Contains(filename, "/") || strings.Contains(filename, "\\") {
		return "", errors.New("invalid file")
	}
	if filename == "." || filename == ".." || !strings.HasSuffix(strings.ToLower(filename), ".zip") {
		return "", errors.New("invalid file")
	}
	return filename, nil
}

func safeJoin(root, rel string) (string, error) {
	normalized := normalizeArchivePath(rel)
	if normalized == "" {
		return "", errors.New("invalid path")
	}
	rootAbs, err := filepath.Abs(root)
	if err != nil {
		return "", err
	}
	fullAbs, err := filepath.Abs(filepath.Join(rootAbs, filepath.FromSlash(normalized)))
	if err != nil {
		return "", err
	}
	if fullAbs != rootAbs && !strings.HasPrefix(fullAbs, rootAbs+string(os.PathSeparator)) {
		return "", errors.New("path escapes data directory")
	}
	return fullAbs, nil
}

func normalizeArchivePath(name string) string {
	name = strings.ReplaceAll(name, "\\", "/")
	name = strings.TrimPrefix(name, "/")
	cleaned := filepath.ToSlash(filepath.Clean(name))
	if cleaned == "." || cleaned == "" || strings.HasPrefix(cleaned, "../") || strings.Contains(cleaned, "/../") {
		return ""
	}
	return cleaned
}

func stringValue(v any) string {
	switch value := v.(type) {
	case string:
		return value
	case fmt.Stringer:
		return value.String()
	case nil:
		return ""
	default:
		return fmt.Sprint(value)
	}
}

func intValue(v any) int {
	switch value := v.(type) {
	case int:
		return value
	case int64:
		return int(value)
	case float64:
		return int(value)
	case json.Number:
		i, _ := value.Int64()
		return int(i)
	case string:
		if value == "true" {
			return 1
		}
	}
	return 0
}

func backupDir() string {
	return filepath.Join(dataDir, "backups")
}

func imageDir() string {
	return filepath.Join(dataDir, "images")
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("write json: %v", err)
	}
}

func corsMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Device-Id, X-Filename")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

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
	mux.HandleFunc("/api/sync/debug", syncDebugHandler)
	mux.HandleFunc("/api/backup/upload", backupUploadHandler)
	mux.HandleFunc("/api/backup/list", backupListHandler)
	mux.HandleFunc("/api/backup/download", backupDownloadHandler)
	mux.HandleFunc("/api/backup/delete", backupDeleteHandler)
	mux.HandleFunc("/api/images/download", imageDownloadHandler)
	mux.HandleFunc("/api/images/upload", imageUploadHandler)

	addr := fmt.Sprintf(":%s", *port)
	log.Printf("sync server listening on %s, data=%s", addr, dataDir)
	if err := http.ListenAndServe(addr, corsMiddleware(mux)); err != nil {
		log.Fatalf("serve: %v", err)
	}
}
