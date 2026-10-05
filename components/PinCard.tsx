"use client";

import Link from "next/link";
import { useState } from "react";
import { authors, type Pin } from "@/lib/data";
import Avatar from "./Avatar";
import PinArt from "./PinArt";
import { MoreIcon, ShareIcon } from "./Icons";

export default function PinCard({ pin, idPrefix = "card" }: { pin: Pin; idPrefix?: string }) {
  const [saved, setSaved] = useState(false);
  const author = authors[pin.author];

  return (
    <article className="pin">
      <div className="pin-media">
        <Link href={`/pin/${pin.id}`} aria-label={pin.title}>
          <PinArt pin={pin} idPrefix={idPrefix} />
        </Link>
        <div className="pin-overlay">
          <span className="pin-board">{pin.category}</span>
          <button
            className={`btn btn-save ${saved ? "saved" : ""}`}
            onClick={() => setSaved((s) => !s)}
            aria-pressed={saved}
          >
            {saved ? "Saklandy" : "Sakla"}
          </button>
          <div className="pin-overlay-bottom">
            <button className="round-btn" aria-label="Paýlaş"><ShareIcon size={16} /></button>
            <button className="round-btn" aria-label="Has köp"><MoreIcon size={16} /></button>
          </div>
        </div>
      </div>
      <Link href={`/pin/${pin.id}`} className="pin-title">{pin.title}</Link>
      <div className="pin-author">
        <Avatar author={author} size={22} />
        <span>{author.name}</span>
      </div>
    </article>
  );
}
