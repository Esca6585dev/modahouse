import type { Category } from "./types";

/** Relative time in Turkmen, e.g. "5 minut öň". */
export function timeAgo(iso: string, now = Date.now()): string {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "";
  const s = Math.max(0, Math.round((now - t) / 1000));
  if (s < 45) return "şu wagt";
  const m = Math.round(s / 60);
  if (m < 60) return `${m} minut öň`;
  const h = Math.round(m / 60);
  if (h < 24) return `${h} sagat öň`;
  const d = Math.round(h / 24);
  if (d < 7) return `${d} gün öň`;
  if (d < 30) return `${Math.round(d / 7)} hepde öň`;
  if (d < 365) return `${Math.max(1, Math.round(d / 30))} aý öň`;
  return `${Math.round(d / 365)} ýyl öň`;
}

/** Compact counts: 950, 1,2 müň, 12 müň, 1,4 mln. */
export function compact(n: number): string {
  if (n < 1000) return String(n);
  if (n < 1_000_000) {
    const v = n / 1000;
    return `${v < 10 ? v.toFixed(1).replace(".", ",").replace(",0", "") : Math.round(v)} müň`;
  }
  return `${(n / 1_000_000).toFixed(1).replace(".", ",").replace(",0", "")} mln`;
}

export function categoryName(slug: string, cats: Category[] | null | undefined): string {
  return cats?.find((c) => c.slug === slug)?.name ?? slug;
}

const AVATAR_COLORS = ["#d6336c", "#7a3e2b", "#c98a10", "#1b4965", "#4b3a73", "#2d6a4f", "#9c3d54", "#5e3b36"];

export function colorFor(key: string): string {
  let h = 0;
  for (const ch of key) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
  return AVATAR_COLORS[h % AVATAR_COLORS.length];
}

/** Whole numbers with a thin space between thousands: 12 450. */
export function num(n: number): string {
  const s = String(Math.round(Math.abs(n)));
  const grouped = s.replace(/\B(?=(\d{3})+(?!\d))/g, " ");
  return n < 0 ? `-${grouped}` : grouped;
}

/** Money in whole manats: "450 TMT". */
export function money(n: number): string {
  return `${num(n)} TMT`;
}

export function discountPercent(price: number, oldPrice: number): number {
  if (!oldPrice || oldPrice <= price) return 0;
  return Math.round(((oldPrice - price) / oldPrice) * 100);
}

export const BUSINESS_CATEGORIES = [
  { value: "dress", label: "Köýnek dükany" },
  { value: "tailor", label: "Tikinçi" },
  { value: "boutique", label: "Butik" },
  { value: "designer", label: "Dizaýner" },
  { value: "accessories", label: "Aksessuarlar" },
] as const;

export function businessCategoryLabel(c: string | undefined | null): string {
  return BUSINESS_CATEGORIES.find((x) => x.value === c)?.label ?? (c ?? "");
}

export const BADGE_LABEL: Record<string, string> = { new: "Täze", hit: "Hit!", sale: "Aksiýa" };

export const ORDER_STATUS_LABEL: Record<string, string> = {
  new: "Täze",
  confirmed: "Tassyklandy",
  shipped: "Ýolda",
  delivered: "Gowşuryldy",
  cancelled: "Ýatyryldy",
};

/** Button text for the business when moving an order to this status. */
export const ORDER_ACTION_LABEL: Record<string, string> = {
  confirmed: "Tassykla",
  shipped: "Ýola goý",
  delivered: "Gowşuryldy",
  cancelled: "Ýatyr",
};

export const PERIODS = [
  { value: "week", label: "Şu hepde" },
  { value: "month", label: "Şu aý" },
  { value: "all", label: "Hemişe" },
] as const;

/** "12 gün" style day counts. */
export function days(n: number): string {
  return `${n} gün`;
}

/** Date like "11.10.2026, 14:05". */
export function dateTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const p = (x: number) => String(x).padStart(2, "0");
  return `${p(d.getDate())}.${p(d.getMonth() + 1)}.${d.getFullYear()}, ${p(d.getHours())}:${p(d.getMinutes())}`;
}

/** Stock line for product pages. */
export function stockText(stock: number | null): string {
  if (stock === null) return "Bar";
  if (stock <= 0) return "Gutardy";
  return `Bar (${stock} sany)`;
}

/** Cart/checkout only accept "sale" listings (pins without a listing type are sales). */
export function isForSale(p: { listingType?: string } | null | undefined): boolean {
  return !!p && (!p.listingType || p.listingType === "sale");
}
