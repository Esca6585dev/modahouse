"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import Carousel from "@/components/Carousel";
import Comments from "@/components/Comments";
import FollowButton from "@/components/FollowButton";
import {
  BackIcon, BagIcon, BoxIcon, CalendarIcon, CartIcon, CashIcon, ChatIcon, CommentIcon, EditIcon, ExternalIcon, EyeIcon, HeartIcon, LayersIcon,
  PhoneIcon, ReturnIcon, RulerIcon, ScanIcon, ShareIcon, ShieldIcon, TruckIcon, VerifiedIcon,
} from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import { Badge, Price } from "@/components/Price";
import { ColorSwatches, optionsError, QtyStepper, SizeButtons } from "@/components/ProductOptions";
import Reviews from "@/components/Reviews";
import SavePicker from "@/components/SavePicker";
import { useShare } from "@/components/ShareSheet";
import Stars from "@/components/Stars";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useAddToCart } from "@/lib/cart";
import { businessCategoryLabel, categoryName, compact, days, isForSale, money, num, phoneDigits, stockText, timeAgo } from "@/lib/format";
import { useCategories, useLoginHref, usePaged } from "@/lib/hooks";
import type { Business, Pin, Profile } from "@/lib/types";
import ContactSheet from "@/components/ContactSheet";
import PinMenu from "@/components/PinMenu";
import { RichText } from "@/components/RichText";

function hostOf(link: string) {
  try {
    return new URL(link).hostname.replace(/^www\./, "");
  } catch {
    return link;
  }
}

const STEPS_BY_TYPE: Record<string, { title: string; text: string }[]> = {
  rent: [
    { title: "Köýnegi saýlaň", text: "Ölçegini we reňkini görüň, synap görmek mugt." },
    { title: "Dükan bilen habarlaşyň", text: "«Kärendä al» düwmesi bilen senäni ylalaşyň." },
    { title: "Girew goýup alyň", text: "Gaýtaryp berlende girew yzyna berilýär." },
  ],
  custom: [
    { title: "Fasony saýlaň", text: "Şu nusga ýa-da öz islegiňiz boýunça." },
    { title: "Ölçegleriňizi iberiň", text: "«Sargyt et» düwmesi bilen ussa ýazyň." },
    { title: "Taýýar bolanda alyň", text: "Möhlet we baha ussa bilen ylalaşylýar." },
  ],
};

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

