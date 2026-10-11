"use client";

import { useEffect, useRef, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { Pin } from "@/lib/types";
import { CameraIcon } from "./Icons";
import Modal from "./Modal";
import { useToast } from "./Toast";

const TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

export default function AddStoryModal({ onClose, onCreated }: { onClose: () => void; onCreated: () => void }) {
  const { user } = useAuth();
  const toast = useToast();
  const input = useRef<HTMLInputElement>(null);
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [caption, setCaption] = useState("");
  const [pinId, setPinId] = useState("");
  const [products, setProducts] = useState<Pin[] | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview); }, [preview]);

  const username = user?.isBusiness ? user.username : null;
  useEffect(() => {
    if (!username) return;
    api.pins({ author: username, type: "products", page: 1, limit: 50 }).then((p) => setProducts(p.items), () => setProducts([]));
  }, [username]);

  const pick = (f: File | undefined) => {
    if (!f) return;
    if (!TYPES.includes(f.type)) {
      setError("Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär");
      return;
    }
    setError(null);
    setFile(f);
    setPreview(URL.createObjectURL(f));
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) {
      setError("Surat saýlaň");
      return;
    }
    const form = new FormData();
    form.append("image", file);
    if (caption.trim()) form.append("caption", caption.trim());
    if (pinId) form.append("pinId", pinId);
    setBusy(true);
    setError(null);
    try {
      await api.createStory(form);
      toast("Story goşuldy. 24 sagat görüner");
      onCreated();
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <Modal title="Story goş" onClose={onClose}>
      <form className="form add-story" onSubmit={submit} noValidate>
        <button type="button" className={`story-pick ${preview ? "has" : ""}`} onClick={() => input.current?.click()}>
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={preview} alt="Saýlanan surat" />
          ) : (
            <span className="story-pick-inner">
              <CameraIcon size={30} />
              <strong>Surat saýlaň</strong>
              <small>Dik (9:16) suratlar iň gowy görünýär</small>
            </span>
          )}
        </button>
        <input ref={input} type="file" accept={TYPES.join(",")} hidden onChange={(e) => pick(e.target.files?.[0])} aria-label="Story suraty" />
        <label>
          Ýazgy
          <input value={caption} onChange={(e) => setCaption(e.target.value)} maxLength={200} placeholder="Mysal: Täze kolleksiýa geldi!" />
        </label>
        {user?.isBusiness && (
          <label>
            Haryt baglanyşygy
            <select value={pinId} onChange={(e) => setPinId(e.target.value)} disabled={!products}>
              <option value="">{products ? "Harytsyz" : "Ýüklenýär…"}</option>
              {products?.map((p) => <option key={p.id} value={p.id}>{p.title}</option>)}
            </select>
          </label>
        )}
        {error && <p className="form-error" role="alert">{error}</p>}
        <div className="form-actions">
          <button type="button" className="btn btn-secondary" onClick={onClose}>Ýatyr</button>
          <button className="btn btn-primary" disabled={busy || !file}>{busy ? "Goşulýar…" : "Paýlaş"}</button>
        </div>
      </form>
    </Modal>
  );
}
