"use client";

import Link from "next/link";
import { useEffect, useMemo, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import { CheckIcon, CloseIcon, InfoIcon, PlusIcon, SearchIcon, StoreIcon, UploadIcon, VerifiedIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { LISTING_TYPES, num } from "@/lib/format";
import { useCategories } from "@/lib/hooks";
import { IMAGE_TYPES } from "@/lib/media";
import type { AdminUser, BulkUploadResult, ListingType } from "@/lib/types";
import { AdminHead } from "../shared";

const MAX_FILES = 30;
const MAX_MB = 20;

type Item = { id: string; file: File; url: string };

let seq = 0;

/** Search-as-you-type author picker over /admin/users. */
function AuthorPicker({ value, onChange }: { value: AdminUser | null; onChange: (u: AdminUser | null) => void }) {
  const [q, setQ] = useState("");
  const [items, setItems] = useState<AdminUser[] | null>(null);
  const [open, setOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const box = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    let alive = true;
    const t = window.setTimeout(() => {
      setError(null);
      api.admin.users({ q: q.trim(), page: 1, limit: 8 }).then(
        (pg) => alive && setItems(pg.items),
        (e) => alive && setError(errorMessage(e)),
      );
    }, q ? 250 : 0);
    return () => { alive = false; window.clearTimeout(t); };
  }, [q, open]);

  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => !box.current?.contains(e.target as Node) && setOpen(false);
    document.addEventListener("mousedown", onDown);
    return () => document.removeEventListener("mousedown", onDown);
  }, [open]);

  if (value) {
    return (
      <div className="bu-author">
        <Avatar user={value} size={44} />
        <div className="bu-author-name">
          <strong>{value.name || value.username} {value.verified && <VerifiedIcon size={14} />}</strong>
          <span className="bu-sub">
            <span className="muted">@{value.username} · {num(value.pinsCount)} post</span>
            {value.isBusiness && <span className="bu-biz"><StoreIcon size={13} /> Biznes</span>}
          </span>
        </div>
        <button type="button" className="btn btn-secondary btn-sm" onClick={() => { onChange(null); setOpen(true); }}>Üýtget</button>
      </div>
    );
  }

  return (
    <div className="bu-picker" ref={box}>
      <div className="bu-search">
        <SearchIcon size={18} />
        <input
          value={q}
          onChange={(e) => { setQ(e.target.value); setOpen(true); }}
          onFocus={() => setOpen(true)}
          onKeyDown={(e) => e.key === "Escape" && setOpen(false)}
          placeholder="Ady ýa-da ulanyjy ady boýunça gözle"
          aria-label="Awtory gözle"
          autoComplete="off"
          role="combobox"
          aria-expanded={open}
          aria-controls="bu-author-list"
        />
      </div>
      {open && (
        <div className="bu-list" id="bu-author-list" role="listbox" aria-label="Awtorlar">
          {error ? (
            <p className="bu-list-state error-text">{error}</p>
          ) : items === null ? (
            <p className="bu-list-state"><span className="spinner" /></p>
          ) : items.length === 0 ? (
            <p className="bu-list-state muted">Ulanyjy tapylmady</p>
          ) : (
            items.map((u) => (
              <button
                key={u.id}
                type="button"
                role="option"
                aria-selected={false}
                className="bu-option"
                disabled={u.suspended}
                onClick={() => { onChange(u); setOpen(false); setQ(""); }}
              >
                <Avatar user={u} size={36} />
                <span className="bu-author-name">
                  <strong>{u.name || u.username} {u.verified && <VerifiedIcon size={13} />}</strong>
                  <span className="muted">@{u.username}</span>
                </span>
                {u.suspended ? <span className="au-tag danger">Petiklenen</span> : u.isBusiness && <span className="bu-biz"><StoreIcon size={13} /> Biznes</span>}
              </button>
            ))
          )}
        </div>
      )}
    </div>
  );
}

