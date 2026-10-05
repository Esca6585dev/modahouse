import Link from "next/link";

export default function NotFound() {
  return (
    <div className="page">
      <div className="empty">
        <h2>Sahypa tapylmady</h2>
        <p>Gözleýän sahypaňyz ýok ýa-da göçürilen.</p>
        <Link href="/" className="btn btn-primary">Baş sahypa gaýt</Link>
      </div>
    </div>
  );
}
