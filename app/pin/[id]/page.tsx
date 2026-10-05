import Link from "next/link";
import { notFound } from "next/navigation";
import Avatar from "@/components/Avatar";
import Comments from "@/components/Comments";
import { BackIcon } from "@/components/Icons";
import Masonry from "@/components/Masonry";
import PinActions from "@/components/PinActions";
import PinArt from "@/components/PinArt";
import { authors, getPin, pins } from "@/lib/data";

export function generateStaticParams() {
  return pins.map((p) => ({ id: p.id }));
}

export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const pin = getPin((await params).id);
  return { title: pin ? `${pin.title} · ModaHouse` : "ModaHouse" };
}

export default async function PinPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const pin = getPin(id);
  if (!pin) notFound();
  const author = authors[pin.author];
  const similar = pins.filter((p) => p.id !== pin.id && p.category === pin.category)
    .concat(pins.filter((p) => p.id !== pin.id && p.category !== pin.category))
    .slice(0, 16);

  return (
    <div className="page">
      <Link href="/" className="back icon-btn" aria-label="Yza"><BackIcon /></Link>
      <article className="detail">
        <div className="detail-media">
          <PinArt pin={pin} idPrefix="detail" />
        </div>
        <div className="detail-body">
          <PinActions />
          <span className="detail-cat">{pin.category}</span>
          <h1>{pin.title}</h1>
          <p className="detail-desc">{pin.description}</p>
          <div className="detail-author">
            <Avatar author={author} size={44} />
            <div>
              <strong>{author.name}</strong>
              <span>{author.followers} yzarlaýjy</span>
            </div>
            <button className="btn btn-secondary">Yzarla</button>
          </div>
          <Comments />
        </div>
      </article>

      <h2 className="section-title">Şuňa meňzeşler</h2>
      <Masonry pins={similar} idPrefix="similar" />
    </div>
  );
}
