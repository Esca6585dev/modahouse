"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { errorMessage, safeNext } from "@/lib/api";
import { useAuth } from "@/lib/auth";

const USERNAME_RE = /^[a-z0-9._]{3,30}$/;

function RegisterForm() {
  const { register, user, ready } = useAuth();
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const [f, setF] = useState({ name: "", username: "", email: "", password: "" });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (ready && user && !busy) router.replace(next);
  }, [ready, user, busy, next, router]);

  const set = (k: keyof typeof f) => (e: React.ChangeEvent<HTMLInputElement>) =>
    setF((v) => ({ ...v, [k]: k === "username" ? e.target.value.toLowerCase() : e.target.value }));

  const validate = (): string | null => {
    if (!f.name.trim()) return "Adyňyzy ýazyň";
    if (!USERNAME_RE.test(f.username.trim())) return "Ulanyjy ady 3-30 simwol bolmaly: kiçi harplar, sanlar, nokat we aşaky çyzyk";
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(f.email.trim())) return "E-poçta nädogry";
    if (f.password.length < 6) return "Parol azyndan 6 simwol bolmaly";
    return null;
  };

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    const invalid = validate();
    if (invalid) {
      setError(invalid);
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await register({ name: f.name.trim(), username: f.username.trim(), email: f.email.trim(), password: f.password });
      router.replace(next);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <div className="auth-card">
      <span className="logo-mark big">M</span>
      <h1>Hasap dörediň</h1>
      <p className="muted">Ideýalaryňyzy saklaň we paýlaşyň</p>
      <form className="form" onSubmit={submit} noValidate>
        <label>
          Adyňyz
          <input value={f.name} onChange={set("name")} autoComplete="name" maxLength={60} autoFocus placeholder="Mysal: Aýna Annaýewa" />
        </label>
        <label>
          Ulanyjy ady
          <input value={f.username} onChange={set("username")} autoComplete="username" autoCapitalize="none" maxLength={30} placeholder="mysal: ayna.moda" />
          <small className="hint">Kiçi harplar, sanlar, nokat we aşaky çyzyk</small>
        </label>
        <label>
          E-poçta
          <input type="email" value={f.email} onChange={set("email")} autoComplete="email" maxLength={120} placeholder="siz@mysal.com" />
        </label>
        <label>
          Parol
          <input type="password" value={f.password} onChange={set("password")} autoComplete="new-password" maxLength={72} placeholder="Azyndan 6 simwol" />
        </label>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={busy}>{busy ? "Döredilýär…" : "Hasaba al"}</button>
      </form>
      <p className="auth-switch">
        Hasabyňyz barmy? <Link href={`/login${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`} className="text-link">Giriň</Link>
      </p>
    </div>
  );
}

export default function RegisterPage() {
  return (
    <div className="page auth-page">
      <Suspense fallback={<div className="auth-card" />}>
        <RegisterForm />
      </Suspense>
    </div>
  );
}
