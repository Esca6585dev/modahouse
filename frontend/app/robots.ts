import type { MetadataRoute } from "next";
import { siteUrl } from "@/lib/seo";

export const dynamic = "force-dynamic";

export default async function robots(): Promise<MetadataRoute.Robots> {
  const base = await siteUrl();
  return {
    rules: {
      userAgent: "*",
      allow: "/",
      disallow: ["/admin", "/settings", "/messages", "/cart", "/checkout", "/orders", "/notifications", "/business", "/create", "/api/"],
    },
    sitemap: `${base}/sitemap.xml`,
  };
}
