"use client";

import Link from "next/link";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import { errorMessage, safeNext } from "@/lib/api";
import { useAuth } from "@/lib/auth";

function LoginForm() {
  const { login, user, ready } = useAuth();
  const router = useRouter();
  const params = useSearchParams();
  const next = safeNext(params.get("next"));
  const [loginName, setLoginName] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (ready && user && !busy) router.replace(next);
  }, [ready, user, busy, next, router]);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!loginName.trim() || !password) {
      setError("Ulanyjy adyňyzy (ýa-da e-poçtaňyzy) we parolyňyzy ýazyň");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await login(loginName.trim(), password);
      router.replace(next);
    } catch (err) {
      setError(errorMessage(err));
      setBusy(false);
    }
  };

  return (
    <div className="auth-card">
      <span className="logo-mark big">M</span>
      <h1>ModaHouse-a hoş geldiňiz</h1>
      <p className="muted">Täze ideýalary tapmak üçin giriň</p>
      <form className="form" onSubmit={submit} noValidate>
        <label>
          Ulanyjy ady ýa-da e-poçta
          <input
            value={loginName}
            onChange={(e) => setLoginName(e.target.value)}
            autoComplete="username"
            autoCapitalize="none"
            autoFocus
            placeholder="mysal: aylar.studio"
          />
        </label>
        <label>
          Parol
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="current-password" placeholder="Parol" />
        </label>
        {error && <p className="form-error" role="alert">{error}</p>}
        <button className="btn btn-primary btn-block" disabled={busy}>{busy ? "Girilýär…" : "Giriş"}</button>
      </form>
      <div className="demo-hint">
        <strong>Synag hasaby</strong>
        <span>Ulanyjy: <code>aylar.studio</code> · Parol: <code>modahouse123</code></span>
        <button
          type="button"
          className="link-btn"
          onClick={() => { setLoginName("aylar.studio"); setPassword("modahouse123"); }}
        >
          Doldur
        </button>
      </div>
      <p className="auth-switch">
        Hasabyňyz ýokmy? <Link href={`/register${next !== "/" ? `?next=${encodeURIComponent(next)}` : ""}`} className="text-link">Hasaba alyň</Link>
      </p>
    </div>
  );
}

export default function LoginPage() {
  return (
    <div className="page auth-page">
      <Suspense fallback={<div className="auth-card" />}>
        <LoginForm />
      </Suspense>
    </div>
  );
}
