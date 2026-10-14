"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import { REPORT_REASONS } from "@/lib/format";
import { shareUrl } from "@/lib/share";
import type { Pin, ReportReason } from "@/lib/types";
import {
  BackIcon, BookmarkIcon, CopyIcon, DotsIcon, DownloadIcon, EditIcon, EyeOffIcon, FlagIcon, ScanIcon, ShareIcon, TrashIcon,
} from "./Icons";
import Popover from "./Popover";
import { BoardPickerBody } from "./SavePicker";
import { useToast } from "./Toast";

function extOf(url: string, type: string): string {
  const m = /\.([a-z0-9]{2,5})(?:\?|$)/i.exec(url);
  if (m) return m[1].toLowerCase();
  if (type.includes("png")) return "png";
  if (type.includes("webm")) return "webm";
  if (type.includes("mp4")) return "mp4";
  if (type.includes("svg")) return "svg";
  return "jpg";
}

function slug(s: string): string {
  return s.toLocaleLowerCase("tk").replace(/[^a-z0-9äçňöşüýž]+/gi, "-").replace(/^-|-$/g, "").slice(0, 40) || "modahouse";
}

/** Downloads a same-origin file (image or video) under a readable name. */
export async function downloadMedia(url: string, title: string) {
  const res = await fetch(url);
  if (!res.ok) throw new Error("Faýl ýüklenmedi");
  const blob = await res.blob();
  const href = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = href;
  a.download = `${slug(title)}.${extOf(url, blob.type)}`;
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(href), 5000);
}

type View = "menu" | "save" | "report";

/**
 * Pinterest-style "⋯" menu for a post. `onHidden` / `onDeleted` let lists remove the card
 * (the caller shows the undo); without them the page navigates away.
 */
