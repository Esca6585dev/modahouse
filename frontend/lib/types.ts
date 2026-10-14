// Types mirror docs/API.md (v1 + v2).

export type UserBrief = {
  id: number;
  username: string;
  name: string;
  avatarUrl: string;
  isBusiness: boolean;
  verified: boolean;
};

export type BusinessCategory =
  | "dress" | "tailor" | "atelier" | "bridal" | "rental" | "boutique" | "designer" | "jewelry" | "beauty" | "accessories";

export type Business = {
  category: BusinessCategory;
  phone: string;
  address: string;
  city: string;
  instagram: string;
  tiktok: string;
  telegram: string;
  whatsapp: string;
  imo: string;
  youtube: string;
  website: string;
  workingHours: string;
  deliveryDays: number;
  returnDays: number;
  rating: number;
  reviewsCount: number;
  ordersCount: number;
  productsCount: number;
};

export type Profile = UserBrief & {
  bio: string;
  followersCount: number;
  followingCount: number;
  pinsCount: number;
  isFollowing: boolean;
  isMe: boolean;
  createdAt: string;
  hasStory: boolean;
  storySeen: boolean;
  /** v3: I blocked this user. */
  isBlocked: boolean;
  business: Business | null;
};

export type Me = Profile & {
  email: string;
  /** v4: may open the admin panel (/admin). */
  isAdmin: boolean;
};

export type ColorOption = { name: string; hex: string };

export type ProductBadge = "" | "new" | "hit" | "sale";

export type Product = {
  price: number;
  oldPrice: number;
  colors: ColorOption[];
  sizes: string[];
  stock: number | null;
  deliveryDays: number;
  returnDays: number;
  material: string;
  badge: ProductBadge;
  /** Only "sale" products can go into the cart; rent/custom open a contact sheet. */
  listingType: ProductListingType;
  deposit: number;
  minDays: number;
  readyDays: number;
};

export type ProductListingType = "sale" | "rent" | "custom";
export type ListingType = "post" | ProductListingType;

export type PinImage = {
  type: "image" | "video";
  url: string;
  /** video: poster image ("" for images) */
  posterUrl: string;
  /** video: seconds (0 = unknown) */
  duration: number;
  width: number;
  height: number;
  color: string;
};

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
  images: PinImage[];
  mediaType: "image" | "video";
  /** only with ?withComments=1 */
  latestComments?: Comment[];
  product: Product | null;
  viewsCount: number;
  ordersCount: number;
  rating: number;
  reviewsCount: number;
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

export type OrderStatus = "new" | "confirmed" | "shipped" | "delivered" | "cancelled";

export type NotificationType = "like" | "comment" | "follow" | "save" | "order" | "order_status" | "review";

export type Notification = {
  id: number;
  type: NotificationType;
  read: boolean;
  actor: UserBrief;
  pin?: { id: number; title: string; imageUrl: string };
  order?: { id: number; status: OrderStatus; total: number };
  createdAt: string;
};

export type Category = { slug: string; name: string };

export type Page<T> = { items: T[]; page: number; limit: number; hasMore: boolean };

export type AuthResponse = { token: string; user: Me };
export type LikeState = { liked: boolean; likesCount: number };

// ---------- v2: business ----------

export type BusinessInput = {
  category: BusinessCategory;
  phone: string;
  address?: string;
  city?: string;
  instagram?: string;
  tiktok?: string;
  telegram?: string;
  whatsapp?: string;
  imo?: string;
  youtube?: string;
  website?: string;
  workingHours?: string;
  deliveryDays?: number;
  returnDays?: number;
};

export type StatsPeriod = "week" | "month" | "all";

export type BusinessStats = {
  views: number;
  likes: number;
  orders: number;
  revenue: number;
  pendingOrders: number;
  rating: number;
  reviewsCount: number;
  productsCount: number;
  followersCount: number;
};

