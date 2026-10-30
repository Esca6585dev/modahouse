import type { Category, ReportReason } from "./types";

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

/** Fallback list; the live one comes from GET /business-categories (useBusinessCategories). */
export const BUSINESS_CATEGORIES: { value: string; label: string }[] = [
  { value: "tailor", label: "Tikinçi" },
  { value: "kurte", label: "Kürte tikinçi" },
  { value: "atelier", label: "Atelýe" },
  { value: "designer", label: "Dizaýner" },
  { value: "embroidery", label: "El keşdeçi" },
  { value: "dress", label: "Köýnek dükany" },
  { value: "boutique", label: "Butik" },
  { value: "bridal", label: "Gelin salony" },
  { value: "rental", label: "Kärende salony" },
  { value: "fata", label: "Fata satyjy" },
  { value: "beauty", label: "Gözellik salony" },
  { value: "hair", label: "Saç ussasy" },
  { value: "makeup", label: "Makiýažçy" },
  { value: "lashes", label: "Kirpikçi" },
  { value: "nails", label: "Dyrnakçy" },
  { value: "jewelry", label: "Şaý-sep ussasy" },
  { value: "accessories", label: "Aksessuarlar" },
];

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

export const LISTING_TYPES = [
  { value: "post", label: "Diňe paýlaşmak", hint: "Ideýa ýa-da surat" },
  { value: "sale", label: "Satlyk", hint: "Sebet we sargyt" },
  { value: "rent", label: "Kärende", hint: "Günlük baha, girew" },
  { value: "custom", label: "Sargyt bilen tikmek", hint: "…-dan başlap, möhlet" },
] as const;

/** Main price line for a product, depending on its listing type. */
export function priceLabel(p: { price: number; listingType?: string }): string {
  if (p.listingType === "rent") return `${money(p.price)} / gün`;
  if (p.listingType === "custom") return `${money(p.price)}-dan`;
  return money(p.price);
}

/** "1:05" style video length. */
export function duration(sec: number): string {
  if (!sec || sec < 0) return "";
  const s = Math.round(sec);
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
}

/** Digits (and a leading +) of a phone number for tel:/wa.me links. */
export function phoneDigits(phone: string): string {
  return phone.replace(/[^\d+]/g, "");
}

/** Report reasons (POST /pins/:id/report), shared by the post menu and the admin panel. */
export const REPORT_REASONS: { value: ReportReason; label: string; hint: string }[] = [
  { value: "spam", label: "Spam", hint: "Mahabat, gaýtalanýan ýa-da aldaw" },
  { value: "inappropriate", label: "Ýerliksiz mazmun", hint: "Kemsidiji, zorlukly ýa-da açyk" },
  { value: "copyright", label: "Awtorlyk hukugy", hint: "Meniň suratym rugsatsyz ulanylýar" },
  { value: "fake", label: "Ýalan haryt", hint: "Galp ýa-da aldawly bildiriş" },
  { value: "other", label: "Başga sebäp", hint: "Gysgaça ýazyň" },
];

export function reportReasonLabel(r: string): string {
  return REPORT_REASONS.find((x) => x.value === r)?.label ?? r;
}
