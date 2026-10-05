// Types mirror docs/API.md.

export type UserBrief = { id: number; username: string; name: string; avatarUrl: string };

export type Profile = UserBrief & {
  bio: string;
  followersCount: number;
  followingCount: number;
  pinsCount: number;
  isFollowing: boolean;
  isMe: boolean;
  createdAt: string;
};

export type Me = Profile & { email: string };

export type Pin = {
  id: number;
  title: string;
  description: string;
  link: string;
  category: string;
  tags: string[];
  imageUrl: string;
  width: number;
  height: number;
  color: string;
  author: UserBrief;
  likesCount: number;
  commentsCount: number;
  liked: boolean;
  savedBoardIds: number[];
  createdAt: string;
};

export type Board = {
  id: number;
  name: string;
  description: string;
  isPrivate: boolean;
  pinsCount: number;
  covers: string[];
  owner: UserBrief;
  createdAt: string;
};

export type Comment = { id: number; text: string; author: UserBrief; canDelete: boolean; createdAt: string };

export type NotificationType = "like" | "comment" | "follow" | "save";

export type Notification = {
  id: number;
  type: NotificationType;
  read: boolean;
  actor: UserBrief;
  pin?: { id: number; title: string; imageUrl: string };
  createdAt: string;
};

export type Category = { slug: string; name: string };

export type Page<T> = { items: T[]; page: number; limit: number; hasMore: boolean };

export type AuthResponse = { token: string; user: Me };
export type LikeState = { liked: boolean; likesCount: number };
