/** Share a URL with the native sheet when available, otherwise copy it. Returns a toast message or null. */
export async function shareUrl(url: string, title: string): Promise<string | null> {
  const abs = new URL(url, window.location.origin).toString();
  if (typeof navigator.share === "function") {
    try {
      await navigator.share({ title, url: abs });
      return null;
    } catch (e) {
      if ((e as Error).name === "AbortError") return null;
    }
  }
  try {
    await navigator.clipboard.writeText(abs);
    return "Baglanyşyk göçürildi";
  } catch {
    window.prompt("Baglanyşygy göçüriň:", abs);
    return null;
  }
}