export default function AdminUpload() {
  const toast = useToast();
  const cats = useCategories();
  const [author, setAuthor] = useState<AdminUser | null>(null);
  const [category, setCategory] = useState("");
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [tags, setTags] = useState("");
  const [type, setType] = useState<ListingType>("post");
  const [price, setPrice] = useState("");
  const [files, setFiles] = useState<Item[]>([]);
  const [dragging, setDragging] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [progress, setProgress] = useState<number | null>(null);
  const [result, setResult] = useState<BulkUploadResult | null>(null);
  const input = useRef<HTMLInputElement>(null);
  const filesRef = useRef(files);
  filesRef.current = files;

  useEffect(() => { document.title = "Köpçülikleýin ýüklemek · Admin paneli"; }, []);
  useEffect(() => () => filesRef.current.forEach((f) => URL.revokeObjectURL(f.url)), []);

  // Only business authors can list items for sale, rent or custom tailoring.
  useEffect(() => {
    if (author && !author.isBusiness && type !== "post") setType("post");
  }, [author, type]);

  const catName = useMemo(() => cats?.find((c) => c.slug === category)?.name ?? "", [cats, category]);

  const addFiles = (list: FileList | File[] | null) => {
    if (!list) return;
    const skipped: string[] = [];
    const next: Item[] = [];
    for (const f of Array.from(list)) {
      if (!IMAGE_TYPES.includes(f.type)) { skipped.push(`${f.name}: diňe surat (JPEG, PNG, WebP, GIF)`); continue; }
      if (f.size > MAX_MB * 1024 * 1024) { skipped.push(`${f.name}: ${MAX_MB} MB-dan uly`); continue; }
      next.push({ id: `f${++seq}`, file: f, url: URL.createObjectURL(f) });
    }
    const room = MAX_FILES - filesRef.current.length;
    if (next.length > room) {
      next.splice(room).forEach((f) => URL.revokeObjectURL(f.url));
      skipped.push(`Iň köp ${MAX_FILES} surat`);
    }
    if (next.length) setFiles((l) => [...l, ...next]);
    if (skipped.length) toast(skipped.slice(0, 2).join(" · ") + (skipped.length > 2 ? ` (+${skipped.length - 2})` : ""), "error");
    setError(null);
  };

  const remove = (id: string) => setFiles((l) => {
    const it = l.find((x) => x.id === id);
    if (it) URL.revokeObjectURL(it.url);
    return l.filter((x) => x.id !== id);
  });

  const reset = () => {
    files.forEach((f) => URL.revokeObjectURL(f.url));
    setFiles([]);
    setResult(null);
    setProgress(null);
  };

  const uploading = progress !== null;
  const needsPrice = type !== "post";
  const priceNum = Number(price.replace(",", "."));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!author) return setError("Awtory saýlaň");
    if (!category) return setError("Kategoriýany saýlaň");
    if (needsPrice && !(priceNum > 0)) return setError("Bahany ýazyň");
    if (!files.length) return setError("Iň bolmanda bir surat goşuň");
    setError(null);
    const form = new FormData();
    form.append("author", author.username);
    form.append("category", category);
    if (title.trim()) form.append("title", title.trim());
    if (description.trim()) form.append("description", description.trim());
    if (tags.trim()) form.append("tags", tags.trim());
    form.append("listingType", type);
    if (needsPrice) form.append("price", String(priceNum));
    for (const it of files) form.append("files", it.file, it.file.name);
    setProgress(0);
    try {
      const r = await api.admin.bulkUpload(form, setProgress);
      files.forEach((f) => URL.revokeObjectURL(f.url));
      setFiles([]);
      setResult(r);
      toast(r.failed.length ? `${r.created.length} post döredildi, ${r.failed.length} ýalňyşlyk` : `${r.created.length} post döredildi`);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setProgress(null);
    }
  };

  if (result) {
    return (
      <>
        <AdminHead title="Ýükle" sub={`@${author?.username ?? ""} · ${catName}`} />
        <section className="card bu-result">
          <div className="bu-result-head">
            <span className={`bu-result-icon ${result.created.length ? "ok" : "bad"}`}>{result.created.length ? <CheckIcon size={22} /> : <CloseIcon size={22} />}</span>
            <div>
              <h2>{result.created.length} post döredildi</h2>
              {result.failed.length > 0 && <p className="muted">{result.failed.length} faýl ýüklenmedi</p>}
            </div>
          </div>
          {result.created.length > 0 && (
            <div className="bu-created">
              {result.created.map((p) => (
                <Link key={p.id} href={`/pin/${p.id}`} className="bu-created-item" target="_blank">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={p.imageUrl} alt="" loading="lazy" style={{ background: p.color || undefined }} />
                  <span>{p.title}</span>
                </Link>
              ))}
            </div>
          )}
          {result.failed.length > 0 && (
            <ul className="bu-failed">
              {result.failed.map((f, i) => (
                <li key={i}><CloseIcon size={16} /><strong>{f.name}</strong><span>{f.error}</span></li>
              ))}
            </ul>
          )}
          <div className="form-actions">
            {author && <Link href={`/u/${author.username}`} className="btn btn-secondary">Profili gör</Link>}
            <button className="btn btn-primary" onClick={reset}><PlusIcon size={18} /> Ýene ýükle</button>
          </div>
        </section>
      </>
    );
  }

  return (
    <>
      <AdminHead title="Ýükle" sub="Birnäçe suraty bir gezekde post edip goşmak" />
      <form className="form card admin-form bu-form" onSubmit={submit} noValidate>
        <div className="admin-note">
          <InfoIcon size={18} />
          <p>
            Diňe çap etmäge rugsadyňyz bolan suratlary ýükläň: özüňiziň ýa-da razylygy alnan hyzmatdaş dükanyň suratlaryny.
            Her surat aýratyn post bolup, saýlanan awtoryň adyndan goşulýar.
          </p>
        </div>

        <div className="bu-field">
          <span className="bu-label">Awtor <span className="req">*</span></span>
          <AuthorPicker value={author} onChange={setAuthor} />
        </div>

        <div className="form-row bu-row">
          <label>
            <span>Kategoriýa <span className="req">*</span></span>
            <select value={category} onChange={(e) => setCategory(e.target.value)} required>
              <option value="">Saýlaň…</option>
              {(cats ?? []).map((c) => <option key={c.slug} value={c.slug}>{c.name}</option>)}
            </select>
          </label>
          <label>
            Ady (hökman däl)
            <input value={title} onChange={(e) => setTitle(e.target.value)} maxLength={100} placeholder={catName || "Kategoriýanyň ady goýlar"} />
          </label>
        </div>

        <label>
          Düşündiriş
          <textarea rows={3} value={description} onChange={(e) => setDescription(e.target.value)} maxLength={1000} placeholder="Ähli postlar üçin umumy düşündiriş" />
        </label>

        <label>
          Bellikler
          <input value={tags} onChange={(e) => setTags(e.target.value)} maxLength={300} placeholder="mysal üçin: toý, köýnek, keşde" />
          <small className="hint">Bellikleri otur bilen bölüň, iň köp 10 sany</small>
        </label>

        <div className="bu-field">
          <span className="bu-label">Görnüşi</span>
          <div className="bu-types" role="radiogroup" aria-label="Görnüşi">
            {LISTING_TYPES.map((o) => {
              const locked = o.value !== "post" && !author?.isBusiness;
              return (
                <label key={o.value} className={`bu-type ${type === o.value ? "on" : ""} ${locked ? "locked" : ""}`} title={locked ? "Diňe biznes hasaplary üçin" : undefined}>
                  <input type="radio" name="type" value={o.value} checked={type === o.value} disabled={locked} onChange={() => setType(o.value)} />
                  <strong>{o.label}</strong>
                  <small>{locked ? "Diňe biznes awtor" : o.hint}</small>
                </label>
              );
            })}
          </div>
        </div>

        {needsPrice && (
          <label className="bu-price">
            <span>{type === "rent" ? "Günlük baha, TMT" : type === "custom" ? "Baha (…-dan başlap), TMT" : "Baha, TMT"} <span className="req">*</span></span>
            <input type="number" inputMode="decimal" min={1} step="any" value={price} onChange={(e) => setPrice(e.target.value)} placeholder="0" />
          </label>
        )}

        <div className="bu-field">
          <span className="bu-label">Suratlar <span className="req">*</span> <span className="muted bu-count">{files.length} / {MAX_FILES}</span></span>
          <div
            className={`bu-drop ${dragging ? "drag" : ""} ${files.length ? "has" : ""}`}
            onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
            onDragLeave={() => setDragging(false)}
            onDrop={(e) => { e.preventDefault(); setDragging(false); addFiles(e.dataTransfer.files); }}
          >
            {files.length === 0 ? (
              <button type="button" className="bu-drop-inner" onClick={() => input.current?.click()}>
                <UploadIcon size={30} />
                <strong>Suratlary şu ýere süýräň ýa-da saýlaň</strong>
                <small>JPEG, PNG, WebP · iň köp {MAX_FILES} surat, her biri {MAX_MB} MB-a çenli</small>
              </button>
            ) : (
              <div className="bu-thumbs">
                {files.map((it, i) => (
                  <div key={it.id} className="bu-thumb">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={it.url} alt={it.file.name} />
                    <span className="ut-num">{i + 1}</span>
                    <button type="button" className="bu-remove" onClick={() => remove(it.id)} disabled={uploading} aria-label={`${it.file.name} aýyr`}>
                      <CloseIcon size={14} />
                    </button>
                  </div>
                ))}
                {files.length < MAX_FILES && (
                  <button type="button" className="upload-more" onClick={() => input.current?.click()} disabled={uploading}>
                    <PlusIcon size={22} /> Goş
                  </button>
                )}
              </div>
            )}
            <input
              ref={input}
              type="file"
              accept={IMAGE_TYPES.join(",")}
              multiple
              hidden
              onChange={(e) => { addFiles(e.target.files); e.target.value = ""; }}
              aria-label="Suratlary saýla"
            />
          </div>
        </div>

        {error && <p className="form-error" role="alert">{error}</p>}

        {uploading && (
          <div className="bu-progress" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round(progress * 100)}>
            <div className="bu-bar"><span style={{ width: `${Math.max(4, Math.round(progress * 100))}%` }} /></div>
            <span className="muted">{progress < 1 ? `Ýüklenýär… ${Math.round(progress * 100)}%` : "Postlar döredilýär…"}</span>
          </div>
        )}

        <div className="form-actions">
          <button className="btn btn-primary btn-lg" disabled={uploading || !files.length}>
            {uploading ? <span className="spinner light" /> : <UploadIcon size={20} />}
            {files.length ? `${files.length} posty ýükle` : "Ýükle"}
          </button>
        </div>
      </form>
    </>
  );
}
