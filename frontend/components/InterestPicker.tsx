"use client";

import { useEffect, useState } from "react";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCategories } from "@/lib/hooks";
import Modal from "./Modal";
import { useToast } from "./Toast";

const SKIP_KEY = "mh_interests_asked";

/** Asks a signed-in user once what they like, so the "Saňa" feed starts personal. */
export default function InterestPicker({ onDone }: { onDone: () => void }) {
  const { user } = useAuth();
  const cats = useCategories();
  const toast = useToast();
  const [open, setOpen] = useState(false);
  const [chosen, setChosen] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!user) return;
    let asked = false;
    try {
      asked = localStorage.getItem(SKIP_KEY) === String(user.id);
    } catch {}
    if (asked) return;
    let alive = true;
    api.interests().then((r) => alive && !r.picked && setOpen(true), () => {});
    return () => { alive = false; };
  }, [user]);

  if (!open || !user) return null;

  const close = () => {
    try {
      localStorage.setItem(SKIP_KEY, String(user.id));
    } catch {}
    setOpen(false);
  };
  const save = async () => {
    setBusy(true);
    try {
      await api.pickInterests(chosen);
      close();
      onDone();
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };
  const toggle = (slug: string) =>
    setChosen((c) => (c.includes(slug) ? c.filter((x) => x !== slug) : [...c, slug]));

  return (
    <Modal title="Näme bilen gyzyklanýarsyňyz?" onClose={close}>
      <p className="muted">Birnäçesini saýlaň: «Saňa» lentasyny şolara görä düzeris. Soňra sazlamalarda üýtgedip bolýar.</p>
      <div className="interest-grid">
        {(cats ?? []).map((c) => (
          <button
            key={c.slug}
            type="button"
            className={`chip ${chosen.includes(c.slug) ? "active" : ""}`}
            aria-pressed={chosen.includes(c.slug)}
            onClick={() => toggle(c.slug)}
          >
            {c.name}
          </button>
        ))}
      </div>
      <div className="form-actions">
        <button type="button" className="btn btn-secondary" onClick={close}>Geçmek</button>
        <button type="button" className="btn btn-primary" disabled={busy || chosen.length === 0} onClick={save}>
          {busy ? "Saklanýar…" : "Dowam et"}
        </button>
      </div>
    </Modal>
  );
}
