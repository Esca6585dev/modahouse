// Package models defines the database schema.
package models

import (
	"time"

	_ "github.com/esca6585dev/modahouse/backend/internal/chatcrypt" // registers the chatcrypt serializer
)

type User struct {
	ID           uint   `gorm:"primaryKey"`
	Username     string `gorm:"size:30;uniqueIndex;not null"`
	Name         string `gorm:"size:60;not null"`
	Email        string `gorm:"size:120;uniqueIndex;not null"`
	PasswordHash string `gorm:"not null"`
	Bio          string `gorm:"size:300"`
	AvatarURL    string `gorm:"size:255"`
	IsBusiness   bool   `gorm:"index"`
	// Category is the profile's craft, e.g. tailor, lashes, nails (see api.ProfileCategories).
	Category  string `gorm:"size:20;index"`
	Verified  bool
	IsAdmin   bool `gorm:"index"`
	Suspended bool `gorm:"index"` // cannot log in; tokens are rejected
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
	Color       string `gorm:"size:9"`
	SearchText  string `gorm:"type:text;index"` // lower-cased title+description+tags for portable search
	// Product fields; a pin is a product when Price > 0 and its author is a business.
	ListingType  string `gorm:"size:10;index"` // post, sale, rent, custom ("" = legacy: sale when priced)
	Price        int    `gorm:"index"`
	Deposit      int    // rent: deposit
	MinDays      int    // rent: minimum days
	ReadyDays    int    // custom: days to make
	OldPrice     int
	Colors       string `gorm:"type:text"` // JSON array of {name, hex}
	Sizes        string `gorm:"size:300"`  // comma separated
	Stock        *int   // nil = not tracked
	DeliveryDays int
	ReturnDays   int
	Material     string `gorm:"size:100"`
	ViewsCount   int
	OrdersCount  int
	HasVideo     bool       `gorm:"index"`
	Credit       string     `gorm:"size:300"` // photo credit of imported, openly licensed photos
	Images       []PinImage `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt    time.Time  `gorm:"index"`
	UpdatedAt    time.Time
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
	NotifyOrder       = "order"
	NotifyOrderStatus = "order_status"
	NotifyReview      = "review"
	NotifyLike        = "like"
	NotifyComment     = "comment"
	NotifyFollow      = "follow"
	NotifySave        = "save"
)

type Notification struct {
	ID          uint   `gorm:"primaryKey"`
	UserID      uint   `gorm:"index;not null"` // recipient
	ActorID     uint   `gorm:"not null"`
	User        User   `gorm:"constraint:OnDelete:CASCADE"`
	Actor       User   `gorm:"constraint:OnDelete:CASCADE"`
	Type        string `gorm:"size:20;not null"`
	PinID       *uint
	Pin         *Pin   `gorm:"constraint:OnDelete:CASCADE"`
	CommentID   *uint  `gorm:"index"`
	OrderID     *uint  `gorm:"index"`
	OrderStatus string `gorm:"size:20"` // order status at the time of the event
	Read        bool   `gorm:"index"`
	CreatedAt   time.Time
}

// Business holds the professional profile of a user with IsBusiness set.
type Business struct {
	UserID       uint   `gorm:"primaryKey"`
	User         User   `gorm:"constraint:OnDelete:CASCADE"`
	Category     string `gorm:"size:20;index"`
	Phone        string `gorm:"size:20"`
	Address      string `gorm:"size:200"`
	City         string `gorm:"size:60"`
	Instagram    string `gorm:"size:60"`
	Tiktok       string `gorm:"size:60"`
	Telegram     string `gorm:"size:60"`
	Whatsapp     string `gorm:"size:20"`
	Imo          string `gorm:"size:20"`
	Youtube      string `gorm:"size:120"`
	Website      string `gorm:"size:200"`
	WorkingHours string `gorm:"size:60"`
	DeliveryDays int
	ReturnDays   int
	CreatedAt    time.Time
}

type PinImage struct {
	ID        uint   `gorm:"primaryKey"`
	PinID     uint   `gorm:"index;not null"`
	Kind      string `gorm:"size:10"` // image (default) or video
	PosterURL string `gorm:"size:255"`
	Duration  float64
	URL       string `gorm:"size:255;not null"`
	Width     int
	Height    int
	Color     string `gorm:"size:9"`
	Position  int
	// Watermarked: the stored file already carries the ModaHouse logo.
	Watermarked bool
}

// PinView records one view per viewer (user id or hashed IP) per day.
type PinView struct {
	PinID  uint      `gorm:"primaryKey"`
	Viewer string    `gorm:"primaryKey;size:64"`
	Day    time.Time `gorm:"primaryKey;type:date"`
	Pin    Pin       `gorm:"constraint:OnDelete:CASCADE"`
}

type CartItem struct {
	ID        uint   `gorm:"primaryKey"`
	UserID    uint   `gorm:"index;not null"`
	PinID     uint   `gorm:"index;not null"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	Pin       Pin    `gorm:"constraint:OnDelete:CASCADE"`
	Color     string `gorm:"size:40"`
	Size      string `gorm:"size:20"`
	Quantity  int
	CreatedAt time.Time
}

