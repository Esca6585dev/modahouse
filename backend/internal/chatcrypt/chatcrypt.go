// Package chatcrypt encrypts chat messages and attachments at rest with
// AES-256-GCM. A database or disk dump alone does not reveal conversations.
//
// Text is stored as "enc1:" + base64(nonce|ciphertext); files start with the
// magic "MHENC1". Values without the marker are older plaintext and are
// returned as they are, so existing data keeps working until it is migrated.
package chatcrypt

import (
	"bytes"
	"context"
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"reflect"
	"strings"
	"sync"

	"gorm.io/gorm/schema"
)

const (
	textPrefix = "enc1:"
	fileMagic  = "MHENC1"
)

var (
	mu   sync.RWMutex
	aead cipher.AEAD
)

func init() {
	schema.RegisterSerializer("chatcrypt", serializer{})
}

// SetKey derives the AES key from secret. CHAT_ENCRYPTION_KEY is preferred;
// without it the JWT secret is used, so changing that secret makes old
// messages unreadable.
func SetKey(secret string) error {
	if secret == "" {
		return errors.New("chatcrypt: empty key")
	}
	sum := sha256.Sum256([]byte("modahouse-chat|" + secret))
	block, err := aes.NewCipher(sum[:])
	if err != nil {
		return err
	}
	g, err := cipher.NewGCM(block)
	if err != nil {
		return err
	}
	mu.Lock()
	aead = g
	mu.Unlock()
	return nil
}

func current() cipher.AEAD {
	mu.RLock()
	defer mu.RUnlock()
	if aead == nil {
		panic("chatcrypt: SetKey was not called")
	}
	return aead
}

func seal(plain []byte) []byte {
	g := current()
	nonce := make([]byte, g.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		panic(err)
	}
	return g.Seal(nonce, nonce, plain, nil)
}

func open(data []byte) ([]byte, error) {
	g := current()
	if len(data) < g.NonceSize() {
		return nil, errors.New("chatcrypt: short ciphertext")
	}
	return g.Open(nil, data[:g.NonceSize()], data[g.NonceSize():], nil)
}

// IsEncrypted reports whether a stored text value is already encrypted.
func IsEncrypted(s string) bool { return strings.HasPrefix(s, textPrefix) }

// EncryptText encrypts s; the empty string stays empty.
func EncryptText(s string) string {
	if s == "" || IsEncrypted(s) {
		return s
	}
	return textPrefix + base64.RawStdEncoding.EncodeToString(seal([]byte(s)))
}

// DecryptText reverses EncryptText; plaintext from before encryption passes through.
func DecryptText(s string) (string, error) {
	if !IsEncrypted(s) {
		return s, nil
	}
	raw, err := base64.RawStdEncoding.DecodeString(s[len(textPrefix):])
	if err != nil {
		return "", err
	}
	plain, err := open(raw)
	if err != nil {
		return "", err
	}
	return string(plain), nil
}

// EncryptFile returns data encrypted for storage on disk.
func EncryptFile(data []byte) []byte {
	return append([]byte(fileMagic), seal(data)...)
}

// IsEncryptedFile reports whether file contents came from EncryptFile.
func IsEncryptedFile(data []byte) bool { return bytes.HasPrefix(data, []byte(fileMagic)) }

// DecryptFile reverses EncryptFile; files saved before encryption pass through.
func DecryptFile(data []byte) ([]byte, error) {
	if !IsEncryptedFile(data) {
		return data, nil
	}
	return open(data[len(fileMagic):])
}

// serializer lets models mark string fields with `gorm:"serializer:chatcrypt"`.
type serializer struct{}

func (serializer) Scan(ctx context.Context, field *schema.Field, dst reflect.Value, dbValue any) error {
	var s string
	switch v := dbValue.(type) {
	case nil:
	case string:
		s = v
	case []byte:
		s = string(v)
	default:
		return fmt.Errorf("chatcrypt: unsupported value %T", dbValue)
	}
	plain, err := DecryptText(s)
	if err != nil {
		plain = "" // wrong key or damaged row: never leak ciphertext to clients
	}
	return field.Set(ctx, dst, plain)
}

func (serializer) Value(ctx context.Context, field *schema.Field, dst reflect.Value, fieldValue any) (any, error) {
	s, _ := fieldValue.(string)
	return EncryptText(s), nil
}
