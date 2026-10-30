"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useRef, useState } from "react";
import Avatar from "@/components/Avatar";
import BusinessSection from "@/components/BusinessForm";
import { useToast } from "@/components/Toast";
import { api, errorMessage, setToken } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useBusinessCategories, useRequireAuth } from "@/lib/hooks";
import type { Interest, UserBrief } from "@/lib/types";

const USERNAME_RE = /^[a-z0-9._]{3,30}$/;
const AVATAR_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];

function ProfileForm() {
  const { user, setUser } = useAuth();
  const toast = useToast();
  const [name, setName] = useState(user?.name ?? "");
  const [username, setUsername] = useState(user?.username ?? "");
  const [bio, setBio] = useState(user?.bio ?? "");
  const [craft, setCraft] = useState(user?.category ?? "");
  const crafts = useBusinessCategories();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  if (!user) return null;

  const dirty = name !== user.name || username !== user.username || bio !== user.bio || craft !== (user.category ?? "");

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return setError("Adyňyzy ýazyň");
    if (!USERNAME_RE.test(username.trim())) return setError("Ulanyjy ady 3-30 simwol bolmaly: kiçi harplar, sanlar, nokat we aşaky çyzyk");
    setBusy(true);
    setError(null);
    try {
      const me = await api.updateMe({ name: name.trim(), username: username.trim(), bio: bio.trim(), category: craft });
      setUser(me);
      setName(me.name);
      setUsername(me.username);
      setBio(me.bio);
      setCraft(me.category ?? "");
      toast("Profil täzelendi");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="form" onSubmit={submit} noValidate>
      <label>
        Adyňyz
        <input value={name} onChange={(e) => setName(e.target.value)} maxLength={60} autoComplete="name" />
      </label>
      <label>
        Ulanyjy ady
        <input value={username} onChange={(e) => setUsername(e.target.value.toLowerCase())} maxLength={30} autoCapitalize="none" />
        <small className="hint">modahouse/u/{username || "…"}</small>
      </label>
      <label>
        Barada
        <textarea rows={3} value={bio} onChange={(e) => setBio(e.target.value)} maxLength={300} placeholder="Özüňiz barada gysgaça ýazyň" />
        <small className="hint">{bio.length}/300</small>
      </label>
      <label>
        Kärim
        <select value={craft} onChange={(e) => setCraft(e.target.value)}>
          {!user.isBusiness && <option value="">Görkezme</option>}
          {crafts.map((c) => <option key={c.value} value={c.value}>{c.label}</option>)}
        </select>
        <small className="hint">Tikinçi, kirpikçi, dyrnakçy, el keşdeçi… Profiliňizde görner we «Ussalar» sahypasynda tapylarsyňyz.</small>
      </label>
      <label>
        E-poçta
        <input value={user.email} disabled readOnly />
      </label>
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="form-actions">
        <button className="btn btn-primary" disabled={busy || !dirty}>{busy ? "Saklanýar…" : "Sakla"}</button>
      </div>
    </form>
  );
}

function AvatarForm() {
  const { user, setUser } = useAuth();
  const toast = useToast();
  const input = useRef<HTMLInputElement>(null);
  const [busy, setBusy] = useState(false);
  if (!user) return null;

  const upload = async (file: File | undefined) => {
    if (!file) return;
    if (!AVATAR_TYPES.includes(file.type)) {
      toast("Diňe JPG, PNG, GIF ýa-da WEBP suratlary kabul edilýär", "error");
      return;
    }
    setBusy(true);
    try {
      setUser(await api.uploadAvatar(file));
      toast("Profil suraty täzelendi");
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
      if (input.current) input.current.value = "";
    }
  };

  const remove = async () => {
    setBusy(true);
    try {
      setUser(await api.deleteAvatar());
      toast("Profil suraty aýryldy");
    } catch (e) {
      toast(errorMessage(e), "error");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="avatar-row">
      <Avatar user={user} size={88} />
      <div className="avatar-actions">
        <input ref={input} type="file" accept={AVATAR_TYPES.join(",")} hidden onChange={(e) => upload(e.target.files?.[0])} aria-label="Profil suraty" />
        <button type="button" className="btn btn-secondary" onClick={() => input.current?.click()} disabled={busy}>
          {busy ? "Garaşyň…" : user.avatarUrl ? "Suraty çalyş" : "Surat ýükle"}
        </button>
        {user.avatarUrl && (
          <button type="button" className="btn btn-secondary" onClick={remove} disabled={busy}>Aýyr</button>
        )}
      </div>
    </div>
  );
}

function MyInterests() {
  const toast = useToast();
  const [items, setItems] = useState<Interest[] | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    api.interests().then((r) => setItems(r.items), () => setItems([]));
  }, []);
  if (!items) return <div className="skeleton" style={{ height: 56 }} />;
  return (
    <>
      <p className="muted small">
        «Saňa» lentasy siziň seredýän, halaýan we saklaýan postlaryňyza görä düzülýär.
        {items.length === 0 && " Entek hiç zat öwrenilmedi."}
      </p>
      {items.length > 0 && (
        <div className="chips interest-chips">
          {items.slice(0, 16).map((i) => (
            <span key={i.kind + i.key} className="chip">{i.kind === "tag" ? "#" : ""}{i.name}</span>
          ))}
        </div>
      )}
      {items.length > 0 && (
        <button
          className="btn btn-secondary btn-sm"
          disabled={busy}
          onClick={async () => {
            setBusy(true);
            try {
              await api.resetInterests();
              setItems([]);
              toast("Gyzyklanmalar arassalandy");
            } catch (e) {
              toast(errorMessage(e), "error");
            } finally {
              setBusy(false);
            }
          }}
        >
          Arassala
        </button>
      )}
    </>
  );
}

