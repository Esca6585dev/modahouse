"use client";

import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import Avatar from "@/components/Avatar";
import BoardCard from "@/components/BoardCard";
import BoardFormModal from "@/components/BoardFormModal";
import FollowButton from "@/components/FollowButton";
import { PlusIcon } from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import { useToast } from "@/components/Toast";
import UserListModal from "@/components/UserListModal";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact } from "@/lib/format";
import { usePaged } from "@/lib/hooks";
import { shareUrl } from "@/lib/share";
import type { Board, Profile } from "@/lib/types";

function CreatedPins({ username, viewer, isMe }: { username: string; viewer: number; isMe: boolean }) {
  const paged = usePaged(`upins:${username}:${viewer}`, (page) => api.userPins(username, page));
  return (
    <PinFeed
      paged={paged}
      empty={
        <div className="empty">
          <h2>Entek pin ýok</h2>
          {isMe ? (
            <>
              <p>Ilkinji pininizi dörediň we ideýalaryňyzy paýlaşyň.</p>
              <Link href="/create" className="btn btn-primary">Pin döret</Link>
            </>
          ) : (
            <p>Bu ulanyjy entek pin döretmedi.</p>
          )}
        </div>
      }
    />
  );
}

function SavedBoards({ username, viewer, isMe }: { username: string; viewer: number; isMe: boolean }) {
  const [boards, setBoards] = useState<Board[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [nonce, setNonce] = useState(0);
  const router = useRouter();

  useEffect(() => {
    let alive = true;
    setBoards(null);
    setError(null);
    api.userBoards(username).then((b) => alive && setBoards(b), (e) => alive && setError(errorMessage(e)));
    return () => { alive = false; };
  }, [username, viewer, nonce]);

  if (error) {
    return (
      <div className="empty">
        <h2>Ýüklenmedi</h2>
        <p>{error}</p>
        <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
      </div>
    );
  }
  if (!boards) {
    return (
      <div className="boards">
        {[0, 1, 2, 3].map((i) => <div key={i} className="board"><div className="board-collage skeleton" /><div className="skeleton skeleton-line" /></div>)}
      </div>
    );
  }
  return (
    <>
      {isMe && (
        <div className="boards-toolbar">
          <button className="btn btn-secondary" onClick={() => setCreating(true)}><PlusIcon size={18} /> Täze tagta</button>
        </div>
      )}
      {boards.length === 0 ? (
        <div className="empty">
          <h2>Tagta ýok</h2>
          <p>{isMe ? "Halan pinleriňizi saklamak üçin tagta dörediň." : "Bu ulanyjynyň açyk tagtasy ýok."}</p>
        </div>
      ) : (
        <div className="boards">
          {boards.map((b) => <BoardCard key={b.id} board={b} />)}
        </div>
      )}
      {creating && (
        <BoardFormModal
          onClose={() => setCreating(false)}
          onSaved={(b) => {
            setCreating(false);
            setBoards((l) => [...(l ?? []), b]);
            router.push(`/board/${b.id}`);
          }}
        />
      )}
    </>
  );
}

function ProfileView() {
  const { username: raw } = useParams<{ username: string }>();
  const username = decodeURIComponent(raw).toLowerCase();
  const params = useSearchParams();
  const router = useRouter();
  const toast = useToast();
  const { user, ready } = useAuth();
  const tab = params.get("tab") === "saved" ? "saved" : "created";
  const [profile, setProfile] = useState<Profile | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "notfound" | "error">("loading");
  const [error, setError] = useState("");
  const [list, setList] = useState<"followers" | "following" | null>(null);
  const [nonce, setNonce] = useState(0);
  const viewer = user?.id ?? 0;

  useEffect(() => {
    if (!ready) return;
    let alive = true;
    api.user(username).then(
      (p) => {
        if (!alive) return;
        setProfile(p);
        setState("ok");
        document.title = `${p.name} (@${p.username}) · ModaHouse`;
      },
      (e) => {
        if (!alive) return;
        if (e instanceof ApiError && e.status === 404) setState("notfound");
        else {
          setError(errorMessage(e));
          setState("error");
        }
      },
    );
    return () => { alive = false; };
  }, [username, ready, viewer, nonce]);

  if (state === "notfound") {
    return (
      <div className="empty">
        <h2>Ulanyjy tapylmady</h2>
        <p>@{username} atly ulanyjy ýok.</p>
        <Link href="/" className="btn btn-primary">Baş sahypa gaýt</Link>
      </div>
    );
  }
  if (state === "error") {
    return (
      <div className="empty">
        <h2>Ýüklenmedi</h2>
        <p>{error}</p>
        <button className="btn btn-primary" onClick={() => setNonce((n) => n + 1)}>Gaýtadan synanyş</button>
      </div>
    );
  }
  if (!profile || profile.username !== username) {
    return (
      <section className="profile" aria-busy="true">
        <div className="skeleton" style={{ width: 112, height: 112, borderRadius: "50%" }} />
        <div className="skeleton skeleton-line" style={{ width: 220, height: 34, marginTop: 16 }} />
        <div className="skeleton skeleton-line" style={{ width: 140 }} />
      </section>
    );
  }

  const isMe = profile.isMe;
  const setTab = (t: "created" | "saved") => router.replace(`/u/${profile.username}${t === "saved" ? "?tab=saved" : ""}`, { scroll: false });

  return (
    <>
      <section className="profile">
        <Avatar user={profile} size={112} />
        <h1>{profile.name}</h1>
        <p className="muted">@{profile.username}</p>
        {profile.bio && <p className="bio">{profile.bio}</p>}
        <p className="stats">
          <button className="stat-btn" onClick={() => setList("followers")}>
            <strong>{compact(profile.followersCount)}</strong> yzarlaýjy
          </button>
          {" · "}
          <button className="stat-btn" onClick={() => setList("following")}>
            <strong>{compact(profile.followingCount)}</strong> yzarlanýan
          </button>
          {" · "}
          <span><strong>{compact(profile.pinsCount)}</strong> pin</span>
        </p>
        <div className="profile-actions">
          <button
            className="btn btn-secondary"
            onClick={async () => {
              const msg = await shareUrl(`/u/${profile.username}`, profile.name);
              if (msg) toast(msg);
            }}
          >
            Paýlaş
          </button>
          {isMe ? (
            <Link href="/settings" className="btn btn-secondary">Profili üýtget</Link>
          ) : (
            <FollowButton
              username={profile.username}
              isFollowing={profile.isFollowing}
              onChange={(on, p) =>
                setProfile((cur) => p ?? (cur ? { ...cur, isFollowing: on, followersCount: cur.followersCount + (on === cur.isFollowing ? 0 : on ? 1 : -1) } : cur))}
            />
          )}
        </div>
      </section>

      <div className="tabs" role="tablist">
        <button role="tab" aria-selected={tab === "created"} className={tab === "created" ? "active" : ""} onClick={() => setTab("created")}>
          Döredilen
        </button>
        <button role="tab" aria-selected={tab === "saved"} className={tab === "saved" ? "active" : ""} onClick={() => setTab("saved")}>
          Saklanan
        </button>
      </div>

      {tab === "created" ? (
        <CreatedPins username={profile.username} viewer={viewer} isMe={isMe} />
      ) : (
        <SavedBoards username={profile.username} viewer={viewer} isMe={isMe} />
      )}

      {list && (
        <UserListModal
          key={list}
          username={profile.username}
          kind={list}
          onClose={() => setList(null)}
        />
      )}
    </>
  );
}

export default function ProfilePage() {
  return (
    <div className="page">
      <Suspense fallback={null}>
        <ProfileView />
      </Suspense>
    </div>
  );
}
