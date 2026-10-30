import type { MetadataRoute } from "next";
import { getPins, siteUrl } from "@/lib/seo";
import { LANGS, topicPath, TOPICS } from "@/lib/topics";

export const dynamic = "force-dynamic";

const PIN_PAGES = 20; // 20 × 50 newest posts

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = await siteUrl();
  const now = new Date();
  const out: MetadataRoute.Sitemap = [
    { url: `${base}/`, lastModified: now, changeFrequency: "daily", priority: 1 },
    { url: `${base}/shops`, lastModified: now, changeFrequency: "weekly", priority: 0.6 },
    { url: `${base}/reels`, lastModified: now, changeFrequency: "daily", priority: 0.5 },
  ];
  // Topic pages in Turkmen, Russian and English, linked to each other as alternates.
  for (const t of TOPICS) {
    const languages = Object.fromEntries(LANGS.map((l) => [l, `${base}${topicPath(l, t.slug)}`]));
    for (const l of LANGS) {
      out.push({
        url: `${base}${topicPath(l, t.slug)}`, lastModified: now, changeFrequency: "daily",
        priority: t.slug === "fasonlar" ? 0.9 : 0.8, alternates: { languages },
      });
    }
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
