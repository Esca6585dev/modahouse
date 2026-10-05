"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { Suspense, useEffect, useRef, useState } from "react";
import { useAuth } from "@/lib/auth";
import Avatar from "./Avatar";
import SearchBar from "./SearchBar";
import { BellIcon, ChevronDownIcon, HomeIcon, PlusIcon } from "./Icons";

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
        <Avatar user={user} size={30} />
        <span className="menu-caret hide-sm"><ChevronDownIcon size={14} /></span>
      </button>
      {open && (
        <div className="menu" role="menu">
          <div className="menu-user">
            <Avatar user={user} size={44} />
            <div>
              <strong>{user.name}</strong>
              <span>@{user.username}</span>
            </div>
          </div>
          <Link role="menuitem" href={`/u/${user.username}`} className="menu-item">Profil</Link>
          <Link role="menuitem" href="/settings" className="menu-item">Sazlamalar</Link>
          <button
            role="menuitem"
            className="menu-item"
            onClick={() => {
              logout();
              setOpen(false);
              router.push("/");
            }}
          >
            Çykyş
          </button>
        </div>
      )}
    </div>
  );
}

export default function Header() {
  const path = usePathname();
  const { user, ready, unread } = useAuth();
  const nav = [
    { href: "/", label: "Baş sahypa", icon: <HomeIcon size={20} /> },
    { href: "/create", label: "Döret", icon: <PlusIcon size={20} /> },
  ];

  return (
    <header className="header">
      <Link href="/" className="logo" aria-label="ModaHouse baş sahypa">
        <span className="logo-mark">M</span>
        <span className="logo-text">ModaHouse</span>
      </Link>
      <nav className="nav">
        {nav.map((n) => (
          <Link key={n.href} href={n.href} className={`nav-link ${path === n.href ? "active" : ""}`} aria-label={n.label}>
            <span className="nav-icon">{n.icon}</span>
            <span className="nav-label">{n.label}</span>
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
            <UserMenu />
          </>
        ) : (
          <>
            <Link href={`/login${path !== "/login" && path !== "/register" ? `?next=${encodeURIComponent(path)}` : ""}`} className="btn btn-secondary btn-sm">Giriş</Link>
            <Link href="/register" className="btn btn-primary btn-sm hide-sm">Hasaba al</Link>
          </>
        )}
      </div>
    </header>
  );
}
