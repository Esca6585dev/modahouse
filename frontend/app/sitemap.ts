import type { MetadataRoute } from "next";
import { backendGet, getPins, siteUrl } from "@/lib/seo";
import type { Category } from "@/lib/types";

export const dynamic = "force-dynamic";

const PIN_PAGES = 20; // 20 × 50 newest posts

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = await siteUrl();
  const now = new Date();
  const out: MetadataRoute.Sitemap = [
    { url: `${base}/`, lastModified: now, changeFrequency: "daily", priority: 1 },
    { url: `${base}/fasonlar`, lastModified: now, changeFrequency: "daily", priority: 0.9 },
    { url: `${base}/shops`, lastModified: now, changeFrequency: "weekly", priority: 0.6 },
    { url: `${base}/reels`, lastModified: now, changeFrequency: "daily", priority: 0.5 },
  ];
  const cats = (await backendGet<Category[]>("/categories", 3600)) ?? [];
  for (const c of cats) {
    out.push({ url: `${base}/fasonlar?c=${encodeURIComponent(c.slug)}`, lastModified: now, changeFrequency: "daily", priority: 0.7 });
  }
  const authors = new Set<string>();
  for (let page = 1; page <= PIN_PAGES; page++) {
    const pg = await getPins(`page=${page}&limit=50`);
    if (!pg) break;
    for (const p of pg.items ?? []) {
      out.push({ url: `${base}/pin/${p.id}`, lastModified: new Date(p.createdAt), changeFrequency: "monthly", priority: 0.6 });
      if (p.author?.username) authors.add(p.author.username);
    }
    if (!pg.hasMore) break;
  }
  for (const u of authors) {
    out.push({ url: `${base}/u/${encodeURIComponent(u)}`, changeFrequency: "weekly", priority: 0.4 });
  }
  return out;
}
