// Types mirror docs/API.md (v1 + v2).

export type UserBrief = {
  id: number;
  username: string;
  name: string;
  avatarUrl: string;
  isBusiness: boolean;
  verified: boolean;
};

export type BusinessCategory = "dress" | "tailor" | "boutique" | "designer" | "accessories";

export type Business = {
  category: BusinessCategory;
  phone: string;
  address: string;
  city: string;
  instagram: string;
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
  business: Business | null;
};

export type Me = Profile & { email: string };

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
  /** v3 (optional here): only "sale" products can go into the cart. */
  listingType?: "sale" | "rent" | "custom";
};

export type PinImage = { url: string; width: number; height: number; color: string };

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
