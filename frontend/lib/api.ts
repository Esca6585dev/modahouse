// Tiny typed client for the ModaHouse REST API. All calls go to the same origin
// (/api/...), which next.config.ts rewrites to the Go backend.

import type {
  AuthResponse, Board, Category, Comment, LikeState, Me, Notification, Page, Pin, Profile, UserBrief,
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

export const api = {
  categories: () => request<Category[]>("/categories"),

  // auth
  register: (b: { username: string; name: string; email: string; password: string }) =>
    request<AuthResponse>("/auth/register", { method: "POST", body: b }),
  login: (b: { login: string; password: string }) => request<AuthResponse>("/auth/login", { method: "POST", body: b }),
  me: () => request<Me>("/me"),

  // current user
  updateMe: (b: { name?: string; bio?: string; username?: string }) => request<Me>("/me", { method: "PUT", body: b }),
  changePassword: (b: { currentPassword: string; newPassword: string }) =>
    // Revokes every older token; the response carries the new one.
    request<AuthResponse>("/me/password", { method: "PUT", body: b }),
  uploadAvatar: (file: File) => {
    const f = new FormData();
    f.append("avatar", file);
    return request<Me>("/me/avatar", { method: "POST", form: f });
  },
  deleteAvatar: () => request<Me>("/me/avatar", { method: "DELETE" }),
  myBoards: () => request<Board[]>("/me/boards"),

  // users
  user: (u: string) => request<Profile>(`/users/${enc(u)}`),
  userPins: (u: string, page: number) => request<Page<Pin>>(`/users/${enc(u)}/pins${qs({ page, limit: PAGE_SIZE })}`),
  userBoards: (u: string) => request<Board[]>(`/users/${enc(u)}/boards`),
  followers: (u: string, page: number) => request<Page<UserBrief>>(`/users/${enc(u)}/followers${qs({ page, limit: 30 })}`),
  following: (u: string, page: number) => request<Page<UserBrief>>(`/users/${enc(u)}/following${qs({ page, limit: 30 })}`),
  follow: (u: string) => request<Profile>(`/users/${enc(u)}/follow`, { method: "POST" }),
  unfollow: (u: string) => request<Profile>(`/users/${enc(u)}/follow`, { method: "DELETE" }),

  // pins
  pins: (p: { q?: string; category?: string; feed?: string; page: number }) =>
    request<Page<Pin>>(`/pins${qs({ ...p, limit: PAGE_SIZE })}`),
  createPin: (form: FormData) => request<Pin>("/pins", { method: "POST", form }),
  pin: (id: number | string) => request<Pin>(`/pins/${enc(String(id))}`),
  updatePin: (id: number, b: { title?: string; description?: string; link?: string; category?: string; tags?: string }) =>
    request<Pin>(`/pins/${id}`, { method: "PUT", body: b }),
  deletePin: (id: number) => request<void>(`/pins/${id}`, { method: "DELETE" }),
  similar: (id: number, page: number) => request<Page<Pin>>(`/pins/${id}/similar${qs({ page, limit: PAGE_SIZE })}`),
  like: (id: number) => request<LikeState>(`/pins/${id}/like`, { method: "POST" }),
  unlike: (id: number) => request<LikeState>(`/pins/${id}/like`, { method: "DELETE" }),
  comments: (id: number, page: number) => request<Page<Comment>>(`/pins/${id}/comments${qs({ page, limit: 30 })}`),
  addComment: (id: number, text: string) => request<Comment>(`/pins/${id}/comments`, { method: "POST", body: { text } }),
  deleteComment: (id: number) => request<void>(`/comments/${id}`, { method: "DELETE" }),

  // boards
  createBoard: (b: { name: string; description?: string; isPrivate?: boolean }) =>
    request<Board>("/boards", { method: "POST", body: b }),
  board: (id: number | string) => request<Board>(`/boards/${enc(String(id))}`),
  updateBoard: (id: number, b: { name?: string; description?: string; isPrivate?: boolean }) =>
    request<Board>(`/boards/${id}`, { method: "PUT", body: b }),
  deleteBoard: (id: number) => request<void>(`/boards/${id}`, { method: "DELETE" }),
  boardPins: (id: number, page: number) => request<Page<Pin>>(`/boards/${id}/pins${qs({ page, limit: PAGE_SIZE })}`),
  savePin: (boardId: number, pinId: number) => request<Pin>(`/boards/${boardId}/pins/${pinId}`, { method: "POST" }),
  unsavePin: (boardId: number, pinId: number) =>
    request<Pin | undefined>(`/boards/${boardId}/pins/${pinId}`, { method: "DELETE" }),

  // notifications
  notifications: (page: number) => request<Page<Notification>>(`/notifications${qs({ page, limit: 30 })}`),
  unreadCount: () => request<{ count: number }>("/notifications/unread-count"),
  readAll: () => request<void>("/notifications/read-all", { method: "POST" }),
};

export function errorMessage(e: unknown): string {
  if (e instanceof Error && e.message) return e.message;
  return "Ýalňyşlyk ýüze çykdy";
}

/** Only allow same-site relative redirect targets. */
export function safeNext(next: string | null | undefined, fallback = "/"): string {
  if (!next || !next.startsWith("/") || next.startsWith("//") || next.startsWith("/\\")) return fallback;
  return next;
}
