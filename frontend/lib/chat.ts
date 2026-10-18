// Chat helpers: previews, times and file sizes in Turkmen.

import type { Chat, Message } from "./types";

/** Chats seen in this tab, so a conversation header shows instantly while it refetches. */
export const chatCache = new Map<number, Chat>();

const MONTHS = ["ýanwar", "fewral", "mart", "aprel", "maý", "iýun", "iýul", "awgust", "sentýabr", "oktýabr", "noýabr", "dekabr"];

const startOfDay = (d: Date) => new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();

/** "Şu gün", "Düýn", "12 oktýabr", "3 mart 2025". */
export function dayLabel(iso: string, now = new Date()): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const diff = Math.round((startOfDay(now) - startOfDay(d)) / 86_400_000);
  if (diff === 0) return "Şu gün";
  if (diff === 1) return "Düýn";
  return `${d.getDate()} ${MONTHS[d.getMonth()]}${d.getFullYear() !== now.getFullYear() ? ` ${d.getFullYear()}` : ""}`;
}

export const sameDay = (a: string, b: string) => startOfDay(new Date(a)) === startOfDay(new Date(b));

/** "14:05". */
export function clock(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

/** Short relative time for the chat list: "şu wagt", "5 min", "3 sag", "2 gün", "3 hep", "12.03.25". */
export function shortAgo(iso: string, now = Date.now()): string {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "";
  const s = Math.max(0, Math.round((now - t) / 1000));
  if (s < 60) return "şu wagt";
  const m = Math.floor(s / 60);
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h} sag`;
  const d = Math.floor(h / 24);
  if (d < 7) return `${d} gün`;
  if (d < 35) return `${Math.floor(d / 7)} hep`;
  const x = new Date(t);
  return `${String(x.getDate()).padStart(2, "0")}.${String(x.getMonth() + 1).padStart(2, "0")}.${String(x.getFullYear()).slice(2)}`;
}

/** "1,2 MB", "340 KB". */
export function fileSize(n: number): string {
  if (!n || n < 0) return "";
  if (n < 1024) return `${n} B`;
  if (n < 1024 * 1024) return `${Math.round(n / 1024)} KB`;
  return `${(n / 1024 / 1024).toFixed(n < 10 * 1024 * 1024 ? 1 : 0).replace(".", ",")} MB`;
}

/** Extension badge for file cards: "PDF", "DOCX". */
export function fileExt(name: string): string {
  const m = /\.([a-z0-9]{1,5})$/i.exec(name);
  return m ? m[1].toUpperCase() : "FAÝL";
}

/** One-line preview of a message: "📷 Surat", "📎 file.pdf", "🔗 Post", "Bu habar pozuldy". */
export function messagePreview(m: Message | null, withMine = true): string {
  if (!m) return "";
  let body: string;
  if (m.deleted) body = "Bu habar pozuldy";
  else if (m.kind === "image") body = m.text ? `📷 ${m.text}` : "📷 Surat";
  else if (m.kind === "file") {
    const mt = m.attachment?.mimeType ?? "";
    const icon = mt.startsWith("video/") ? "🎬" : mt.startsWith("audio/") ? "🎵" : "📎";
    body = `${icon} ${m.attachment?.name || "Faýl"}`;
  } else if (m.kind === "pin") body = m.text ? `🔗 ${m.text}` : "🔗 Post";
  else body = m.text;
  body = body.replace(/\s+/g, " ").trim();
  return withMine && m.mine && !m.deleted ? `Siz: ${body}` : body;
}

/** Unique id for optimistic sends (crypto.randomUUID needs a secure context). */
export function newClientId(): string {
  try {
    if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") return crypto.randomUUID();
  } catch {
    /* insecure context */
  }
  return `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 10)}`;
}

export const CHAT_ACCEPT = [
  "image/jpeg", "image/png", "image/webp", "image/gif", "video/mp4", "video/webm",
  ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".zip", ".mp3", ".m4a", ".ogg",
].join(",");

const IMAGE = ["image/jpeg", "image/png", "image/webp", "image/gif"];
const VIDEO = ["video/mp4", "video/webm"];
const DOC_EXT = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "zip", "mp3", "m4a", "ogg"];

export const isImageFile = (f: File) => IMAGE.includes(f.type);

/** Client-side check mirroring the server rules; returns an error text or "". */
export function checkChatFile(f: File): string {
  const ext = (/\.([a-z0-9]+)$/i.exec(f.name)?.[1] ?? "").toLowerCase();
  const mb = f.size / 1024 / 1024;
  if (IMAGE.includes(f.type)) return mb > 20 ? `${f.name}: surat 20 MB-dan uly` : "";
  if (VIDEO.includes(f.type)) return mb > 60 ? `${f.name}: wideo 60 MB-dan uly` : "";
  if (DOC_EXT.includes(ext)) return mb > 20 ? `${f.name}: faýl 20 MB-dan uly` : "";
  return `${f.name}: bu görnüşli faýly ugradyp bolmaýar`;
}

/** Sorts newest activity first. */
export function sortChats(list: Chat[]): Chat[] {
  const t = (c: Chat) => new Date(c.lastMessage?.createdAt || c.updatedAt || 0).getTime() || 0;
  return [...list].sort((a, b) => t(b) - t(a));
}
