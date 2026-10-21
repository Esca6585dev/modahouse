"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth";
import { phoneDigits } from "@/lib/format";
import type { Business, Pin } from "@/lib/types";
import { useChat } from "./chat/ChatProvider";
import {
  CheckIcon, ChevronRightIcon, CopyIcon, GlobeIcon, ImoIcon, InstagramIcon, PhoneIcon, SendIcon, TelegramIcon, TiktokIcon, WhatsappIcon,
  YoutubeIcon,
} from "./Icons";
import Modal from "./Modal";
import { useToast } from "./Toast";

function wantText(pin: Pin): string {
  return pin.product?.listingType === "rent"
    ? "Kärendä almak isleýärin."
    : pin.product?.listingType === "custom" ? "Şuňa meňzeşini tikdirmek isleýärin." : "Satyn almak isleýärin.";
}

export function contactMessage(pin: Pin): string {
  const url = typeof window !== "undefined" ? new URL(`/pin/${pin.id}`, window.location.origin).toString() : `/pin/${pin.id}`;
  return `Salam! ModaHouse-da «${pin.title}» gördüm. ${wantText(pin)} Maglumat berip bilersiňizmi? ${url}`;
}

/** First line of an in-app chat about a post (the post itself goes along as a card). */
export function chatMessage(pin: Pin): string {
  return `Salam! ${wantText(pin)} Maglumat berip bilersiňizmi?`;
}

const handle = (h: string) => h.trim().replace(/^@/, "");

export type SocialLink = { key: string; label: string; value: string; href: string; icon: React.ReactNode; external: boolean };

/** Business contact channels as links (phone, WhatsApp with prefilled text, Telegram, IMO, socials, website). */
export function socialLinks(b: Business, message?: string): SocialLink[] {
  const out: SocialLink[] = [];
  if (b.phone) out.push({ key: "phone", label: "Jaň et", value: b.phone, href: `tel:${phoneDigits(b.phone)}`, icon: <PhoneIcon size={20} />, external: false });
  if (b.whatsapp) {
    const digits = phoneDigits(b.whatsapp).replace(/^\+/, "");
    out.push({
      key: "whatsapp", label: "WhatsApp", value: b.whatsapp,
      href: `https://wa.me/${digits}${message ? `?text=${encodeURIComponent(message)}` : ""}`, icon: <WhatsappIcon size={20} />, external: true,
    });
  }
  if (b.telegram) out.push({ key: "telegram", label: "Telegram", value: `@${handle(b.telegram)}`, href: `https://t.me/${handle(b.telegram)}`, icon: <TelegramIcon size={20} />, external: true });
  if (b.imo) out.push({ key: "imo", label: "IMO", value: b.imo, href: `tel:${phoneDigits(b.imo)}`, icon: <ImoIcon size={20} />, external: false });
  if (b.instagram) out.push({ key: "instagram", label: "Instagram", value: `@${handle(b.instagram)}`, href: `https://instagram.com/${handle(b.instagram)}`, icon: <InstagramIcon size={20} />, external: true });
  if (b.tiktok) out.push({ key: "tiktok", label: "TikTok", value: `@${handle(b.tiktok)}`, href: `https://www.tiktok.com/@${handle(b.tiktok)}`, icon: <TiktokIcon size={20} />, external: true });
  if (b.youtube) out.push({ key: "youtube", label: "YouTube", value: b.youtube.replace(/^https?:\/\/(www\.)?/, ""), href: b.youtube, icon: <YoutubeIcon size={20} />, external: true });
  if (b.website) out.push({ key: "website", label: "Web sahypa", value: b.website.replace(/^https?:\/\/(www\.)?/, ""), href: b.website, icon: <GlobeIcon size={20} />, external: true });
  return out;
}

export default function ContactSheet({ pin, business, onClose }: { pin: Pin; business: Business | null; onClose: () => void }) {
  const toast = useToast();
  const { user } = useAuth();
  const { openChat } = useChat();
  const [copied, setCopied] = useState(false);
  const [opening, setOpening] = useState(false);
  const canChat = user?.id !== pin.author.id;
  const message = contactMessage(pin);
  const links = business ? socialLinks(business, message) : [];
  const title = pin.product?.listingType === "rent" ? "Kärendä almak" : pin.product?.listingType === "custom" ? "Tikdirmek üçin sargyt" : "Dükan bilen habarlaş";

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(message);
      setCopied(true);
      toast("Habar göçürildi");
    } catch {
      window.prompt("Habary göçüriň:", message);
    }
  };

  return (
    <Modal title={title} onClose={onClose}>
      <div className="contact-sheet">
        <p className="muted small">{pin.author.name} bilen göni habarlaşyň. Töleg we eltip bermek dükan bilen ylalaşylýar.</p>
        {canChat && (
          <button
            type="button"
            className="contact-row c-modahouse"
            disabled={opening}
            onClick={async () => {
              setOpening(true);
              try {
                await openChat(pin.author.username, { pin: pin.id, text: chatMessage(pin) });
              } finally {
                setOpening(false);
              }
            }}
          >
            <span className="contact-icon">{opening ? <span className="spinner light" /> : <SendIcon size={20} />}</span>
            <span className="contact-text"><strong>ModaHouse-da ýaz</strong><span>Post bilen bilelikde, programmanyň içinde</span></span>
            <ChevronRightIcon size={18} />
          </button>
        )}
        {links.length === 0 ? (
          !canChat && <p className="form-error">Dükanyň aragatnaşyk maglumaty ýok.</p>
        ) : (
          <ul className="contact-list">
            {links.map((l) => (
              <li key={l.key}>
                <a href={l.href} className={`contact-row c-${l.key}`} target={l.external ? "_blank" : undefined} rel={l.external ? "noopener noreferrer" : undefined}>
                  <span className="contact-icon">{l.icon}</span>
                  <span className="contact-text"><strong>{l.label}</strong><span>{l.value}</span></span>
                </a>
              </li>
            ))}
          </ul>
        )}
        <div className="contact-msg">
          <span className="opt-label">Taýýar habar</span>
          <p>{message}</p>
          <button type="button" className="btn btn-secondary btn-block" onClick={copy}>
            {copied ? <CheckIcon size={16} /> : <CopyIcon size={16} />} {copied ? "Göçürildi" : "Habary göçür"}
          </button>
        </div>
      </div>
    </Modal>
  );
}