function BlockedUsers() {
  const toast = useToast();
  const [list, setList] = useState<UserBrief[] | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  useEffect(() => {
    api.myBlocks().then(setList, () => setList([]));
  }, []);
  if (!list) return <div className="skeleton" style={{ height: 56 }} />;
  if (list.length === 0) return <p className="muted small">Petiklenen ulanyjy ýok. Profildäki «⋯» menýusyndan petikläp bilersiňiz.</p>;
  return (
    <ul className="user-list">
      {list.map((u) => (
        <li key={u.id} className="user-row">
          <Link href={`/u/${u.username}`}><Avatar user={u} size={40} /></Link>
          <span className="blocked-name">
            <strong>{u.name}</strong>
            <span className="muted">@{u.username}</span>
          </span>
          <button
            className="btn btn-secondary btn-sm"
            disabled={busy === u.username}
            onClick={async () => {
              setBusy(u.username);
              try {
                await api.unblock(u.username);
                setList((l) => l?.filter((x) => x.id !== u.id) ?? l);
                toast(`@${u.username} petikden aýryldy`);
              } catch (e) {
                toast(errorMessage(e), "error");
              } finally {
                setBusy(null);
              }
            }}
          >
            Petigi aýyr
          </button>
        </li>
      ))}
    </ul>
  );
}

function PasswordForm() {
  const toast = useToast();
  const { setUser } = useAuth();
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [repeat, setRepeat] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!current) return setError("Häzirki parolyňyzy ýazyň");
    if (next.length < 6) return setError("Parol azyndan 6 simwol bolmaly");
    if (next !== repeat) return setError("Täze parollar gabat gelmeýär");
    setBusy(true);
    setError(null);
    try {
      const res = await api.changePassword({ currentPassword: current, newPassword: next });
      setToken(res.token);
      setUser(res.user);
      setCurrent("");
      setNext("");
      setRepeat("");
      toast("Parol üýtgedildi");
    } catch (err) {
      setError(errorMessage(err));
    } finally {
      setBusy(false);
    }
  };

  return (
    <form className="form" onSubmit={submit} noValidate>
      <label>
        Häzirki parol
        <input type="password" value={current} onChange={(e) => setCurrent(e.target.value)} autoComplete="current-password" />
      </label>
      <div className="form-row">
        <label>
          Täze parol
          <input type="password" value={next} onChange={(e) => setNext(e.target.value)} autoComplete="new-password" maxLength={72} />
        </label>
        <label>
          Täze paroly gaýtalaň
          <input type="password" value={repeat} onChange={(e) => setRepeat(e.target.value)} autoComplete="new-password" maxLength={72} />
        </label>
      </div>
      {error && <p className="form-error" role="alert">{error}</p>}
      <div className="form-actions">
        <button className="btn btn-primary" disabled={busy || !current || !next}>{busy ? "Üýtgedilýär…" : "Paroly üýtget"}</button>
      </div>
    </form>
  );
}

export default function SettingsPage() {
  const { user } = useRequireAuth();
  const { logout } = useAuth();
  const router = useRouter();

  useEffect(() => { document.title = "Sazlamalar · ModaHouse"; }, []);

  // Jump to #business (e.g. from "Biznes hasabyny aç" links) once the page is rendered.
  const ready = !!user;
  useEffect(() => {
    if (!ready || window.location.hash !== "#business") return;
    document.getElementById("business")?.scrollIntoView({ behavior: "smooth", block: "start" });
  }, [ready]);

  if (!user) {
    return <div className="page narrow-sm"><div className="skeleton" style={{ height: 400, borderRadius: 24 }} /></div>;
  }

  return (
    <div className="page narrow-sm">
      <div className="settings-head">
        <h1 className="page-title">Sazlamalar</h1>
        <div className="head-actions">
          {user.isAdmin && <Link href="/admin" className="btn btn-secondary btn-sm">Admin paneli</Link>}
          <Link href={`/u/${user.username}`} className="btn btn-secondary btn-sm">Profile git</Link>
        </div>
      </div>

      <section className="card">
        <h2>Profil suraty</h2>
        <AvatarForm />
      </section>

      <section className="card">
        <h2>Şahsy maglumatlar</h2>
        <ProfileForm key={user.id} />
      </section>

      <section className="card" id="business">
        <h2>Biznes hasaby</h2>
        <BusinessSection key={`${user.id}:${user.isBusiness}`} />
      </section>

      <section className="card" id="interests">
        <h2>Gyzyklanmalarym</h2>
        <MyInterests />
      </section>

      <section className="card" id="blocked">
        <h2>Petiklenen ulanyjylar</h2>
        <BlockedUsers />
      </section>

      <section className="card">
        <h2>Parol</h2>
        <PasswordForm />
      </section>

      <section className="card">
        <h2>Hasapdan çykmak</h2>
        <p className="muted small">Bu enjamda hasabyňyzdan çykarsyňyz.</p>
        <button
          className="btn btn-secondary danger"
          onClick={() => {
            logout();
            router.push("/");
          }}
        >
          Çykyş
        </button>
      </section>
    </div>
  );
}
