package api_test

import (
	"bytes"
	"io"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/gofiber/fiber/v3"

	"github.com/esca6585dev/modahouse/backend/internal/api"
	"github.com/esca6585dev/modahouse/backend/internal/chatcrypt"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

func TestChatEncryptedAtRest(t *testing.T) {
	e := newEnv(t, false)
	a, b := e.register("aygul"), e.register("bahar")
	var ch chatResp
	e.expect(201, "POST", "/api/chats", a.Token, map[string]string{"username": "bahar"}, &ch)
	path := "/api/chats/" + itoa(ch.ID) + "/messages"

	var txt, img msgResp
	e.expect(201, "POST", path, a.Token, map[string]string{"text": "Gizlin habar", "clientId": "c1"}, &txt)
	png := testPNG(64, 48)
	e.expect(201, "POST", path, a.Token, fileForm(t, "surat.png", png, "Seret"), &img)

	// The database holds only ciphertext.
	var row struct{ Text, FileName, File string }
	e.db.Table("messages").Select("text, file_name, file").Where("id = ?", txt.ID).Scan(&row)
	if !chatcrypt.IsEncrypted(row.Text) || strings.Contains(row.Text, "Gizlin") {
		t.Fatalf("text stored in clear: %q", row.Text)
	}
	e.db.Table("messages").Select("text, file_name, file").Where("id = ?", img.ID).Scan(&row)
	if !chatcrypt.IsEncrypted(row.FileName) || strings.Contains(row.FileName, "surat") {
		t.Fatalf("file name stored in clear: %q", row.FileName)
	}
	disk, err := os.ReadFile(filepath.Join(e.dir, filepath.FromSlash(storage.PrivateChat), row.File))
	if err != nil || !chatcrypt.IsEncryptedFile(disk) || bytes.Contains(disk, png[:16]) {
		t.Fatalf("file stored in clear (err %v)", err)
	}

	// The API still returns the plain text and the original file.
	var page struct {
		Items []msgResp `json:"items"`
	}
	e.expect(200, "GET", path, b.Token, nil, &page)
	found := false
	for _, m := range page.Items {
		found = found || m.Text == "Gizlin habar"
	}
	if !found {
		t.Fatalf("decrypted text missing: %+v", page.Items)
	}
	s, h, data := e.raw("GET", img.Attachment.URL, "", nil, "")
	if s != 200 || h["Content-Type"] != "image/png" || !bytes.Equal(data, png) {
		t.Fatalf("decrypted file: %d %v %d bytes", s, h, len(data))
	}
	// Range requests work on the decrypted bytes (video seeking).
	req := httptest.NewRequest("GET", img.Attachment.URL, nil)
	req.Header.Set("Range", "bytes=0-9")
	resp, err := e.app.Test(req, fiber.TestConfig{Timeout: 30 * time.Second})
	if err != nil {
		t.Fatal(err)
	}
	part, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != 206 || !bytes.Equal(part, png[:10]) {
		t.Fatalf("range: %d %d bytes", resp.StatusCode, len(part))
	}
}

func TestEncryptOldChats(t *testing.T) {
	e := newEnv(t, false)
	a := e.register("aygul")
	e.register("bahar")
	var ch chatResp
	e.expect(201, "POST", "/api/chats", a.Token, map[string]string{"username": "bahar"}, &ch)
	var m msgResp
	e.expect(201, "POST", "/api/chats/"+itoa(ch.ID)+"/messages", a.Token, map[string]string{"text": "x"}, &m)

	// Simulate a message and a file from before encryption.
	name := "0123456789abcdef01234567.png"
	png := testPNG(8, 8)
	if err := os.WriteFile(filepath.Join(e.dir, filepath.FromSlash(storage.PrivateChat), name), png, 0o600); err != nil {
		t.Fatal(err)
	}
	e.db.Table("messages").Where("id = ?", m.ID).UpdateColumns(map[string]any{"text": "köne habar", "file": name, "file_name": "a.png"})

	var page struct {
		Items []msgResp `json:"items"`
	}
	e.expect(200, "GET", "/api/chats/"+itoa(ch.ID)+"/messages", a.Token, nil, &page)
	if len(page.Items) == 0 || page.Items[len(page.Items)-1].Text != "köne habar" {
		t.Fatalf("legacy plaintext unreadable: %+v", page.Items)
	}

	api.EncryptOldChats(e.db, e.store)
	api.EncryptOldChats(e.db, e.store) // idempotent
	var row struct{ Text, FileName string }
	e.db.Table("messages").Select("text, file_name").Where("id = ?", m.ID).Scan(&row)
	if !chatcrypt.IsEncrypted(row.Text) || !chatcrypt.IsEncrypted(row.FileName) {
		t.Fatalf("not migrated: %+v", row)
	}
	if got, _ := chatcrypt.DecryptText(row.Text); got != "köne habar" {
		t.Fatalf("double encrypted? %q", got)
	}
	disk, _ := os.ReadFile(filepath.Join(e.dir, filepath.FromSlash(storage.PrivateChat), name))
	if plain, err := chatcrypt.DecryptFile(disk); !chatcrypt.IsEncryptedFile(disk) || err != nil || !bytes.Equal(plain, png) {
		t.Fatalf("file not migrated: %v", err)
	}
}
