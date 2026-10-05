# ModaHouse REST API

Base URL: `http://localhost:8080/api`. All bodies are JSON unless marked multipart.
Errors always look like `{"error": "Türkmençe habar"}` with a matching HTTP status
(400 validation, 401 not logged in / bad login, 403 not owner, 404 not found, 409 conflict).

Auth: send `Authorization: Bearer <token>` (JWT, valid 30 days). Endpoints marked 🔒 need it.
Without a token, viewer-specific fields (`liked`, `savedBoardIds`, `isFollowing`, `canDelete`) are false/empty.

Image URLs (`imageUrl`, `avatarUrl`, `covers[]`) are **relative paths** like `/uploads/pins/abc.jpg`.
Prefix them with the server origin (`http://localhost:8080`). Empty `avatarUrl` means "no avatar":
show the first letter of `name` instead. Seed images are SVG files.

Paginated lists accept `?page=1&limit=24` (limit max 50) and return
`{"items": [...], "page": 1, "limit": 24, "hasMore": true}`.

Demo accounts (password `modahouse123`): `aylar.studio`, `ic.bezeg`, `tagam.tm`, `gezelenc`, `renk.lab`, `yasyl.burc`.

## Types

```ts
type UserBrief = { id: number; username: string; name: string; avatarUrl: string };
type Profile = UserBrief & {
  bio: string; followersCount: number; followingCount: number; pinsCount: number;
  isFollowing: boolean; isMe: boolean; createdAt: string;
};
type Me = Profile & { email: string };
type Pin = {
  id: number; title: string; description: string; link: string;
  category: string;            // category slug
  tags: string[]; imageUrl: string;
  width: number; height: number; // pixel size, use for aspect ratio in masonry
  color: string;               // placeholder background while the image loads
  author: UserBrief; likesCount: number; commentsCount: number;
  liked: boolean;              // viewer liked it
  savedBoardIds: number[];     // viewer's boards that contain this pin (empty = not saved)
  createdAt: string;
};
type Board = {
  id: number; name: string; description: string; isPrivate: boolean;
  pinsCount: number; covers: string[]; // up to 3 latest pin image URLs
  owner: UserBrief; createdAt: string;
};
type Comment = { id: number; text: string; author: UserBrief; canDelete: boolean; createdAt: string };
type Notification = {
  id: number; type: "like" | "comment" | "follow" | "save"; read: boolean;
  actor: UserBrief; pin?: { id: number; title: string; imageUrl: string }; createdAt: string;
};
type Category = { slug: string; name: string };
```

## Endpoints

### Misc
| Method | Path | Body / query | Response |
|---|---|---|---|
| GET | `/health` | | `{status:"ok"}` |
| GET | `/categories` | | `Category[]` (moda, ic-bezeg, tagamlar, syyahat, sungat, osumlikler) |

### Auth
| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/auth/register` | `{username, name, email, password}` | 201 `{token, user: Me}`. Username: `^[a-z0-9._]{3,30}$`, password ≥ 6. A default board "Saklananlar" is created. |
| POST | `/auth/login` | `{login, password}` (login = username or email) | `{token, user: Me}` |
| GET 🔒 | `/auth/me` | | `Me` |

### Current user 🔒
| Method | Path | Body | Response |
|---|---|---|---|
| PUT | `/me` | `{name?, bio?, username?}` | `Me` |
| GET | `/me` | | `Me` (same as `/auth/me`) |
| PUT | `/me/password` | `{currentPassword, newPassword}` | `{token, user: Me}`. All older tokens stop working: store the new token. |
| POST | `/me/avatar` | multipart field `avatar` (jpg/png/gif/webp) | `Me` |
| DELETE | `/me/avatar` | | `Me` |
| GET | `/me/boards` | | `Board[]` incl. private (use for the "save to board" picker) |

### Users
| Method | Path | Response |
|---|---|---|
| GET | `/users/:username` | `Profile` |
| GET | `/users/:username/pins` | `Page<Pin>` pins the user created |
| GET | `/users/:username/boards` | `Board[]` (private ones only for the owner) |
| GET | `/users/:username/followers` | `Page<UserBrief>` |
| GET | `/users/:username/following` | `Page<UserBrief>` |
| POST 🔒 | `/users/:username/follow` | `Profile` (updated) |
| DELETE 🔒 | `/users/:username/follow` | `Profile` |

### Pins
| Method | Path | Body / query | Response |
|---|---|---|---|
| GET | `/pins` | `?q=&category=<slug>&feed=following&page&limit` (`feed=following` needs 🔒) | `Page<Pin>` newest first |
| POST 🔒 | `/pins` | **multipart**: `image` (file, required), `title` (required), `category` (required slug), `description`, `link` (http/https), `tags` (comma separated), `boardId` (optional, save into own board) | 201 `Pin` |
| GET | `/pins/:id` | | `Pin` |
| PUT 🔒 | `/pins/:id` | `{title?, description?, link?, category?, tags?}` (owner only) | `Pin` |
| DELETE 🔒 | `/pins/:id` | owner only | 204 |
| GET | `/pins/:id/similar` | `?page&limit` | `Page<Pin>` same category first |
| POST 🔒 | `/pins/:id/like` | | `{liked, likesCount}` |
| DELETE 🔒 | `/pins/:id/like` | | `{liked, likesCount}` |
| GET | `/pins/:id/comments` | `?page&limit` | `Page<Comment>` oldest first |
| POST 🔒 | `/pins/:id/comments` | `{text}` (1..500) | 201 `Comment` |
| DELETE 🔒 | `/comments/:id` | comment author or pin owner | 204 |

### Boards
| Method | Path | Body | Response |
|---|---|---|---|
| POST 🔒 | `/boards` | `{name, description?, isPrivate?}` | 201 `Board` |
| GET | `/boards/:id` | | `Board` (404 if private and not owner) |
| PUT 🔒 | `/boards/:id` | `{name?, description?, isPrivate?}` | `Board` |
| DELETE 🔒 | `/boards/:id` | | 204 (pins themselves stay) |
| GET | `/boards/:id/pins` | `?page&limit` | `Page<Pin>` |
| POST 🔒 | `/boards/:id/pins/:pinId` | save pin into own board | `Pin` (updated `savedBoardIds`) |
| DELETE 🔒 | `/boards/:id/pins/:pinId` | remove from board | `Pin`, or 204 if the pin no longer exists |

### Notifications 🔒
| Method | Path | Response |
|---|---|---|
| GET | `/notifications` | `Page<Notification>` newest first |
| GET | `/notifications/unread-count` | `{count}` |
| POST | `/notifications/read-all` | 204 |

Notifications are created for the pin/user owner when someone likes, comments, saves (to a public board) or follows.
Undoing the action (unlike, unfollow, unsave, deleting the comment) removes the notification again.

Only `POST /auth/login` and `POST /auth/register` are rate limited (20 per minute per client IP).
