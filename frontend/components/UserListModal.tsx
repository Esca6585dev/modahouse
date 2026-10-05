"use client";

import Link from "next/link";
import { api } from "@/lib/api";
import { usePaged } from "@/lib/hooks";
import Avatar from "./Avatar";
import { InfiniteFooter } from "./Masonry";
import Modal from "./Modal";

export default function UserListModal({
  username, kind, onClose,
}: { username: string; kind: "followers" | "following"; onClose: () => void }) {
  const paged = usePaged(`${kind}:${username}`, (page) =>
    kind === "followers" ? api.followers(username, page) : api.following(username, page));

  return (
    <Modal title={kind === "followers" ? "Yzarlaýjylar" : "Yzarlanýanlar"} onClose={onClose}>
      {!paged.loaded ? (
        <ul className="user-list">
          {[0, 1, 2].map((i) => <li key={i}><div className="skeleton" style={{ height: 48, width: "100%" }} /></li>)}
        </ul>
      ) : paged.items.length === 0 && !paged.error ? (
        <p className="muted center">{kind === "followers" ? "Entek yzarlaýjy ýok" : "Entek hiç kimi yzarlamaýar"}</p>
      ) : (
        <ul className="user-list">
          {paged.items.map((u) => (
            <li key={u.id}>
              <Link href={`/u/${u.username}`} className="user-row" onClick={onClose}>
                <Avatar user={u} size={44} />
                <span>
                  <strong>{u.name}</strong>
                  <span className="muted">@{u.username}</span>
                </span>
              </Link>
            </li>
          ))}
        </ul>
      )}
      <InfiniteFooter paged={paged} />
    </Modal>
  );
}
