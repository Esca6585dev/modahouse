"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import Comments from "@/components/Comments";
import FollowButton from "@/components/FollowButton";
import { BackIcon, EditIcon, ExternalIcon, HeartIcon, ShareIcon, TrashIcon } from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import PinImage from "@/components/PinImage";
import SavePicker from "@/components/SavePicker";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { categoryName, compact, timeAgo } from "@/lib/format";
import { useCategories, useLoginHref, usePaged } from "@/lib/hooks";
import { shareUrl } from "@/lib/share";
import type { Pin, Profile } from "@/lib/types";

function hostOf(link: string) {
  try {
    return new URL(link).hostname.replace(/^www\./, "");
  } catch {
    return link;
  }
}

export default function PinPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const { user, ready } = useAuth();
  const loginHref = useLoginHref();
  const toast = useToast();
  const cats = useCategories();

  const [pin, setPin] = useState<Pin | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "notfound" | "error">("loading");
  const [loadError, setLoadError] = useState("");
  const [author, setAuthor] = useState<Profile | null>(null);
  const [likeBusy, setLikeBusy] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [nonce, setNonce] = useState(0);

  const viewer = user?.id ?? 0;
  useEffect(() => {
    if (!ready) return;
    let alive = true;
    setState((s) => (s === "ok" ? s : "loading"));
    api.pin(id).then(
      (p) => {
        if (!alive) return;
        setPin(p);
        setState("ok");
        document.title = `${p.title} · ModaHouse`;
      },
      (e) => {
        if (!alive) return;
        if (e instanceof ApiError && e.status === 404) setState("notfound");
        else {
          setLoadError(errorMessage(e));
          setState("error");
        }
      },
    );
    return () => { alive = false; };
  }, [id, ready, viewer, nonce]);

  const authorName = pin?.author.username;
  useEffect(() => {
    if (!authorName || !ready) return;
    let alive = true;
    api.user(authorName).then((p) => alive && setAuthor(p), () => {});
    return () => { alive = false; };
  }, [authorName, ready, viewer]);

  const similar = usePaged(pin ? `similar:${pin.id}:${viewer}` : null, (page) => api.similar(Number(id), page));

  if (state === "notfound") {
    return (
      <div className="page">
        <div className="empty">
          <h2>Pin tapylmady</h2>
          <p>Bu pin pozulan ýa-da hiç haçan bolmadyk bolmagy mümkin.</p>
          <Link href="/" className="btn btn-primary">Baş sahypa gaýt</Link>
        </div>
      </div>
    );
  }
  if (state === "error") {
    return (
      <div className="page">
        <div className="empty">
          <h2>Ýüklenmedi</h2>
          <p>{loadError}</p>
          <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
        </div>
      </div>
    );
  }
  if (!pin || String(pin.id) !== id) {
    return (
      <div className="page">
        <div className="detail detail-loading" aria-busy="true">
          <div className="skeleton" style={{ aspectRatio: "3 / 4" }} />
          <div className="detail-body">
            <div className="skeleton skeleton-line" style={{ width: "40%", height: 44 }} />
            <div className="skeleton skeleton-line" style={{ width: "80%", height: 36 }} />
            <div className="skeleton skeleton-line" />
            <div className="skeleton skeleton-line" style={{ width: "60%" }} />
          </div>
        </div>
      </div>
    );
  }

  const isOwner = viewer !== 0 && viewer === pin.author.id;

  const toggleLike = async () => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    if (likeBusy) return;
    const prev = { liked: pin.liked, likesCount: pin.likesCount };
    const next = { liked: !prev.liked, likesCount: prev.likesCount + (prev.liked ? -1 : 1) };
    setPin((p) => (p ? { ...p, ...next } : p));
    setLikeBusy(true);
    try {
      const res = next.liked ? await api.like(pin.id) : await api.unlike(pin.id);
      setPin((p) => (p ? { ...p, ...res } : p));
    } catch (e) {
      setPin((p) => (p ? { ...p, ...prev } : p));
      toast(errorMessage(e), "error");
    } finally {
      setLikeBusy(false);
    }
  };

  const remove = async () => {
    if (!window.confirm("Bu pini pozmalymy? Bu hereketi yzyna gaýtaryp bolmaýar.")) return;
    setDeleting(true);
    try {
      await api.deletePin(pin.id);
      toast("Pin pozuldy");
      router.replace(`/u/${pin.author.username}`);
    } catch (e) {
      toast(errorMessage(e), "error");
      setDeleting(false);
    }
  };

  return (
    <div className="page">
      <button className="back icon-btn" aria-label="Yza" onClick={() => (window.history.length > 1 ? router.back() : router.push("/"))}>
        <BackIcon />
      </button>
      <article className="detail">
        <div className="detail-media" style={{ background: pin.color || undefined }}>
          <PinImage pin={pin} eager />
        </div>
        <div className="detail-body">
          <div className="detail-actions">
            <div className="detail-icons">
              <button
                className="icon-btn"
                aria-label="Paýlaş"
                title="Paýlaş"
                onClick={async () => {
                  const msg = await shareUrl(`/pin/${pin.id}`, pin.title);
                  if (msg) toast(msg);
                }}
              >
                <ShareIcon size={22} />
              </button>
            </div>
            <div className="detail-save">
              <SavePicker
                pinId={pin.id}
                savedBoardIds={pin.savedBoardIds}
                onChange={(ids) => setPin((p) => (p ? { ...p, savedBoardIds: ids } : p))}
              />
            </div>
          </div>

          {isOwner && (
            <div className="owner-bar">
              <Link href={`/pin/${pin.id}/edit`} className="btn btn-secondary btn-sm"><EditIcon size={16} /> Üýtget</Link>
              <button className="btn btn-secondary btn-sm danger" onClick={remove} disabled={deleting}>
                <TrashIcon size={16} /> {deleting ? "Pozulýar…" : "Poz"}
              </button>
            </div>
          )}

          <Link href={`/?c=${encodeURIComponent(pin.category)}`} className="detail-cat">{categoryName(pin.category, cats)}</Link>
          <h1>{pin.title}</h1>
          {pin.description && <p className="detail-desc">{pin.description}</p>}
          {pin.link && (
            <a className="detail-link" href={pin.link} target="_blank" rel="noopener noreferrer">
              <ExternalIcon /> {hostOf(pin.link)}
            </a>
          )}
          {pin.tags.length > 0 && (
            <div className="tags">
              {pin.tags.map((t) => (
                <Link key={t} href={`/?q=${encodeURIComponent(t)}`} className="tag">#{t}</Link>
              ))}
            </div>
          )}
          <span className="muted small">{timeAgo(pin.createdAt)} goşuldy</span>

          <div className="detail-author">
            <Link href={`/u/${pin.author.username}`}><Avatar user={pin.author} size={44} /></Link>
            <div>
              <Link href={`/u/${pin.author.username}`}><strong>{pin.author.name}</strong></Link>
              <span>{author ? `${compact(author.followersCount)} yzarlaýjy` : `@${pin.author.username}`}</span>
            </div>
            {!isOwner && (
              <FollowButton
                username={pin.author.username}
                isFollowing={author?.isFollowing ?? false}
                onChange={(on, p) =>
                  setAuthor((a) => p ?? (a ? { ...a, isFollowing: on, followersCount: a.followersCount + (on === a.isFollowing ? 0 : on ? 1 : -1) } : a))}
              />
            )}
          </div>

          <Comments
            pinId={pin.id}
            count={pin.commentsCount}
            onCountChange={(n) => setPin((p) => (p ? { ...p, commentsCount: n } : p))}
            head={
              <button
                className={`like ${pin.liked ? "on" : ""}`}
                onClick={toggleLike}
                disabled={likeBusy}
                aria-pressed={pin.liked}
                aria-label={pin.liked ? "Halamany aýyr" : "Halaýaryn"}
              >
                <HeartIcon /> {pin.likesCount}
              </button>
            }
          />
        </div>
      </article>

      <h2 className="section-title">Şuňa meňzeşler</h2>
      <PinFeed paged={similar} empty={<p className="muted center">Meňzeş pin tapylmady.</p>} />
    </div>
  );
}
