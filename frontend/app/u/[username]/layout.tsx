import type { Metadata } from "next";
import { businessCategoryLabel } from "@/lib/format";
import { absolute, getProfile, siteUrl, SITE_NAME, snippet } from "@/lib/seo";

export async function generateMetadata({ params }: { params: Promise<{ username: string }> }): Promise<Metadata> {
  const { username } = await params;
  const [p, base] = await Promise.all([getProfile(decodeURIComponent(username)), siteUrl()]);
  if (!p) return { title: `Profil · ${SITE_NAME}` };
  const craft = p.business?.category || p.category;
  const role = craft ? businessCategoryLabel(craft) : "";
  const title = `${p.name} (@${p.username})${role ? ` · ${role}` : ""} · ${SITE_NAME}`;
  const description = snippet(p.bio || `${p.name}: fasonlar, köýnekler we moda ideýalary ModaHouse-da.`);
  return {
    title,
    description,
    alternates: { canonical: `${base}/u/${p.username}` },
    openGraph: {
      type: "profile", siteName: SITE_NAME, title, description, url: `${base}/u/${p.username}`,
      images: p.avatarUrl ? [{ url: absolute(base, p.avatarUrl) }] : undefined,
    },
  };
}

export default function UserLayout({ children }: { children: React.ReactNode }) {
  return children;
}
