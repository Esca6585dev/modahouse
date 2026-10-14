// Tiny typed client for the ModaHouse REST API. All calls go to the same origin (/api/...);
// the route handler in app/api/[...path] proxies them to the Go backend at BACKEND_URL (read at runtime).

import type {
  AdminReport, AdminStats, AdminUser, AdminUserFilter, AppConfig, AuthResponse, Board, BusinessCard, BusinessInput, BusinessStats, Cart, Category, ColorOption, Comment, LikeState, Me,
  ListingType, Notification, Order, OrderInput, OrderStatus, Page, Pin, PinImage, Profile, ReportReason, Review, ReviewsPage,
  SearchResult, StatsPeriod, Story, StoryGroup, Suggestion, TopEntry, UrlCheck, UserBrief, VisualResult,
} from "./types";

const TOKEN_KEY = "mh_token";
export const UNAUTHORIZED_EVENT = "mh:unauthorized";

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

export function getToken(): string | null {
  try {
    return typeof window === "undefined" ? null : window.localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setToken(token: string | null) {
  try {
    if (token) window.localStorage.setItem(TOKEN_KEY, token);
    else window.localStorage.removeItem(TOKEN_KEY);
  } catch {
    /* storage unavailable: session only lasts for this page */
  }
}

type Options = { method?: string; body?: unknown; form?: FormData; signal?: AbortSignal };

function fallbackMessage(status: number): string {
  switch (status) {
    case 401: return "Ilki ulgama giriň";
    case 403: return "Bu hereket üçin rugsadyňyz ýok";
    case 404: return "Tapylmady";
    case 413: return "Faýl gaty uly";
    case 429: return "Haýyşlar gaty köp. Birazdan gaýtadan synanyşyň";
    default: return status >= 500 ? "Serwerde ýalňyşlyk ýüze çykdy" : "Ýalňyşlyk ýüze çykdy";
  }
}

export async function request<T>(path: string, opts: Options = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: "application/json" };
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  let body: BodyInit | undefined;
  if (opts.form) {
    body = opts.form;
  } else if (opts.body !== undefined) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(opts.body);
  }

  let res: Response;
  try {
    res = await fetch(`/api${path}`, { method: opts.method ?? "GET", headers, body, signal: opts.signal, cache: "no-store" });
  } catch (e) {
    if ((e as Error).name === "AbortError") throw e;
    throw new ApiError("Serwer bilen baglanyşyk ýok. Internedi barlaň", 0);
  }

  if (res.status === 204) return undefined as T;
  const text = await res.text();
  let data: unknown = undefined;
  if (text) {
    try {
      data = JSON.parse(text);
    } catch {
      data = undefined;
    }
  }
  if (!res.ok) {
    const msg = data && typeof data === "object" && "error" in data && typeof (data as { error: unknown }).error === "string"
      ? (data as { error: string }).error
      : fallbackMessage(res.status);
    if (res.status === 401 && token) window.dispatchEvent(new Event(UNAUTHORIZED_EVENT));
    throw new ApiError(msg, res.status);
  }
  return data as T;
}

const qs = (params: Record<string, string | number | undefined | null>) => {
  const s = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) if (v !== undefined && v !== null && v !== "") s.set(k, String(v));
  const str = s.toString();
  return str ? `?${str}` : "";
};

const enc = encodeURIComponent;
export const PAGE_SIZE = 24;

// ---------- normalization ----------
// Fill v2 fields with safe defaults so the UI also works against an older backend.

function normUser<T extends Partial<UserBrief>>(u: T): T & UserBrief {
  return { ...u, isBusiness: !!u.isBusiness, verified: !!u.verified } as T & UserBrief;
}