/** Rent / custom listings: details and a contact sheet instead of the cart. */
function ContactBox({ pin, business }: { pin: Pin; business: Business | null }) {
  const product = pin.product!;
  const [open, setOpen] = useState(false);
  const rent = product.listingType === "rent";
  return (
    <>
      {(product.colors.length > 0 || product.sizes.length > 0) && (
        <div className="opt-block">
          {product.colors.length > 0 && (
            <div className="ro-opts">
              <span className="opt-label">Reňkleri</span>
              <div className="chip-list">
                {product.colors.map((c) => <span key={c.name} className="edit-chip ro"><span className="dot" style={{ background: c.hex }} /> {c.name}</span>)}
              </div>
            </div>
          )}
          {product.sizes.length > 0 && (
            <div className="ro-opts">
              <span className="opt-label">Ölçegleri</span>
              <div className="chip-list">{product.sizes.map((x) => <span key={x} className="edit-chip ro">{x}</span>)}</div>
            </div>
          )}
        </div>
      )}
      <div className="spec-grid">
        {rent ? (
          <>
            <div className="spec"><CashIcon /><div><span>Günlük baha</span><strong>{money(product.price)}</strong></div></div>
            <div className="spec"><ShieldIcon /><div><span>Girew</span><strong>{product.deposit ? money(product.deposit) : "Girewsiz"}</strong></div></div>
            <div className="spec"><CalendarIcon /><div><span>Iň az möhlet</span><strong>{product.minDays ? days(product.minDays) : "1 gün"}</strong></div></div>
            <div className="spec"><ReturnIcon /><div><span>Synap görmek</span><strong>Mugt, salonda</strong></div></div>
          </>
        ) : (
          <>
            <div className="spec"><CashIcon /><div><span>Baha</span><strong>{money(product.price)}-dan başlap</strong></div></div>
            <div className="spec"><CalendarIcon /><div><span>Taýýar bolýar</span><strong>{product.readyDays ? `${days(product.readyDays)} içinde` : "Ylalaşyk boýunça"}</strong></div></div>
            <div className="spec"><LayersIcon /><div><span>Mata görnüşleri</span><strong>{product.material || "Saýlap bolýar"}</strong></div></div>
            <div className="spec"><RulerIcon /><div><span>Ölçeg</span><strong>Siziň ölçegiňize görä</strong></div></div>
          </>
        )}
      </div>
      <div className="buy-box">
        <button className="btn btn-primary btn-lg buy-now" onClick={() => setOpen(true)}>
          <ChatIcon size={20} /> {rent ? "Kärendä al" : "Sargyt et"}
        </button>
        {business?.phone && (
          <a href={`tel:${phoneDigits(business.phone)}`} className="btn btn-secondary btn-lg icon-only" aria-label="Jaň et" title="Jaň et">
            <PhoneIcon size={20} />
          </a>
        )}
      </div>
      {open && <ContactSheet pin={pin} business={business} onClose={() => setOpen(false)} />}
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
  const openShare = useShare();

  const [pin, setPin] = useState<Pin | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "notfound" | "error">("loading");
  const [loadError, setLoadError] = useState("");
  const [author, setAuthor] = useState<Profile | null>(null);
  const [likeBusy, setLikeBusy] = useState(false);
  const [slide, setSlide] = useState(0);
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

  // Links like /pin/1#comments or #reviews: scroll once the async content is there.
  useEffect(() => {
    if (state !== "ok" || !window.location.hash) return;
    const t = window.setTimeout(() => document.getElementById(window.location.hash.slice(1))?.scrollIntoView({ block: "start" }), 450);
    return () => window.clearTimeout(t);
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

  // Pinterest-style action row: ♡ count, comments, share, ⋯ on the left; the big red "Sakla" on the right.
  // Edit and delete live in the ⋯ menu.
  const toolbar = (
    <div className="detail-actions">
      <div className="detail-icons">
        {likeBtn}
        <a
          href="#comments"
          className="like"
          aria-label={`Teswirler: ${pin.commentsCount}`}
          title="Teswirler"
          onClick={(e) => {
            e.preventDefault();
            document.getElementById("comments")?.scrollIntoView({ behavior: "smooth", block: "start" });
          }}
        >
          <CommentIcon size={21} /> {pin.commentsCount > 0 ? compact(pin.commentsCount) : null}
        </a>
        <button className="icon-btn" aria-label="Paýlaş" title="Paýlaş" onClick={() => openShare(pin, slide)}>
          <ShareIcon size={21} />
        </button>
        <PinMenu
          pin={pin}
          index={slide}
          savedBoardIds={pin.savedBoardIds}
          onSavedChange={(ids) => setPin((p) => (p ? { ...p, savedBoardIds: ids } : p))}
          className="icon-btn"
        />
      </div>
      <div className="detail-save">
        <SavePicker
          pinId={pin.id}
          savedBoardIds={pin.savedBoardIds}
          onChange={(ids) => setPin((p) => (p ? { ...p, savedBoardIds: ids } : p))}
          className="btn-lg"
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
      {pin.description && <p className="detail-desc"><RichText text={pin.description} /></p>}
      {pin.link && (
        <a className="detail-link" href={pin.link} target="_blank" rel="noopener noreferrer">
          <ExternalIcon /> {hostOf(pin.link)}
        </a>
      )}
      {pin.tags.length > 0 && (
        <div className="tags">
          {pin.tags.map((t) => (
            <Link key={t} href={`/tag/${encodeURIComponent(t)}`} className="tag">#{t}</Link>
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
            <Carousel images={pin.images} title={pin.title} onIndexChange={setSlide} />
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
          <Carousel images={pin.images} title={pin.title} onIndexChange={setSlide}>
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
          <Price price={product.price} oldPrice={product.oldPrice} big type={product.listingType} />
          <div className="pdp-perks">
            {product.listingType === "rent" ? (
              <>
                <span><ShieldIcon size={18} /> Girew: {product.deposit ? money(product.deposit) : "ýok"}</span>
                {product.minDays > 0 && <span><CalendarIcon size={18} /> Iň az: {days(product.minDays)}</span>}
              </>
            ) : product.listingType === "custom" ? (
              <>
                <span><CalendarIcon size={18} /> {product.readyDays ? `${days(product.readyDays)}de taýýar` : "Möhlet ylalaşyk boýunça"}</span>
                <span><RulerIcon size={18} /> Ölçegiňize görä</span>
              </>
            ) : (
              <>
                {product.deliveryDays > 0 && <span><TruckIcon size={18} /> Eltip bermek: {days(product.deliveryDays)}</span>}
                <span><ShieldIcon size={18} /> Töleg gowşurylanda</span>
              </>
            )}
            <Link href={`/visual?pin=${pin.id}`} className="similar-link"><ScanIcon size={18} /> Meňzeşini tap</Link>
          </div>

          {isOwner ? (
            <div className="owner-panel">
              <strong>Bu siziň harydyňyz</strong>
              <div className="owner-stats">
                <span><b>{num(pin.viewsCount)}</b> görülme</span>
                <span><b>{num(pin.likesCount)}</b> halanma</span>
                <span><b>{num(pin.ordersCount)}</b> sargyt</span>
                <span><b>{product.listingType === "sale" ? stockText(product.stock) : product.listingType === "rent" ? "Kärende" : "Tikin"}</b> {product.listingType === "sale" ? "galyndy" : "görnüşi"}</span>
              </div>
              <div className="owner-bar">
                <Link href={`/pin/${pin.id}/edit`} className="btn btn-secondary btn-sm"><EditIcon size={16} /> Harydy üýtget</Link>
                <Link href="/business" className="btn btn-secondary btn-sm">Biznes paneli</Link>
              </div>
            </div>
          ) : isForSale(product) ? (
            <BuyBox pin={pin} />
          ) : (
            <ContactBox pin={pin} business={author?.business ?? null} />
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
              {(STEPS_BY_TYPE[product.listingType] ?? STEPS).map((s, i) => (
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
