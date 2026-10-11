"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import {
  BagIcon, CalendarIcon, ChevronLeftIcon, ChevronRightIcon, CloseIcon, LightbulbIcon, PlayIcon, PlusIcon, RulerIcon, SparkIcon,
  UploadIcon,
} from "@/components/Icons";
import PinFields, { emptyPinFields, validatePinFields, type PinFieldValues } from "@/components/PinFields";
import ProductFields, { appendProduct, emptyProduct, validateProduct, type ProductValues } from "@/components/ProductFields";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { duration } from "@/lib/format";
import { useCategories, useRequireAuth } from "@/lib/hooks";
import { IMAGE_TYPES, MAX_VIDEO_MB, MAX_VIDEO_SECONDS, VIDEO_TYPES, videoPoster } from "@/lib/media";
import type { Board, ListingType, Suggestion } from "@/lib/types";

const MAX_MB = 20;
const MAX_MEDIA = 8;

type Picked = { file: File; url: string; src?: string; kind: "image" | "video"; poster?: File; duration?: number; loading?: boolean };

const TYPE_OPTIONS: { value: ListingType; label: string; hint: string; icon: React.ReactNode; business: boolean }[] = [
  { value: "post", label: "Diňe paýlaşmak", hint: "Ideýa, surat ýa-da wideo", icon: <LightbulbIcon size={18} />, business: false },
  { value: "sale", label: "Satlyk", hint: "Sebet we sargyt", icon: <BagIcon size={18} />, business: true },
  { value: "rent", label: "Kärende", hint: "Günlük baha we girew", icon: <CalendarIcon size={18} />, business: true },
  { value: "custom", label: "Sargyt bilen tikmek", hint: "…-dan başlap, möhlet", icon: <RulerIcon size={18} />, business: true },
];

