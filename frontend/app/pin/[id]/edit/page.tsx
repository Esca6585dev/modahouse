"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import PinFields, { validatePinFields, type PinFieldValues } from "@/components/PinFields";
import PinImage from "@/components/PinImage";
import { useToast } from "@/components/Toast";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useRequireAuth } from "@/lib/hooks";
import type { Pin } from "@/lib/types";

export default function EditPinPage() {
  const { id } = useParams<{ id: string }>();
  const { user } = useRequireAuth();
  const router = useRouter();
  const toast = useToast();
  const [pin, setPin] = useState<Pin | null>(null);
  const [fields, setFields] = useState<PinFieldValues | null>(null);
  const [loadError, setLoadError] = useState<{ status: number; message: string } | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const userId = user?.id;
  useEffect(() => {
    if (!userId) return;
    let alive = true;
    api.pin(id).then(
      (p) => {
        if (!alive) return;
        setPin(p);
        setFields({ title: p.title, description: p.description, link: p.link, category: p.category, tags: p.tags.join(", ") });
      },
      (e) => alive && setLoadError({ status: e instanceof ApiError ? e.status : 0, message: errorMessage(e) }),
    );
    return () => { alive = false; };
  }, [id, userId]);

  if (loadError) {
    return (
      <div className="page narrow">
        <div className="empty">
          <h2>{loadError.status === 404 ? "Pin tapylmady" : "Ýüklenmedi"}</h2>
          <p>{loadError.message}</p>
          <Link href="/" className="btn btn-primary">Baş sahypa gaýt</Link>
        </div>
      </div>
    );
  }
  if (!user || !pin || !fields) {
    return <div className="page narrow"><div className="skeleton" style={{ height: 420, borderRadius: 32 }} /></div>;
  }
  if (pin.author.id !== user.id) {
    return (
      <div className="page narrow">
        <div className="empty">
          <h2>Rugsat ýok</h2>
          <p>Diňe öz pinleriňizi üýtgedip bilersiňiz.</p>
          <Link href={`/pin/${pin.id}`} className="btn btn-primary">Pine gaýt</Link>
        </div>
      </div>
    );
  }

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (busy) return;
    const invalid = validatePinFields(fields);
    if (invalid) {
      setError(invalid);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await api.updatePin(pin.id, {
        title: fields.title.trim(),
        description: fields.description.trim(),
        link: fields.link.trim(),
        category: fields.category,
        tags: fields.tags,
      });
      toast("Üýtgeşmeler saklandy");
      router.push(`/pin/${pin.id}`);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <div className="page narrow">
      <div className="create-head">
        <h1>Pini üýtget</h1>
        <div className="head-actions">
          <Link href={`/pin/${pin.id}`} className="btn btn-secondary">Ýatyr</Link>
          <button className="btn btn-primary" form="edit-form" disabled={busy}>{busy ? "Saklanýar…" : "Sakla"}</button>
        </div>
      </div>
      <div className="create">
        <div className="edit-preview"><PinImage pin={pin} eager /></div>
        <form id="edit-form" className="form" onSubmit={submit} noValidate>
          <PinFields value={fields} onChange={setFields} />
          {error && <p className="form-error" role="alert">{error}</p>}
        </form>
      </div>
    </div>
  );
}