export function normPin(p: Pin): Pin {
  const images: PinImage[] = (Array.isArray(p.images) && p.images.length
    ? p.images
    : [{ url: p.imageUrl, width: p.width, height: p.height, color: p.color } as PinImage]
  ).map((im) => ({
    ...im,
    type: im.type === "video" ? "video" : "image",
    posterUrl: im.posterUrl ?? "",
    duration: im.duration ?? 0,
  }));
  const product = p.product
    ? {
      ...p.product,
      oldPrice: p.product.oldPrice ?? 0,
      colors: p.product.colors ?? [],
      sizes: p.product.sizes ?? [],
      stock: p.product.stock ?? null,
      deliveryDays: p.product.deliveryDays ?? 0,
      returnDays: p.product.returnDays ?? 0,
      material: p.product.material ?? "",
      badge: p.product.badge ?? "",
      listingType: p.product.listingType ?? "sale",
      deposit: p.product.deposit ?? 0,
      minDays: p.product.minDays ?? 0,
      readyDays: p.product.readyDays ?? 0,
    }
    : null;
  return {
    ...p,
    tags: p.tags ?? [],
    savedBoardIds: p.savedBoardIds ?? [],
    images,
    mediaType: p.mediaType ?? images[0].type,
    product,
    viewsCount: p.viewsCount ?? 0,
    ordersCount: p.ordersCount ?? 0,
    rating: p.rating ?? 0,
    reviewsCount: p.reviewsCount ?? 0,
    author: normUser(p.author),
  };
}

export function normProfile<T extends Profile>(p: T): T {
  const b = p.business;
  return {
    ...normUser(p),
    hasStory: !!p.hasStory,
    storySeen: !!p.storySeen,
    isBlocked: !!p.isBlocked,
    business: b
      ? {
        ...b,
        tiktok: b.tiktok ?? "", telegram: b.telegram ?? "", whatsapp: b.whatsapp ?? "", imo: b.imo ?? "",
        youtube: b.youtube ?? "", website: b.website ?? "", instagram: b.instagram ?? "",
      }
      : null,
  };
}

const pinPage = (pg: Page<Pin>): Page<Pin> => ({ ...pg, items: (pg.items ?? []).map(normPin) });
const userPage = (pg: Page<UserBrief>): Page<UserBrief> => ({ ...pg, items: (pg.items ?? []).map(normUser) });
const meRes = (m: Me): Me => ({ ...normProfile(m), isAdmin: !!m.isAdmin });
const authRes = (r: AuthResponse): AuthResponse => ({ ...r, user: meRes(r.user) });

function normConfig(c: Partial<AppConfig>): AppConfig {
  return { apiUrl: c.apiUrl ?? "", webUrl: c.webUrl ?? "", registrationOpen: c.registrationOpen ?? true, updatedAt: c.updatedAt ?? "" };
}

function normAdminUser(u: AdminUser): AdminUser {
  return {
    ...u, email: u.email ?? "", avatarUrl: u.avatarUrl ?? "", pinsCount: u.pinsCount ?? 0,
    isAdmin: !!u.isAdmin, isBusiness: !!u.isBusiness, verified: !!u.verified, suspended: !!u.suspended,
  };
}

function normReport(r: AdminReport): AdminReport {
  return { ...r, pin: { ...r.pin, author: normUser(r.pin.author) }, reasons: r.reasons ?? [], lastNote: r.lastNote ?? "", count: r.count ?? 0 };
}

export type PinsQuery = {
  q?: string;
  category?: string;
  feed?: string;
  type?: "products" | "ideas" | "videos";
  author?: string;
  tag?: string;
  withComments?: boolean;
  page: number;
  limit?: number;
};

export type ProductUpdate = {
  listingType?: ListingType;
  deposit?: number;
  minDays?: number;
  readyDays?: number;
  price?: number;
  oldPrice?: number;
  stock?: number | null;
  deliveryDays?: number;
  returnDays?: number;
  material?: string;
  colors?: ColorOption[];
  sizes?: string[];
};

