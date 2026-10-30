import type { Metadata } from "next";
import { absolute, getPin, siteUrl, SITE_NAME, snippet } from "@/lib/seo";
import { LANGS, TOPICS } from "@/lib/topics";

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
    // Words people search for in Turkmen, Russian and English for this kind of post.
    keywords: [...tags, ...topicWords(pin.category), "fasonlar", "фасоны", "dress styles"],
    alternates: { canonical: `${base}/pin/${pin.id}` },
    openGraph: {
      type: "article", siteName: SITE_NAME, title: pin.title, description, url: `${base}/pin/${pin.id}`,
      images: [{ url: image, width: pin.width || undefined, height: pin.height || undefined, alt: pin.title }],
    },
    twitter: { card: "summary_large_image", title: pin.title, description, images: [image] },
  };
}

function topicWords(category: string): string[] {
  const t = TOPICS.find((x) => x.category === category);
  return t ? LANGS.flatMap((l) => t.text[l].keywords.slice(0, 2)) : [];
}

export default function PinLayout({ children }: { children: React.ReactNode }) {
  return children;
}
