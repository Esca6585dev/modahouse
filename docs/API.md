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

---

# v2: Business accounts, shop, Top 10 and stories

Everything above still applies. This section adds an Instagram-style business layer on top of the
Pinterest-style pins. Money is in whole manats (TMT, integer). Payment is on delivery: there is no
online payment.

## Changed types

```ts
type UserBrief = {
  id: number; username: string; name: string; avatarUrl: string;
  isBusiness: boolean; verified: boolean;          // NEW
};

type Profile = UserBrief & {
  bio: string; followersCount: number; followingCount: number; pinsCount: number;
  isFollowing: boolean; isMe: boolean; createdAt: string;
  hasStory: boolean; storySeen: boolean;            // NEW: active story ring (seen by viewer?)
  business: Business | null;                        // NEW: set when isBusiness
};

type Business = {
  category: BusinessCategory;
  phone: string; address: string; city: string; instagram: string; workingHours: string;
  deliveryDays: number;   // default delivery time for new products
  returnDays: number;     // default return/exchange window
  rating: number;         // 0..5, average of all product reviews (0 = no reviews)
  reviewsCount: number; ordersCount: number; productsCount: number;
};
type BusinessCategory = "dress" | "tailor" | "boutique" | "designer" | "accessories";
// Turkmen labels: dress "Köýnek dükany", tailor "Tikinçi", boutique "Butik",
// designer "Dizaýner", accessories "Aksessuarlar"

type ColorOption = { name: string; hex: string };   // e.g. {name:"Gyzyl", hex:"#C62828"}

type Product = {
  price: number;            // TMT, > 0
  oldPrice: number;         // 0 = no discount; > price = discount
  colors: ColorOption[];    // may be empty
  sizes: string[];          // may be empty, e.g. ["42","44","46"]
  stock: number | null;     // null = not tracked (always available), 0 = out of stock
  deliveryDays: number; returnDays: number; material: string;
  badge: "" | "new" | "hit" | "sale";  // sale > hit > new; Turkmen: Täze, Hit!, Aksiýa
};

type PinImage = { url: string; width: number; height: number; color: string };

type Pin = {
  ...existing fields...,     // imageUrl/width/height/color stay = the cover (images[0])
  images: PinImage[];        // NEW: 1..8 images, first = cover (carousel "1/5")
  product: Product | null;   // NEW: set when the author is a business and price > 0
  viewsCount: number; ordersCount: number;      // NEW
  rating: number; reviewsCount: number;         // NEW: 0..5 average for this pin
  author: UserBrief;         // now carries isBusiness / verified
};

type Notification = {
  ...existing...,
  type: "like" | "comment" | "follow" | "save" | "order" | "order_status" | "review";
  order?: { id: number; status: OrderStatus; total: number };  // NEW for order types
};
```

New categories (prepended to `GET /categories`): `koynekler` (Köýnekler), `toy` (Toý köýnekleri),
`milli` (Milli eşikler), `aksessuarlar` (Aksessuarlar).

## Business account (Instagram-style "switch to professional account")

| Method | Path | Body | Response |
|---|---|---|---|
| POST 🔒 | `/me/business` | `{category, phone, address?, city?, instagram?, workingHours?, deliveryDays?, returnDays?}` | `Me` with `isBusiness: true` and `business` |
| PUT 🔒 | `/me/business` | same fields, all optional | `Me` |
| DELETE 🔒 | `/me/business` | | `Me` (back to a personal account; existing products stop being products) |
| GET 🔒 | `/business/stats` | `?period=week\|month\|all` | `{views, likes, orders, revenue, pendingOrders, rating, reviewsCount, productsCount, followersCount}` |
| GET | `/businesses` | `?q=&category=&page&limit` | `Page<BusinessCard>` |
| GET | `/top` | `?period=week\|month\|all&category=&limit=10` | `TopEntry[]` (max 10) |

`phone` is required (Turkmen mobile like `+993 61 234567`; 8 to 20 chars of digits, spaces, `+`, `-`).
`category` must be one of the BusinessCategory values.

```ts
type BusinessCard = UserBrief & {
  category: BusinessCategory; city: string; rating: number; reviewsCount: number;
  followersCount: number; productsCount: number; hasStory: boolean;
  covers: string[];          // up to 4 product image URLs
};
type TopEntry = {
  rank: number;              // 1..10
  business: BusinessCard;
  score: number;             // 0..100 "Umumy bal"
  views: number; likes: number; orders: number;   // within the period
  moreCount: number;         // productsCount - covers.length ("+5")
};
```

Score = 25% views + 25% likes + 35% orders (each relative to the best business in the period)
+ 15% rating/5, rounded to 0..100. Businesses with no products are not ranked.

## Products

Products are pins created by business accounts with a price.

