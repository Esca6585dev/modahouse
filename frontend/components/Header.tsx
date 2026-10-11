"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { useAuth } from "@/lib/auth";
import { useCart } from "@/lib/cart";
import Avatar from "./Avatar";
import {
  BagIcon, BellIcon, CartIcon, ChartIcon, ChevronDownIcon, HeartIcon, HomeIcon, LogoutIcon, PlusIcon, ReelsIcon, SearchIcon,
  SettingsIcon, StoreIcon, TrophyIcon, UserIcon,
} from "./Icons";
import { LogoWordmark } from "./Logo";
import SearchBar from "./SearchBar";

function UserMenu() {
  const { user, logout } = useAuth();
  const router = useRouter();
  const path = usePathname();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => setOpen(false), [path]);
  useEffect(() => {
    if (!open) return;
    const onDown = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false);
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  if (!user) return null;
  const mine = path === `/u/${user.username}`;
  return (
    <div className="menu-wrap" ref={ref}>
      <button
        className={`icon-btn avatar-btn ${mine ? "ring" : ""}`}
        onClick={() => setOpen((o) => !o)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label="Hasap menýusy"
      >
        <Avatar user={user} size={32} />
        <span className="menu-caret"><ChevronDownIcon size={14} /></span>
      </button>
      {open && (
        <div className="menu" role="menu">
          <Link href={`/u/${user.username}`} className="menu-user" role="menuitem">
            <Avatar user={user} size={48} />
            <div>
              <strong>{user.name}</strong>
              <span>{user.isBusiness ? "Biznes hasaby" : "Şahsy hasap"} · @{user.username}</span>
            </div>
          </Link>
          <Link role="menuitem" href={`/u/${user.username}`} className="menu-item"><UserIcon size={18} /> Profil</Link>
          <Link role="menuitem" href={`/u/${user.username}?tab=liked`} className="menu-item"><HeartIcon size={18} /> Halanlarym</Link>
          <Link role="menuitem" href="/orders" className="menu-item"><BagIcon size={18} /> Sargytlarym</Link>
          {user.isBusiness ? (
            <Link role="menuitem" href="/business" className="menu-item"><ChartIcon size={18} /> Biznes paneli</Link>
          ) : (
            <Link role="menuitem" href="/settings#business" className="menu-item"><StoreIcon size={18} /> Biznes hasabyny aç</Link>
          )}
          <Link role="menuitem" href="/settings" className="menu-item"><SettingsIcon size={18} /> Sazlamalar</Link>
          <div className="menu-sep" />
          <button
            role="menuitem"
            className="menu-item"
            onClick={() => {
              logout();
              setOpen(false);
              router.push("/");
            }}
          >
            <LogoutIcon size={18} /> Çykyş
          </button>
        </div>
      )}
    </div>
  );
}

function CartLink({ path }: { path: string }) {
  const { count } = useCart();
  return (
    <Link href="/cart" className={`icon-btn ${path === "/cart" ? "current" : ""}`} aria-label={count ? `Sebet, ${count} haryt` : "Sebet"}>
      <CartIcon />
      {count > 0 && <span className="badge">{count > 99 ? "99+" : count}</span>}
    </Link>
  );
}

export default function Header() {
  const path = usePathname();
  const { user, ready, unread } = useAuth();
  const nav = [
    { href: "/", label: "Baş sahypa" },
    { href: "/reels", label: "Reels" },
    { href: "/top", label: "Top 10" },
    { href: "/shops", label: "Dükanlar" },
    { href: "/create", label: "Döret" },
  ];
  const isActive = (href: string) => (href === "/" ? path === "/" : path.startsWith(href));
  const loginHref = `/login${path !== "/login" && path !== "/register" ? `?next=${encodeURIComponent(path)}` : ""}`;

  return (
    <header className="header">
      <div className="header-inner">
        <Link href="/" className="logo" aria-label="ModaHouse baş sahypa">
          <LogoWordmark height={42} />
        </Link>
        <nav className="nav" aria-label="Esasy menýu">
          {nav.map((n) => (
            <Link key={n.href} href={n.href} className={`nav-link ${isActive(n.href) ? "active" : ""}`}>
              {n.label}
            </Link>
          ))}
        </nav>
        <Suspense fallback={<div className="search" />}>
          <SearchBar />
        </Suspense>
        <div className="header-actions">
          {!ready ? (
            <span className="header-placeholder" />
          ) : user ? (
            <>
              <Link
                href="/notifications"
                className={`icon-btn ${path === "/notifications" ? "current" : ""}`}
                aria-label={unread ? `Habarnamalar, ${unread} täze` : "Habarnamalar"}
              >
                <BellIcon />
                {unread > 0 && <span className="badge">{unread > 99 ? "99+" : unread}</span>}
              </Link>
              <Link href="/top" className={`icon-btn show-sm ${path === "/top" ? "current" : ""}`} aria-label="Top 10"><TrophyIcon size={22} /></Link>
              <CartLink path={path} />
              <span className="hide-sm"><UserMenu /></span>
            </>
          ) : (
            <>
              <Link href="/top" className={`icon-btn show-sm ${path === "/top" ? "current" : ""}`} aria-label="Top 10"><TrophyIcon size={22} /></Link>
              <Link href={loginHref} className="btn btn-secondary btn-sm">Giriş</Link>
              <Link href="/register" className="btn btn-primary btn-sm hide-sm">Hasaba al</Link>
            </>
          )}
        </div>
      </div>
    </header>
  );
}

/** Mobile bottom navigation (hidden on desktop by CSS). */
export function BottomNav() {
  const path = usePathname();
  const { user } = useAuth();
  if (path === "/login" || path === "/register") return null;
  const profileHref = user ? `/u/${user.username}` : "/login?next=%2Fprofile";
  const items = [
    { href: "/", label: "Baş sahypa", icon: <HomeIcon size={24} />, active: path === "/" },
    { href: "/search", label: "Gözleg", icon: <SearchIcon size={24} />, active: path === "/search" || path === "/shops" || path === "/visual" || path.startsWith("/tag/") },
    { href: "/create", label: "Döret", icon: <PlusIcon size={24} />, active: path === "/create", create: true },
    { href: "/reels", label: "Reels", icon: <ReelsIcon size={24} />, active: path === "/reels" },
    {
      href: profileHref,
      label: "Profil",
      icon: user ? <Avatar user={user} size={26} /> : <UserIcon size={24} />,
      active: !!user && (path === `/u/${user.username}` || path === "/settings" || path.startsWith("/orders") || path === "/business"),
    },
  ];
  return (
    <nav className="bottom-nav" aria-label="Aşaky menýu">
      {items.map((it) => (
        <Link key={it.label} href={it.href} className={`bn-item ${it.active ? "active" : ""} ${it.create ? "bn-create" : ""}`} aria-label={it.label}>
          <span className="bn-icon">{it.icon}</span>
          <span className="bn-label">{it.label}</span>
        </Link>
      ))}
    </nav>
  );
}
