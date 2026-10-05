import Link from "next/link";
import Masonry from "@/components/Masonry";
import { categories, pins } from "@/lib/data";

type Search = { q?: string; c?: string };

export default async function Home({ searchParams }: { searchParams: Promise<Search> }) {
  const { q = "", c = "" } = await searchParams;
  const query = q.trim().toLocaleLowerCase("tk");

  const list = pins.filter((p) => {
    if (c && p.category !== c) return false;
    if (!query) return true;
    return [p.title, p.description, p.category].some((t) => t.toLocaleLowerCase("tk").includes(query));
  });

  return (
    <div className="page">
      <div className="chips" role="list">
        <Link href="/" className={`chip ${!c ? "active" : ""}`} role="listitem">Hemmesi</Link>
        {categories.map((cat) => (
          <Link
            key={cat}
            href={`/?c=${encodeURIComponent(cat)}`}
            className={`chip ${c === cat ? "active" : ""}`}
            role="listitem"
          >
            {cat}
          </Link>
        ))}
      </div>

      {q && (
        <p className="result-note">
          “{q}” boýunça {list.length} netije
        </p>
      )}

      {list.length ? (
        <Masonry pins={list} />
      ) : (
        <div className="empty">
          <h2>Hiç zat tapylmady</h2>
          <p>Başga söz bilen gözläp görüň ýa-da kategoriýany üýtgediň.</p>
          <Link href="/" className="btn btn-primary">Ähli pinlere gaýt</Link>
        </div>
      )}
    </div>
  );
}
