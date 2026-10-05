"use client";

import { useCategories } from "@/lib/hooks";

export type PinFieldValues = { title: string; description: string; link: string; category: string; tags: string };

export const emptyPinFields: PinFieldValues = { title: "", description: "", link: "", category: "", tags: "" };

/** Client-side checks that mirror the server's messages. */
export function validatePinFields(v: PinFieldValues): string | null {
  if (!v.title.trim()) return "Pine at beriň";
  if (!v.category) return "Kategoriýa saýlaň";
  const link = v.link.trim();
  if (link && !/^https?:\/\/[^\s/]+/i.test(link)) return "Baglanyşyk http:// ýa-da https:// bilen başlamaly";
  return null;
}

export default function PinFields({
  value, onChange, children,
}: { value: PinFieldValues; onChange: (v: PinFieldValues) => void; children?: React.ReactNode }) {
  const cats = useCategories();
  const set = (k: keyof PinFieldValues) => (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) =>
    onChange({ ...value, [k]: e.target.value });

  return (
    <>
      <label>
        <span>Ady <span className="req" aria-hidden>*</span></span>
        <input value={value.title} onChange={set("title")} maxLength={100} placeholder="Pine at beriň" required />
      </label>
      <label>
        Düşündiriş
        <textarea rows={4} value={value.description} onChange={set("description")} maxLength={1000} placeholder="Bu pin barada gysgaça ýazyň" />
      </label>
      <label>
        Baglanyşyk
        <input type="url" inputMode="url" value={value.link} onChange={set("link")} maxLength={500} placeholder="https://" />
      </label>
      <div className="form-row">
        <label>
          <span>Kategoriýa <span className="req" aria-hidden>*</span></span>
          <select value={value.category} onChange={set("category")} required>
            <option value="" disabled>{cats ? "Saýlaň…" : "Ýüklenýär…"}</option>
            {cats?.map((c) => <option key={c.slug} value={c.slug}>{c.name}</option>)}
          </select>
        </label>
        {children}
      </div>
      <label>
        Bellikler
        <input value={value.tags} onChange={set("tags")} maxLength={300} placeholder="mysal üçin: güýz, palto, klassyk" />
        <small className="hint">Bellikleri otur bilen bölüň, iň köp 10 sany</small>
      </label>
    </>
  );
}