export type BusinessCard = UserBrief & {
  category: BusinessCategory;
  city: string;
  rating: number;
  reviewsCount: number;
  followersCount: number;
  productsCount: number;
  hasStory: boolean;
  covers: string[];
};

export type TopEntry = {
  rank: number;
  business: BusinessCard;
  score: number;
  views: number;
  likes: number;
  orders: number;
  moreCount: number;
};

// ---------- v2: reviews ----------

export type Review = { id: number; rating: number; text: string; author: UserBrief; canDelete: boolean; createdAt: string };
export type ReviewsPage = Page<Review> & { rating: number; reviewsCount: number; canReview: boolean };

// ---------- v2: cart & orders ----------

export type CartItem = {
  id: number;
  quantity: number;
  color: string;
  size: string;
  pin: {
    id: number;
    title: string;
    imageUrl: string;
    color: string;
    price: number;
    oldPrice: number;
    stock: number | null;
    author: UserBrief;
  };
  lineTotal: number;
  available: boolean;
};

export type Cart = { items: CartItem[]; total: number; count: number };

export type OrderItem = {
  pinId: number | null;
  title: string;
  imageUrl: string;
  price: number;
  color: string;
  size: string;
  quantity: number;
};

export type Order = {
  id: number;
  status: OrderStatus;
  total: number;
  buyer: UserBrief;
  business: UserBrief;
  fullName: string;
  phone: string;
  address: string;
  note: string;
  items: OrderItem[];
  canCancel: boolean;
  nextStatuses: OrderStatus[];
  createdAt: string;
  updatedAt: string;
};

export type BuyNow = { pinId: number; color?: string; size?: string; quantity?: number };

export type OrderInput = {
  fullName: string;
  phone: string;
  address: string;
  note?: string;
  cartItemIds?: number[];
  buyNow?: BuyNow;
};

// ---------- v2: stories ----------

export type Story = {
  id: number;
  imageUrl: string;
  mediaType: "image" | "video";
  videoUrl: string;
  width: number;
  height: number;
  color: string;
  caption: string;
  pinId: number | null;
  seen: boolean;
  viewsCount: number;
  createdAt: string;
  expiresAt: string;
};

export type StoryGroup = { user: UserBrief; stories: Story[]; allSeen: boolean };

// ---------- v3 ----------

export type ReportReason = "spam" | "inappropriate" | "copyright" | "fake" | "other";

export type Suggestion = {
  title: string;
  description: string;
  hashtags: string[];
  category: string;
  priceLine: string;
  details: string[];
  source: "ai" | "template";
};

export type SearchResult = { users: UserBrief[]; tags: { tag: string; count: number }[] };

export type VisualResult = { items: Pin[]; scores: number[]; category: string; source: "local" | "ai+local" };

// ---------- v4: app config and admin panel ----------

export type AppConfig = {
  /** Public server origin for the apps, e.g. "https://api.modahouse.tm"; "" = keep the current one. */
  apiUrl: string;
  /** Public web address used in shared links; "" = client default. */
  webUrl: string;
  registrationOpen: boolean;
  /** ISO time of the last settings change ("" if never changed). */
  updatedAt: string;
};

export type AdminStats = {
  users: number; businesses: number; admins: number; suspended: number;
  pins: number; products: number; videos: number;
  comments: number; orders: number; openReports: number;
  newUsers7d: number; newPins7d: number;
};

export type AdminUser = {
  id: number; username: string; name: string; email: string; avatarUrl: string;
  isAdmin: boolean; isBusiness: boolean; verified: boolean; suspended: boolean;
  pinsCount: number; createdAt: string;
};

export type AdminUserFilter = "" | "admin" | "business" | "suspended";

export type AdminReport = {
  pin: { id: number; title: string; imageUrl: string; author: UserBrief };
  count: number;
  reasons: string[];
  lastNote: string;
  lastReportedAt: string;
};

export type UrlCheck = { ok: boolean; status: number; error: string };
