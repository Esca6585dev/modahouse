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
