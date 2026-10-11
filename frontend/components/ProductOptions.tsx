"use client";

import type { ColorOption } from "@/lib/types";
import { CheckIcon, MinusIcon, PlusIcon } from "./Icons";

/** Perceived brightness, so the check mark on a swatch stays visible. */
function isLight(hex: string): boolean {
  const m = /^#?([0-9a-f]{6})$/i.exec(hex.trim());
  if (!m) return true;
  const n = parseInt(m[1], 16);
  const r = (n >> 16) & 255, g = (n >> 8) & 255, b = n & 255;
  return 0.299 * r + 0.587 * g + 0.114 * b > 170;
}

export function ColorSwatches({ colors, value, onChange }: { colors: ColorOption[]; value: string; onChange: (name: string) => void }) {
  if (!colors.length) return null;
  return (
    <div className="opt-block">
      <div className="opt-label">Reňki{value && <span>: {value}</span>}</div>
      <div className="swatches" role="radiogroup" aria-label="Reňk">
        {colors.map((c) => (
          <button
            key={c.name}
            type="button"
            role="radio"
            aria-checked={value === c.name}
            aria-label={c.name}
            title={c.name}
            className={`swatch ${value === c.name ? "on" : ""}`}
            onClick={() => onChange(c.name)}
          >
            <span style={{ background: c.hex, color: isLight(c.hex) ? "#111" : "#fff" }}>
              {value === c.name && <CheckIcon size={16} />}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

export function SizeButtons({ sizes, value, onChange }: { sizes: string[]; value: string; onChange: (s: string) => void }) {
  if (!sizes.length) return null;
  return (
    <div className="opt-block">
      <div className="opt-label">Ölçegi{value && <span>: {value}</span>}</div>
      <div className="sizes" role="radiogroup" aria-label="Ölçeg">
        {sizes.map((s) => (
          <button
            key={s}
            type="button"
            role="radio"
            aria-checked={value === s}
            className={`size-btn ${value === s ? "on" : ""}`}
            onClick={() => onChange(s)}
          >
            {s}
          </button>
        ))}
      </div>
    </div>
  );
}

export function QtyStepper({ value, onChange, max = 99, small }: { value: number; onChange: (n: number) => void; max?: number; small?: boolean }) {
  const top = Math.max(1, Math.min(99, max));
  return (
    <div className={`qty ${small ? "small" : ""}`} role="group" aria-label="Sany">
      <button type="button" onClick={() => onChange(Math.max(1, value - 1))} disabled={value <= 1} aria-label="Azalt"><MinusIcon size={16} /></button>
      <span aria-live="polite">{value}</span>
      <button type="button" onClick={() => onChange(Math.min(top, value + 1))} disabled={value >= top} aria-label="Köpelt"><PlusIcon size={16} /></button>
    </div>
  );
}

/** Returns a Turkmen error when a required option is missing. */
export function optionsError(p: { colors: ColorOption[]; sizes: string[] }, color: string, size: string): string | null {
  if (p.colors.length && !color) return "Reňk saýlaň";
  if (p.sizes.length && !size) return "Ölçeg saýlaň";
  return null;
}
