"use client";

import { useState } from "react";
import type { ColorOption, ProductListingType } from "@/lib/types";
import { CloseIcon, PlusIcon } from "./Icons";

export type ProductValues = {
  price: string;
  oldPrice: string;
  stock: string;
  deliveryDays: string;
  returnDays: string;
  material: string;
  colors: ColorOption[];
  sizes: string[];
  deposit: string;
  minDays: string;
  readyDays: string;
};

export const emptyProduct = (deliveryDays = 3, returnDays = 14): ProductValues => ({
  price: "", oldPrice: "", stock: "", deliveryDays: String(deliveryDays), returnDays: String(returnDays),
  material: "", colors: [], sizes: [], deposit: "", minDays: "", readyDays: "",
});

const PRESET_COLORS: ColorOption[] = [
  { name: "Gyzyl", hex: "#C62828" },
  { name: "Gara", hex: "#111111" },
  { name: "Ak", hex: "#FFFFFF" },
  { name: "Gülgüne", hex: "#E8A0B4" },
  { name: "Gök", hex: "#1E5AA8" },
  { name: "Ýaşyl", hex: "#1B6E4A" },
  { name: "Bež", hex: "#E8D8C0" },
  { name: "Şerap", hex: "#7A1F2B" },
];

const PRESET_SIZES = ["XS", "S", "M", "L", "XL", "40", "42", "44", "46", "48", "50"];

const int = (s: string) => Math.round(Number(s));

/** Client checks mirroring the server rules; returns a Turkmen message or null. */
export function validateProduct(v: ProductValues, type: ProductListingType = "sale"): string | null {
  const price = int(v.price);
  if (!v.price.trim() || !(price > 0)) return type === "rent" ? "Günlük bahany ýazyň (0-dan uly)" : "Bahany ýazyň (0-dan uly)";
  if (type === "sale" && v.oldPrice.trim() && int(v.oldPrice) > 0 && int(v.oldPrice) <= price) return "Köne baha häzirki bahadan uly bolmaly";
  for (const [k, label] of [["deposit", "Girew"], ["minDays", "Iň az gün"], ["readyDays", "Taýýar bolýan gün"]] as const) {
    if (v[k].trim() && !(int(v[k]) >= 0)) return `${label} san bolmaly`;
  }
  if (v.stock.trim() && !(int(v.stock) >= 0)) return "Galyndy san bolmaly";
  return null;
}

/** Multipart fields for POST /pins. */
export function appendProduct(form: FormData, v: ProductValues, type: ProductListingType = "sale") {
  form.append("listingType", type);
  form.append("price", String(int(v.price)));
  if (type === "rent") {
    if (v.deposit.trim()) form.append("deposit", String(int(v.deposit) || 0));
    if (v.minDays.trim()) form.append("minDays", String(int(v.minDays) || 0));
    if (v.colors.length) form.append("colors", JSON.stringify(v.colors));
    if (v.sizes.length) form.append("sizes", v.sizes.join(","));
    if (v.material.trim()) form.append("material", v.material.trim());
    return;
  }
  if (type === "custom") {
    if (v.readyDays.trim()) form.append("readyDays", String(int(v.readyDays) || 0));
    if (v.material.trim()) form.append("material", v.material.trim());
    if (v.colors.length) form.append("colors", JSON.stringify(v.colors));
    if (v.sizes.length) form.append("sizes", v.sizes.join(","));
    return;
  }
  if (v.oldPrice.trim()) form.append("oldPrice", String(int(v.oldPrice) || 0));
  if (v.stock.trim()) form.append("stock", String(int(v.stock)));
  if (v.deliveryDays.trim()) form.append("deliveryDays", String(int(v.deliveryDays) || 0));
  if (v.returnDays.trim()) form.append("returnDays", String(int(v.returnDays) || 0));
  if (v.material.trim()) form.append("material", v.material.trim());
  if (v.colors.length) form.append("colors", JSON.stringify(v.colors));
  if (v.sizes.length) form.append("sizes", v.sizes.join(","));
}

