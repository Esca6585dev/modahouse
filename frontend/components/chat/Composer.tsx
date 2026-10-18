"use client";

import { useEffect, useImperativeHandle, useLayoutEffect, useRef, useState } from "react";
import { CloseIcon, PlusIcon, SendIcon } from "@/components/Icons";
import { useToast } from "@/components/Toast";
import { CHAT_ACCEPT, checkChatFile, fileExt, fileSize, isImageFile } from "@/lib/chat";
import { priceLabel } from "@/lib/format";
import type { PinPreview } from "@/lib/types";

export type Draft = { text: string; files: File[]; pin: PinPreview | null };
export type ComposerHandle = { addFiles: (files: FileList | File[]) => void; focus: () => void };

type Chip = { id: string; file: File; url: string };

const MAX_FILES = 10;
const MAX_TEXT = 2000;
let seq = 0;

/**
 * Message box: auto-growing textarea (Enter sends, Shift+Enter breaks the line; on touch screens
 * Enter breaks the line), attachments by button, paste or drop, and preview chips before sending.
 */
export default function Composer({
  ref, onSend, onTyping, initialText = "", initialPin = null, disabled,
}: {
  ref?: React.Ref<ComposerHandle>;
  onSend: (d: Draft) => void;
  onTyping: () => void;
  initialText?: string;
  initialPin?: PinPreview | null;
  disabled?: boolean;
}) {
  const toast = useToast();
  const [text, setText] = useState(initialText);
  const [chips, setChips] = useState<Chip[]>([]);
  const [pin, setPin] = useState<PinPreview | null>(initialPin);
  const area = useRef<HTMLTextAreaElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const chipsRef = useRef(chips);
  chipsRef.current = chips;

  useEffect(() => setPin(initialPin), [initialPin]);
  useEffect(() => { if (initialText) setText(initialText); }, [initialText]);
  useEffect(() => () => chipsRef.current.forEach((c) => c.url && URL.revokeObjectURL(c.url)), []);

  // Grow with the text up to ~6 lines.
  useLayoutEffect(() => {
    const el = area.current;
    if (!el) return;
    el.style.height = "0px";
    el.style.height = `${Math.min(el.scrollHeight, 148)}px`;
  }, [text]);

  const addFiles = (list: FileList | File[]) => {
    const errors: string[] = [];
    const next: Chip[] = [];
    for (const f of Array.from(list)) {
      const err = checkChatFile(f);
      if (err) { errors.push(err); continue; }
      next.push({ id: `a${++seq}`, file: f, url: isImageFile(f) ? URL.createObjectURL(f) : "" });
    }
    const room = MAX_FILES - chipsRef.current.length;
    if (next.length > room) {
      next.splice(room).forEach((c) => c.url && URL.revokeObjectURL(c.url));
      errors.push(`Bir gezekde iň köp ${MAX_FILES} faýl`);
    }
    if (next.length) setChips((l) => [...l, ...next]);
    if (errors.length) toast(errors[0] + (errors.length > 1 ? ` (+${errors.length - 1})` : ""), "error");
    area.current?.focus();
  };

  useImperativeHandle(ref, () => ({ addFiles, focus: () => area.current?.focus() }));

  const removeChip = (id: string) => setChips((l) => {
    const c = l.find((x) => x.id === id);
    if (c?.url) URL.revokeObjectURL(c.url);
    return l.filter((x) => x.id !== id);
  });

  const canSend = !disabled && (text.trim().length > 0 || chips.length > 0 || !!pin);

  const submit = () => {
    if (!canSend) return;
    onSend({ text: text.trim().slice(0, MAX_TEXT), files: chips.map((c) => c.file), pin });
    chips.forEach((c) => c.url && URL.revokeObjectURL(c.url));
    setChips([]);
    setPin(null);
    setText("");
    area.current?.focus();
  };

  const onKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key !== "Enter" || e.shiftKey || e.nativeEvent.isComposing) return;
    if (window.matchMedia("(pointer: coarse)").matches) return;
    e.preventDefault();
    submit();
  };

  const onPaste = (e: React.ClipboardEvent) => {
    const files = Array.from(e.clipboardData.files ?? []);
    if (!files.length) return;
    e.preventDefault();
    addFiles(files);
  };

  return (
    <div className="composer">
      {(chips.length > 0 || pin) && (
        <div className="composer-chips">
          {pin && (
            <div className="cchip cchip-pin">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={pin.imageUrl} alt="" style={{ background: pin.color || undefined }} />
              <span className="cchip-text">
                <strong>{pin.title || "Post"}</strong>
                {pin.price > 0 && <span>{priceLabel(pin)}</span>}
              </span>
              <button type="button" className="cchip-x" onClick={() => setPin(null)} aria-label="Posty aýyr"><CloseIcon size={14} /></button>
            </div>
          )}
          {chips.map((c) => (
            c.url ? (
              <div key={c.id} className="cchip cchip-img">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={c.url} alt={c.file.name} />
                <button type="button" className="cchip-x" onClick={() => removeChip(c.id)} aria-label={`${c.file.name} aýyr`}><CloseIcon size={14} /></button>
              </div>
            ) : (
              <div key={c.id} className="cchip cchip-file">
                <span className="file-ext">{fileExt(c.file.name)}</span>
                <span className="cchip-text">
                  <strong>{c.file.name}</strong>
                  <span>{fileSize(c.file.size)}</span>
                </span>
                <button type="button" className="cchip-x" onClick={() => removeChip(c.id)} aria-label={`${c.file.name} aýyr`}><CloseIcon size={14} /></button>
              </div>
            )
          ))}
        </div>
      )}
      <div className="composer-row">
        <button
          type="button"
          className="composer-attach"
          onClick={() => input.current?.click()}
          disabled={disabled}
          aria-label="Surat ýa-da faýl goş"
          title="Surat ýa-da faýl goş"
        >
          <PlusIcon size={22} />
        </button>
        <textarea
          ref={area}
          rows={1}
          value={text}
          onChange={(e) => {
            setText(e.target.value);
            if (e.target.value.trim()) onTyping();
          }}
          onKeyDown={onKeyDown}
          onPaste={onPaste}
          placeholder="Habar ýazyň…"
          aria-label="Habar"
          maxLength={MAX_TEXT}
          disabled={disabled}
        />
        <button type="button" className="composer-send" onClick={submit} disabled={!canSend} aria-label="Ugrat" title="Ugrat">
          <SendIcon size={20} />
        </button>
        <input
          ref={input}
          type="file"
          accept={CHAT_ACCEPT}
          multiple
          hidden
          onChange={(e) => {
            if (e.target.files) addFiles(e.target.files);
            e.target.value = "";
          }}
        />
      </div>
    </div>
  );
}
