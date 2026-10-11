"use client";

import Link from "next/link";
import { Fragment, useState } from "react";

const TOKEN = /([#@][\p{L}\p{N}_.]*[\p{L}\p{N}_])/gu;

/** Text with #hashtags → /tag/… and @mentions → /u/… links; keeps line breaks. */
export function RichText({ text }: { text: string }) {
  const parts = text.split(TOKEN);
  return (
    <>
      {parts.map((p, i) => {
        if (i % 2 === 1) {
          const body = p.slice(1);
          if (p[0] === "#") return <Link key={i} href={`/tag/${encodeURIComponent(body.toLocaleLowerCase("tk"))}`} className="hashtag">{p}</Link>;
          return <Link key={i} href={`/u/${encodeURIComponent(body.toLowerCase())}`} className="mention">{p}</Link>;
        }
        return <Fragment key={i}>{p}</Fragment>;
      })}
    </>
  );
}

/** Instagram caption: bold name, text clamped to ~2 lines with "… köpräk". */
export default function Caption({ name, href, text, limit = 110 }: { name: string; href: string; text: string; limit?: number }) {
  const [open, setOpen] = useState(false);
  const firstBreak = text.indexOf("\n");
  const long = text.length > limit || (firstBreak !== -1 && firstBreak < text.length - 1 && text.split("\n").length > 2);
  let shown = text;
  if (long && !open) {
    const cut = Math.min(limit, firstBreak === -1 ? limit : Math.max(firstBreak, 40));
    shown = text.slice(0, cut).replace(/\s+\S*$/, "");
  }
  return (
    <p className="caption">
      <Link href={href} className="caption-name">{name}</Link>{" "}
      <RichText text={shown} />
      {long && !open && (
        <>
          {"… "}
          <button type="button" className="more-btn" onClick={() => setOpen(true)}>köpräk</button>
        </>
      )}
    </p>
  );
}
