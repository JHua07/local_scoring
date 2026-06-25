package main

import (
	"archive/zip"
	"bytes"
	"database/sql"
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func makeTestZip(t *testing.T, reviewID string) []byte {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)

	tw, err := zw.Create("templates.json")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := tw.Write([]byte(`[]`)); err != nil {
		t.Fatal(err)
	}

	rw, err := zw.Create("food/data.json")
	if err != nil {
		t.Fatal(err)
	}
	reviews := `[{"id":"` + reviewID + `","category":"food","title":"test","createdAt":"2026-06-26T00:00:00Z","updatedAt":"2026-06-26T00:00:00Z","evaluations":[]}]`
	if _, err := rw.Write([]byte(reviews)); err != nil {
		t.Fatal(err)
	}

	iw, err := zw.Create("food/images/test.jpg")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := iw.Write([]byte{1, 2, 3, 4}); err != nil {
		t.Fatal(err)
	}

	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

func setupTestServer(t *testing.T) http.Handler {
	t.Helper()
	dataDir = t.TempDir()
	if err := initDB(dataDir); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		if db != nil {
			_ = db.Close()
			db = (*sql.DB)(nil)
		}
	})

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", healthHandler)
	mux.HandleFunc("/api/sync/push", syncPushHandler)
	mux.HandleFunc("/api/sync/pull", syncPullHandler)
	mux.HandleFunc("/api/sync/check", syncCheckHandler)
	mux.HandleFunc("/api/backup/upload", backupUploadHandler)
	mux.HandleFunc("/api/backup/list", backupListHandler)
	mux.HandleFunc("/api/backup/manifest", backupListHandler)
	mux.HandleFunc("/api/backup/download", backupDownloadHandler)
	mux.HandleFunc("/api/backup/delete", backupDeleteHandler)
	return corsMiddleware(mux)
}

func decodeJSON(t *testing.T, resp *http.Response) map[string]any {
	t.Helper()
	defer resp.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	return body
}

func TestBackupLifecycle(t *testing.T) {
	server := httptest.NewServer(setupTestServer(t))
	defer server.Close()

	for i := 0; i < 4; i++ {
		resp, err := http.Post(
			server.URL+"/api/sync/push",
			"application/zip",
			bytes.NewReader(makeTestZip(t, string(rune('a'+i)))),
		)
		if err != nil {
			t.Fatal(err)
		}
		body := decodeJSON(t, resp)
		if resp.StatusCode != http.StatusOK || body["ok"] != true {
			t.Fatalf("push %d failed: status=%d body=%v", i, resp.StatusCode, body)
		}
	}

	resp, err := http.Get(server.URL + "/api/backup/list")
	if err != nil {
		t.Fatal(err)
	}
	body := decodeJSON(t, resp)
	backups, ok := body["backups"].([]any)
	if !ok {
		t.Fatalf("missing backups list: %v", body)
	}
	if len(backups) != backupKeep {
		t.Fatalf("expected %d backups, got %d: %v", backupKeep, len(backups), body)
	}
	latest := backups[0].(map[string]any)["filename"].(string)
	if latest == "" {
		t.Fatalf("missing latest filename: %v", body)
	}

	resp, err = http.Get(server.URL + "/api/sync/check")
	if err != nil {
		t.Fatal(err)
	}
	check := decodeJSON(t, resp)
	if check["latestBackup"] != latest {
		t.Fatalf("check latest mismatch: latest=%s check=%v", latest, check)
	}

	resp, err = http.Get(server.URL + "/api/backup/download?file=" + latest)
	if err != nil {
		t.Fatal(err)
	}
	downloaded, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if resp.StatusCode != http.StatusOK || len(downloaded) == 0 || downloaded[0] != 'P' || downloaded[1] != 'K' {
		t.Fatalf("download failed: status=%d bytes=%d", resp.StatusCode, len(downloaded))
	}

	deleteBody := bytes.NewBufferString(`{"filename":"` + latest + `"}`)
	resp, err = http.Post(server.URL+"/api/backup/delete", "application/json", deleteBody)
	if err != nil {
		t.Fatal(err)
	}
	deleted := decodeJSON(t, resp)
	if deleted["ok"] != true || deleted["fileDeleted"] != true {
		t.Fatalf("delete failed: %v", deleted)
	}

	if _, err := os.Stat(filepath.Join(backupDir(), latest)); !os.IsNotExist(err) {
		t.Fatalf("backup file still exists after delete: %v", err)
	}

	resp, err = http.Get(server.URL + "/api/backup/list")
	if err != nil {
		t.Fatal(err)
	}
	afterDelete := decodeJSON(t, resp)
	backupsAfterDelete := afterDelete["backups"].([]any)
	if len(backupsAfterDelete) != backupKeep-1 {
		t.Fatalf("expected %d backups after delete, got %d: %v", backupKeep-1, len(backupsAfterDelete), afterDelete)
	}
}
