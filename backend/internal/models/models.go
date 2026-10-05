// Package models defines the database schema.
package models

import "time"

type User struct {
	ID           uint   `gorm:"primaryKey"`
	Username     string `gorm:"size:30;uniqueIndex;not null"`
	Name         string `gorm:"size:60;not null"`
	Email        string `gorm:"size:120;uniqueIndex;not null"`
	PasswordHash string `gorm:"not null"`
	Bio          string `gorm:"size:300"`
	AvatarURL    string `gorm:"size:255"`
	// Tokens issued before this moment are rejected (set on password change).
	TokensValidAfter time.Time
	CreatedAt        time.Time
}

type Pin struct {
	ID          uint   `gorm:"primaryKey"`
	UserID      uint   `gorm:"index;not null"`
	User        User   `gorm:"constraint:OnDelete:CASCADE"`
	Title       string `gorm:"size:100;not null"`
	Description string `gorm:"size:1000"`
	Link        string `gorm:"size:500"`
	Category    string `gorm:"size:30;index"`
	Tags        string `gorm:"size:300"` // comma separated
	ImageURL    string `gorm:"size:255;not null"`
	Width       int
	Height      int
	Color       string    `gorm:"size:9"`
	SearchText  string    `gorm:"type:text;index"` // lower-cased title+description+tags for portable search
	CreatedAt   time.Time `gorm:"index"`
	UpdatedAt   time.Time
}

type Board struct {
	ID          uint   `gorm:"primaryKey"`
	UserID      uint   `gorm:"index;not null"`
	User        User   `gorm:"constraint:OnDelete:CASCADE"`
	Name        string `gorm:"size:50;not null"`
	Description string `gorm:"size:300"`
	IsPrivate   bool
	CreatedAt   time.Time
}

type BoardPin struct {
	BoardID   uint  `gorm:"primaryKey"`
	PinID     uint  `gorm:"primaryKey;index"`
	Board     Board `gorm:"constraint:OnDelete:CASCADE"`
	Pin       Pin   `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt time.Time
}

type Like struct {
	UserID    uint `gorm:"primaryKey"`
	PinID     uint `gorm:"primaryKey;index"`
	User      User `gorm:"constraint:OnDelete:CASCADE"`
	Pin       Pin  `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt time.Time
}

type Comment struct {
	ID        uint   `gorm:"primaryKey"`
	PinID     uint   `gorm:"index;not null"`
	UserID    uint   `gorm:"index;not null"`
	Pin       Pin    `gorm:"constraint:OnDelete:CASCADE"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	Text      string `gorm:"size:500;not null"`
	CreatedAt time.Time
}

type Follow struct {
	FollowerID  uint `gorm:"primaryKey"`
	FollowingID uint `gorm:"primaryKey;index"`
	Follower    User `gorm:"constraint:OnDelete:CASCADE"`
	Following   User `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt   time.Time
}

const (
	NotifyLike    = "like"
	NotifyComment = "comment"
	NotifyFollow  = "follow"
	NotifySave    = "save"
)

type Notification struct {
	ID        uint   `gorm:"primaryKey"`
	UserID    uint   `gorm:"index;not null"` // recipient
	ActorID   uint   `gorm:"not null"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	Actor     User   `gorm:"constraint:OnDelete:CASCADE"`
	Type      string `gorm:"size:20;not null"`
	PinID     *uint
	Pin       *Pin  `gorm:"constraint:OnDelete:CASCADE"`
	CommentID *uint `gorm:"index"`
	Read      bool  `gorm:"index"`
	CreatedAt time.Time
}

func All() []any {
	return []any{&User{}, &Pin{}, &Board{}, &BoardPin{}, &Like{}, &Comment{}, &Follow{}, &Notification{}}
}
