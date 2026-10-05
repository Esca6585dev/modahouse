"use client";

import { useState } from "react";
import { authors, currentUser, sampleComments } from "@/lib/data";
import Avatar from "./Avatar";
import { HeartIcon } from "./Icons";

export default function Comments() {
  const [list, setList] = useState(sampleComments);
  const [text, setText] = useState("");
  const [liked, setLiked] = useState(false);

  return (
    <section className="comments">
      <div className="comments-head">
        <h3>{list.length} teswir</h3>
        <button className={`like ${liked ? "on" : ""}`} onClick={() => setLiked((l) => !l)} aria-pressed={liked}>
          <HeartIcon /> {liked ? 129 : 128}
        </button>
      </div>
      <ul>
        {list.map((c, i) => (
          <li key={i} className="comment">
            <Avatar author={authors[c.author]} size={28} />
            <p><strong>{authors[c.author].name}</strong> {c.text}</p>
          </li>
        ))}
      </ul>
      <form
        className="comment-form"
        onSubmit={(e) => {
          e.preventDefault();
          if (!text.trim()) return;
          setList((l) => [...l, { author: currentUser.handle, text: text.trim() }]);
          setText("");
        }}
      >
        <Avatar author={currentUser} size={32} />
        <input value={text} onChange={(e) => setText(e.target.value)} placeholder="Teswir goş…" aria-label="Teswir" />
        <button className="btn btn-primary" disabled={!text.trim()}>Iber</button>
      </form>
    </section>
  );
}
