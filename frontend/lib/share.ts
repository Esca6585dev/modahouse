import { ApiError, getToken } from "./api";

/** Absolute URL of a same-site path (for shared links). */
export function absUrl(path: string): string {
  return new URL(path, window.location.origin).toString();
}

/** Copies text; falls back to a prompt. Returns true when it reached the clipboard. */
export async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    window.prompt("Baglanyşygy göçüriň:", text);
    return false;
  }
}

/** Share a URL with the native sheet when available, otherwise copy it. Returns a toast message or null. */
export async function shareUrl(url: string, title: string): Promise<string | null> {
  const abs = absUrl(url);
  if (typeof navigator.share === "function") {
    try {
      await navigator.share({ title, url: abs });
      return null;
    } catch (e) {
      if ((e as Error).name === "AbortError") return null;
    }
  }
  return (await copyText(abs)) ? "Baglanyşyk göçürildi" : null;
}

/** Fetches a binary API response (with the session token) as a Blob; JSON errors become ApiError. */
export async function fetchBlob(path: string, signal?: AbortSignal): Promise<{ blob: Blob; filename: string }> {
  const headers: Record<string, string> = {};
  const token = getToken();
  if (token) headers.Authorization = `Bearer ${token}`;
  let res: Response;
  try {
    res = await fetch(path, { headers, cache: "no-store", signal });
  } catch (e) {
    if ((e as Error).name === "AbortError") throw e;
    throw new ApiError("Serwer bilen baglanyşyk ýok. Internedi barlaň", 0);
  }
  if (!res.ok) {
    let msg = res.status === 404 ? "Tapylmady" : "Faýl ýüklenmedi";
    try {
      const data = await res.json();
      if (data && typeof data.error === "string") msg = data.error;
    } catch {
      /* not JSON */
    }
    throw new ApiError(msg, res.status);
  }
  const blob = await res.blob();
  const cd = res.headers.get("content-disposition") ?? "";
  const m = /filename\*=UTF-8''([^;]+)|filename="?([^";]+)"?/i.exec(cd);
  const filename = m ? decodeURIComponent(m[1] ?? m[2]) : "";
  return { blob, filename };
}

function extFor(type: string): string {
  if (type.includes("png")) return "png";
  if (type.includes("webm")) return "webm";
  if (type.includes("mp4")) return "mp4";
  if (type.includes("quicktime")) return "mov";
  return "jpg";
}

/** Saves a Blob through a temporary <a download> (works in mobile Chrome and Safari 13+). */
export function saveBlob(blob: Blob, filename: string) {
  const href = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = href;
  a.download = filename;
  a.rel = "noopener";
  a.style.display = "none";
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(href), 30_000);
}

export const pinDownloadPath = (id: number, index = 0) => `/api/pins/${id}/download?index=${Math.max(0, index)}`;
export const shareCardPath = (id: number) => `/api/pins/${id}/share-card`;

/**
 * Downloads media item `index` of a post from the server, which stamps images with the ModaHouse
 * watermark (videos come back unchanged). Returns the toast text.
 */
export async function downloadPin(id: number, index = 0): Promise<string> {
  const { blob, filename } = await fetchBlob(pinDownloadPath(id, index));
  saveBlob(blob, filename || `modahouse-${id}-${index}.${extFor(blob.type)}`);
  return blob.type.startsWith("video/") ? "Wideo ýüklendi" : "Surat ýüklendi";
}

/** The branded share card (1080×1920 JPEG) of a post as a File ready for navigator.share. */
export async function fetchShareCard(id: number, signal?: AbortSignal): Promise<File> {
  const { blob } = await fetchBlob(shareCardPath(id), signal);
  return new File([blob], `modahouse-${id}.jpg`, { type: blob.type || "image/jpeg" });
}

/**
 * Shares the card image together with the post link. Without file sharing (desktop browsers),
 * downloads the card and copies the link. Returns a toast message, or null when nothing to say.
 */
export async function shareCardFile(file: File, title: string, url: string): Promise<string | null> {
  const abs = absUrl(url);
  const data: ShareData = { files: [file], title, text: `${title} — ModaHouse`, url: abs };
  if (typeof navigator.canShare === "function" && typeof navigator.share === "function" && navigator.canShare({ files: [file] })) {
    try {
      // Some targets drop `url` when files are attached; it is in `text` too only if canShare rejects the full data.
      await navigator.share(navigator.canShare(data) ? data : { files: [file], text: `${title} ${abs}` });
      return null;
    } catch (e) {
      if ((e as Error).name === "AbortError") return null;
    }
  }
  saveBlob(file, file.name);
  return (await copyText(abs)) ? "Surat ýüklendi, baglanyşyk göçürildi" : "Surat ýüklendi";
}
