"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useRef, useState } from "react";
import CropBox, { CENTER_CROP, type Crop, FULL_CROP } from "@/components/CropBox";
import { CameraIcon, PlayIcon, ScanIcon, SparkIcon, UploadIcon } from "@/components/Icons";
import { Price } from "@/components/Price";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { categoryName } from "@/lib/format";
import { useCategories } from "@/lib/hooks";
import { IMAGE_TYPES, rasterize } from "@/lib/media";
import type { Pin, VisualResult } from "@/lib/types";
import { onPendingPhoto, takePendingPhoto } from "@/lib/visualStore";

function ResultTile({ pin, score }: { pin: Pin; score: number }) {
  const pct = Math.round(score * 100);
  return (
    <Link href={`/pin/${pin.id}`} className="vr-tile">
      <span className="vr-media" style={{ background: pin.color }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={pin.imageUrl} alt={pin.title} loading="lazy" />
        {pin.mediaType === "video" && <span className="pin-video"><PlayIcon size={11} /></span>}
        <span className="vr-score">{pct}% meňzeş</span>
      </span>
      <span className="vr-title">{pin.title}</span>
      {pin.product && <Price price={pin.product.price} oldPrice={pin.product.oldPrice} type={pin.product.listingType} />}
    </Link>
  );
}

function Picker({ onPick }: { onPick: (f: File) => void }) {
  const gallery = useRef<HTMLInputElement>(null);
  const camera = useRef<HTMLInputElement>(null);
  const [drag, setDrag] = useState(false);
  return (
    <div
      className={`visual-picker ${drag ? "drag" : ""}`}
      onDragOver={(e) => { e.preventDefault(); setDrag(true); }}
      onDragLeave={() => setDrag(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDrag(false);
        const f = e.dataTransfer.files?.[0];
        if (f) onPick(f);
      }}
    >
      <span className="vp-icon"><ScanIcon size={40} /></span>
      <h2>Surat bilen gözle</h2>
      <p>Köýnegiň, şaý-sebiň ýa-da saç düzüminiň suratyny saýlaň — meňzeş postlary we harytlary görkezeris.</p>
      <div className="vp-actions">
        <button className="btn btn-primary btn-lg" onClick={() => camera.current?.click()}><CameraIcon size={20} /> Surata düş</button>
        <button className="btn btn-secondary btn-lg" onClick={() => gallery.current?.click()}><UploadIcon size={20} /> Surat saýla</button>
      </div>
      <input ref={camera} type="file" accept="image/*" capture="environment" hidden onChange={(e) => e.target.files?.[0] && onPick(e.target.files[0])} />
      <input ref={gallery} type="file" accept="image/*" hidden onChange={(e) => e.target.files?.[0] && onPick(e.target.files[0])} />
    </div>
  );
}

function VisualView() {
  const params = useSearchParams();
  const pinParam = Number(params.get("pin") ?? 0) || 0;
  const { ready } = useAuth();
  const cats = useCategories();
  const [srcUrl, setSrcUrl] = useState<string | null>(null);
  const [sourcePin, setSourcePin] = useState<Pin | null>(null);
  const [crop, setCrop] = useState<Crop>(CENTER_CROP);
  const [committed, setCommitted] = useState<Crop>(CENTER_CROP);
  const [products, setProducts] = useState(false);
  const [result, setResult] = useState<VisualResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [mode, setMode] = useState<"photo" | "pin" | "none">("none");
  const blob = useRef<Promise<Blob> | null>(null);
  const reqId = useRef(0);
  const gallery = useRef<HTMLInputElement>(null);

  useEffect(() => { document.title = "Surat bilen gözleg · ModaHouse"; }, []);

  const pickPhoto = useCallback((f: File) => {
    if (!IMAGE_TYPES.includes(f.type) && !f.type.startsWith("image/")) {
      setError("Surat saýlaň (JPG, PNG, WEBP)");
      return;
    }
    setError(null);
    setSourcePin(null);
    setMode("photo");
    setResult(null);
    setSrcUrl((old) => {
      if (old?.startsWith("blob:")) URL.revokeObjectURL(old);
      return URL.createObjectURL(f);
    });
    blob.current = rasterize(f).then((r) => r.blob);
    setCrop(CENTER_CROP);
    setCommitted(CENTER_CROP);
  }, []);

  // A photo picked from the header camera while this page is open.
  useEffect(() => onPendingPhoto(() => {
    const f = takePendingPhoto();
    if (f) pickPhoto(f);
  }), [pickPhoto]);

  // Start: a photo handed over by the search bar, or ?pin= for "Meňzeşini tap".
  useEffect(() => {
    const f = takePendingPhoto();
    if (f) {
      pickPhoto(f);
      return;
    }
    if (!pinParam) return;
    let alive = true;
    setMode("pin");
    setCrop(FULL_CROP);
    setCommitted(FULL_CROP);
    api.pin(pinParam).then((p) => {
      if (!alive) return;
      setSourcePin(p);
      setSrcUrl(p.imageUrl);
      blob.current = rasterize(p.imageUrl).then((r) => r.blob);
    }, (e) => alive && setError(e instanceof ApiError && e.status === 404 ? "Post tapylmady" : errorMessage(e)));
    return () => { alive = false; };
  }, [pinParam, pickPhoto]);

  // Search whenever the committed frame or the filter changes (debounced while dragging).
  useEffect(() => {
    if (!ready || mode === "none") return;
    if (mode === "pin" && !sourcePin) return;
    const id = ++reqId.current;
    const t = window.setTimeout(async () => {
      setLoading(true);
      setError(null);
      try {
        const full = committed.x <= 0.001 && committed.y <= 0.001 && committed.w >= 0.999 && committed.h >= 0.999;
        let r: VisualResult;
        if (mode === "pin" && full && sourcePin) {
          r = await api.visual(sourcePin.id, products);
        } else {
          const b = await blob.current!;
          const form = new FormData();
          form.append("image", new File([b], "query.jpg", { type: "image/jpeg" }));
          form.append("x", committed.x.toFixed(4));
          form.append("y", committed.y.toFixed(4));
          form.append("w", committed.w.toFixed(4));
          form.append("h", committed.h.toFixed(4));
          if (products) form.append("type", "products");
          form.append("limit", "40");
          r = await api.searchImage(form);
          if (sourcePin) {
            const keep = r.items.map((p, i) => [p, r.scores[i]] as const).filter(([p]) => p.id !== sourcePin.id);
            r = { ...r, items: keep.map(([p]) => p), scores: keep.map(([, s]) => s) };
          }
        }
        if (id === reqId.current) setResult(r);
      } catch (e) {
        if (id === reqId.current) setError(errorMessage(e));
      } finally {
        if (id === reqId.current) setLoading(false);
      }
    }, 350);
    return () => window.clearTimeout(t);
  }, [committed, products, mode, sourcePin, ready]);

  if (mode === "none" && !pinParam) {
    return (
      <div className="page narrow-sm">
        <Picker onPick={pickPhoto} />
        {error && <p className="form-error">{error}</p>}
      </div>
    );
  }

  const aiCat = result?.category ? categoryName(result.category, cats) : "";

  return (
    <div className="page visual-page">
      <div className="visual-layout">
        <section className="visual-left">
          <div className="visual-head">
            <h1><ScanIcon size={22} /> {mode === "pin" ? "Meňzeşini tap" : "Surat bilen gözleg"}</h1>
            <button className="btn btn-secondary btn-sm" onClick={() => gallery.current?.click()}><CameraIcon size={16} /> Başga surat</button>
            <input ref={gallery} type="file" accept="image/*" hidden onChange={(e) => { const f = e.target.files?.[0]; e.target.value = ""; if (f) pickPhoto(f); }} />
          </div>
          <div className="crop-stage">
            {srcUrl ? (
              <CropBox src={srcUrl} crop={crop} onChange={setCrop} onCommit={setCommitted} alt={sourcePin?.title ?? "Gözleg suraty"} />
            ) : (
              <div className="skeleton" style={{ width: "100%", aspectRatio: "3 / 4" }} />
            )}
          </div>
          <p className="crop-hint">Çarçuwany harydyň üstüne süýşüriň ýa-da burçlaryndan çekiň — netijeler täzelenýär.</p>
          {sourcePin && (
            <Link href={`/pin/${sourcePin.id}`} className="visual-source">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={sourcePin.imageUrl} alt="" />
              <span><small>Gözlenýän post</small><strong>{sourcePin.title}</strong></span>
            </Link>
          )}
        </section>

        <section className="visual-right" aria-live="polite" aria-busy={loading}>
          <div className="visual-toolbar">
            <label className="switch">
              <input type="checkbox" checked={products} onChange={(e) => setProducts(e.target.checked)} />
              <span className="switch-track" aria-hidden><span /></span>
              Diňe harytlar
            </label>
            {aiCat && (
              <Link href={`/?c=${encodeURIComponent(result!.category)}`} className="ai-chip" title={result!.source === "ai+local" ? "AI tapan kategoriýa" : "Kategoriýa"}>{result!.source === "ai+local" && <SparkIcon size={14} />} {aiCat}</Link>
            )}
            <span className="muted small vr-count">
              {loading ? <span className="spinner" /> : result ? `${result.items.length} netije` : ""}
            </span>
          </div>
          {error && <p className="form-error">{error}</p>}
          {!result ? (
            <div className="vr-grid">{Array.from({ length: 8 }, (_, i) => <div key={i} className="skeleton" style={{ aspectRatio: "3 / 4" }} />)}</div>
          ) : result.items.length === 0 ? (
            <div className="empty">
              <h2>Meňzeş zat tapylmady</h2>
              <p>Çarçuwany üýtgediň ýa-da başga surat synap görüň.</p>
            </div>
          ) : (
            <div className={`vr-grid ${loading ? "dim" : ""}`}>
              {result.items.map((p, i) => <ResultTile key={p.id} pin={p} score={result.scores[i] ?? 0} />)}
            </div>
          )}
        </section>
      </div>
    </div>
  );
}

export default function VisualPage() {
  return (
    <Suspense fallback={<div className="page" />}>
      <VisualView />
    </Suspense>
  );
}
