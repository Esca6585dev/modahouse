"use client";

import Link from "next/link";
import { useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { timeAgo } from "@/lib/format";
import { useLoginHref, usePaged } from "@/lib/hooks";
import Avatar from "./Avatar";
import { TrashIcon } from "./Icons";
import { useToast } from "./Toast";

export default function Comments({
  pinId, count, onCountChange, head,
}: { pinId: number; count: number; onCountChange: (n: number) => void; head?: React.ReactNode }) {
  const { user, ready } = useAuth();
  const loginHref = useLoginHref();
  const toast = useToast();
  // Wait for auth so canDelete reflects the viewer.
  const paged = usePaged(ready ? `comments:${pinId}:${user?.id ?? 0}` : null, (page) => api.comments(pinId, page));
  const [text, setText] = useState("");
  const [sending, setSending] = useState(false);
  const [deleting, setDeleting] = useState<number | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const t = text.trim();
    if (!t || sending) return;
    setSending(true);
    try {
      const c = await api.addComment(pinId, t);
      // Append only when the list is fully loaded (oldest first); otherwise it will appear on the last page.
      if (!paged.hasMore) paged.setItems((l) => [...l, c]);
      onCountChange(count + 1);
      setText("");
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setSending(false);
    }
  };

  const remove = async (id: number) => {
    if (!window.confirm("Bu teswiri pozmalymy?")) return;
    setDeleting(id);
    try {
      await api.deleteComment(id);
      paged.setItems((l) => l.filter((c) => c.id !== id));
      onCountChange(Math.max(0, count - 1));
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setDeleting(null);
    }
  };

  return (
    <section className="comments">
      <div className="comments-head">
        <h3>{count ? `${count} teswir` : "Teswirler"}</h3>
        {head}
      </div>

      {!paged.loaded ? (
        <p className="muted small">Teswirler ýüklenýär…</p>
      ) : paged.error && paged.items.length === 0 ? (
        <p className="error-text small">{paged.error} <button className="link-btn" onClick={paged.reload}>Gaýtadan synanyş</button></p>
      ) : paged.items.length === 0 ? (
        <p className="muted small">Entek teswir ýok. Ilkinji bolup pikiriňizi ýazyň!</p>
      ) : (
        <ul>
          {paged.items.map((c) => (
            <li key={c.id} className="comment">
              <Link href={`/u/${c.author.username}`}><Avatar user={c.author} size={32} /></Link>
              <div className="comment-body">
                <p>
                  <Link href={`/u/${c.author.username}`}><strong>{c.author.name}</strong></Link> {c.text}
                </p>
                <span className="comment-meta">{timeAgo(c.createdAt)}</span>
              </div>
              {c.canDelete && (
                <button
                  className="icon-btn comment-del"
                  onClick={() => remove(c.id)}
                  disabled={deleting === c.id}
                  aria-label="Teswiri poz"
                  title="Poz"
                >
                  <TrashIcon size={16} />
                </button>
              )}
            </li>
          ))}
        </ul>
      )}
      {paged.hasMore && paged.loaded && !paged.error && (
        <button className="link-btn" onClick={paged.loadMore} disabled={paged.loading}>
          {paged.loading ? "Ýüklenýär…" : "Köp teswir görkez"}
        </button>
      )}

      {user ? (
        <form className="comment-form" onSubmit={submit}>
          <Avatar user={user} size={32} />
          <input
            value={text}
            maxLength={500}
            onChange={(e) => setText(e.target.value)}
            placeholder="Teswir goş…"
            aria-label="Teswir"
          />
          <button className="btn btn-primary" disabled={!text.trim() || sending}>{sending ? "…" : "Iber"}</button>
        </form>
      ) : ready ? (
        <p className="comment-form muted small">
          <span><Link href={loginHref()} className="text-link">Giriň</Link> we teswir ýazyň.</span>
        </p>
      ) : null}
    </section>
  );
}
