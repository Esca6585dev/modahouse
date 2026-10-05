package api

import (
	"time"

	"github.com/esca6585dev/modahouse/backend/internal/models"
)

type UserBrief struct {
	ID        uint   `json:"id"`
	Username  string `json:"username"`
	Name      string `json:"name"`
	AvatarURL string `json:"avatarUrl"`
}

type Profile struct {
	UserBrief
	Bio            string    `json:"bio"`
	FollowersCount int64     `json:"followersCount"`
	FollowingCount int64     `json:"followingCount"`
	PinsCount      int64     `json:"pinsCount"`
	IsFollowing    bool      `json:"isFollowing"`
	IsMe           bool      `json:"isMe"`
	CreatedAt      time.Time `json:"createdAt"`
}

type Me struct {
	Profile
	Email string `json:"email"`
}

type PinDTO struct {
	ID            uint      `json:"id"`
	Title         string    `json:"title"`
	Description   string    `json:"description"`
	Link          string    `json:"link"`
	Category      string    `json:"category"`
	Tags          []string  `json:"tags"`
	ImageURL      string    `json:"imageUrl"`
	Width         int       `json:"width"`
	Height        int       `json:"height"`
	Color         string    `json:"color"`
	Author        UserBrief `json:"author"`
	LikesCount    int64     `json:"likesCount"`
	CommentsCount int64     `json:"commentsCount"`
	Liked         bool      `json:"liked"`
	SavedBoardIDs []uint    `json:"savedBoardIds"`
	CreatedAt     time.Time `json:"createdAt"`
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
	ID        uint      `json:"id"`
	Type      string    `json:"type"`
	Read      bool      `json:"read"`
	Actor     UserBrief `json:"actor"`
	Pin       *PinBrief `json:"pin,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
}

type PinBrief struct {
	ID       uint   `json:"id"`
	Title    string `json:"title"`
	ImageURL string `json:"imageUrl"`
}

func brief(u models.User) UserBrief {
	return UserBrief{ID: u.ID, Username: u.Username, Name: u.Name, AvatarURL: u.AvatarURL}
}
