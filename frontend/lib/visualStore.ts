// Hands a picked photo from the search bar to the /visual page (client memory only).
let pending: File | null = null;
const listeners = new Set<() => void>();

export function setPendingPhoto(f: File) {
  pending = f;
  listeners.forEach((l) => l());
}

export function takePendingPhoto(): File | null {
  const f = pending;
  pending = null;
  return f;
}

/** Called when a new photo is handed over while /visual is already open. */
export function onPendingPhoto(l: () => void): () => void {
  listeners.add(l);
  return () => { listeners.delete(l); };
}
