import type { Metadata } from "next";
import { siteUrl, SITE_NAME } from "@/lib/seo";

export async function generateMetadata({ params }: { params: Promise<{ tag: string }> }): Promise<Metadata> {
  const tag = decodeURIComponent((await params).tag);
  const base = await siteUrl();
  return {
    title: `#${tag} · fasonlar we ideýalar · ${SITE_NAME}`,
    description: `#${tag} belligi bilen fasonlar, köýnekler we moda ideýalary ModaHouse-da.`,
    alternates: { canonical: `${base}/tag/${encodeURIComponent(tag)}` },
  };
}

export default function TagLayout({ children }: { children: React.ReactNode }) {
  return children;
}
