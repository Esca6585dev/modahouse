package api

import (
	"time"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

type UserBrief struct {
	ID         uint   `json:"id"`
	Username   string `json:"username"`
	Name       string `json:"name"`
	AvatarURL  string `json:"avatarUrl"`
	IsBusiness bool   `json:"isBusiness"`
	Verified   bool   `json:"verified"`
}

type Profile struct {
	UserBrief
	Bio            string       `json:"bio"`
	FollowersCount int64        `json:"followersCount"`
	FollowingCount int64        `json:"followingCount"`
	PinsCount      int64        `json:"pinsCount"`
	IsFollowing    bool         `json:"isFollowing"`
	IsMe           bool         `json:"isMe"`
	CreatedAt      time.Time    `json:"createdAt"`
	HasStory       bool         `json:"hasStory"`
	StorySeen      bool         `json:"storySeen"`
	IsBlocked      bool         `json:"isBlocked"` // the viewer blocked this user
	Business       *BusinessDTO `json:"business"`
}

type BusinessDTO struct {
	Category      string  `json:"category"`
	Phone         string  `json:"phone"`
	Address       string  `json:"address"`
	City          string  `json:"city"`
	Instagram     string  `json:"instagram"`
	Tiktok        string  `json:"tiktok"`
	Telegram      string  `json:"telegram"`
	Whatsapp      string  `json:"whatsapp"`
	Imo           string  `json:"imo"`
	Youtube       string  `json:"youtube"`
	Website       string  `json:"website"`
	WorkingHours  string  `json:"workingHours"`
	DeliveryDays  int     `json:"deliveryDays"`
	ReturnDays    int     `json:"returnDays"`
	Rating        float64 `json:"rating"`
	ReviewsCount  int64   `json:"reviewsCount"`
	OrdersCount   int64   `json:"ordersCount"`
	ProductsCount int64   `json:"productsCount"`
}

type BusinessCard struct {
	UserBrief
	Category       string   `json:"category"`
	City           string   `json:"city"`
	Rating         float64  `json:"rating"`
	ReviewsCount   int64    `json:"reviewsCount"`
	FollowersCount int64    `json:"followersCount"`
	ProductsCount  int64    `json:"productsCount"`
	IsFollowing    bool     `json:"isFollowing"`
	HasStory       bool     `json:"hasStory"`
	Covers         []string `json:"covers"`
}

type TopEntry struct {
	Rank      int          `json:"rank"`
	Business  BusinessCard `json:"business"`
	Score     int          `json:"score"`
	Views     int64        `json:"views"`
	Likes     int64        `json:"likes"`
	Orders    int64        `json:"orders"`
	MoreCount int64        `json:"moreCount"`
}

type ColorOption struct {
	Name string `json:"name"`
	Hex  string `json:"hex"`
}

type ProductDTO struct {
	ListingType  string        `json:"listingType"` // sale, rent, custom
	Deposit      int           `json:"deposit"`
	MinDays      int           `json:"minDays"`
	ReadyDays    int           `json:"readyDays"`
	Price        int           `json:"price"`
	OldPrice     int           `json:"oldPrice"`
	Colors       []ColorOption `json:"colors"`
	Sizes        []string      `json:"sizes"`
	Stock        *int          `json:"stock"`
	DeliveryDays int           `json:"deliveryDays"`
	ReturnDays   int           `json:"returnDays"`
	Material     string        `json:"material"`
	Badge        string        `json:"badge"`
}

type PinImageDTO struct {
	Type      string  `json:"type"` // image or video
	PosterURL string  `json:"posterUrl"`
	Duration  float64 `json:"duration"`
	URL       string  `json:"url"`
	Width     int     `json:"width"`
	Height    int     `json:"height"`
	Color     string  `json:"color"`
}

type Me struct {
	Profile
	Email   string `json:"email"`
	IsAdmin bool   `json:"isAdmin"`
}

type PinDTO struct {
	ID             uint          `json:"id"`
	Title          string        `json:"title"`
	Description    string        `json:"description"`
	Link           string        `json:"link"`
	Category       string        `json:"category"`
	Tags           []string      `json:"tags"`
	ImageURL       string        `json:"imageUrl"`
	Width          int           `json:"width"`
	Height         int           `json:"height"`
	Color          string        `json:"color"`
	Author         UserBrief     `json:"author"`
	LikesCount     int64         `json:"likesCount"`
	CommentsCount  int64         `json:"commentsCount"`
	Liked          bool          `json:"liked"`
	SavedBoardIDs  []uint        `json:"savedBoardIds"`
	Images         []PinImageDTO `json:"images"`
	Product        *ProductDTO   `json:"product"`
	LatestComments []CommentDTO  `json:"latestComments,omitempty"`
	MediaType      string        `json:"mediaType"` // image or video (the cover)
	ViewsCount     int           `json:"viewsCount"`
	OrdersCount    int           `json:"ordersCount"`
	Rating         float64       `json:"rating"`
	ReviewsCount   int64         `json:"reviewsCount"`
	CreatedAt      time.Time     `json:"createdAt"`
}

type BoardDTO struct {
	ID          uint      `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	IsPrivate   bool      `json:"isPrivate"`
	PinsCount   int64     `json:"pinsCount"`
	Covers      []string  `json:"covers"`
	Owner       UserBrief `json:"owner"`
	CreatedAt   time.Time `json:"createdAt"`
}

type CommentDTO struct {
	ID        uint      `json:"id"`
	Text      string    `json:"text"`
	Author    UserBrief `json:"author"`
	CanDelete bool      `json:"canDelete"`
	CreatedAt time.Time `json:"createdAt"`
}

type NotificationDTO struct {
	ID        uint        `json:"id"`
	Type      string      `json:"type"`
	Read      bool        `json:"read"`
	Actor     UserBrief   `json:"actor"`
	Pin       *PinBrief   `json:"pin,omitempty"`
	Order     *OrderBrief `json:"order,omitempty"`
	CreatedAt time.Time   `json:"createdAt"`
}

type OrderBrief struct {
	ID            uint   `json:"id"`
	Status        string `json:"status"`        // status this notification is about
	CurrentStatus string `json:"currentStatus"` // the order's status now
	Total         int    `json:"total"`
	Role          string `json:"role"` // the recipient is the "buyer" or the "seller"
}

type PinBrief struct {
	ID       uint   `json:"id"`
	Title    string `json:"title"`
	ImageURL string `json:"imageUrl"`
}

func brief(u models.User) UserBrief {
	return UserBrief{ID: u.ID, Username: u.Username, Name: u.Name, AvatarURL: u.AvatarURL, IsBusiness: u.IsBusiness, Verified: u.Verified}
}
