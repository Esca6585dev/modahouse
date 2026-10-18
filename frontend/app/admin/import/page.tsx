"use client";

import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { CheckIcon, CloseIcon, GlobeIcon, ImagesIcon, InfoIcon, PlusIcon, SearchIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { num } from "@/lib/format";
import { useCategories } from "@/lib/hooks";
import type { CommonsCategory, CommonsImportResult } from "@/lib/types";
import { AdminHead } from "../shared";

type Failure = { message: string; network: boolean };

const failure = (e: unknown): Failure => ({
  // Drop low-level detail such as `(Get "https://…": Forbidden)` from the server message.
  message: errorMessage(e).replace(/\s*\((?:Get|Post|dial|read)\b[\s\S]*$/i, "").trim() || "Ýalňyşlyk ýüze çykdy",
  // 502/503/504 or no answer at all: the server could not reach Wikimedia Commons (or us).
  network: e instanceof ApiError && (e.status === 0 || e.status >= 502),
});

const shortTitle = (t: string) => t.replace(/^Category:/i, "");

function ErrorBox({ f, onRetry }: { f: Failure; onRetry?: () => void }) {
  return (
    <div className="imp-error" role="alert">
      <span className="imp-error-icon"><GlobeIcon size={20} /></span>
      <div>
        <strong>{f.message}</strong>
        {f.network && (
          <p className="muted">
            Import serwerde işleýär: serweriň <code>commons.wikimedia.org</code> salgysyna çykyp bilýändigini ýa-da
            {" "}<code>COMMONS_API_URL</code> sazlamasyny barlaň.
          </p>
        )}
      </div>
      {onRetry && <button type="button" className="btn btn-secondary btn-sm" onClick={onRetry}>Gaýtadan synanyş</button>}
    </div>
  );
}

export default function AdminImport() {
  const toast = useToast();
  const cats = useCategories();
  const [q, setQ] = useState("");
  const [searched, setSearched] = useState("");
  const [found, setFound] = useState<CommonsCategory[] | null>(null);
  const [searching, setSearching] = useState(false);
  const [searchError, setSearchError] = useState<Failure | null>(null);
  const [category, setCategory] = useState("");
  const [appCategory, setAppCategory] = useState("");
  const [limit, setLimit] = useState(20);
  const [author, setAuthor] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const [importError, setImportError] = useState<Failure | null>(null);
  const [running, setRunning] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [result, setResult] = useState<CommonsImportResult | null>(null);
  const started = useRef(0);

  useEffect(() => { document.title = "Suratlar importy · Admin paneli"; }, []);

  useEffect(() => {
    if (!running) return;
    started.current = Date.now();
    setElapsed(0);
    const t = window.setInterval(() => setElapsed(Math.round((Date.now() - started.current) / 1000)), 1000);
    return () => window.clearInterval(t);
  }, [running]);

  const search = async (e?: React.FormEvent) => {
    e?.preventDefault();
    const query = q.trim();
    if (!query) return;
    setSearching(true);
    setSearchError(null);
    setSearched(query);
    try {
      const list = await api.admin.commonsSearch(query);
      setFound(list);
    } catch (err) {
      setFound(null);
      setSearchError(failure(err));
    } finally {
      setSearching(false);
    }
  };

  const run = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!category) return setFormError("Commons kategoriýasyny saýlaň");
    if (!appCategory) return setFormError("ModaHouse kategoriýasyny saýlaň");
    const n = Math.round(limit);
    if (!(n >= 1 && n <= 50)) return setFormError("Sany 1–50 aralygynda bolmaly");
    setFormError(null);
    setImportError(null);
    setRunning(true);
    try {
      const r = await api.admin.commonsImport({
        category, limit: n, appCategory, author: author.trim().replace(/^@/, "") || undefined,
      });
      setResult(r);
      toast(`${r.created.length} post goşuldy`);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (err) {
      setImportError(failure(err));
    } finally {
      setRunning(false);
    }
  };

  if (result) {
    return (
      <>
        <AdminHead title="Suratlar importy" sub={shortTitle(category)} />
        <section className="card bu-result">
          <div className="bu-result-head">
            <span className={`bu-result-icon ${result.created.length ? "ok" : "bad"}`}>{result.created.length ? <CheckIcon size={22} /> : <CloseIcon size={22} />}</span>
            <div>
              <h2>{result.created.length} post goşuldy</h2>
              {result.skipped.length > 0 && <p className="muted">{result.skipped.length} faýl geçildi</p>}
            </div>
          </div>
          {result.created.length > 0 && (
            <div className="bu-created">
              {result.created.map((p) => (
                <Link key={p.id} href={`/pin/${p.id}`} className="bu-created-item" target="_blank">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img src={p.imageUrl} alt="" loading="lazy" style={{ background: p.color || undefined }} />
                  <span>{p.title}</span>
                  {p.credit && <small className="muted imp-credit">{p.credit}</small>}
                </Link>
              ))}
            </div>
          )}
          {result.skipped.length > 0 && (
            <>
              <h3 className="imp-sub">Geçilen faýllar</h3>
              <ul className="bu-failed">
                {result.skipped.map((f, i) => (
                  <li key={i}><CloseIcon size={16} /><strong>{f.title.replace(/^File:/i, "")}</strong><span>{f.reason}</span></li>
                ))}
              </ul>
            </>
          )}
          <div className="form-actions">
            <Link href={`/u/${author.trim().replace(/^@/, "") || "modahouse"}`} className="btn btn-secondary">Profili gör</Link>
            <button className="btn btn-primary" onClick={() => setResult(null)}><PlusIcon size={18} /> Ýene import et</button>
          </div>
        </section>
      </>
    );
  }

  return (
    <>
      <AdminHead title="Suratlar importy" sub="Wikimedia Commons-dan açyk ygtyýarnamaly suratlar" />
      <div className="card admin-form imp-card">
        <div className="admin-note">
          <InfoIcon size={18} />
          <p>
            Diňe açyk ygtyýarnamaly suratlar (CC0, Public domain, CC BY, CC BY-SA) Wikimedia Commons-dan göçürilýär.
            Her postuň aşagynda awtoryň ady, ygtyýarnamasy we çeşmä salgylanma görkezilýär. Import serwerde işleýär,
            şonuň üçin serweriň internete çykyp bilmegi gerek.
          </p>
        </div>

        <form className="imp-search" onSubmit={search} role="search">
          <label className="chat-search imp-search-box">
            <SearchIcon size={18} />
            <input
              type="search"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              placeholder="mysal üçin: Turkmen clothing, Turkmen carpets"
              aria-label="Commons kategoriýalaryny gözle"
            />
          </label>
          <button className="btn btn-dark" disabled={searching || !q.trim()}>
            {searching ? <span className="spinner light" /> : <SearchIcon size={18} />} Gözle
          </button>
        </form>

        {searchError && <ErrorBox f={searchError} onRetry={() => search()} />}

        {found && (
          found.length === 0 ? (
            <p className="muted imp-empty">«{searched}» boýunça kategoriýa tapylmady. Başga söz bilen (iňlisçe) synanyşyň.</p>
          ) : (
            <div className="imp-cats" role="radiogroup" aria-label="Commons kategoriýalary">
              {found.map((c) => (
                <label key={c.title} className={`imp-cat ${category === c.title ? "on" : ""}`}>
                  <input type="radio" name="commons" value={c.title} checked={category === c.title} onChange={() => setCategory(c.title)} />
                  <ImagesIcon size={18} />
                  <span className="imp-cat-title">{shortTitle(c.title)}</span>
                  <span className="imp-cat-count">{num(c.files)} faýl</span>
                </label>
              ))}
            </div>
          )
        )}

        <form className="form imp-form" onSubmit={run} noValidate>
          <div className="form-row bu-row">
            <label>
              <span>ModaHouse kategoriýasy <span className="req">*</span></span>
              <select value={appCategory} onChange={(e) => setAppCategory(e.target.value)} required>
                <option value="">Saýlaň…</option>
                {(cats ?? []).map((c) => <option key={c.slug} value={c.slug}>{c.name}</option>)}
              </select>
            </label>
            <label className="imp-limit">
              <span>Näçe surat (1–50)</span>
              <input type="number" min={1} max={50} value={limit} onChange={(e) => setLimit(Number(e.target.value))} />
            </label>
          </div>
          <label>
            Awtor (hökman däl)
            <input value={author} onChange={(e) => setAuthor(e.target.value)} placeholder="modahouse" autoComplete="off" />
            <small className="hint">Boş goýulsa, postlar resmi «ModaHouse» hasabyndan goşulýar</small>
          </label>

          <div className="imp-chosen">
            {category ? <>Saýlanan: <strong>{shortTitle(category)}</strong></> : <span className="muted">Ilki ýokarda kategoriýa gözläň we saýlaň</span>}
          </div>

          {formError && <p className="form-error" role="alert">{formError}</p>}
          {importError && <ErrorBox f={importError} />}

          {running && (
            <div className="bu-progress" role="status">
              <div className="bu-bar indeterminate"><span /></div>
              <span className="muted">Suratlar göçürilýär… {elapsed} sek. Bu bir minuda çenli dowam edip biler, sahypany ýapmaň.</span>
            </div>
          )}

          <div className="form-actions">
            <button className="btn btn-primary btn-lg" disabled={running || !category}>
              {running ? <span className="spinner light" /> : <ImagesIcon size={20} />}
              {running ? "Import edilýär…" : `${Math.max(1, Math.min(50, Math.round(limit) || 1))} surat import et`}
            </button>
          </div>
        </form>
      </div>
    </>
  );
}
