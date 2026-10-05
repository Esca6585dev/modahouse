"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Suspense } from "react";
import { currentUser } from "@/lib/data";
import Avatar from "./Avatar";
import SearchBar from "./SearchBar";
import { BellIcon, ChatIcon, HomeIcon, PlusIcon } from "./Icons";

export default function Header() {
  const path = usePathname();
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
          <Link key={n.href} href={n.href} className={`nav-link ${path === n.href ? "active" : ""}`}>
            <span className="nav-icon">{n.icon}</span>
            <span className="nav-label">{n.label}</span>
          </Link>
        ))}
      </nav>
      <Suspense fallback={<div className="search" />}>
        <SearchBar />
      </Suspense>
      <div className="header-actions">
        <button className="icon-btn hide-sm" aria-label="Habarnamalar">
          <BellIcon />
          <span className="dot" />
        </button>
        <button className="icon-btn hide-sm" aria-label="Hatlar">
          <ChatIcon />
        </button>
        <Link href="/profile" className={`icon-btn ${path === "/profile" ? "ring" : ""}`} aria-label="Profil">
          <Avatar author={currentUser} size={30} />
        </Link>
      </div>
    </header>
  );
}
