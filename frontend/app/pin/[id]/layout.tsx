import type { Metadata } from "next";
import { absolute, getPin, siteUrl, SITE_NAME, snippet } from "@/lib/seo";

// The page itself renders in the browser; this gives search engines and link previews its title and photo.
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }): Promise<Metadata> {
  const { id } = await params;
  const [pin, base] = await Promise.all([getPin(id), siteUrl()]);
  if (!pin) return { title: `Post · ${SITE_NAME}` };
  const tags = (pin.tags ?? []).slice(0, 6);
  const description = snippet(pin.description || `${pin.title}: fason we köýnek ideýalary ModaHouse-da.${tags.length ? ` #${tags.join(" #")}` : ""}`);
  const image = absolute(base, pin.imageUrl);
  return {
    title: `${pin.title} · ${SITE_NAME}`,
    description,
    keywords: [...tags, "fasonlar", "fason", "köýnek"],
    alternates: { canonical: `${base}/pin/${pin.id}` },
    openGraph: {
      type: "article", siteName: SITE_NAME, title: pin.title, description, url: `${base}/pin/${pin.id}`,
      images: [{ url: image, width: pin.width || undefined, height: pin.height || undefined, alt: pin.title }],
    },
    twitter: { card: "summary_large_image", title: pin.title, description, images: [image] },
  };
}

export default function PinLayout({ children }: { children: React.ReactNode }) {
  return children;
}