const (
	OrderNew       = "new"
	OrderConfirmed = "confirmed"
	OrderShipped   = "shipped"
	OrderDelivered = "delivered"
	OrderCancelled = "cancelled"
)

type Order struct {
	ID         uint   `gorm:"primaryKey"`
	BuyerID    uint   `gorm:"index;not null"`
	BusinessID uint   `gorm:"index;not null"`
	Buyer      User   `gorm:"constraint:OnDelete:CASCADE"`
	Business   User   `gorm:"constraint:OnDelete:CASCADE"`
	Status     string `gorm:"size:20;index"`
	Total      int
	FullName   string      `gorm:"size:80"`
	Phone      string      `gorm:"size:20"`
	Address    string      `gorm:"size:300"`
	Note       string      `gorm:"size:500"`
	Items      []OrderItem `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt  time.Time   `gorm:"index"`
	UpdatedAt  time.Time
}

// OrderItem is a snapshot so orders survive product edits and deletion.
type OrderItem struct {
	ID       uint   `gorm:"primaryKey"`
	OrderID  uint   `gorm:"index;not null"`
	PinID    *uint  `gorm:"index"`
	Title    string `gorm:"size:100"`
	ImageURL string `gorm:"size:255"`
	Price    int
	Color    string `gorm:"size:40"`
	Size     string `gorm:"size:20"`
	Quantity int
}

type Review struct {
	ID         uint   `gorm:"primaryKey"`
	PinID      uint   `gorm:"uniqueIndex:idx_review_pin_user;not null"`
	UserID     uint   `gorm:"uniqueIndex:idx_review_pin_user;not null"`
	BusinessID uint   `gorm:"index;not null"`
	Pin        Pin    `gorm:"constraint:OnDelete:CASCADE"`
	User       User   `gorm:"constraint:OnDelete:CASCADE"`
	Rating     int    `gorm:"not null"`
	Text       string `gorm:"size:1000"`
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

type Story struct {
	ID        uint   `gorm:"primaryKey"`
	UserID    uint   `gorm:"index;not null"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	ImageURL  string `gorm:"size:255;not null"` // image, or poster for a video story
	VideoURL  string `gorm:"size:255"`
	Width     int
	Height    int
	Color     string `gorm:"size:9"`
	Caption   string `gorm:"size:200"`
	PinID     *uint
	CreatedAt time.Time
	ExpiresAt time.Time `gorm:"index"`
}

type StoryView struct {
	StoryID   uint  `gorm:"primaryKey"`
	UserID    uint  `gorm:"primaryKey"`
	Story     Story `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt time.Time
}

type Report struct {
	ID        uint   `gorm:"primaryKey"`
	PinID     uint   `gorm:"index;not null"`
	UserID    uint   `gorm:"index;not null"`
	Pin       Pin    `gorm:"constraint:OnDelete:CASCADE"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	Reason    string `gorm:"size:20"`
	Note      string `gorm:"size:300"`
	CreatedAt time.Time
}

