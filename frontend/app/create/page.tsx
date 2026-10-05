"use client";

import { useEffect, useState } from "react";
import { UploadIcon } from "@/components/Icons";
import { boards, categories } from "@/lib/data";

export default function CreatePage() {
  const [preview, setPreview] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [done, setDone] = useState(false);

  useEffect(() => () => { if (preview) URL.revokeObjectURL(preview); }, [preview]);

  return (
    <div className="page narrow">
      <div className="create-head">
        <h1>Pin döret</h1>
        <button className="btn btn-primary" disabled={!title.trim()} onClick={() => setDone(true)}>
          Çap et
        </button>
      </div>

      <div className="create">
        <label className={`upload ${preview ? "has" : ""}`}>
          <input
            type="file"
            accept="image/*"
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) setPreview(URL.createObjectURL(f));
            }}
          />
          {preview ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img src={preview} alt="Saýlanan surat" />
          ) : (
            <span className="upload-inner">
              <UploadIcon />
              <strong>Surat saýlaň ýa-da şu ýere süýräň</strong>
              <small>JPG, PNG ýa-da WEBP, 20 MB-dan kiçi</small>
            </span>
          )}
        </label>

        <form className="form" onSubmit={(e) => { e.preventDefault(); if (title.trim()) setDone(true); }}>
          <label>
            Ady
            <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="Pine at beriň" />
          </label>
          <label>
            Düşündiriş
            <textarea rows={4} placeholder="Bu pin barada gysgaça ýazyň" />
          </label>
          <label>
            Baglanyşyk
            <input type="url" placeholder="https://" />
          </label>
          <div className="form-row">
            <label>
              Tagta
              <select defaultValue={boards[0].name}>
                {boards.map((b) => <option key={b.name}>{b.name}</option>)}
              </select>
            </label>
            <label>
              Kategoriýa
              <select defaultValue={categories[0]}>
                {categories.map((c) => <option key={c}>{c}</option>)}
              </select>
            </label>
          </div>
          <label>
            Bellikler
            <input placeholder="mysal üçin: güýz, palto, klassyk" />
          </label>
        </form>
      </div>

      {done && (
        <div className="toast" role="status" onAnimationEnd={() => setDone(false)}>
          “{title}” pini döredildi. Bu diňe UI görkezişi, maglumat saklanmaýar.
        </div>
      )}
    </div>
  );
}
