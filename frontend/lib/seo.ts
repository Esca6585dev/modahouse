// Server-side helpers for search engines: absolute site URL and backend reads.
// Used by sitemap.ts, robots.ts, the /fasonlar page and generateMetadata.

import { headers } from "next/headers";
import { backendOrigin } from "./proxy";
import type { Page, Pin, Profile } from "./types";

export const SITE_NAME = "ModaHouse";
export const SITE_DESCRIPTION =
  "Fasonlar we köýnek fasonlary: milli köýnekler, ştapel fasonlar, gelin we toý köýnekleri, ýaka fasonlary, el keşdeleri. " +
  "Tikinçiler, el keşdeçiler, kirpikçiler we dyrnakçylar bir ýerde.";
export const SITE_KEYWORDS = [
  "fasonlar", "fason", "köýnek fasonlary", "koynek fasonlar", "ştapel fasonlar", "stapel fasonlar", "milli köýnekler",
  "türkmen fasonlar", "gelin köýnekleri", "toý köýnekleri", "ýaka fasonlary", "el keşdeleri", "tikinçi", "ModaHouse",
];

/** Server fetch of the Go API (public data only), cached for revalidate seconds. */
export async function backendGet<T>(path: string, revalidate = 600): Promise<T | null> {
  try {
    const res = await fetch(`${backendOrigin()}/api${path}`, { next: { revalidate } });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  }
}

/** Public web address: admin setting / PUBLIC_WEB_URL, else the address of this request. */
export async function siteUrl(): Promise<string> {
  const cfg = await backendGet<{ webUrl?: string }>("/config", 300);
  if (cfg?.webUrl) return cfg.webUrl.replace(/\/+$/, "");
  const h = await headers();
  const host = h.get("x-forwarded-host")?.split(",")[0].trim() || h.get("host") || "localhost:3000";
  const proto = h.get("x-forwarded-proto")?.split(",")[0].trim() || (host.startsWith("localhost") ? "http" : "https");
  return `${proto}://${host}`;
}

export const absolute = (base: string, path: string) => (/^https?:\/\//.test(path) ? path : `${base}${path}`);

export const getPin = (id: string) => (/^\d+$/.test(id) ? backendGet<Pin>(`/pins/${id}`) : Promise.resolve(null));
export const getProfile = (u: string) => backendGet<Profile>(`/users/${encodeURIComponent(u.toLowerCase())}`);
export const getPins = (query: string) => backendGet<Page<Pin>>(`/pins?${query}`);

export function snippet(s: string, max = 160): string {
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > max ? `${t.slice(0, max - 1).trimEnd()}…` : t;
}