export default function PinMenu({
  pin, savedBoardIds, onSavedChange, onHidden, onDeleted, className = "", light,
}: {
  pin: Pin;
  savedBoardIds: number[];
  onSavedChange: (ids: number[]) => void;
  onHidden?: () => void;
  onDeleted?: () => void;
  className?: string;
  /** white icon for dark backgrounds (reels) */
  light?: boolean;
}) {
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const btn = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const [view, setView] = useState<View>("menu");
  const [reason, setReason] = useState<ReportReason | "">("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const own = !!user && user.id === pin.author.id;
  const href = `/pin/${pin.id}`;

  const close = () => {
    setOpen(false);
    setView("menu");
    setReason("");
    setNote("");
  };
  const needLogin = () => {
    if (user) return false;
    close();
    router.push(loginHref());
    return true;
  };

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    try {
      await fn();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  const media = pin.images[0];
  const items: { key: string; icon: React.ReactNode; label: string; onClick?: () => void; href?: string; danger?: boolean }[] = [
    {
      key: "save", icon: <BookmarkIcon size={18} filled={savedBoardIds.length > 0} />,
      label: savedBoardIds.length ? "Saklandy · tagtany üýtget" : "Sakla",
      onClick: () => !needLogin() && setView("save"),
    },
    {
      key: "share", icon: <ShareIcon size={18} />, label: "Paýlaş",
      onClick: async () => {
        close();
        const msg = await shareUrl(href, pin.title);
        if (msg) toast(msg);
      },
    },
    {
      key: "download", icon: <DownloadIcon size={18} />, label: media?.type === "video" ? "Wideony ýükle" : "Suraty ýükle",
      onClick: () => run(async () => {
        await downloadMedia(media?.url || pin.imageUrl, pin.title);
        close();
      }),
    },
    {
      key: "copy", icon: <CopyIcon size={18} />, label: "Baglanyşygy göçür",
      onClick: async () => {
        close();
        try {
          await navigator.clipboard.writeText(new URL(href, window.location.origin).toString());
          toast("Baglanyşyk göçürildi");
        } catch {
          window.prompt("Baglanyşygy göçüriň:", new URL(href, window.location.origin).toString());
        }
      },
    },
    { key: "similar", icon: <ScanIcon size={18} />, label: "Meňzeşini tap", href: `/visual?pin=${pin.id}` },
    ...(own
      ? [
        { key: "edit", icon: <EditIcon size={18} />, label: "Üýtget", href: `/pin/${pin.id}/edit` },
        {
          key: "delete", icon: <TrashIcon size={18} />, label: "Poz", danger: true,
          onClick: () => {
            if (!window.confirm("Bu posty pozmalymy? Bu hereketi yzyna gaýtaryp bolmaýar.")) return;
            run(async () => {
              await api.deletePin(pin.id);
              close();
              toast("Pozuldy");
              if (onDeleted) onDeleted();
              else router.replace(`/u/${pin.author.username}`);
            });
          },
        },
      ]
      : [
        {
          key: "hide", icon: <EyeOffIcon size={18} />, label: "Gyzyklanmaýaryn",
          onClick: () => {
            if (needLogin()) return;
            run(async () => {
              await api.hidePin(pin.id);
              close();
              if (onHidden) onHidden();
              else {
                toast("Bu post indi lentaňyzda görünmez");
                router.push("/");
              }
            });
          },
        },
        { key: "report", icon: <FlagIcon size={18} />, label: "Şikaýat et", danger: true, onClick: () => !needLogin() && setView("report") },
      ]),
  ];

  return (
    <>
      <button
        ref={btn}
        type="button"
        className={`dots-btn ${light ? "light" : ""} ${className}`}
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          if (open) close();
          else setOpen(true);
        }}
        aria-label="Has köp"
        aria-haspopup="menu"
        aria-expanded={open}
      >
        <DotsIcon size={20} />
      </button>
      <Popover anchor={btn} open={open} onClose={close} width={view === "menu" ? 264 : 320} label="Post menýusy" className="pin-menu">
        {view === "menu" && (
          <div className="pm-list" role="menu">
            {items.map((it) =>
              it.href ? (
                <Link key={it.key} href={it.href} className="menu-item" role="menuitem" onClick={close}>
                  {it.icon} {it.label}
                </Link>
              ) : (
                <button key={it.key} className={`menu-item ${it.danger ? "danger" : ""}`} role="menuitem" onClick={it.onClick} disabled={busy}>
                  {it.icon} {it.label}
                </button>
              ),
            )}
          </div>
        )}
        {view === "save" && (
          <>
            <button className="pm-back" onClick={() => setView("menu")}><BackIcon size={16} /> Yza</button>
            <BoardPickerBody pinId={pin.id} savedBoardIds={savedBoardIds} onChange={onSavedChange} />
          </>
        )}
        {view === "report" && (
          <form
            className="pm-report"
            onSubmit={(e) => {
              e.preventDefault();
              if (!reason) return;
              run(async () => {
                await api.report(pin.id, reason, note.trim());
                close();
                toast("Şikaýatyňyz ugradyldy. Sag boluň!");
              });
            }}
          >
            <button type="button" className="pm-back" onClick={() => setView("menu")}><BackIcon size={16} /> Yza</button>
            <strong>Näme üçin şikaýat edýärsiňiz?</strong>
            <div className="pm-reasons" role="radiogroup">
              {REPORT_REASONS.map((r) => (
                <label key={r.value} className={`pm-reason ${reason === r.value ? "on" : ""}`}>
                  <input type="radio" name="reason" value={r.value} checked={reason === r.value} onChange={() => setReason(r.value)} />
                  <span><b>{r.label}</b><small>{r.hint}</small></span>
                </label>
              ))}
            </div>
            {reason && (
              <textarea
                rows={2}
                value={note}
                maxLength={500}
                onChange={(e) => setNote(e.target.value)}
                placeholder={reason === "other" ? "Sebäbi ýazyň" : "Goşmaça bellik (hökman däl)"}
                aria-label="Bellik"
              />
            )}
            <button className="btn btn-primary btn-block" disabled={!reason || busy}>{busy ? "Iberilýär…" : "Şikaýaty iber"}</button>
          </form>
        )}
      </Popover>
    </>
  );
}
