package api

import (
	"log"
	"os"

	"gorm.io/gorm"

	"github.com/esca6585dev/modahouse/backend/internal/chatcrypt"
	"github.com/esca6585dev/modahouse/backend/internal/storage"
)

// EncryptOldChats encrypts messages and attachments saved before chat
// encryption existed. It is safe to run on every start: encrypted rows and
// files are recognised and skipped. Call it after New, which sets the key.
func EncryptOldChats(db *gorm.DB, store *storage.Storage) {
	type row struct {
		ID       uint
		Text     string
		File     string
		FileName string
	}
	var texts, files int
	lastID := uint(0)
	for {
		var rows []row
		// Raw columns: the model's serializer would hide whether a row is encrypted.
		if err := db.Table("messages").Select("id, text, file, file_name").Where("id > ?", lastID).
			Order("id").Limit(500).Scan(&rows).Error; err != nil {
			log.Printf("chat encryption: %v", err)
			return
		}
		if len(rows) == 0 {
			break
		}
		for _, r := range rows {
			lastID = r.ID
			if (r.Text != "" && !chatcrypt.IsEncrypted(r.Text)) || (r.FileName != "" && !chatcrypt.IsEncrypted(r.FileName)) {
				db.Table("messages").Where("id = ?", r.ID).UpdateColumns(map[string]any{
					"text": chatcrypt.EncryptText(r.Text), "file_name": chatcrypt.EncryptText(r.FileName)})
				texts++
			}
			if r.File != "" && encryptChatFile(store, r.File) {
				files++
			}
		}
	}
	if texts+files > 0 {
		log.Printf("chat encryption: encrypted %d old messages and %d files", texts, files)
	}
}

func encryptChatFile(store *storage.Storage, name string) bool {
	path, ok := store.PrivatePath(storage.PrivateChat, name)
	if !ok {
		return false
	}
	data, err := os.ReadFile(path)
	if err != nil || chatcrypt.IsEncryptedFile(data) {
		return false
	}
	tmp := path + ".tmp"
	if os.WriteFile(tmp, chatcrypt.EncryptFile(data), 0o600) != nil || os.Rename(tmp, path) != nil {
		_ = os.Remove(tmp)
		return false
	}
	return true
}
