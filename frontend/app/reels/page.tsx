"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import FollowButton from "@/components/FollowButton";
import { BagIcon, BookmarkIcon, CommentIcon, HeartIcon, MuteIcon, PlusIcon, ReelsIcon, SendIcon, VerifiedIcon, VolumeIcon } from "@/components/Icons";
import PinMenu from "@/components/PinMenu";
import { HiddenCard } from "@/components/PinCard";
import Popover from "@/components/Popover";
import { Price } from "@/components/Price";
import { RichText } from "@/components/RichText";
import { BoardPickerBody } from "@/components/SavePicker";
import { useShare } from "@/components/ShareSheet";
import StoryAvatar from "@/components/StoryAvatar";
import { useStories } from "@/components/StoryViewer";
import { useToast } from "@/components/Toast";
import VideoMedia, { useMuted } from "@/components/VideoMedia";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact } from "@/lib/format";
import { useLoginHref, usePaged } from "@/lib/hooks";
import type { Pin } from "@/lib/types";

function Reel({ pin: initial, active }: { pin: Pin; active: boolean }) {
  const [pin, setPin] = useState(initial);
  const [hidden, setHidden] = useState(false);
  const [deleted, setDeleted] = useState(false);
  const [saveOpen, setSaveOpen] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const [heart, setHeart] = useState(0);
  const [muted, setMuted] = useMuted();
  const [flash, setFlash] = useState(0);
  const saveBtn = useRef<HTMLButtonElement>(null);
  const lastTap = useRef(0);
  const busy = useRef(false);
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const openShare = useShare();
  const stories = useStories();
  const media = pin.images.find((m) => m.type === "video") ?? pin.images[0];
  const [following, setFollowing] = useState<boolean | null>(null);

  // Follow state is not part of a pin: look it up once the reel is on screen.
  const author = pin.author.username;
  const needFollow = active && !!user && user.id !== pin.author.id && following === null;
  useEffect(() => {
    if (!needFollow) return;
    let alive = true;
    api.user(author).then((p) => alive && setFollowing(p.isFollowing), () => {});
    return () => { alive = false; };
  }, [needFollow, author]);

  if (deleted) return <div className="reel"><div className="reel-frame reel-gone">Pozuldy</div></div>;

  const like = async (want: boolean) => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    if (busy.current || pin.liked === want) return;
    busy.current = true;
    const prev = { liked: pin.liked, likesCount: pin.likesCount };
    setPin((p) => ({ ...p, liked: want, likesCount: p.likesCount + (want ? 1 : -1) }));
    try {
      const r = want ? await api.like(pin.id) : await api.unlike(pin.id);
      setPin((p) => ({ ...p, ...r }));
    } catch (e) {
      setPin((p) => ({ ...p, ...prev }));
      toast(errorMessage(e), "error");
    } finally {
      busy.current = false;
    }
  };

  const onTap = () => {
    const now = Date.now();
    if (now - lastTap.current < 300) {
      lastTap.current = 0;
      setHeart((n) => n + 1);
      like(true);
      return;
    }
    lastTap.current = now;
    window.setTimeout(() => {
      if (lastTap.current !== now) return;
      setMuted(!muted);
      setFlash((n) => n + 1);
    }, 300);
  };

  const saved = pin.savedBoardIds.length > 0;
  const text = [pin.title, pin.description].filter(Boolean).join("\n");

  return (
    <div className="reel">
      <div className="reel-frame" style={{ background: media?.color || "#000" }}>
        {hidden ? (
          <HiddenCard pin={pin} onUndo={() => setHidden(false)} className="reel-hidden" />
        ) : (
          <>
            {media?.type === "video" ? (
              <VideoMedia src={media.url} poster={media.posterUrl} fit="cover" active={active} showMute={false} onTap={onTap} />
            ) : (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={pin.imageUrl} alt={pin.title} className="reel-img" />
            )}
            {flash > 0 && (
              <span key={flash} className="reel-flash" aria-hidden onAnimationEnd={() => setFlash(0)}>
                {muted ? <MuteIcon size={30} /> : <VolumeIcon size={30} />}
              </span>
            )}
            {heart > 0 && (
              <span key={`h${heart}`} className="big-heart" aria-hidden onAnimationEnd={() => setHeart(0)}><HeartIcon size={110} /></span>
            )}
            <div className="reel-info">
              <div className="reel-author">
                <StoryAvatar user={pin.author} size={34} ring={stories.ringFor(pin.author.id)} onClick={() => stories.openFor(pin.author)} />
                <Link href={`/u/${pin.author.username}`} className="reel-name">
                  {pin.author.username}
                  {pin.author.verified && <VerifiedIcon size={13} />}
                </Link>
                {(!user || (user.id !== pin.author.id && following !== null)) && (
                  <FollowButton username={pin.author.username} isFollowing={!!following} onChange={(on) => setFollowing(on)} className="btn-sm reel-follow" />
                )}
              </div>
              <p className={`reel-caption ${expanded ? "open" : ""}`} onClick={() => setExpanded((e) => !e)}>
                <RichText text={text} />
              </p>
              {pin.product && (
                <Link href={`/pin/${pin.id}`} className="reel-product">
                  <BagIcon size={16} />
                  <Price price={pin.product.price} oldPrice={pin.product.oldPrice} type={pin.product.listingType} />
                </Link>
              )}
            </div>
          </>
        )}
      </div>
      {!hidden && (
        <div className="reel-rail">
          <button className={`rail-btn ${pin.liked ? "liked" : ""}`} onClick={() => like(!pin.liked)} aria-pressed={pin.liked} aria-label="Halaýaryn">
            <HeartIcon size={28} /><span>{compact(pin.likesCount)}</span>
          </button>
          <Link href={`/pin/${pin.id}#comments`} className="rail-btn" aria-label="Teswirler">
            <CommentIcon size={27} /><span>{compact(pin.commentsCount)}</span>
          </Link>
          <button
            className="rail-btn"
            aria-label="Paýlaş"
            onClick={() => openShare(pin)}
          >
            <SendIcon size={26} /><span>Paýlaş</span>
          </button>
          <button ref={saveBtn} className={`rail-btn ${saved ? "saved" : ""}`} aria-label="Sakla" onClick={() => (user ? setSaveOpen((o) => !o) : router.push(loginHref()))}>
            <BookmarkIcon size={27} filled={saved} /><span>{saved ? "Saklandy" : "Sakla"}</span>
          </button>
          <Popover anchor={saveBtn} open={saveOpen} onClose={() => setSaveOpen(false)} width={320} label="Tagta saýla">
            <BoardPickerBody pinId={pin.id} savedBoardIds={pin.savedBoardIds} onChange={(ids) => setPin((p) => ({ ...p, savedBoardIds: ids }))} />
          </Popover>
          <PinMenu
            pin={pin}
            savedBoardIds={pin.savedBoardIds}
            onSavedChange={(ids) => setPin((p) => ({ ...p, savedBoardIds: ids }))}
            onHidden={() => setHidden(true)}
            onDeleted={() => setDeleted(true)}
            className="rail-btn rail-dots"
            light
          />
        </div>
      )}
    </div>
  );
}

