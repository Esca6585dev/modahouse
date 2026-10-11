"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { timeAgo } from "@/lib/format";
import type { Review } from "@/lib/types";
import Avatar from "./Avatar";
import { TrashIcon } from "./Icons";
import Stars, { StarInput } from "./Stars";
import { useToast } from "./Toast";

type State = { items: Review[]; rating: number; count: number; canReview: boolean; hasMore: boolean; page: number };

export default function Reviews({ pinId, onSummary }: { pinId: number; onSummary?: (rating: number, count: number) => void }) {
  const { user, ready } = useAuth();
  const toast = useToast();
  const [data, setData] = useState<State | null>(null);
  const [failed, setFailed] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [rating, setRating] = useState(0);
  const [text, setText] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState(false);

  const viewer = user?.id ?? 0;
  const load = useCallback(async (page: number) => {
    const res = await api.reviews(pinId, page);
    return res;
  }, [pinId]);

  useEffect(() => {
    if (!ready) return;
    let alive = true;
    setFailed(false);
    load(1).then(
      (res) => {
        if (!alive) return;
        setData({ items: res.items ?? [], rating: res.rating ?? 0, count: res.reviewsCount ?? 0, canReview: !!res.canReview, hasMore: res.hasMore, page: 1 });
      },
      () => alive && setFailed(true),
    );
    return () => { alive = false; };
  }, [ready, viewer, load]);

  const mine = data?.items.find((r) => r.author.id === viewer);
  useEffect(() => {
    if (mine) {
      setRating(mine.rating);
      setText(mine.text);
    }
  }, [mine]);

  if (failed) return null;

  const more = async () => {
    if (!data) return;
    setLoadingMore(true);
    try {
      const res = await load(data.page + 1);
      setData({ ...data, items: [...data.items, ...res.items], hasMore: res.hasMore, page: data.page + 1 });
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setLoadingMore(false);
    }
  };

  const refresh = async () => {
    const res = await load(1);
    setData({ items: res.items ?? [], rating: res.rating ?? 0, count: res.reviewsCount ?? 0, canReview: !!res.canReview, hasMore: res.hasMore, page: 1 });
    onSummary?.(res.rating ?? 0, res.reviewsCount ?? 0);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!rating) {
      setError("Ýyldyz bilen baha beriň");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await api.addReview(pinId, { rating, text: text.trim() || undefined });
      toast(mine ? "Synyňyz täzelendi" : "Synyňyz üçin sag boluň!");
      setEditing(false);
      await refresh();
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const remove = async (id: number) => {
    if (!window.confirm("Bu syny pozmalymy?")) return;
    try {
      await api.deleteReview(id);
      setRating(0);
      setText("");
      await refresh();
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  };

  const showForm = !!data?.canReview && (!mine || editing);

  return (
    <section className="reviews" id="reviews">
      <div className="reviews-head">
        <h3>Synlar</h3>
        {data && data.count > 0 && (
          <div className="reviews-summary">
            <strong>{data.rating.toFixed(1)}</strong>
            <div>
              <Stars value={data.rating} size={16} />
              <span className="muted small">{data.count} syn</span>
            </div>
          </div>
        )}
      </div>

      {!data ? (
        <div className="skeleton" style={{ height: 64 }} />
      ) : (
        <>
          {showForm && (
            <form className="review-form" onSubmit={submit}>
              <strong>{mine ? "Synyňyzy üýtgediň" : "Haryda baha beriň"}</strong>
              <StarInput value={rating} onChange={(n) => { setRating(n); setError(null); }} />
              <textarea
                rows={3}
                value={text}
                onChange={(e) => setText(e.target.value)}
                maxLength={1000}
                placeholder="Haryt barada pikiriňizi ýazyň (hökman däl)"
                aria-label="Syn"
              />
              {error && <p className="form-error" role="alert">{error}</p>}
              <div className="form-actions">
                {mine && <button type="button" className="btn btn-secondary btn-sm" onClick={() => setEditing(false)}>Ýatyr</button>}
                <button className="btn btn-primary btn-sm" disabled={busy}>{busy ? "Iberilýär…" : "Syny iber"}</button>
              </div>
            </form>
          )}
          {!data.canReview && user && !mine && data.items.length === 0 && (
            <p className="muted small">Harydy satyn alyp, gowşurylandan soň syn ýazyp bilersiňiz.</p>
          )}
          {!user && data.items.length === 0 && (
            <p className="muted small">Entek syn ýok.</p>
          )}
          {data.items.length > 0 && (
            <ul className="review-list">
              {data.items.map((r) => (
                <li key={r.id} className="review">
                  <Link href={`/u/${r.author.username}`}><Avatar user={r.author} size={36} /></Link>
                  <div className="review-body">
                    <div className="review-top">
                      <Link href={`/u/${r.author.username}`}><strong>{r.author.name}</strong></Link>
                      <span className="muted small">{timeAgo(r.createdAt)}</span>
                    </div>
                    <Stars value={r.rating} size={13} />
                    {r.text && <p>{r.text}</p>}
                    {r.author.id === viewer && data.canReview && !editing && (
                      <button className="link-btn small" onClick={() => setEditing(true)}>Üýtget</button>
                    )}
                  </div>
                  {r.canDelete && (
                    <button className="icon-btn comment-del" onClick={() => remove(r.id)} aria-label="Syny poz"><TrashIcon size={16} /></button>
                  )}
                </li>
              ))}
            </ul>
          )}
          {data.hasMore && (
            <button className="link-btn" onClick={more} disabled={loadingMore}>{loadingMore ? "Ýüklenýär…" : "Köp syn görkez"}</button>
          )}
        </>
      )}
    </section>
  );
}
