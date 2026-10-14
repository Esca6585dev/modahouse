import { StarIcon } from "./Icons";

/** 0..5 star rating with partial fill. */
export default function Stars({ value, size = 14, count, showValue }: { value: number; size?: number; count?: number; showValue?: boolean }) {
  const pct = Math.max(0, Math.min(100, (value / 5) * 100));
  const label = value > 0 ? `${value.toFixed(1)} / 5` : "Baha ýok";
  return (
    <span className="stars" aria-label={label} title={label}>
      <span className="stars-track" aria-hidden>
        {[0, 1, 2, 3, 4].map((i) => <StarIcon key={i} size={size} />)}
        <span className="stars-fill" style={{ width: `${pct}%` }}>
          {[0, 1, 2, 3, 4].map((i) => <StarIcon key={i} size={size} />)}
        </span>
      </span>
      {showValue && value > 0 && <strong className="stars-value">{value.toFixed(1)}</strong>}
      {count !== undefined && <span className="stars-count">({count})</span>}
    </span>
  );
}

/** Clickable 1..5 input. */
export function StarInput({ value, onChange }: { value: number; onChange: (n: number) => void }) {
  return (
    <span className="star-input" role="radiogroup" aria-label="Baha">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          role="radio"
          aria-checked={value === n}
          aria-label={`${n} ýyldyz`}
          className={n <= value ? "on" : ""}
          onClick={() => onChange(n)}
        >
          <StarIcon size={28} filled={n <= value} />
        </button>
      ))}
    </span>
  );
}
