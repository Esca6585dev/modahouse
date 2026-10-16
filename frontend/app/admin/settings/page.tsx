"use client";

import { useCallback, useEffect, useState } from "react";
import { CheckIcon, CloseIcon, InfoIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { api, errorMessage } from "@/lib/api";
import { dateTime } from "@/lib/format";
import type { AppConfig, UrlCheck } from "@/lib/types";
import { AdminHead, LoadError } from "../shared";

const URL_RE = /^https?:\/\/[^\s/?#]+(?::\d+)?(?:\/[^\s]*)?$/i;

/** Mirrors the server: trims a trailing slash and a trailing /api. */
function cleanUrl(v: string): string {
  return v.trim().replace(/\/+$/, "").replace(/\/api$/i, "").replace(/\/+$/, "");
}

function checkText(r: UrlCheck): string {
  if (r.ok) return `Serwer jogap berýär${r.status ? ` (HTTP ${r.status})` : ""}`;
  if (r.error) return r.error;
  return r.status ? `Serwer nädogry jogap berdi (HTTP ${r.status})` : "Serwer jogap bermedi";
}

export default function AdminSettings() {
  const toast = useToast();
  const [saved, setSaved] = useState<AppConfig | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [apiUrl, setApiUrl] = useState("");
  const [webUrl, setWebUrl] = useState("");
  const [registrationOpen, setRegistrationOpen] = useState(true);
  const [watermarkUploads, setWatermarkUploads] = useState(true);
  const [check, setCheck] = useState<{ url: string; result: UrlCheck } | null>(null);
  const [checking, setChecking] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const apply = (c: AppConfig) => {
    setSaved(c);
    setApiUrl(c.apiUrl);
    setWebUrl(c.webUrl);
    setRegistrationOpen(c.registrationOpen);
    setWatermarkUploads(c.watermarkUploads);
  };

  const load = useCallback(() => {
    setLoadError(null);
    setSaved(null);
    api.admin.settings().then(apply, (e) => setLoadError(errorMessage(e)));
  }, []);
  useEffect(() => {
    document.title = "Sazlamalar · Admin paneli";
    load();
  }, [load]);

  if (loadError) {
    return (
      <>
        <AdminHead title="Sazlamalar" />
        <LoadError message={loadError} onRetry={load} />
      </>
    );
  }
  if (!saved) {
    return (
      <>
        <AdminHead title="Sazlamalar" sub="Serwer salgylary, hasap açmak we logo" />
        <div className="skeleton" style={{ height: 420, borderRadius: 24 }} />
      </>
    );
  }

  const api0 = cleanUrl(apiUrl);
  const web0 = cleanUrl(webUrl);
  const dirty = api0 !== saved.apiUrl || web0 !== saved.webUrl || registrationOpen !== saved.registrationOpen
    || watermarkUploads !== saved.watermarkUploads;
  const apiInvalid = api0 !== "" && !URL_RE.test(api0);
  const webInvalid = web0 !== "" && !URL_RE.test(web0);
  const shownCheck = check && check.url === api0 ? check.result : null;

  const runCheck = async (url: string): Promise<UrlCheck | null> => {
    setChecking(true);
    try {
      const result = await api.admin.checkUrl(url);
      setCheck({ url, result });
      return result;
    } catch (e) {
      const result = { ok: false, status: 0, error: errorMessage(e) };
      setCheck({ url, result });
      return result;
    } finally {
      setChecking(false);
    }
  };

  const save = async (e: React.FormEvent) => {
    e.preventDefault();
    if (apiInvalid || webInvalid) return setError("Salgy http:// ýa-da https:// bilen başlamaly");
    setError(null);
    // A new API address is checked first: the apps would ignore an address that does not answer anyway.
    if (api0 && api0 !== saved.apiUrl) {
      const r = shownCheck ?? (await runCheck(api0));
      if (r && !r.ok && !window.confirm(`API salgysy jogap bermedi: ${checkText(r)}.\nBarybir saklamalymy? Programmalar bu salgy işläp başlaýança öňküsinde galar.`)) return;
    }
    setSaving(true);
    try {
      const c = await api.admin.updateSettings({ apiUrl: api0, webUrl: web0, registrationOpen, watermarkUploads });
      apply(c);
      toast("Sazlamalar saklandy");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <AdminHead
        title="Sazlamalar"
        sub={saved.updatedAt ? `Soňky üýtgeşme: ${dateTime(saved.updatedAt)}` : "Serwer salgylary, hasap açmak we logo"}
      />
      <form className="form card admin-form" onSubmit={save} noValidate>
        <label>
          API salgysy (programmalar üçin)
          <div className="admin-url-row">
            <input
              type="url"
              inputMode="url"
              value={apiUrl}
              onChange={(e) => setApiUrl(e.target.value)}
              placeholder="https://api.modahouse.tm"
              autoCapitalize="none"
              autoCorrect="off"
              spellCheck={false}
              aria-invalid={apiInvalid || undefined}
            />
            <button
              type="button"
              className="btn btn-secondary"
              disabled={!api0 || apiInvalid || checking}
              onClick={() => runCheck(api0)}
            >
              {checking ? <span className="spinner" aria-label="Barlanýar" /> : "Barla"}
            </button>
          </div>
          {apiInvalid ? (
            <small className="hint error-text">Salgy http:// ýa-da https:// bilen başlamaly</small>
          ) : shownCheck ? (
            <small className={`admin-check ${shownCheck.ok ? "ok" : "bad"}`} role="status">
              {shownCheck.ok ? <CheckIcon size={16} /> : <CloseIcon size={16} />} {checkText(shownCheck)}
            </small>
          ) : (
            <small className="hint">Serweriň umumy salgysy, /api goşmazdan. Boş goýsaňyz, programmalar häzirki salgysynda galar.</small>
          )}
        </label>

        <label>
          Web salgysy
          <input
            type="url"
            inputMode="url"
            value={webUrl}
            onChange={(e) => setWebUrl(e.target.value)}
            placeholder="https://modahouse.tm"
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            aria-invalid={webInvalid || undefined}
          />
          <small className={`hint ${webInvalid ? "error-text" : ""}`}>
            {webInvalid ? "Salgy http:// ýa-da https:// bilen başlamaly" : "Paýlaşylan baglanyşyklarda ulanylýar."}
          </small>
        </label>

        <div className="admin-switch-row">
          <div>
            <strong>Täze hasap açmak</strong>
            <span className="muted">{registrationOpen ? "Islendik adam hasaba alnyp biler." : "Täze hasap açmak ýapyk: diňe bar bolan hasaplar girip biler."}</span>
          </div>
          <label className="switch" aria-label="Täze hasap açmak">
            <input type="checkbox" checked={registrationOpen} onChange={(e) => setRegistrationOpen(e.target.checked)} />
            <span className="switch-track"><span /></span>
          </label>
        </div>

        <div className="admin-switch-row">
          <div>
            <strong>Ýüklenen suratlara ModaHouse logosyny goş</strong>
            <span className="muted">
              {watermarkUploads
                ? "Täze postlaryň suratlaryna saklananda logo we @awtor goşulýar. Awatarlar we hekaýalar üýtgemeýär."
                : "Täze postlaryň suratlary üýtgedilmän saklanýar. Ýüklenip alnanda logo barybir goşulýar."}
            </span>
          </div>
          <label className="switch" aria-label="Ýüklenen suratlara ModaHouse logosyny goş">
            <input type="checkbox" checked={watermarkUploads} onChange={(e) => setWatermarkUploads(e.target.checked)} />
            <span className="switch-track"><span /></span>
          </label>
        </div>

        <div className="admin-note">
          <InfoIcon size={18} />
          <p>
            Android programmalary täze API salgysyna özbaşdak geçýär, ýöne diňe ol salgy jogap berenden soň.
            Ýalňyş salgy ýazylsa, programmalar öňki salgysynda galýar. Web serweriň öz backend salgysy bu ýerde däl-de,
            <code>BACKEND_URL</code> gurşaw üýtgeýjisi bilen bellenýär: ony üýtgedip, web serweri täzeden işlediň.
          </p>
        </div>

        {error && <p className="form-error" role="alert">{error}</p>}
        <div className="form-actions">
          {dirty && (
            <button type="button" className="btn btn-secondary" onClick={() => { apply(saved); setError(null); }} disabled={saving}>
              Yzyna al
            </button>
          )}
          <button className="btn btn-primary" disabled={!dirty || saving || checking}>{saving ? "Saklanýar…" : "Sakla"}</button>
        </div>
      </form>
    </>
  );
}
