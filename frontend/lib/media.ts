// Browser-side media helpers: video posters, durations and image rasterising.

export const IMAGE_TYPES = ["image/jpeg", "image/png", "image/gif", "image/webp"];
export const VIDEO_TYPES = ["video/mp4", "video/webm", "video/quicktime"];
export const MAX_VIDEO_MB = 60;
export const MAX_VIDEO_SECONDS = 60;

function canvasBlob(canvas: HTMLCanvasElement, type = "image/jpeg", quality = 0.86): Promise<Blob> {
  return new Promise((resolve, reject) =>
    canvas.toBlob((b) => (b ? resolve(b) : reject(new Error("Surat döredilmedi"))), type, quality));
}

/** First frame of a video as a JPEG poster, plus its duration and size. */
export function videoPoster(file: File): Promise<{ poster: File; duration: number; width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const v = document.createElement("video");
    v.muted = true;
    v.playsInline = true;
    v.preload = "auto";
    v.src = url;
    let done = false;
    const fail = () => {
      if (done) return;
      done = true;
      URL.revokeObjectURL(url);
      reject(new Error("Wideony okap bolmady. MP4 ýa-da WebM saýlaň"));
    };
    const timer = window.setTimeout(fail, 15000);
    const grab = async () => {
      if (done) return;
      try {
        const w = v.videoWidth || 720;
        const h = v.videoHeight || 1280;
        const scale = Math.min(1, 1080 / Math.max(w, h));
        const c = document.createElement("canvas");
        c.width = Math.round(w * scale);
        c.height = Math.round(h * scale);
        c.getContext("2d")!.drawImage(v, 0, 0, c.width, c.height);
        const blob = await canvasBlob(c);
        let d = v.duration;
        if (!Number.isFinite(d)) d = 0; // WebM from MediaRecorder may report Infinity
        done = true;
        window.clearTimeout(timer);
        URL.revokeObjectURL(url);
        resolve({ poster: new File([blob], "poster.jpg", { type: "image/jpeg" }), duration: Math.round(d * 10) / 10, width: w, height: h });
      } catch {
        fail();
      }
    };
    const seekToPoster = () => {
      // Seek a little into the clip so the poster is not a black first frame.
      if (Number.isFinite(v.duration) && v.duration > 0.3) {
        v.onseeked = grab;
        v.currentTime = Math.min(0.15, v.duration / 3);
      } else grab();
    };
    v.onloadeddata = () => {
      if (Number.isFinite(v.duration)) {
        seekToPoster();
        return;
      }
      // WebM from MediaRecorder reports Infinity until the end is seeked once.
      v.ondurationchange = () => {
        if (!Number.isFinite(v.duration)) return;
        v.ondurationchange = null;
        v.onseeked = () => {
          v.onseeked = null;
          seekToPoster();
        };
        v.currentTime = 0;
      };
      v.currentTime = 1e7;
    };
    v.onerror = fail;
  });
}

/** Loads any image URL/file (incl. SVG) and redraws it as a JPEG no larger than `max` px. */
export async function rasterize(src: string | Blob, max = 1024): Promise<{ blob: Blob; width: number; height: number }> {
  const url = typeof src === "string" ? src : URL.createObjectURL(src);
  try {
    const img = new Image();
    img.decoding = "async";
    img.src = url;
    await img.decode();
    const w = img.naturalWidth || 800;
    const h = img.naturalHeight || 800;
    const scale = Math.min(1, max / Math.max(w, h));
    const c = document.createElement("canvas");
    c.width = Math.max(1, Math.round(w * scale));
    c.height = Math.max(1, Math.round(h * scale));
    const ctx = c.getContext("2d")!;
    ctx.fillStyle = "#fff";
    ctx.fillRect(0, 0, c.width, c.height);
    ctx.drawImage(img, 0, 0, c.width, c.height);
    return { blob: await canvasBlob(c), width: w, height: h };
  } finally {
    if (typeof src !== "string") URL.revokeObjectURL(url);
  }
}
