"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import Carousel from "@/components/Carousel";
import Comments from "@/components/Comments";
import FollowButton from "@/components/FollowButton";
import {
  BackIcon, BagIcon, BoxIcon, CalendarIcon, CartIcon, EditIcon, ExternalIcon, EyeIcon, HeartIcon, LayersIcon, ReturnIcon,
  ShareIcon, ShieldIcon, TrashIcon, TruckIcon, VerifiedIcon,
} from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import { Badge, Price } from "@/components/Price";
import { ColorSwatches, optionsError, QtyStepper, SizeButtons } from "@/components/ProductOptions";
import Reviews from "@/components/Reviews";
import SavePicker from "@/components/SavePicker";
import Stars from "@/components/Stars";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useAddToCart } from "@/lib/cart";
import { businessCategoryLabel, categoryName, compact, days, isForSale, num, stockText, timeAgo } from "@/lib/format";
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

const STEPS = [
  { title: "Halan harydyňy saýla", text: "Reňkini, ölçegini we sanyny kesgitle." },
  { title: "Sebede goş ýa-da «Zakaz et»", text: "Adyňy, telefonyňy we salgyňy ýaz." },
  { title: "Tassyklanyş", text: "Dükan sargydy tassyklap, size jaň eder. Töleg gowşurylanda." },
];