// HiddenPin: "not interested" — the pin no longer shows in the user's feeds.
type HiddenPin struct {
	UserID    uint `gorm:"primaryKey"`
	PinID     uint `gorm:"primaryKey"`
	User      User `gorm:"constraint:OnDelete:CASCADE"`
	Pin       Pin  `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt time.Time
}

type Block struct {
	BlockerID uint `gorm:"primaryKey"`
	BlockedID uint `gorm:"primaryKey;index"`
	Blocker   User `gorm:"constraint:OnDelete:CASCADE"`
	Blocked   User `gorm:"constraint:OnDelete:CASCADE"`
	CreatedAt time.Time
}

// PinFeature stores the visual-search descriptor of a pin's cover image.
type PinFeature struct {
	PinID   uint `gorm:"primaryKey"`
	Pin     Pin  `gorm:"constraint:OnDelete:CASCADE"`
	Version int
	Data    []byte
}

func All() []any {
	return []any{&User{}, &Pin{}, &Board{}, &BoardPin{}, &Like{}, &Comment{}, &Follow{}, &Notification{},
		&Business{}, &PinImage{}, &PinView{}, &CartItem{}, &Order{}, &OrderItem{}, &Review{}, &Story{}, &StoryView{},
		&Report{}, &HiddenPin{}, &Block{}, &PinFeature{}, &Setting{}, &Chat{}, &Message{}, &Interest{}, &SearchLog{}}
}

// Setting is an admin-editable key/value pair (see api.AppConfig).
type Setting struct {
	Key       string `gorm:"primaryKey;size:50"`
	Value     string `gorm:"type:text"`
	UpdatedAt time.Time
}

// Chat is a one-to-one conversation. UserAID < UserBID, so a pair has one chat.
type Chat struct {
	ID        uint `gorm:"primaryKey"`
	UserAID   uint `gorm:"uniqueIndex:idx_chat_pair;not null"`
	UserBID   uint `gorm:"uniqueIndex:idx_chat_pair;index;not null"`
	UserA     User `gorm:"foreignKey:UserAID;constraint:OnDelete:CASCADE"`
	UserB     User `gorm:"foreignKey:UserBID;constraint:OnDelete:CASCADE"`
	ReadA     uint // last message id read by UserA
	ReadB     uint // last message id read by UserB
	LastID    uint // last message id (0 = no messages yet)
	CreatedAt time.Time
	UpdatedAt time.Time `gorm:"index"`
}

// Message is one chat message: text, an attachment (private file) or a shared pin.
type Message struct {
	ID        uint   `gorm:"primaryKey"`
	ChatID    uint   `gorm:"index;not null"`
	Chat      Chat   `gorm:"constraint:OnDelete:CASCADE"`
	SenderID  uint   `gorm:"index;not null"`
	Sender    User   `gorm:"constraint:OnDelete:CASCADE"`
	Kind      string `gorm:"size:10;not null"`               // text, image, file, pin
	Text      string `gorm:"type:text;serializer:chatcrypt"` // encrypted at rest (chatcrypt)
	File      string `gorm:"size:80"`                        // private file name under uploads/.private/chat (encrypted)
	FileName  string `gorm:"type:text;serializer:chatcrypt"`
	FileMime  string `gorm:"size:100"`
	FileSize  int64
	Width     int
	Height    int
	PinID     *uint  `gorm:"index"`
	Pin       *Pin   `gorm:"constraint:OnDelete:SET NULL"`
	ClientID  string `gorm:"size:64"`
	Deleted   bool
	CreatedAt time.Time
}

// Interest is how much a user cares about a category or a tag, learned from
// what they view, like, save, buy and search. Scores fade with a 30-day half-life.
type Interest struct {
	UserID    uint   `gorm:"primaryKey"`
	Kind      string `gorm:"primaryKey;size:10"` // category, tag
	Key       string `gorm:"primaryKey;size:60;index"`
	User      User   `gorm:"constraint:OnDelete:CASCADE"`
	Score     float64
	UpdatedAt time.Time
}

// SearchLog keeps the text searches for admin analytics.
type SearchLog struct {
	ID        uint   `gorm:"primaryKey"`
	UserID    *uint  `gorm:"index"`
	User      *User  `gorm:"constraint:OnDelete:SET NULL"`
	Query     string `gorm:"size:100;index"`
	Results   int
	CreatedAt time.Time `gorm:"index"`
}
