"use client";

import Link from "next/link";
import { useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { BusinessCategory, BusinessInput } from "@/lib/types";
import { BagIcon, ChartIcon, StoreIcon, TrophyIcon } from "./Icons";
import { useBusinessCategories } from "@/lib/hooks";
import { useToast } from "./Toast";

const PHONE_RE = /^[0-9+\-\s]{8,20}$/;

type Values = {
  category: BusinessCategory | "";
  phone: string;
  city: string;
  address: string;
  instagram: string;
  tiktok: string;
  telegram: string;
  whatsapp: string;
  imo: string;
  youtube: string;
  website: string;
  workingHours: string;
  deliveryDays: string;
  returnDays: string;
};

function Fields({ v, set }: { v: Values; set: (k: keyof Values) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => void }) {
  const bizCats = useBusinessCategories();
  return (
    <>
      <div className="form-row">
        <label>
          <span>Kategoriýa <span className="req">*</span></span>
          <select value={v.category} onChange={set("category")}>
            <option value="" disabled>Saýlaň…</option>
            {bizCats.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
          </select>
        </label>
        <label>
          <span>Telefon <span className="req">*</span></span>
          <input type="tel" inputMode="tel" value={v.phone} onChange={set("phone")} maxLength={20} placeholder="+993 61 234567" />
        </label>
      </div>
      <div className="form-row">
        <label>
          Şäher
          <input value={v.city} onChange={set("city")} maxLength={60} placeholder="Aşgabat" />
        </label>
        <label>
          Iş wagty
          <input value={v.workingHours} onChange={set("workingHours")} maxLength={60} placeholder="09:00–20:00, dynç güni ýok" />
        </label>
      </div>
      <label>
        Salgy
        <input value={v.address} onChange={set("address")} maxLength={200} placeholder="Köçe, jaý, söwda merkezi" />
      </label>
      <fieldset className="social-fields">
        <legend>Sosial ulgamlar</legend>
        <div className="form-row">
          <label>
            Instagram
            <input value={v.instagram} onChange={set("instagram")} maxLength={60} placeholder="@dukanyň_ady" autoCapitalize="none" />
          </label>
          <label>
            TikTok
            <input value={v.tiktok} onChange={set("tiktok")} maxLength={60} placeholder="@dukanyň_ady" autoCapitalize="none" />
          </label>
        </div>
        <div className="form-row">
          <label>
            Telegram
            <input value={v.telegram} onChange={set("telegram")} maxLength={60} placeholder="@dukanyň_ady" autoCapitalize="none" />
          </label>
          <label>
            WhatsApp
            <input type="tel" inputMode="tel" value={v.whatsapp} onChange={set("whatsapp")} maxLength={20} placeholder="+993 61 234567" />
          </label>
        </div>
        <div className="form-row">
          <label>
            IMO
            <input type="tel" inputMode="tel" value={v.imo} onChange={set("imo")} maxLength={20} placeholder="+993 61 234567" />
          </label>
          <label>
            YouTube
            <input type="url" inputMode="url" value={v.youtube} onChange={set("youtube")} maxLength={200} placeholder="https://youtube.com/@…" />
          </label>
        </div>
        <label>
          Web sahypa
          <input type="url" inputMode="url" value={v.website} onChange={set("website")} maxLength={200} placeholder="https://" />
        </label>
      </fieldset>
      <div className="form-row">
        <label>
          Eltip bermek (gün)
          <input type="number" min={0} max={90} inputMode="numeric" value={v.deliveryDays} onChange={set("deliveryDays")} placeholder="3" />
          <small className="hint">Täze harytlar üçin adaty möhlet</small>
        </label>
        <label>
          Gaýtaryp bermek (gün)
          <input type="number" min={0} max={90} inputMode="numeric" value={v.returnDays} onChange={set("returnDays")} placeholder="14" />
          <small className="hint">0 = gaýtaryp alynmaýar</small>
        </label>
      </div>
    </>
  );
}

function toInput(v: Values): BusinessInput {
  const n = (s: string) => (s.trim() === "" ? undefined : Math.max(0, Math.round(Number(s) || 0)));
  return {
    category: v.category as BusinessCategory,
    phone: v.phone.trim(),
    city: v.city.trim(),
    address: v.address.trim(),
    instagram: v.instagram.trim(),
    tiktok: v.tiktok.trim(),
    telegram: v.telegram.trim(),
    whatsapp: v.whatsapp.trim(),
    imo: v.imo.trim(),
    youtube: v.youtube.trim(),
    website: v.website.trim(),
    workingHours: v.workingHours.trim(),
    deliveryDays: n(v.deliveryDays),
    returnDays: n(v.returnDays),
  };
}

function validate(v: Values): string | null {
  if (!v.category) return "Biznes kategoriýasyny saýlaň";
  if (!PHONE_RE.test(v.phone.trim())) return "Telefon belgisi nädogry. Mysal: +993 61 234567";
  if (v.whatsapp.trim() && !PHONE_RE.test(v.whatsapp.trim())) return "WhatsApp belgisi nädogry";
  if (v.imo.trim() && !PHONE_RE.test(v.imo.trim())) return "IMO belgisi nädogry";
  for (const u of [v.youtube, v.website]) if (u.trim() && !/^https?:\/\/\S+/i.test(u.trim())) return "Baglanyşyk http:// ýa-da https:// bilen başlamaly";
  return null;
}

export default function BusinessSection() {
  const { user, setUser } = useAuth();
  const toast = useToast();
  const biz = user?.business ?? null;
  const [opening, setOpening] = useState(false);
  const [v, setV] = useState<Values>(() => ({
    category: biz?.category ?? "",
    phone: biz?.phone ?? "",
    city: biz?.city ?? "",
    address: biz?.address ?? "",
    instagram: biz?.instagram ?? "",
    tiktok: biz?.tiktok ?? "",
    telegram: biz?.telegram ?? "",
    whatsapp: biz?.whatsapp ?? "",
    imo: biz?.imo ?? "",
    youtube: biz?.youtube ?? "",
    website: biz?.website ?? "",
    workingHours: biz?.workingHours ?? "",
    deliveryDays: biz ? String(biz.deliveryDays) : "3",
    returnDays: biz ? String(biz.returnDays) : "14",
  }));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (!user) return null;

  const set = (k: keyof Values) => (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => setV((x) => ({ ...x, [k]: e.target.value }));

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const invalid = validate(v);
    if (invalid) return setError(invalid);
    setBusy(true);
    setError(null);
    try {
      const me = user.isBusiness ? await api.updateBusiness(toInput(v)) : await api.openBusiness(toInput(v));
      setUser(me);
      toast(user.isBusiness ? "Biznes maglumatlary saklandy" : "Biznes hasabyňyz açyldy!");
      setOpening(false);
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  const close = async () => {
    if (!window.confirm("Şahsy hasaba geçmelimi? Harytlaryňyz adaty pinlere öwrüler we satylmaz.")) return;
    setBusy(true);
    try {
      setUser(await api.closeBusiness());
      toast("Şahsy hasaba geçildi");
    } catch (err) {
      toast(errorMessage(err), "error");
    } finally {
      setBusy(false);
    }
  };

  if (!user.isBusiness && !opening) {
    return (
      <div className="biz-cta">
        <div className="biz-cta-icon"><StoreIcon size={28} /></div>
        <div>
          <strong>Biznes hasabyny aç</strong>
          <p className="muted small">Dükanyňyzy ModaHouse-da açyň: harytlary bahasy bilen goşuň, sargyt kabul ediň we Top 10 reýtinge giriň.</p>
          <ul className="biz-perks">
            <li><BagIcon size={16} /> Harytlar we sargytlar</li>
            <li><ChartIcon size={16} /> Statistika paneli</li>
            <li><TrophyIcon size={16} /> Top 10 köýnekçi</li>
          </ul>
          <button className="btn btn-primary" onClick={() => setOpening(true)}>Biznes hasabyny aç</button>
        </div>
      </div>
    );
  }

  return (
    <form className="form" onSubmit={submit} noValidate>
      {user.isBusiness && (
        <div className="biz-status">
          <span className="status-pill st-delivered">Biznes hasaby</span>
          <Link href="/business" className="text-link">Biznes paneline git</Link>
        </div>
      )}
      <Fields v={v} set={set} />
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="form-actions">
        {user.isBusiness ? (
          <button type="button" className="btn btn-secondary danger" onClick={close} disabled={busy}>Şahsy hasaba geç</button>
        ) : (
          <button type="button" className="btn btn-secondary" onClick={() => setOpening(false)} disabled={busy}>Ýatyr</button>
        )}
        <button className="btn btn-primary" disabled={busy}>{busy ? "Garaşyň…" : user.isBusiness ? "Sakla" : "Biznes hasabyny aç"}</button>
      </div>
    </form>
  );
}