- `POST /pins` (multipart) also accepts:
  - `images`: repeat the field for several files (max 8). `image` still works for a single file.
  - `price`, `oldPrice`, `stock` (empty = not tracked), `deliveryDays`, `returnDays`, `material`.
  - `colors`: JSON string, e.g. `[{"name":"Gyzyl","hex":"#C62828"}]`. `sizes`: comma separated, e.g. `42,44,46`.
  - Sending `price` > 0 from a personal account → 403.
- `PUT /pins/:id` (JSON) also accepts `price, oldPrice, stock (null = untracked), deliveryDays, returnDays, material, colors: ColorOption[], sizes: string[]`. Images are not editable.
- `GET /pins` also accepts `type=products` (only products) or `type=ideas` (only non-products), and `author=<username>`.
- `POST /pins/:id/view` → `{viewsCount}`. Counts once per viewer (user or IP) per day. Call it when a pin detail opens.

### Reviews

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/pins/:id/reviews` | `?page&limit` | `Page<Review>` newest first, plus top-level `rating`, `reviewsCount`, `canReview` |
| POST 🔒 | `/pins/:id/reviews` | `{rating: 1..5, text?}` | 201 `Review` (one per user per pin; posting again updates it). Only buyers with a **delivered** order containing this pin → otherwise 403 |
| DELETE 🔒 | `/reviews/:id` | author only | 204 |

```ts
type Review = { id: number; rating: number; text: string; author: UserBrief; canDelete: boolean; createdAt: string };
```

## Cart 🔒

```ts
type CartItem = {
  id: number; quantity: number; color: string; size: string;  // color = ColorOption.name
  pin: { id: number; title: string; imageUrl: string; color: string; price: number; oldPrice: number;
         stock: number | null; author: UserBrief };
  lineTotal: number;
  available: boolean;   // false when the product was removed, is no longer for sale or stock < quantity
};
type Cart = { items: CartItem[]; total: number; count: number };  // count = sum of quantities
```

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/cart` | | `Cart` |
| GET | `/cart/count` | | `{count}` |
| POST | `/cart` | `{pinId, color?, size?, quantity?}` (adds to an existing identical line) | `Cart` |
| PUT | `/cart/:id` | `{quantity}` (1..99) | `Cart` |
| DELETE | `/cart/:id` | | `Cart` |
| DELETE | `/cart` | | `Cart` (empty) |

`color`/`size` are required when the product has options and must be one of them (400 otherwise).
You cannot add your own product (400).

## Orders

```ts
type OrderStatus = "new" | "confirmed" | "shipped" | "delivered" | "cancelled";
// Turkmen: Täze, Tassyklandy, Ýolda, Gowşuryldy, Ýatyryldy
type Order = {
  id: number; status: OrderStatus; total: number;
  buyer: UserBrief; business: UserBrief;
  fullName: string; phone: string; address: string; note: string;
  items: { pinId: number | null; title: string; imageUrl: string; price: number;
           color: string; size: string; quantity: number }[];
  canCancel: boolean;          // buyer, status "new"
  nextStatuses: OrderStatus[]; // what the business may set next
  createdAt: string; updatedAt: string;
};
```

| Method | Path | Body | Response |
|---|---|---|---|
| POST 🔒 | `/orders` | `{fullName, phone, address, note?, cartItemIds?: number[], buyNow?: {pinId, color?, size?, quantity?}}` | 201 `Order[]` (one order per business) |
| GET 🔒 | `/orders` | `?status=&page&limit` | `Page<Order>` my purchases |
| GET 🔒 | `/orders/:id` | | `Order` (buyer or seller) |
| POST 🔒 | `/orders/:id/cancel` | | `Order` (buyer, only while "new") |
| GET 🔒 | `/business/orders` | `?status=&page&limit` | `Page<Order>` incoming orders |
| PUT 🔒 | `/business/orders/:id` | `{status}` | `Order`. Allowed: new→confirmed/cancelled, confirmed→shipped/cancelled, shipped→delivered |

Without `buyNow`, the order uses the cart lines in `cartItemIds` (default: all available lines) and
removes them from the cart. Stock is reserved when ordering and given back when an order is cancelled.
The business gets an `order` notification; the buyer gets `order_status` on every change.

## Stories (Instagram style, 24 hours)

```ts
type Story = { id: number; imageUrl: string; width: number; height: number; color: string;
               caption: string; pinId: number | null; seen: boolean; viewsCount: number; createdAt: string; expiresAt: string };
type StoryGroup = { user: UserBrief; stories: Story[]; allSeen: boolean };
```

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/stories` | | `StoryGroup[]`: own first, then followed users, then other businesses; unseen groups first |
| GET | `/users/:username/stories` | | `StoryGroup` (404 if none active) |
| POST 🔒 | `/stories` | multipart `image`, `caption?`, `pinId?` (link a product) | 201 `Story` |
| POST 🔒 | `/stories/:id/view` | | 204 |
| DELETE 🔒 | `/stories/:id` | owner | 204 |

`viewsCount` is only filled for the owner (0 for others).