function BuyBox({ pin }: { pin: Pin }) {
  const product = pin.product!;
  const router = useRouter();
  const toast = useToast();
  const { user } = useAuth();
  const loginHref = useLoginHref();
  const addToCart = useAddToCart(toast);
  const [color, setColor] = useState(product.colors.length === 1 ? product.colors[0].name : "");
  const [size, setSize] = useState(product.sizes.length === 1 ? product.sizes[0] : "");
  const [qty, setQty] = useState(1);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const out = product.stock !== null && product.stock <= 0;

  const check = () => {
    const err = optionsError(product, color, size);
    setError(err);
    if (err) toast(err, "error");
    return !err;
  };

  const buyNow = () => {
    if (!check()) return;
    const q = new URLSearchParams({ buy: String(pin.id), qty: String(qty) });
    if (color) q.set("color", color);
    if (size) q.set("size", size);
    const href = `/checkout?${q.toString()}`;
    if (!user) router.push(`/login?next=${encodeURIComponent(href)}`);
    else router.push(href);
  };

  const add = async () => {
    if (!user) {
      router.push(loginHref());
      return;
    }
    if (!check()) return;
    setBusy(true);
    await addToCart({ pinId: pin.id, color: color || undefined, size: size || undefined, quantity: qty });
    setBusy(false);
  };

  return (
    <>
      <ColorSwatches colors={product.colors} value={color} onChange={(c) => { setColor(c); setError(null); }} />
      <SizeButtons sizes={product.sizes} value={size} onChange={(s) => { setSize(s); setError(null); }} />

      <div className="spec-grid">
        <div className="spec"><LayersIcon /><div><span>Materialy</span><strong>{product.material || "Görkezilmedik"}</strong></div></div>
        <div className="spec"><BoxIcon /><div><span>Galyndy</span><strong className={out ? "danger-text" : product.stock !== null && product.stock <= 3 ? "warn-text" : "ok-text"}>{stockText(product.stock)}</strong></div></div>
        <div className="spec"><CalendarIcon /><div><span>Eltip bermek wagty</span><strong>{product.deliveryDays ? days(product.deliveryDays) : "Ylalaşyk boýunça"}</strong></div></div>
        <div className="spec"><ReturnIcon /><div><span>Gaýtaryp bermek / çalyşmak</span><strong>{product.returnDays ? `${days(product.returnDays)} içinde` : "Ýok"}</strong></div></div>
      </div>

      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="buy-box">
        <div className="buy-qty">
          <span className="muted small">Sany</span>
          <QtyStepper value={qty} onChange={setQty} max={product.stock ?? 99} />
        </div>
        <button className="btn btn-primary btn-lg buy-now" onClick={buyNow} disabled={out}>
          <BagIcon size={20} /> {out ? "Gutardy" : "Zakaz et"}
        </button>
        <button className="btn btn-secondary btn-lg icon-only" onClick={add} disabled={busy || out} aria-label="Sebede goş" title="Sebede goş">
          {busy ? <span className="spinner" /> : <CartIcon size={22} />}
        </button>
      </div>
    </>
  );
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
  const viewed = useRef<string | null>(null);

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

  // Count a view once per page open.
  useEffect(() => {
    if (state !== "ok" || viewed.current === id) return;
    viewed.current = id;
    api.viewPin(Number(id)).then(
      (r) => setPin((p) => (p && String(p.id) === id && typeof r?.viewsCount === "number" ? { ...p, viewsCount: r.viewsCount } : p)),
      () => {},
    );
  }, [state, id]);

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
  const product = pin.product;

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
    if (!window.confirm(product ? "Bu harydy pozmalymy? Bu hereketi yzyna gaýtaryp bolmaýar." : "Bu pini pozmalymy? Bu hereketi yzyna gaýtaryp bolmaýar.")) return;
    setDeleting(true);
    try {
      await api.deletePin(pin.id);
      toast(product ? "Haryt pozuldy" : "Pin pozuldy");
      router.replace(`/u/${pin.author.username}`);
    } catch (e) {
      toast(errorMessage(e), "error");
      setDeleting(false);
    }
  };

  const likeBtn = (
    <button
      className={`like ${pin.liked ? "on" : ""}`}
      onClick={toggleLike}
      disabled={likeBusy}
      aria-pressed={pin.liked}
      aria-label={pin.liked ? "Halamany aýyr" : "Halaýaryn"}
    >
      <HeartIcon size={20} /> {compact(pin.likesCount)}
    </button>
  );

  const toolbar = (
    <div className="detail-actions">
      <div className="detail-icons">
        {likeBtn}
        <button
          className="icon-btn"
          aria-label="Paýlaş"
          title="Paýlaş"
          onClick={async () => {
            const msg = await shareUrl(`/pin/${pin.id}`, pin.title);
            if (msg) toast(msg);
          }}
        >
          <ShareIcon size={20} />
        </button>
        {isOwner && (
          <>
            <Link href={`/pin/${pin.id}/edit`} className="icon-btn" aria-label="Üýtget" title="Üýtget"><EditIcon size={20} /></Link>
            <button className="icon-btn danger" onClick={remove} disabled={deleting} aria-label="Poz" title="Poz"><TrashIcon size={20} /></button>
          </>
        )}
      </div>
      <div className="detail-save">
        <SavePicker
          pinId={pin.id}
          savedBoardIds={pin.savedBoardIds}
          onChange={(ids) => setPin((p) => (p ? { ...p, savedBoardIds: ids } : p))}
        />
      </div>
    </div>
  );

  const authorCard = (
    <div className="detail-author">
      <Link href={`/u/${pin.author.username}`}><Avatar user={pin.author} size={48} /></Link>
      <div>
        <Link href={`/u/${pin.author.username}`} className="name-line">
          <strong>{pin.author.name}</strong>
          {pin.author.verified && <VerifiedIcon size={15} />}
        </Link>
        <span>
          {author?.business ? `${businessCategoryLabel(author.business.category)} · ` : ""}
          {author ? `${compact(author.followersCount)} yzarlaýjy` : `@${pin.author.username}`}
        </span>
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
  );

  const textBlock = (
    <>
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
    </>
  );

  const comments = (
    <Comments
      pinId={pin.id}
      count={pin.commentsCount}
      onCountChange={(n) => setPin((p) => (p ? { ...p, commentsCount: n } : p))}
    />
  );

  const back = (
    <button className="back icon-btn" aria-label="Yza" onClick={() => (window.history.length > 1 ? router.back() : router.push("/"))}>
      <BackIcon />
    </button>
  );

  if (!product) {
    return (
      <div className="page">
        {back}
        <article className="detail">
          <div className="detail-media" style={{ background: pin.color || undefined }}>
            <Carousel images={pin.images} title={pin.title} />
          </div>
          <div className="detail-body">
            {toolbar}
            <Link href={`/?c=${encodeURIComponent(pin.category)}`} className="detail-cat">{categoryName(pin.category, cats)}</Link>
            <h1>{pin.title}</h1>
            {textBlock}
            <span className="muted small">{timeAgo(pin.createdAt)} goşuldy</span>
            {authorCard}
            {comments}
          </div>
        </article>

        <h2 className="section-title">Şuňa meňzeşler</h2>
        <PinFeed paged={similar} empty={<p className="muted center">Meňzeş pin tapylmady.</p>} />
      </div>
    );
  }

  return (
    <div className="page">
      {back}
      <article className="pdp">
        <div className="pdp-gallery">
          <Carousel images={pin.images} title={pin.title}>
            <Badge badge={product.badge} className="pdp-badge" />
          </Carousel>
        </div>

        <div className="pdp-info">
          {toolbar}
          <Link href={`/u/${pin.author.username}`} className="pdp-shop">
            <Avatar user={pin.author} size={28} />
            <span>{pin.author.name}</span>
            {pin.author.verified && <VerifiedIcon size={14} />}
          </Link>
          <h1 className="pdp-title">{pin.title}</h1>
          <div className="pdp-meta">
            <a href="#reviews" className="pdp-rating">
              <Stars value={pin.rating} size={15} />
              <span>{pin.reviewsCount ? `${pin.rating.toFixed(1)} · ${pin.reviewsCount} syn` : "Entek syn ýok"}</span>
            </a>
            <span className="dot-sep" />
            <span><EyeIcon size={15} /> {num(pin.viewsCount)}</span>
            {pin.ordersCount > 0 && (<><span className="dot-sep" /><span><BagIcon size={15} /> {num(pin.ordersCount)} sargyt</span></>)}
          </div>
          <Price price={product.price} oldPrice={product.oldPrice} big />
          <div className="pdp-perks">
            {product.deliveryDays > 0 && <span><TruckIcon size={18} /> Eltip bermek: {days(product.deliveryDays)}</span>}
            <span><ShieldIcon size={18} /> Töleg gowşurylanda</span>
          </div>

          {isOwner ? (
            <div className="owner-panel">
              <strong>Bu siziň harydyňyz</strong>
              <div className="owner-stats">
                <span><b>{num(pin.viewsCount)}</b> görülme</span>
                <span><b>{num(pin.likesCount)}</b> halanma</span>
                <span><b>{num(pin.ordersCount)}</b> sargyt</span>
                <span><b>{stockText(product.stock)}</b> galyndy</span>
              </div>
              <div className="owner-bar">
                <Link href={`/pin/${pin.id}/edit`} className="btn btn-secondary btn-sm"><EditIcon size={16} /> Harydy üýtget</Link>
                <Link href="/business" className="btn btn-secondary btn-sm">Biznes paneli</Link>
              </div>
            </div>
          ) : isForSale(product) ? (
            <BuyBox pin={pin} />
          ) : (
            <div className="owner-panel">
              <strong>Bu haryt sebede goşulmaýar</strong>
              <span className="muted small">Şertleri anyklamak üçin dükan bilen habarlaşyň.</span>
              <Link href={`/u/${pin.author.username}`} className="btn btn-primary">Dükan bilen habarlaş</Link>
            </div>
          )}

          <section className="how-to">
            <div className="how-head">
              <BagIcon size={22} />
              <div>
                <strong>Nädip sargyt etmeli?</strong>
                <span>Örän aňsat! 3 ädimde sargyt ediň:</span>
              </div>
            </div>
            <ol className="steps">
              {STEPS.map((s, i) => (
                <li key={i}>
                  <span className="step-num">{i + 1}</span>
                  <div><strong>{s.title}</strong><span>{s.text}</span></div>
                </li>
              ))}
            </ol>
          </section>
        </div>
      </article>

      <div className="pdp-lower">
        <div className="pdp-col">
          <section className="panel">
            <h3>Haryt barada</h3>
            {textBlock}
            {!pin.description && pin.tags.length === 0 && !pin.link && <p className="muted small">Goşmaça maglumat ýok.</p>}
            <span className="muted small">
              <Link href={`/?c=${encodeURIComponent(pin.category)}`} className="text-link">{categoryName(pin.category, cats)}</Link> · {timeAgo(pin.createdAt)} goşuldy
            </span>
            {authorCard}
          </section>
          <section className="panel">{comments}</section>
        </div>
        <div className="pdp-col">
          <section className="panel">
            <Reviews
              pinId={pin.id}
              onSummary={(rating, count) => setPin((p) => (p ? { ...p, rating, reviewsCount: count } : p))}
            />
          </section>
        </div>
      </div>

      <h2 className="section-title">Meňzeş harytlar</h2>
      <PinFeed paged={similar} empty={<p className="muted center">Meňzeş haryt tapylmady.</p>} />
    </div>
  );
}
