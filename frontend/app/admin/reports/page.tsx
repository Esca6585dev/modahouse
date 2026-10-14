"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import { CheckIcon, CloseIcon, ExternalIcon, FlagIcon, TrashIcon } from "@/components/Icons";
import { InfiniteFooter } from "@/components/Masonry";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { usePaged } from "@/lib/hooks";
import { dateTime, reportReasonLabel, timeAgo } from "@/lib/format";
import type { AdminReport } from "@/lib/types";
import { AdminHead, LoadError, useAdminBadge } from "../shared";

export default function AdminReports() {
  const toast = useToast();
  const badge = useAdminBadge();
  const paged = usePaged<AdminReport>("reports", (page) => api.admin.reports(page));
  const { items, setItems, loaded, error } = paged;
  const [busy, setBusy] = useState<number | null>(null);

  useEffect(() => { document.title = "Şikaýatlar · Admin paneli"; }, []);

  const act = async (r: AdminReport, kind: "delete" | "dismiss") => {
    const title = r.pin.title || "Atsyz post";
    if (kind === "delete" && !window.confirm(`“${title}” posty pozulsynmy? Post, onuň faýllary we şikaýatlary yzyna gaýtaryp bolmaz ýaly pozular.`)) return;
    setBusy(r.pin.id);
    try {
      if (kind === "delete") await api.admin.deletePin(r.pin.id);
      else await api.admin.dismissReports(r.pin.id);
      setItems((l) => l.filter((x) => x.pin.id !== r.pin.id));
      toast(kind === "delete" ? "Post pozuldy" : "Şikaýatlar ýapyldy");
      badge.refresh();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(null);
    }
  };

  return (
    <>
      <AdminHead title="Şikaýatlar" sub="Ulanyjylaryň şikaýat eden postlary, iň täzeleri ilki" />

      {!loaded ? (
        <div className="ar-list">
          {[0, 1, 2].map((i) => <div key={i} className="skeleton" style={{ height: 168, borderRadius: 24 }} />)}
        </div>
      ) : error && items.length === 0 ? (
        <LoadError message={error} onRetry={paged.reload} />
      ) : items.length === 0 ? (
        <div className="empty empty-card">
          <span className="empty-icon ok"><CheckIcon size={34} /></span>
          <h2>Şikaýat ýok</h2>
          <p>Ähli şikaýatlara seredildi. Täze şikaýat gelende şu ýerde görersiňiz.</p>
        </div>
      ) : (
        <div className="ar-list">
          {items.map((r) => (
            <article key={r.pin.id} className={`ar-card ${busy === r.pin.id ? "busy" : ""}`}>
              <Link href={`/pin/${r.pin.id}`} className="ar-thumb" target="_blank" rel="noopener" aria-label="Posty täze bellikde aç">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                {r.pin.imageUrl ? <img src={r.pin.imageUrl} alt="" loading="lazy" /> : <FlagIcon size={28} />}
              </Link>
              <div className="ar-body">
                <div className="ar-top">
                  <Link href={`/pin/${r.pin.id}`} className="ar-title" target="_blank" rel="noopener">
                    {r.pin.title || "Atsyz post"} <ExternalIcon size={14} />
                  </Link>
                  <span className="ar-count"><FlagIcon size={14} /> {r.count} şikaýat</span>
                </div>
                <Link href={`/u/${r.pin.author.username}`} className="ar-author">
                  <Avatar user={r.pin.author} size={24} />
                  <span><strong>{r.pin.author.name || r.pin.author.username}</strong> <span className="muted">@{r.pin.author.username}</span></span>
                </Link>
                {r.reasons.length > 0 && (
                  <div className="ar-reasons">
                    {r.reasons.map((x) => <span key={x} className="ar-reason">{reportReasonLabel(x)}</span>)}
                  </div>
                )}
                {r.lastNote && <p className="ar-note">“{r.lastNote}”</p>}
                <div className="ar-foot">
                  <time className="muted small" dateTime={r.lastReportedAt} title={dateTime(r.lastReportedAt)}>
                    Soňky şikaýat: {timeAgo(r.lastReportedAt)}
                  </time>
                  <div className="ar-actions">
                    <button className="btn btn-secondary btn-sm" onClick={() => act(r, "dismiss")} disabled={busy !== null}>
                      <CloseIcon size={16} /> Ýap
                    </button>
                    <button className="btn btn-sm btn-danger" onClick={() => act(r, "delete")} disabled={busy !== null}>
                      <TrashIcon size={16} /> Postu poz
                    </button>
                  </div>
                </div>
              </div>
            </article>
          ))}
          <InfiniteFooter paged={paged} />
        </div>
      )}
    </>
  );
}
