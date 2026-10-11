"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { BagIcon, ChevronLeftIcon, ChevronRightIcon, CloseIcon, LightbulbIcon, PlusIcon, UploadIcon } from "@/components/Icons";
import PinFields, { emptyPinFields, validatePinFields, type PinFieldValues } from "@/components/PinFields";
import ProductFields, { appendProduct, emptyProduct, validateProduct, type ProductValues } from "@/components/ProductFields";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useRequireAuth } from "@/lib/hooks";
import type { Board } from "@/lib/types";

const TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];
const MAX_MB = 20;
const MAX_IMAGES = 8;

type Picked = { file: File; url: string };

export default function CreatePage() {
  const { user } = useRequireAuth();
  const router = useRouter();
  const toast = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const [images, setImages] = useState<Picked[]>([]);
  const [active, setActive] = useState(0);
  const [dragging, setDragging] = useState(false);
  const [fields, setFields] = useState<PinFieldValues>(emptyPinFields);
  const [mode, setMode] = useState<"product" | "idea">("idea");
  const [product, setProduct] = useState<ProductValues>(() => emptyProduct());
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [boardId, setBoardId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const imagesRef = useRef(images);
  imagesRef.current = images;
  useEffect(() => () => imagesRef.current.forEach((i) => URL.revokeObjectURL(i.url)), []);

  useEffect(() => { document.title = "Döret · ModaHouse"; }, []);

  const userId = user?.id;
  const isBusiness = !!user?.isBusiness;
  useEffect(() => {
    if (!userId) return;
    api.myBoards().then(setBoards, () => setBoards([]));
  }, [userId]);

  // Businesses create products by default, with their default delivery/return days.
  const bizDelivery = user?.business?.deliveryDays;
  const bizReturn = user?.business?.returnDays;
  useEffect(() => {
    if (!isBusiness) return;
    setMode("product");
    setProduct((p) => (p.price ? p : emptyProduct(bizDelivery ?? 3, bizReturn ?? 14)));
    setFields((f) => (f.category ? f : { ...f, category: "koynekler" }));
  }, [isBusiness, bizDelivery, bizReturn]);

  const addFiles = (list: FileList | File[] | null | undefined) => {
    if (!list) return;
    const files = Array.from(list);
    const next: Picked[] = [];
    for (const f of files) {
      if (!TYPES.includes(f.type)) {
        setError("Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär");
        continue;
      }
      if (f.size > MAX_MB * 1024 * 1024) {
        setError(`Her surat ${MAX_MB} MB-dan kiçi bolmaly`);
        continue;
      }
      next.push({ file: f, url: URL.createObjectURL(f) });
    }
    if (!next.length) return;
    setImages((cur) => {
      const room = MAX_IMAGES - cur.length;
      if (next.length > room) setError(`Iň köp ${MAX_IMAGES} surat goşup bolýar`);
      else setError(null);
      next.slice(room).forEach((p) => URL.revokeObjectURL(p.url));
      return [...cur, ...next.slice(0, Math.max(0, room))];
    });
    if (inputRef.current) inputRef.current.value = "";
  };

  const removeAt = (i: number) => {
    setImages((cur) => {
      URL.revokeObjectURL(cur[i].url);
      return cur.filter((_, j) => j !== i);
    });
    setActive((a) => Math.max(0, a > i ? a - 1 : Math.min(a, images.length - 2)));
  };

  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= images.length) return;
    setImages((cur) => {
      const next = [...cur];
      [next[i], next[j]] = [next[j], next[i]];
      return next;
    });
    setActive(j);
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    if (!images.length) {
      setError("Iň bolmanda bir surat saýlaň");
      return;
    }
    const invalid = validatePinFields(fields) ?? (mode === "product" ? validateProduct(product) : null);
    if (invalid) {
      setError(invalid);
      return;
    }
    const form = new FormData();
    for (const im of images) form.append("images", im.file);
    form.append("title", fields.title.trim());
    form.append("description", fields.description.trim());
    form.append("link", fields.link.trim());
    form.append("category", fields.category);
    form.append("tags", fields.tags);
    if (boardId) form.append("boardId", boardId);
    if (mode === "product") appendProduct(form, product);
    setBusy(true);
    setError(null);
    try {
      const pin = await api.createPin(form);
      toast(mode === "product" ? "Haryt goşuldy" : "Pin döredildi");
      router.push(`/pin/${pin.id}`);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  if (!user) {
    return <div className="page narrow"><div className="skeleton" style={{ height: 460, borderRadius: 32 }} /></div>;
  }

  const cur = images[Math.min(active, images.length - 1)];
  const submitLabel = busy ? "Çap edilýär…" : mode === "product" ? "Harydy çap et" : "Çap et";

  return (
    <div className="page narrow">
      <div className="create-head">
        <h1>{mode === "product" ? "Haryt goş" : "Pin döret"}</h1>
        <button className="btn btn-primary" form="create-form" disabled={busy}>{submitLabel}</button>
      </div>

      {isBusiness && (
        <div className="seg create-mode" role="tablist" aria-label="Görnüşi">
          <button type="button" role="tab" aria-selected={mode === "product"} className={mode === "product" ? "active" : ""} onClick={() => setMode("product")}>
            <BagIcon size={16} /> Haryt (bahaly)
          </button>
          <button type="button" role="tab" aria-selected={mode === "idea"} className={mode === "idea" ? "active" : ""} onClick={() => setMode("idea")}>
            <LightbulbIcon size={16} /> Ideýa pin
          </button>
        </div>
      )}

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
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={cur.url} alt="Saýlanan surat" />
                {active === 0 && <span className="cover-tag">Esasy surat</span>}
                <span className="carousel-count">{Math.min(active, images.length - 1) + 1}/{images.length}</span>
              </>
            ) : (
              <label className="upload-inner">
                <input
                  type="file"
                  multiple
                  accept={TYPES.join(",")}
                  onChange={(e) => addFiles(e.target.files)}
                  aria-label="Surat saýla"
                />
                <UploadIcon />
                <strong>Suratlary saýlaň ýa-da şu ýere süýräň</strong>
                <small>Iň köp {MAX_IMAGES} surat · JPG, PNG, GIF ýa-da WEBP, {MAX_MB} MB-dan kiçi</small>
              </label>
            )}
          </div>
          <input ref={inputRef} type="file" multiple hidden accept={TYPES.join(",")} onChange={(e) => addFiles(e.target.files)} aria-label="Ýene surat goş" />
          {images.length > 0 && (
            <div className="upload-thumbs">
              {images.map((im, i) => (
                <div key={im.url} className={`upload-thumb ${i === active ? "on" : ""}`}>
                  <button type="button" className="ut-img" onClick={() => setActive(i)} aria-label={`${i + 1}-nji surat`}>
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={im.url} alt="" />
                    <span className="ut-num">{i + 1}</span>
                  </button>
                  <div className="ut-tools">
                    <button type="button" onClick={() => move(i, -1)} disabled={i === 0} aria-label="Çepe süýşür"><ChevronLeftIcon size={14} /></button>
                    <button type="button" onClick={() => removeAt(i)} aria-label="Aýyr"><CloseIcon size={14} /></button>
                    <button type="button" onClick={() => move(i, 1)} disabled={i === images.length - 1} aria-label="Saga süýşür"><ChevronRightIcon size={14} /></button>
                  </div>
                </div>
              ))}
              {images.length < MAX_IMAGES && (
                <button type="button" className="upload-more" onClick={() => inputRef.current?.click()} aria-label="Surat goş">
                  <PlusIcon size={22} />
                  <span>{images.length}/{MAX_IMAGES}</span>
                </button>
              )}
            </div>
          )}
        </div>

        <form id="create-form" className="form" onSubmit={submit} noValidate>
          <PinFields value={fields} onChange={setFields} product={mode === "product"}>
            <label>
              Tagta
              <select value={boardId} onChange={(e) => setBoardId(e.target.value)} disabled={!boards}>
                <option value="">{boards ? "Tagtasyz" : "Ýüklenýär…"}</option>
                {boards?.map((b) => <option key={b.id} value={b.id}>{b.name}{b.isPrivate ? " (gizlin)" : ""}</option>)}
              </select>
            </label>
          </PinFields>
          {mode === "product" && <ProductFields value={product} onChange={setProduct} />}
          {!isBusiness && (
            <p className="biz-hint muted small">Harytlary bahasy bilen satmak isleýärsiňizmi? <a href="/settings#business" className="text-link">Biznes hasabyny açyň</a></p>
          )}
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="btn btn-primary btn-lg form-submit-sm" disabled={busy}>{submitLabel}</button>
        </form>
      </div>
    </div>
  );
}
