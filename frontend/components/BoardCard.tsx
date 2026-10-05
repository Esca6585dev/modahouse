import Link from "next/link";
import type { Board } from "@/lib/types";
import { LockIcon } from "./Icons";

export default function BoardCard({ board }: { board: Board }) {
  return (
    <Link href={`/board/${board.id}`} className="board">
      <div className="board-collage">
        {[0, 1, 2].map((i) => (
          <div key={i} className={`bc bc-${i}`}>
            {board.covers[i] && (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={board.covers[i]} alt="" loading="lazy" />
            )}
          </div>
        ))}
        {board.isPrivate && <span className="board-lock" title="Gizlin tagta" aria-label="Gizlin tagta"><LockIcon size={14} /></span>}
      </div>
      <strong>{board.name}</strong>
      <span>{board.pinsCount} pin</span>
    </Link>
  );
}