function AiBox({
  listingType, fields, product, firstImage, onInsert,
}: {
  listingType: ListingType;
  fields: PinFieldValues;
  product: ProductValues;
  firstImage: File | null;
  onInsert: (s: Suggestion) => void;
}) {
  const toast = useToast();
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [sugg, setSugg] = useState<Suggestion | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    api.aiStatus().then((r) => setEnabled(!!r.enabled), () => setEnabled(false));
  }, []);

  const run = async () => {
    setBusy(true);
    setError(null);
    const form = new FormData();
    form.append("listingType", listingType);
    form.append("category", fields.category);
    form.append("title", fields.title.trim());
    const auto = [
      product.price && listingType !== "post" ? `baha ${product.price} TMT` : "",
      product.deposit && listingType === "rent" ? `girew ${product.deposit} TMT` : "",
      product.readyDays && listingType === "custom" ? `${product.readyDays} günde taýýar` : "",
      product.material ? `mata: ${product.material}` : "",
    ].filter(Boolean).join(", ");
    form.append("notes", [notes.trim(), auto].filter(Boolean).join(". "));
    if (firstImage) form.append("image", firstImage);
    try {
      setSugg(await api.aiSuggest(form));
    } catch (e) {
      setError(errorMessage(e));
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <section className="ai-box" aria-live="polite">
      <div className="ai-head">
        <span className="ai-badge"><SparkIcon size={16} /></span>
        <div>
          <strong>AI kömekçi</strong>
          <span>Surata we belliklere görä at, düşündiriş we hashteg ýazar.</span>
        </div>
        {enabled === false && <span className="ai-note" title="Serwerde AI açary ýok: taýýar şablon teklip berilýär">şablon</span>}
      </div>
      {!sugg && (
        <div className="ai-input">
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            maxLength={300}
            placeholder="Gysga bellik (hökman däl): mata, fason, kime laýyk…"
            aria-label="AI üçin bellik"
          />
          <button type="button" className="btn btn-ai" onClick={run} disabled={busy}>
            {busy ? <span className="spinner" /> : <SparkIcon size={16} />} {busy ? "Ýazylýar…" : "✨ AI bilen ýaz"}
          </button>
        </div>
      )}
      {error && !sugg && <p className="form-error">{error}</p>}
      {sugg && (
        <div className="ai-sugg">
          <strong className="ai-title">{sugg.title}</strong>
          <p className="ai-desc">{sugg.description}</p>
          {sugg.hashtags.length > 0 && (
            <div className="ai-tags">{sugg.hashtags.map((t) => <span key={t} className="hashtag">#{t.replace(/^#/, "")}</span>)}</div>
          )}
          {sugg.priceLine && <p className="ai-price">{sugg.priceLine}</p>}
          {sugg.details.length > 0 && (
            <ul className="ai-details">{sugg.details.map((d, i) => <li key={i}>{d}</li>)}</ul>
          )}
          <div className="ai-actions">
            <button type="button" className="btn btn-primary btn-sm" onClick={() => { onInsert(sugg); setSugg(null); toast("Teklip goşuldy — isleseňiz üýtgedip bilersiňiz"); }}>
              Goş
            </button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={run} disabled={busy}>{busy ? "…" : "Täzeden"}</button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => setSugg(null)}>Ýap</button>
            <span className="ai-source">{sugg.source === "ai" ? "Claude AI" : "Şablon"}</span>
          </div>
        </div>
      )}
    </section>
  );
}

export default function CreatePage() {
  const { user } = useRequireAuth();
  const router = useRouter();
  const toast = useToast();
  const cats = useCategories();
  const inputRef = useRef<HTMLInputElement>(null);
  const [media, setMedia] = useState<Picked[]>([]);
  const [active, setActive] = useState(0);
  const [dragging, setDragging] = useState(false);
  const [fields, setFields] = useState<PinFieldValues>(emptyPinFields);
  const [type, setType] = useState<ListingType>("post");
  const [product, setProduct] = useState<ProductValues>(() => emptyProduct());
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [boardId, setBoardId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const mediaRef = useRef(media);
  mediaRef.current = media;
  useEffect(() => () => mediaRef.current.forEach((m) => { URL.revokeObjectURL(m.url); if (m.src) URL.revokeObjectURL(m.src); }), []);
  useEffect(() => { document.title = "Döret · ModaHouse"; }, []);

  const userId = user?.id;
  const isBusiness = !!user?.isBusiness;
  useEffect(() => {
    if (!userId) return;
    api.myBoards().then(setBoards, () => setBoards([]));
  }, [userId]);

  // Businesses start on "Satlyk" with their default delivery/return days.
  const bizDelivery = user?.business?.deliveryDays;
  const bizReturn = user?.business?.returnDays;
  useEffect(() => {
    if (!isBusiness) return;
    setType((t) => (t === "post" ? "sale" : t));
    setProduct((p) => (p.price ? p : emptyProduct(bizDelivery ?? 3, bizReturn ?? 14)));
    setFields((f) => (f.category ? f : { ...f, category: "koynekler" }));
  }, [isBusiness, bizDelivery, bizReturn]);

  const addFiles = async (list: FileList | File[] | null | undefined) => {
    if (!list) return;
    const files = Array.from(list);
    let room = MAX_MEDIA - mediaRef.current.length;
    for (const f of files) {
      if (room <= 0) {
        setError(`Iň köp ${MAX_MEDIA} surat ýa-da wideo goşup bolýar`);
        break;
      }
      const isVideo = VIDEO_TYPES.includes(f.type) || /\.(mp4|webm|mov)$/i.test(f.name);
      if (!isVideo && !IMAGE_TYPES.includes(f.type)) {
        setError("Surat (JPG, PNG, GIF, WEBP) ýa-da wideo (MP4, WebM) saýlaň");
        continue;
      }
      if (!isVideo && f.size > MAX_MB * 1024 * 1024) {
        setError(`Her surat ${MAX_MB} MB-dan kiçi bolmaly`);
        continue;
      }
      if (isVideo && f.size > MAX_VIDEO_MB * 1024 * 1024) {
        setError(`Wideo ${MAX_VIDEO_MB} MB-dan kiçi bolmaly`);
        continue;
      }
      room--;
      setError(null);
      if (!isVideo) {
        setMedia((cur) => [...cur, { file: f, url: URL.createObjectURL(f), kind: "image" }]);
        continue;
      }
      const placeholder: Picked = { file: f, url: "", kind: "video", loading: true };
      setMedia((cur) => [...cur, placeholder]);
      try {
        const info = await videoPoster(f);
        if (info.duration > MAX_VIDEO_SECONDS + 1) {
          setMedia((cur) => cur.filter((m) => m !== placeholder));
          setError(`Wideo ${MAX_VIDEO_SECONDS} sekuntdan gysga bolmaly`);
          continue;
        }
        const ready: Picked = { file: f, url: URL.createObjectURL(info.poster), src: URL.createObjectURL(f), kind: "video", poster: info.poster, duration: info.duration };
        setMedia((cur) => cur.map((m) => (m === placeholder ? ready : m)));
      } catch (e) {
        setMedia((cur) => cur.filter((m) => m !== placeholder));
        setError((e as Error).message);
      }
    }
    if (inputRef.current) inputRef.current.value = "";
  };

  const removeAt = (i: number) => {
    setMedia((cur) => {
      if (cur[i]?.url) URL.revokeObjectURL(cur[i].url);
      if (cur[i]?.src) URL.revokeObjectURL(cur[i].src!);
      return cur.filter((_, j) => j !== i);
    });
    setActive((a) => Math.max(0, a > i ? a - 1 : Math.min(a, media.length - 2)));
  };

  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= media.length) return;
    setMedia((cur) => {
      const next = [...cur];
      [next[i], next[j]] = [next[j], next[i]];
      return next;
    });
    setActive(j);
  };

  const insertSuggestion = (s: Suggestion) => {
    const tags = s.hashtags.map((t) => `#${t.replace(/^#/, "").replace(/\s+/g, "")}`).join(" ");
    setFields((f) => ({
      ...f,
      title: s.title && !/^…+$/.test(s.title) ? s.title.slice(0, 100) : f.title,
      description: [s.description, tags].filter(Boolean).join("\n\n").slice(0, 1000),
      category: cats?.some((c) => c.slug === s.category) ? s.category : f.category,
    }));
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    if (!media.length) {
      setError("Iň bolmanda bir surat ýa-da wideo saýlaň");
      return;
    }
    if (media.some((m) => m.loading)) {
      setError("Wideo taýýarlanýar, birazdan gaýtadan basyň");
      return;
    }
    const invalid = validatePinFields(fields) ?? (type !== "post" ? validateProduct(product, type) : null);
    if (invalid) {
      setError(invalid);
      return;
    }
    const form = new FormData();
    for (const m of media) form.append("images", m.file);
    for (const m of media) if (m.kind === "video" && m.poster) form.append("posters", m.poster);
    for (const m of media) if (m.kind === "video") form.append("durations", String(m.duration ?? 0));
    form.append("title", fields.title.trim());
    form.append("description", fields.description.trim());
    form.append("link", fields.link.trim());
    form.append("category", fields.category);
    form.append("tags", fields.tags);
    if (boardId) form.append("boardId", boardId);
    if (type !== "post") appendProduct(form, product, type);
    setBusy(true);
    setError(null);
    try {
      const pin = await api.createPin(form);
      toast(type === "post" ? "Post paýlaşyldy" : "Bildiriş çap edildi");
      router.push(`/pin/${pin.id}`);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  if (!user) {
    return <div className="page narrow"><div className="skeleton" style={{ height: 460, borderRadius: 32 }} /></div>;
  }

  const cur = media[Math.min(active, media.length - 1)];
  const firstImage = media[0] ? (media[0].kind === "video" ? media[0].poster ?? null : media[0].file) : null;
  const processing = media.some((m) => m.loading);
  const submitLabel = busy ? "Çap edilýär…" : processing ? "Wideo taýýarlanýar…" : type === "post" ? "Paýlaş" : "Çap et";

  return (
    <div className="page narrow">
      <div className="create-head">
        <h1>Täze post</h1>
        <button className="btn btn-primary" form="create-form" disabled={busy || processing}>{submitLabel}</button>
      </div>

      <div className="type-picker" role="radiogroup" aria-label="Postuň maksady">
        {TYPE_OPTIONS.map((o) => {
          const locked = o.business && !isBusiness;
          return (
            <button
              key={o.value}
              type="button"
              role="radio"
              aria-checked={type === o.value}
              className={`type-opt ${type === o.value ? "on" : ""} ${locked ? "locked" : ""}`}
              onClick={() => (locked ? router.push("/settings#business") : setType(o.value))}
              title={locked ? "Biznes hasaby gerek" : o.hint}
            >
              <span className="type-icon">{o.icon}</span>
              <span className="type-text"><strong>{o.label}</strong><small>{locked ? "Biznes hasaby gerek" : o.hint}</small></span>
            </button>
          );
        })}
      </div>

      <div className="create">
        <div className="create-media">
          <div
            className={`upload ${cur ? "has" : ""} ${dragging ? "drag" : ""}`}
            onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
            onDragLeave={() => setDragging(false)}
            onDrop={(e) => {
              e.preventDefault();
              setDragging(false);
              addFiles(e.dataTransfer.files);
            }}
          >
            {cur ? (
              <>
                {cur.kind === "video" && !cur.loading ? (
                  <video src={cur.src} poster={cur.url} muted loop autoPlay playsInline className="upload-video" />
                ) : cur.loading ? (
                  <div className="upload-loading"><span className="spinner" /> Wideo taýýarlanýar…</div>
                ) : (
                  // eslint-disable-next-line @next/next/no-img-element
                  <img src={cur.url} alt="Saýlanan surat" />
                )}
                {active === 0 && <span className="cover-tag">Esasy</span>}
                <span className="carousel-count">{Math.min(active, media.length - 1) + 1}/{media.length}</span>
              </>
            ) : (
              <label className="upload-inner">
                <input
                  type="file"
                  multiple
                  accept={[...IMAGE_TYPES, ...VIDEO_TYPES].join(",")}
                  onChange={(e) => addFiles(e.target.files)}
                  aria-label="Surat ýa-da wideo saýla"
                />
                <UploadIcon />
                <strong>Surat ýa-da wideo saýlaň</strong>
                <small>Iň köp {MAX_MEDIA} sany · surat {MAX_MB} MB, wideo {MAX_VIDEO_SECONDS} sekunt we {MAX_VIDEO_MB} MB çenli</small>
              </label>
            )}
          </div>
          <input ref={inputRef} type="file" multiple hidden accept={[...IMAGE_TYPES, ...VIDEO_TYPES].join(",")} onChange={(e) => addFiles(e.target.files)} aria-label="Ýene goş" />
          {media.length > 0 && (
            <div className="upload-thumbs">
              {media.map((m, i) => (
                <div key={i + m.file.name} className={`upload-thumb ${i === active ? "on" : ""}`}>
                  <button type="button" className="ut-img" onClick={() => setActive(i)} aria-label={`${i + 1}-nji`}>
                    {m.url ? (
                      // eslint-disable-next-line @next/next/no-img-element
                      <img src={m.url} alt="" />
                    ) : (
                      <span className="spinner" />
                    )}
                    <span className="ut-num">{i + 1}</span>
                    {m.kind === "video" && !m.loading && <span className="ut-video"><PlayIcon size={10} /> {duration(m.duration ?? 0)}</span>}
                  </button>
                  <div className="ut-tools">
                    <button type="button" onClick={() => move(i, -1)} disabled={i === 0} aria-label="Çepe süýşür"><ChevronLeftIcon size={14} /></button>
                    <button type="button" onClick={() => removeAt(i)} aria-label="Aýyr"><CloseIcon size={14} /></button>
                    <button type="button" onClick={() => move(i, 1)} disabled={i === media.length - 1} aria-label="Saga süýşür"><ChevronRightIcon size={14} /></button>
                  </div>
                </div>
              ))}
              {media.length < MAX_MEDIA && (
                <button type="button" className="upload-more" onClick={() => inputRef.current?.click()} aria-label="Goş">
                  <PlusIcon size={22} />
                  <span>{media.length}/{MAX_MEDIA}</span>
                </button>
              )}
            </div>
          )}
        </div>

        <form id="create-form" className="form" onSubmit={submit} noValidate>
          <AiBox listingType={type} fields={fields} product={product} firstImage={firstImage} onInsert={insertSuggestion} />
          <PinFields value={fields} onChange={setFields} product={type !== "post"}>
            <label>
              Tagta
              <select value={boardId} onChange={(e) => setBoardId(e.target.value)} disabled={!boards}>
                <option value="">{boards ? "Tagtasyz" : "Ýüklenýär…"}</option>
                {boards?.map((b) => <option key={b.id} value={b.id}>{b.name}{b.isPrivate ? " (gizlin)" : ""}</option>)}
              </select>
            </label>
          </PinFields>
          {type !== "post" && <ProductFields value={product} onChange={setProduct} type={type} />}
          {!isBusiness && (
            <p className="biz-hint muted small">Satmak, kärendä bermek ýa-da tikin sargydy almak isleýärsiňizmi? <Link href="/settings#business" className="text-link">Biznes hasabyny açyň</Link></p>
          )}
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="btn btn-primary btn-lg form-submit-sm" disabled={busy || processing}>{submitLabel}</button>
        </form>
      </div>
    </div>
  );
}
