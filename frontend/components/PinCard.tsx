"use client";

import Link from "next/link";
import { useState } from "react";
import { categoryName } from "@/lib/format";
import { useCategories } from "@/lib/hooks";
import { shareUrl } from "@/lib/share";
import type { Pin } from "@/lib/types";
import Avatar from "./Avatar";
import { ExternalIcon, ShareIcon } from "./Icons";
import PinImage from "./PinImage";
import SavePicker from "./SavePicker";
import { useToast } from "./Toast";

export type PinCardAction = { label: string; onClick: (pin: Pin) => void | Promise<void> };

export default function PinCard({ pin, action }: { pin: Pin; action?: PinCardAction }) {
  const [saved, setSaved] = useState(pin.savedBoardIds);
  const [busy, setBusy] = useState(false);
  const cats = useCategories();
  const toast = useToast();
  const href = `/pin/${pin.id}`;

  return (
    <article className="pin">
      <div className="pin-media">
        <Link href={href} aria-label={pin.title}>
          <PinImage pin={pin} />
        </Link>
        <div className="pin-overlay">
          <span className="pin-board">{categoryName(pin.category, cats)}</span>
          <SavePicker pinId={pin.id} savedBoardIds={saved} onChange={setSaved} />
          <div className="pin-overlay-bottom">
            {pin.link && (
              <a className="round-btn" href={pin.link} target="_blank" rel="noopener noreferrer" aria-label="Çeşmä git">
                <ExternalIcon size={16} />
              </a>
            )}
            <button
              className="round-btn"
              aria-label="Paýlaş"
              onClick={async () => {
                const msg = await shareUrl(href, pin.title);
                if (msg) toast(msg);
              }}
            >
              <ShareIcon size={16} />
            </button>
          </div>
          {action && (
            <button
              className="pin-action btn btn-secondary btn-sm"
              disabled={busy}
              onClick={async () => {
                setBusy(true);
                try {
                  await action.onClick(pin);
                } finally {
                  setBusy(false);
                }
              }}
            >
              {action.label}
            </button>
          )}
        </div>
      </div>
      <Link href={href} className="pin-title">{pin.title}</Link>
      <Link href={`/u/${pin.author.username}`} className="pin-author">
        <Avatar user={pin.author} size={22} />
        <span>{pin.author.name}</span>
      </Link>
    </article>
  );
}