/** JSON body for PUT /pins/:id. */
export function productBody(v: ProductValues, type: ProductListingType = "sale") {
  return {
    listingType: type,
    deposit: type === "rent" ? int(v.deposit) || 0 : 0,
    minDays: type === "rent" ? int(v.minDays) || 0 : 0,
    readyDays: type === "custom" ? int(v.readyDays) || 0 : 0,
    price: int(v.price),
    oldPrice: type === "sale" && v.oldPrice.trim() ? int(v.oldPrice) || 0 : 0,
    stock: v.stock.trim() ? int(v.stock) : null,
    deliveryDays: int(v.deliveryDays) || 0,
    returnDays: int(v.returnDays) || 0,
    material: v.material.trim(),
    colors: v.colors,
    sizes: v.sizes,
  };
}

export default function ProductFields({
  value, onChange, type = "sale",
}: { value: ProductValues; onChange: (v: ProductValues) => void; type?: ProductListingType }) {
  const [colorName, setColorName] = useState("");
  const [colorHex, setColorHex] = useState("#D7263D");
  const [size, setSize] = useState("");
  const set = (k: keyof ProductValues) => (e: React.ChangeEvent<HTMLInputElement>) => onChange({ ...value, [k]: e.target.value });

  const addColor = (c: ColorOption) => {
    const name = c.name.trim();
    if (!name || value.colors.some((x) => x.name.toLowerCase() === name.toLowerCase()) || value.colors.length >= 12) return;
    onChange({ ...value, colors: [...value.colors, { name, hex: c.hex.toUpperCase() }] });
  };
  const addSize = (s: string) => {
    const parts = s.split(",").map((x) => x.trim()).filter(Boolean);
    const next = [...value.sizes];
    for (const p of parts) if (!next.includes(p) && next.length < 30) next.push(p);
    onChange({ ...value, sizes: next });
  };

  return (
    <fieldset className="product-fields">
      <legend>{type === "rent" ? "Kärende maglumatlary" : type === "custom" ? "Tikin sargydy" : "Haryt maglumatlary"}</legend>
      {type === "sale" && (
        <div className="form-row">
          <label>
            <span>Baha, TMT <span className="req">*</span></span>
            <input type="number" min={1} inputMode="numeric" value={value.price} onChange={set("price")} placeholder="450" />
          </label>
          <label>
            Köne baha, TMT
            <input type="number" min={0} inputMode="numeric" value={value.oldPrice} onChange={set("oldPrice")} placeholder="Arzanladyş üçin" />
            <small className="hint">Doldurylsa «Aksiýa» bellik goşulýar</small>
          </label>
        </div>
      )}
      {type === "rent" && (
        <>
          <div className="form-row">
            <label>
              <span>Günlük baha, TMT <span className="req">*</span></span>
              <input type="number" min={1} inputMode="numeric" value={value.price} onChange={set("price")} placeholder="250" />
            </label>
            <label>
              Girew, TMT
              <input type="number" min={0} inputMode="numeric" value={value.deposit} onChange={set("deposit")} placeholder="500" />
              <small className="hint">Boş = girewsiz</small>
            </label>
          </div>
          <label>
            Iň az möhlet (gün)
            <input type="number" min={0} inputMode="numeric" value={value.minDays} onChange={set("minDays")} placeholder="1" />
          </label>
        </>
      )}
      {type === "custom" && (
        <div className="form-row">
          <label>
            <span>Baha «…-dan başlap», TMT <span className="req">*</span></span>
            <input type="number" min={1} inputMode="numeric" value={value.price} onChange={set("price")} placeholder="600" />
          </label>
          <label>
            Taýýar bolýar (gün)
            <input type="number" min={0} inputMode="numeric" value={value.readyDays} onChange={set("readyDays")} placeholder="10" />
          </label>
        </div>
      )}

      <div className="opt-edit">
        <span className="opt-label">Reňkler</span>
        {value.colors.length > 0 && (
          <div className="chip-list">
            {value.colors.map((c) => (
              <span key={c.name} className="edit-chip">
                <span className="dot" style={{ background: c.hex }} /> {c.name}
                <button type="button" onClick={() => onChange({ ...value, colors: value.colors.filter((x) => x.name !== c.name) })} aria-label={`${c.name} aýyr`}>
                  <CloseIcon size={14} />
                </button>
              </span>
            ))}
          </div>
        )}
        <div className="color-add">
          <input type="color" value={colorHex} onChange={(e) => setColorHex(e.target.value)} aria-label="Reňk saýla" />
          <input
            value={colorName}
            onChange={(e) => setColorName(e.target.value)}
            maxLength={30}
            placeholder="Reňkiň ady, mysal: Gyzyl"
            aria-label="Reňkiň ady"
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addColor({ name: colorName, hex: colorHex });
                setColorName("");
              }
            }}
          />
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => { addColor({ name: colorName, hex: colorHex }); setColorName(""); }} disabled={!colorName.trim()}>
            <PlusIcon size={16} /> Goş
          </button>
        </div>
        <div className="preset-row">
          {PRESET_COLORS.filter((p) => !value.colors.some((c) => c.name === p.name)).map((p) => (
            <button key={p.name} type="button" className="preset-color" onClick={() => addColor(p)} title={p.name}>
              <span className="dot" style={{ background: p.hex }} /> {p.name}
            </button>
          ))}
        </div>
      </div>

      <div className="opt-edit">
        <span className="opt-label">Ölçegler</span>
        {value.sizes.length > 0 && (
          <div className="chip-list">
            {value.sizes.map((s) => (
              <span key={s} className="edit-chip">
                {s}
                <button type="button" onClick={() => onChange({ ...value, sizes: value.sizes.filter((x) => x !== s) })} aria-label={`${s} aýyr`}>
                  <CloseIcon size={14} />
                </button>
              </span>
            ))}
          </div>
        )}
        <div className="color-add">
          <input
            value={size}
            onChange={(e) => setSize(e.target.value)}
            maxLength={40}
            placeholder="Mysal: 42 ýa-da 42, 44, 46"
            aria-label="Ölçeg"
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                addSize(size);
                setSize("");
              }
            }}
          />
          <button type="button" className="btn btn-secondary btn-sm" onClick={() => { addSize(size); setSize(""); }} disabled={!size.trim()}>
            <PlusIcon size={16} /> Goş
          </button>
        </div>
        <div className="preset-row">
          {PRESET_SIZES.filter((s) => !value.sizes.includes(s)).map((s) => (
            <button key={s} type="button" className="preset-size" onClick={() => addSize(s)}>{s}</button>
          ))}
        </div>
      </div>

      {type === "sale" ? (
        <div className="form-row">
          <label>
            Galyndy (sany)
            <input type="number" min={0} inputMode="numeric" value={value.stock} onChange={set("stock")} placeholder="Boş = hasaba alynmaýar" />
          </label>
          <label>
            Material
            <input value={value.material} onChange={set("material")} maxLength={100} placeholder="Mysal: Atlas, ýüpek" />
          </label>
        </div>
      ) : (
        <label>
          {type === "custom" ? "Mata görnüşleri" : "Material"}
          <input value={value.material} onChange={set("material")} maxLength={100} placeholder={type === "custom" ? "Mysal: atlas, barhat, kešde ýüpegi" : "Mysal: Atlas, ýüpek"} />
        </label>
      )}
      {type === "sale" && <div className="form-row">
        <label>
          Eltip bermek (gün)
          <input type="number" min={0} inputMode="numeric" value={value.deliveryDays} onChange={set("deliveryDays")} />
        </label>
        <label>
          Gaýtaryp bermek (gün)
          <input type="number" min={0} inputMode="numeric" value={value.returnDays} onChange={set("returnDays")} />
        </label>
      </div>}
    </fieldset>
  );
}
