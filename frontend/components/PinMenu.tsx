"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useLoginHref } from "@/lib/hooks";
import { REPORT_REASONS } from "@/lib/format";
import { copyText, downloadPin } from "@/lib/share";
import type { Pin, ReportReason } from "@/lib/types";
import {
  BackIcon, BookmarkIcon, CopyIcon, DotsIcon, DownloadIcon, EditIcon, EyeOffIcon, FlagIcon, ScanIcon, ShareIcon, TrashIcon,
} from "./Icons";
import Popover from "./Popover";
import { BoardPickerBody } from "./SavePicker";
import { useShare } from "./ShareSheet";
import { useToast } from "./Toast";

type View = "menu" | "save" | "report";

/**
 * Pinterest-style "⋯" menu for a post. `onHidden` / `onDeleted` let lists remove the card
 * (the caller shows the undo); without them the page navigates away.
 */
export default function PinMenu({
  pin, savedBoardIds, onSavedChange, onHidden, onDeleted, className = "", light, index = 0,
}: {
  pin: Pin;
  /** carousel position: "Ýükle" downloads this media item */
  index?: number;
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
  const openShare = useShare();
  const btn = useRef<HTMLButtonElement>(null);
  const [open, setOpen] = useState(false);
  const [view, setView] = useState<View>("menu");
  const [reason, setReason] = useState<ReportReason | "">("");
  const [note, setNote] = useState("");
  const [busy, setBusy] = useState(false);
  const [downloading, setDownloading] = useState(false);
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
      setDownloading(false);
    }
  };

  const media = pin.images[index] ?? pin.images[0];
  const items: { key: string; icon: React.ReactNode; label: string; onClick?: () => void; href?: string; danger?: boolean }[] = [
    {
      key: "save", icon: <BookmarkIcon size={18} filled={savedBoardIds.length > 0} />,
      label: savedBoardIds.length ? "Saklandy · tagtany üýtget" : "Sakla",
      onClick: () => !needLogin() && setView("save"),
    },
    {
      key: "share", icon: <ShareIcon size={18} />, label: "Paýlaş",
      onClick: () => {
        close();
        openShare(pin, index);
      },
    },
    {
      key: "download",
      icon: downloading ? <span className="spinner" aria-hidden /> : <DownloadIcon size={18} />,
      label: downloading ? "Ýüklenýär…" : media?.type === "video" ? "Wideony ýükle" : "Suraty ýükle",
      onClick: () => run(async () => {
        setDownloading(true);
        // The server stamps images with the ModaHouse watermark.
        const msg = await downloadPin(pin.id, pin.images[index] ? index : 0);
        close();
        toast(msg);
      }),
    },
    {
      key: "copy", icon: <CopyIcon size={18} />, label: "Baglanyşygy göçür",
      onClick: async () => {
        close();
        if (await copyText(new URL(href, window.location.origin).toString())) toast("Baglanyşyk göçürildi");
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