export default function ReelsPage() {
  const { user, ready } = useAuth();
  const paged = usePaged(ready ? `reels:${user?.id ?? 0}` : null, (page) => api.pins({ type: "videos", page, limit: 8 }));
  const [active, setActive] = useState(0);
  const box = useRef<HTMLDivElement>(null);
  const { items, hasMore, loading, loadMore } = paged;

  useEffect(() => { document.title = "Reels · ModaHouse"; }, []);

  useEffect(() => {
    const root = box.current;
    if (!root) return;
    const io = new IntersectionObserver((entries) => {
      for (const e of entries) {
        if (e.isIntersecting && e.intersectionRatio >= 0.6) setActive(Number((e.target as HTMLElement).dataset.index));
      }
    }, { root, threshold: [0.6] });
    root.querySelectorAll<HTMLElement>("[data-index]").forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, [items.length]);

  useEffect(() => {
    if (hasMore && !loading && active >= items.length - 3) loadMore();
  }, [active, items.length, hasMore, loading, loadMore]);

  // Arrow keys move between reels on desktop.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (!box.current || (e.key !== "ArrowDown" && e.key !== "ArrowUp")) return;
      if ((e.target as HTMLElement)?.closest("input, textarea")) return;
      e.preventDefault();
      const next = Math.max(0, Math.min(items.length - 1, active + (e.key === "ArrowDown" ? 1 : -1)));
      box.current.querySelector<HTMLElement>(`[data-index="${next}"]`)?.scrollIntoView({ behavior: "smooth" });
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, items.length]);

  return (
    <div className="reels-page">
      <div className="reels-top">
        <h1><ReelsIcon size={22} /> Reels</h1>
        <Link href="/create" className="reels-add" aria-label="Wideo goş"><PlusIcon size={20} /></Link>
      </div>
      <div className="reels" ref={box}>
        {!paged.loaded ? (
          <div className="reel"><div className="reel-frame skeleton-dark"><span className="spinner sv-spinner" /></div></div>
        ) : items.length === 0 ? (
          <div className="reel">
            <div className="reel-frame reel-empty">
              <ReelsIcon size={44} />
              <h2>Entek reels ýok</h2>
              <p>{paged.error ?? "Ilkinji gysga wideony siz goşuň!"}</p>
              <Link href="/create" className="btn btn-primary">Wideo goş</Link>
            </div>
          </div>
        ) : (
          items.map((p, i) => (
            <section key={p.id} className="reel-slot" data-index={i} aria-label={p.title}>
              <Reel pin={p} active={i === active} />
            </section>
          ))
        )}
      </div>
    </div>
  );
}