export const api = {
  categories: () => request<Category[]>("/categories"),

  // auth
  register: (b: { username: string; name: string; email: string; password: string }) =>
    request<AuthResponse>("/auth/register", { method: "POST", body: b }).then(authRes),
  login: (b: { login: string; password: string }) =>
    request<AuthResponse>("/auth/login", { method: "POST", body: b }).then(authRes),
  me: () => request<Me>("/me").then(meRes),

  // current user
  updateMe: (b: { name?: string; bio?: string; username?: string }) => request<Me>("/me", { method: "PUT", body: b }).then(meRes),
  changePassword: (b: { currentPassword: string; newPassword: string }) =>
    // Revokes every older token; the response carries the new one.
    request<AuthResponse>("/me/password", { method: "PUT", body: b }).then(authRes),
  uploadAvatar: (file: File) => {
    const f = new FormData();
    f.append("avatar", file);
    return request<Me>("/me/avatar", { method: "POST", form: f }).then(meRes);
  },
  deleteAvatar: () => request<Me>("/me/avatar", { method: "DELETE" }).then(meRes),
  myBoards: () => request<Board[]>("/me/boards"),

  // users
  user: (u: string) => request<Profile>(`/users/${enc(u)}`).then(normProfile),
  userPins: (u: string, page: number) => request<Page<Pin>>(`/users/${enc(u)}/pins${qs({ page, limit: PAGE_SIZE })}`).then(pinPage),
  userBoards: (u: string) => request<Board[]>(`/users/${enc(u)}/boards`),
  followers: (u: string, page: number) => request<Page<UserBrief>>(`/users/${enc(u)}/followers${qs({ page, limit: 30 })}`).then(userPage),
  following: (u: string, page: number) => request<Page<UserBrief>>(`/users/${enc(u)}/following${qs({ page, limit: 30 })}`).then(userPage),
  follow: (u: string) => request<Profile>(`/users/${enc(u)}/follow`, { method: "POST" }).then(normProfile),
  unfollow: (u: string) => request<Profile>(`/users/${enc(u)}/follow`, { method: "DELETE" }).then(normProfile),

  // pins
  pins: ({ limit, withComments, ...p }: PinsQuery) =>
    request<Page<Pin>>(`/pins${qs({ ...p, withComments: withComments ? 1 : undefined, limit: limit ?? PAGE_SIZE })}`).then(pinPage),
  createPin: (form: FormData) => request<Pin>("/pins", { method: "POST", form }).then(normPin),
  pin: (id: number | string) => request<Pin>(`/pins/${enc(String(id))}`).then(normPin),
  updatePin: (id: number, b: { title?: string; description?: string; link?: string; category?: string; tags?: string } & ProductUpdate) =>
    request<Pin>(`/pins/${id}`, { method: "PUT", body: b }).then(normPin),
  deletePin: (id: number) => request<void>(`/pins/${id}`, { method: "DELETE" }),
  similar: (id: number, page: number) => request<Page<Pin>>(`/pins/${id}/similar${qs({ page, limit: PAGE_SIZE })}`).then(pinPage),
  like: (id: number) => request<LikeState>(`/pins/${id}/like`, { method: "POST" }),
  unlike: (id: number) => request<LikeState>(`/pins/${id}/like`, { method: "DELETE" }),
  viewPin: (id: number) => request<{ viewsCount: number }>(`/pins/${id}/view`, { method: "POST" }),
  comments: (id: number, page: number) => request<Page<Comment>>(`/pins/${id}/comments${qs({ page, limit: 30 })}`),
  addComment: (id: number, text: string) => request<Comment>(`/pins/${id}/comments`, { method: "POST", body: { text } }),
  deleteComment: (id: number) => request<void>(`/comments/${id}`, { method: "DELETE" }),

  // reviews
  reviews: (pinId: number, page: number) => request<ReviewsPage>(`/pins/${pinId}/reviews${qs({ page, limit: 10 })}`),
  addReview: (pinId: number, b: { rating: number; text?: string }) =>
    request<Review>(`/pins/${pinId}/reviews`, { method: "POST", body: b }),
  deleteReview: (id: number) => request<void>(`/reviews/${id}`, { method: "DELETE" }),

  // boards
  createBoard: (b: { name: string; description?: string; isPrivate?: boolean }) =>
    request<Board>("/boards", { method: "POST", body: b }),
  board: (id: number | string) => request<Board>(`/boards/${enc(String(id))}`),
  updateBoard: (id: number, b: { name?: string; description?: string; isPrivate?: boolean }) =>
    request<Board>(`/boards/${id}`, { method: "PUT", body: b }),
  deleteBoard: (id: number) => request<void>(`/boards/${id}`, { method: "DELETE" }),
  boardPins: (id: number, page: number) => request<Page<Pin>>(`/boards/${id}/pins${qs({ page, limit: PAGE_SIZE })}`).then(pinPage),
  savePin: (boardId: number, pinId: number) => request<Pin>(`/boards/${boardId}/pins/${pinId}`, { method: "POST" }).then(normPin),
  unsavePin: (boardId: number, pinId: number) =>
    request<Pin | undefined>(`/boards/${boardId}/pins/${pinId}`, { method: "DELETE" }).then((p) => (p ? normPin(p) : p)),

  // notifications
  notifications: (page: number) => request<Page<Notification>>(`/notifications${qs({ page, limit: 30 })}`),
  unreadCount: () => request<{ count: number }>("/notifications/unread-count"),
  readAll: () => request<void>("/notifications/read-all", { method: "POST" }),

  // business account
  openBusiness: (b: BusinessInput) => request<Me>("/me/business", { method: "POST", body: b }).then(meRes),
  updateBusiness: (b: Partial<BusinessInput>) => request<Me>("/me/business", { method: "PUT", body: b }).then(meRes),
  closeBusiness: () => request<Me>("/me/business", { method: "DELETE" }).then(meRes),
  businessStats: (period: StatsPeriod) => request<BusinessStats>(`/business/stats${qs({ period })}`),
  businesses: (p: { q?: string; category?: string; page: number; limit?: number }) =>
    request<Page<BusinessCard>>(`/businesses${qs({ ...p, limit: p.limit ?? PAGE_SIZE })}`),
  top: (p: { period: StatsPeriod; category?: string; limit?: number }) =>
    request<TopEntry[]>(`/top${qs({ ...p, limit: p.limit ?? 10 })}`),

  // cart
  cart: () => request<Cart>("/cart"),
  cartCount: () => request<{ count: number }>("/cart/count"),
  addToCart: (b: { pinId: number; color?: string; size?: string; quantity?: number }) =>
    request<Cart>("/cart", { method: "POST", body: b }),
  updateCartItem: (id: number, quantity: number) => request<Cart>(`/cart/${id}`, { method: "PUT", body: { quantity } }),
  removeCartItem: (id: number) => request<Cart>(`/cart/${id}`, { method: "DELETE" }),
  clearCart: () => request<Cart>("/cart", { method: "DELETE" }),

  // orders
  createOrder: (b: OrderInput) => request<Order[]>("/orders", { method: "POST", body: b }),
  orders: (p: { status?: OrderStatus | ""; page: number }) => request<Page<Order>>(`/orders${qs({ ...p, limit: 20 })}`),
  order: (id: number | string) => request<Order>(`/orders/${enc(String(id))}`),
  cancelOrder: (id: number) => request<Order>(`/orders/${id}/cancel`, { method: "POST" }),
  businessOrders: (p: { status?: OrderStatus | ""; page: number }) =>
    request<Page<Order>>(`/business/orders${qs({ ...p, limit: 20 })}`),
  setOrderStatus: (id: number, status: OrderStatus) =>
    request<Order>(`/business/orders/${id}`, { method: "PUT", body: { status } }),

  // stories
  stories: () => request<StoryGroup[]>("/stories"),
  userStories: (u: string) => request<StoryGroup>(`/users/${enc(u)}/stories`),
  createStory: (form: FormData) => request<Story>("/stories", { method: "POST", form }),
  viewStory: (id: number) => request<void>(`/stories/${id}/view`, { method: "POST" }),
  deleteStory: (id: number) => request<void>(`/stories/${id}`, { method: "DELETE" }),

  // v3: discovery
  businessCategories: () => request<Category[]>("/business-categories"),
  search: (q: string) =>
    request<SearchResult>(`/search${qs({ q })}`).then((r) => ({ users: (r.users ?? []).map(normUser), tags: r.tags ?? [] })),
  myLikes: (page: number) => request<Page<Pin>>(`/me/likes${qs({ page, limit: PAGE_SIZE })}`).then(pinPage),
  searchImage: (form: FormData) =>
    request<VisualResult>("/search/image", { method: "POST", form }).then(visualRes),
  visual: (id: number, products: boolean) =>
    request<VisualResult>(`/pins/${id}/visual${qs({ type: products ? "products" : undefined, limit: 40 })}`).then(visualRes),

  // v3: moderation
  report: (id: number, reason: ReportReason, note?: string) =>
    request<void>(`/pins/${id}/report`, { method: "POST", body: { reason, note: note || undefined } }),
  hidePin: (id: number) => request<void>(`/pins/${id}/hide`, { method: "POST" }),
  unhidePin: (id: number) => request<void>(`/pins/${id}/hide`, { method: "DELETE" }),
  block: (u: string) => request<{ blocked: boolean }>(`/users/${enc(u)}/block`, { method: "POST" }),
  unblock: (u: string) => request<{ blocked: boolean }>(`/users/${enc(u)}/block`, { method: "DELETE" }),
  myBlocks: () => request<UserBrief[]>("/me/blocks").then((l) => (l ?? []).map(normUser)),

  // v3: AI writing assistant
  aiStatus: () => request<{ enabled: boolean }>("/ai/status"),
  aiSuggest: (form: FormData) => request<Suggestion>("/ai/suggest", { method: "POST", form }),

  // v4: public app config
  config: () => request<AppConfig>("/config").then(normConfig),

  // v4: admin panel (admins only, otherwise 403)
  admin: {
    stats: () => request<AdminStats>("/admin/stats"),
    settings: () => request<AppConfig>("/admin/settings").then(normConfig),
    updateSettings: (b: Partial<Pick<AppConfig, "apiUrl" | "webUrl" | "registrationOpen">>) =>
      request<AppConfig>("/admin/settings", { method: "PUT", body: b }).then(normConfig),
    checkUrl: (url: string) => request<UrlCheck>("/admin/check-url", { method: "POST", body: { url } }),
    users: (p: { q?: string; filter?: AdminUserFilter; page: number; limit?: number }) =>
      request<Page<AdminUser>>(`/admin/users${qs({ ...p, limit: p.limit ?? 30 })}`)
        .then((pg) => ({ ...pg, items: (pg.items ?? []).map(normAdminUser) })),
    updateUser: (id: number, b: Partial<Pick<AdminUser, "isAdmin" | "verified" | "suspended">>) =>
      request<AdminUser>(`/admin/users/${id}`, { method: "PUT", body: b }).then(normAdminUser),
    reports: (page: number, limit = 20) =>
      request<Page<AdminReport>>(`/admin/reports${qs({ page, limit })}`)
        .then((pg) => ({ ...pg, items: (pg.items ?? []).map(normReport) })),
    dismissReports: (pinId: number) => request<void>(`/admin/reports/${pinId}`, { method: "DELETE" }),
    deletePin: (id: number) => request<void>(`/admin/pins/${id}`, { method: "DELETE" }),
  },
};

function visualRes(r: VisualResult): VisualResult {
  return { ...r, items: (r.items ?? []).map(normPin), scores: r.scores ?? [], category: r.category ?? "" };
}

export function errorMessage(e: unknown): string {
  if (e instanceof Error && e.message) return e.message;
  return "Ýalňyşlyk ýüze çykdy";
}

/** Only allow same-site relative redirect targets. */
export function safeNext(next: string | null | undefined, fallback = "/"): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
  return next;
}
