"use client";

import Link from "next/link";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import AddStoryModal from "@/components/AddStoryModal";
import BoardCard from "@/components/BoardCard";
import BoardFormModal from "@/components/BoardFormModal";
import FollowButton from "@/components/FollowButton";
import {
  BagIcon, BoardsIcon, CameraIcon, ChartIcon, ChatIcon, ClockIcon, GridIcon, MasonryIcon, PhoneIcon, PinMapIcon, PlusIcon,
  SettingsIcon, ShareIcon, StoreIcon, TruckIcon, VerifiedIcon,
} from "@/components/Icons";
import { PinFeed } from "@/components/Masonry";
import ProductGrid from "@/components/ProductGrid";
import Stars from "@/components/Stars";
import StoryAvatar from "@/components/StoryAvatar";
import { useStories } from "@/components/StoryViewer";
import { useToast } from "@/components/Toast";
import UserListModal from "@/components/UserListModal";
import { api, ApiError, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { businessCategoryLabel, compact, days } from "@/lib/format";
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

function Products({ username, viewer, isMe }: { username: string; viewer: number; isMe: boolean }) {
  const paged = usePaged(`uprod:${username}:${viewer}`, (page) => api.pins({ author: username, type: "products", page }));
  return (
    <ProductGrid
      paged={paged}
      empty={
        <div className="empty">
          <h2>Entek haryt ýok</h2>
          {isMe ? (
            <>
              <p>Ilkinji harydyňyzy goşuň: suratlar, baha, reňkler we ölçegler.</p>
              <Link href="/create" className="btn btn-primary">Haryt goş</Link>
            </>
          ) : (
            <p>Bu dükan entek haryt goşmady.</p>
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

type Tab = "products" | "pins" | "boards";

function phoneHref(phone: string) {
  return `tel:${phone.replace(/[^\d+]/g, "")}`;
}

function ProfileView() {
  const { username: raw } = useParams<{ username: string }>();
  const username = decodeURIComponent(raw).toLowerCase();
  const params = useSearchParams();
  const router = useRouter();
  const toast = useToast();
  const { user, ready } = useAuth();
  const stories = useStories();
  const [profile, setProfile] = useState<Profile | null>(null);
  const [state, setState] = useState<"loading" | "ok" | "notfound" | "error">("loading");
  const [error, setError] = useState("");
  const [list, setList] = useState<"followers" | "following" | null>(null);
  const [addingStory, setAddingStory] = useState(false);
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
  }, [username, ready, viewer, nonce, stories.version]);

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
      <section className="ig" aria-busy="true">
        <div className="ig-avatar"><div className="skeleton ig-skel-avatar" /></div>
        <div className="ig-top"><div className="skeleton skeleton-line" style={{ width: 220, height: 28 }} /></div>
        <div className="ig-counts"><div className="skeleton skeleton-line" style={{ width: 260 }} /></div>
        <div className="ig-bio"><div className="skeleton skeleton-line" style={{ width: 180 }} /></div>
      </section>
    );
  }

  const isMe = profile.isMe;
  const biz = profile.business;
  const rawTab = params.get("tab");
  const tab: Tab = rawTab === "saved" || rawTab === "boards" ? "boards"
    : rawTab === "pins" || rawTab === "created" ? "pins"
      : rawTab === "products" && biz ? "products"
        : biz ? "products" : "pins";
  const setTab = (t: Tab) => router.replace(`/u/${profile.username}?tab=${t}`, { scroll: false });
  const ring = profile.hasStory ? (profile.storySeen ? "seen" : "unseen") : "none";

  const share = async () => {
    const msg = await shareUrl(`/u/${profile.username}`, profile.name);
    if (msg) toast(msg);
  };

  const contactHref = biz?.instagram
    ? `https://instagram.com/${biz.instagram.replace(/^@/, "")}`
    : biz?.phone ? `sms:${biz.phone.replace(/[^\d+]/g, "")}` : null;

  const tabs: { key: Tab; label: string; icon: React.ReactNode }[] = [
    ...(biz ? [{ key: "products" as Tab, label: "Harytlar", icon: <GridIcon size={16} /> }] : []),
    { key: "pins", label: "Pinler", icon: <MasonryIcon size={16} /> },
    { key: "boards", label: "Tagtalar", icon: <BoardsIcon size={16} /> },
  ];

  return (
    <>
      <section className={`ig ${biz ? "is-biz" : ""}`}>
        <div className="ig-avatar">
          <StoryAvatar
            user={profile}
            size={150}
            ring={ring}
            onClick={() => stories.openUser(profile.username)}
          />
          {isMe && (
            <button className="ig-add-story" onClick={() => setAddingStory(true)} aria-label="Story goş" title="Story goş">
              <PlusIcon size={16} />
            </button>
          )}
        </div>

        <div className="ig-top">
          <h1>
            {profile.name}
            {profile.verified && <VerifiedIcon size={20} />}
          </h1>
          <span className="ig-username">@{profile.username}</span>
          {isMe && (
            <Link href="/settings" className="icon-btn ig-gear" aria-label="Sazlamalar" title="Sazlamalar"><SettingsIcon size={22} /></Link>
          )}
        </div>

        <ul className="ig-counts">
          <li><strong>{compact(profile.pinsCount)}</strong> {biz ? "post" : "pin"}</li>
          <li><button onClick={() => setList("followers")}><strong>{compact(profile.followersCount)}</strong> yzarlaýjy</button></li>
          <li><button onClick={() => setList("following")}><strong>{compact(profile.followingCount)}</strong> yzarlanýan</button></li>
        </ul>

        <div className="ig-bio">
          {biz && (
            <div className="ig-cat">
              <StoreIcon size={14} /> {businessCategoryLabel(biz.category)}
              {biz.rating > 0 && (
                <span className="ig-rating"><Stars value={biz.rating} size={13} showValue count={biz.reviewsCount} /></span>
              )}
            </div>
          )}
          {profile.bio && <p className="bio">{profile.bio}</p>}
          {biz && (
            <ul className="biz-info">
              {(biz.city || biz.address) && (
                <li><PinMapIcon /> {biz.address && biz.city && biz.address.toLocaleLowerCase("tk").startsWith(biz.city.toLocaleLowerCase("tk")) ? biz.address : [biz.city, biz.address].filter(Boolean).join(", ")}</li>
              )}
              {biz.workingHours && <li><ClockIcon /> {biz.workingHours}</li>}
              {biz.phone && <li><PhoneIcon size={16} /> <a href={phoneHref(biz.phone)} className="text-link">{biz.phone}</a></li>}
              {biz.deliveryDays > 0 && <li><TruckIcon size={16} /> Eltip bermek: {days(biz.deliveryDays)}{biz.returnDays > 0 ? ` · Gaýtaryp bermek: ${days(biz.returnDays)}` : ""}</li>}
              {biz.ordersCount > 0 && <li><BagIcon size={16} /> {compact(biz.ordersCount)} sargyt ýerine ýetirildi</li>}
            </ul>
          )}
        </div>

        <div className="ig-actions">
          {isMe ? (
            <>
              <Link href="/settings" className="btn btn-secondary">Profili üýtget</Link>
              {biz ? (
                <Link href="/business" className="btn btn-secondary"><ChartIcon size={18} /> Biznes paneli</Link>
              ) : (
                <Link href="/orders" className="btn btn-secondary"><BagIcon size={18} /> Sargytlarym</Link>
              )}
              <button className="btn btn-secondary icon-only-sm" onClick={() => setAddingStory(true)} aria-label="Story goş"><CameraIcon size={18} /> <span className="hide-sm">Story</span></button>
              <button className="btn btn-secondary icon-only" onClick={share} aria-label="Paýlaş"><ShareIcon size={18} /></button>
            </>
          ) : (
            <>
              <FollowButton
                username={profile.username}
                isFollowing={profile.isFollowing}
                onChange={(on, p) =>
                  setProfile((cur) => p ?? (cur ? { ...cur, isFollowing: on, followersCount: cur.followersCount + (on === cur.isFollowing ? 0 : on ? 1 : -1) } : cur))}
              />
              {biz?.phone && <a href={phoneHref(biz.phone)} className="btn btn-secondary"><PhoneIcon size={16} /> Jaň et</a>}
              {contactHref && (
                <a href={contactHref} className="btn btn-secondary" target={biz?.instagram ? "_blank" : undefined} rel="noopener noreferrer">
                  <ChatIcon size={16} /> Habarlaş
                </a>
              )}
              <button className="btn btn-secondary icon-only" onClick={share} aria-label="Paýlaş"><ShareIcon size={18} /></button>
            </>
          )}
        </div>
      </section>

      <div className="ig-tabs" role="tablist">
        {tabs.map((t) => (
          <button key={t.key} role="tab" aria-selected={tab === t.key} className={tab === t.key ? "active" : ""} onClick={() => setTab(t.key)}>
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {tab === "products" ? (
        <Products username={profile.username} viewer={viewer} isMe={isMe} />
      ) : tab === "pins" ? (
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
      {addingStory && (
        <AddStoryModal
          onClose={() => setAddingStory(false)}
          onCreated={() => {
            setAddingStory(false);
            stories.bump();
          }}
        />
      )}
    </>
  );
}

export default function ProfilePage() {
  return (
    <div className="page profile-page">
      <Suspense fallback={null}>
        <ProfileView />
      </Suspense>
    </div>
  );
}
