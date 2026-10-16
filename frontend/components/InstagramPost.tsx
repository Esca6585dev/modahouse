"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact, isForSale, timeAgo } from "@/lib/format";
import { useLoginHref } from "@/lib/hooks";
import type { Pin } from "@/lib/types";
import Caption, { RichText } from "./RichText";
import Carousel from "./Carousel";
import { BagIcon, BookmarkIcon, ChevronRightIcon, CommentIcon, HeartIcon, SendIcon, VerifiedIcon } from "./Icons";
import PinMenu from "./PinMenu";
import Popover from "./Popover";
import { HiddenCard } from "./PinCard";
import { ListingChip, Price } from "./Price";
import { BoardPickerBody } from "./SavePicker";
import { useShare } from "./ShareSheet";
import StoryAvatar from "./StoryAvatar";
import { useStories } from "./StoryViewer";
import { useToast } from "./Toast";

/** One full-width post in the Instagram view. */
export default function InstagramPost({ pin: initial }: { pin: Pin }) {
  const [pin, setPin] = useState(initial);
  const [state, setState] = useState<"shown" | "hidden" | "deleted">("shown");
  const [heart, setHeart] = useState(0);
  const [index, setIndex] = useState(0);
  const [saveOpen, setSaveOpen] = useState(false);
  const saveBtn = useRef<HTMLButtonElement>(null);
  const likeBusy = useRef(false);
  const { user } = useAuth();
  const router = useRouter();
  const loginHref = useLoginHref();
  const toast = useToast();
  const stories = useStories();
  const openShare = useShare();
  const href = `/pin/${pin.id}`;
  const product = pin.product;

  if (state === "deleted") return null;
  if (state === "hidden") return <HiddenCard pin={pin} onUndo={() => setState("shown")} className="ig-post hidden-post" />;

  const setLike = async (want: boolean) => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    if (likeBusy.current || pin.liked === want) return;
    likeBusy.current = true;
    const prev = { liked: pin.liked, likesCount: pin.likesCount };
    setPin((p) => ({ ...p, liked: want, likesCount: p.likesCount + (want ? 1 : -1) }));
    try {
      const res = want ? await api.like(pin.id) : await api.unlike(pin.id);
      setPin((p) => ({ ...p, ...res }));
    } catch (e) {
      setPin((p) => ({ ...p, ...prev }));
      toast(errorMessage(e), "error");
    } finally {
      likeBusy.current = false;
    }
  };

  const doubleTap = () => {
    setHeart((n) => n + 1);
    setLike(true);
  };

  const text = [pin.title, pin.description].filter(Boolean).join(pin.description ? " — " : "");
  const ring = stories.ringFor(pin.author.id);
  const comments = pin.latestComments ?? [];
  const saved = pin.savedBoardIds.length > 0;

  return (
    <article className="ig-post">
      <header className="igp-head">
        <StoryAvatar user={pin.author} size={36} ring={ring} onClick={() => stories.openFor(pin.author)} />
        <div className="igp-who">
          <Link href={`/u/${pin.author.username}`} className="igp-name">
            {pin.author.username}
            {pin.author.verified && <VerifiedIcon size={13} />}
          </Link>
          <span className="igp-sub">
            {product ? (isForSale(product) ? "Satlyk" : product.listingType === "rent" ? "Kärende" : "Sargyt bilen tikmek") : pin.author.name}
          </span>
        </div>
        <PinMenu
          pin={pin}
          savedBoardIds={pin.savedBoardIds}
          onSavedChange={(ids) => setPin((p) => ({ ...p, savedBoardIds: ids }))}
          onHidden={() => setState("hidden")}
          onDeleted={() => setState("deleted")}
          index={index}
        />
      </header>

      <div className="igp-media">
        <Carousel images={pin.images} title={pin.title} thumbs={false} onDoubleTap={doubleTap} onIndexChange={setIndex} maxRatio={1.25} className="igp-carousel">
          {product && <ListingChip type={product.listingType} className="igp-chip" />}
        </Carousel>
        {heart > 0 && (
          <span key={heart} className="big-heart" aria-hidden onAnimationEnd={() => setHeart(0)}>
            <HeartIcon size={96} />
          </span>
        )}
      </div>

      {product && (
        <Link href={href} className="igp-shop">
          <BagIcon size={18} />
          <Price price={product.price} oldPrice={product.oldPrice} type={product.listingType} />
          <span className="igp-shop-cta">
            {isForSale(product) ? "Satyn al" : product.listingType === "rent" ? "Kärendä al" : "Sargyt et"}
            <ChevronRightIcon size={16} />
          </span>
        </Link>
      )}

      <div className="igp-actions">
        <button className={`igp-btn ${pin.liked ? "liked" : ""}`} onClick={() => setLike(!pin.liked)} aria-pressed={pin.liked} aria-label={pin.liked ? "Halamany aýyr" : "Halaýaryn"}>
          <HeartIcon size={26} />
        </button>
        <Link href={`${href}#comments`} className="igp-btn" aria-label="Teswir"><CommentIcon size={25} /></Link>
        <button
          className="igp-btn"
          aria-label="Paýlaş"
          onClick={() => openShare(pin, index)}
        >
          <SendIcon size={24} />
        </button>
        <button
          ref={saveBtn}
          className={`igp-btn igp-save ${saved ? "saved" : ""}`}
          aria-label={saved ? "Saklandy" : "Sakla"}
          onClick={() => (user ? setSaveOpen((o) => !o) : router.push(loginHref()))}
        >
          <BookmarkIcon size={25} filled={saved} />
        </button>
        <Popover anchor={saveBtn} open={saveOpen} onClose={() => setSaveOpen(false)} width={320} label="Tagta saýla">
          <BoardPickerBody pinId={pin.id} savedBoardIds={pin.savedBoardIds} onChange={(ids) => setPin((p) => ({ ...p, savedBoardIds: ids }))} />
        </Popover>
      </div>

      <div className="igp-body">
        {pin.likesCount > 0 && <strong className="igp-likes">{compact(pin.likesCount)} halanma</strong>}
        <Caption name={pin.author.username} href={`/u/${pin.author.username}`} text={text} />
        {pin.commentsCount > comments.length && (
          <Link href={`${href}#comments`} className="igp-all">
            {pin.commentsCount} teswiriň hemmesini gör
          </Link>
        )}
        {comments.length > 0 && (
          <ul className="igp-comments">
            {comments.map((c) => (
              <li key={c.id}>
                <Link href={`/u/${c.author.username}`} className="caption-name">{c.author.username}</Link>{" "}
                <RichText text={c.text} />
              </li>
            ))}
          </ul>
        )}
        <time className="igp-time" dateTime={pin.createdAt}>{timeAgo(pin.createdAt)}</time>
      </div>
    </article>
  );
}
