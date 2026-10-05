"use client";

import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import { CloseIcon, UploadIcon } from "@/components/Icons";
import PinFields, { emptyPinFields, validatePinFields, type PinFieldValues } from "@/components/PinFields";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { useRequireAuth } from "@/lib/hooks";
import type { Board } from "@/lib/types";

const TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];
const MAX_MB = 20;

export default function CreatePage() {
  const { user } = useRequireAuth();
  const router = useRouter();
  const toast = useToast();
  const inputRef = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [dragging, setDragging] = useState(false);
  const [fields, setFields] = useState<PinFieldValues>(emptyPinFields);
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [boardId, setBoardId] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview); }, [preview]);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    api.myBoards().then(setBoards, () => setBoards([]));
  }, [userId]);

  const pick = (f: File | undefined | null) => {
    if (!f) return;
    if (!TYPES.includes(f.type)) {
      setError("Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär");
      return;
    }
    if (f.size > MAX_MB * 1024 * 1024) {
      setError(`Surat ${MAX_MB} MB-dan kiçi bolmaly`);
      return;
    }
    setError(null);
    setFile(f);
    setPreview(URL.createObjectURL(f));
  };

  const clearFile = () => {
    setFile(null);
    setPreview(null);
    if (inputRef.current) inputRef.current.value = "";
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    if (!file) {
      setError("Surat saýlaň");
      return;
    }
    const invalid = validatePinFields(fields);
    if (invalid) {
      setError(invalid);
      return;
    }
    const form = new FormData();
    form.append("image", file);
    form.append("title", fields.title.trim());
    form.append("description", fields.description.trim());
    form.append("link", fields.link.trim());
    form.append("category", fields.category);
    form.append("tags", fields.tags);
    if (boardId) form.append("boardId", boardId);
    setBusy(true);
    setError(null);
    try {
      const pin = await api.createPin(form);
      toast("Pin döredildi");
      router.push(`/pin/${pin.id}`);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  if (!user) {
    return <div className="page narrow"><div className="skeleton" style={{ height: 460, borderRadius: 32 }} /></div>;
  }

  return (
    <div className="page narrow">
      <div className="create-head">
        <h1>Pin döret</h1>
        <button className="btn btn-primary" form="create-form" disabled={busy}>
          {busy ? "Çap edilýär…" : "Çap et"}
        </button>
      </div>

      <div className="create">
        <div
          className={`upload ${preview ? "has" : ""} ${dragging ? "drag" : ""}`}
          onDragOver={(e) => { e.preventDefault(); setDragging(true); }}
          onDragLeave={() => setDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragging(false);
            pick(e.dataTransfer.files?.[0]);
          }}
        >
          {preview ? (
            <>
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={preview} alt="Saýlanan surat" />
              <button type="button" className="round-btn upload-clear" onClick={clearFile} aria-label="Suraty aýyr" title="Suraty aýyr">
                <CloseIcon size={18} />
              </button>
            </>
          ) : (
            <label className="upload-inner">
              <input
                ref={inputRef}
                type="file"
                accept={TYPES.join(",")}
                onChange={(e) => pick(e.target.files?.[0])}
                aria-label="Surat saýla"
              />
              <UploadIcon />
              <strong>Surat saýlaň ýa-da şu ýere süýräň</strong>
              <small>JPG, PNG, GIF ýa-da WEBP, {MAX_MB} MB-dan kiçi</small>
            </label>
          )}
        </div>

        <form id="create-form" className="form" onSubmit={submit} noValidate>
          <PinFields value={fields} onChange={setFields}>
            <label>
              Tagta
              <select value={boardId} onChange={(e) => setBoardId(e.target.value)} disabled={!boards}>
                <option value="">{boards ? "Tagtasyz" : "Ýüklenýär…"}</option>
                {boards?.map((b) => <option key={b.id} value={b.id}>{b.name}{b.isPrivate ? " (gizlin)" : ""}</option>)}
              </select>
            </label>
          </PinFields>
          {error && <p className="form-error" role="alert">{error}</p>}
          <button className="btn btn-primary form-submit-sm" disabled={busy}>{busy ? "Çap edilýär…" : "Çap et"}</button>
        </form>
      </div>
    </div>
  );
}
