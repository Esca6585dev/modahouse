// Runtime reverse proxy from the web server to the Go backend (used by app/api and app/uploads).
//
// BACKEND_URL is read on every request, so the backend address can be changed by setting the
// environment variable and restarting `node server.js`: no rebuild needed.

import type { NextRequest } from "next/server";

const DEFAULT_BACKEND = "http://localhost:8080";

export function backendOrigin(): string {
  const raw = (process.env.BACKEND_URL ?? "").trim() || DEFAULT_BACKEND;
  return raw.replace(/\/+$/, "");
}

// Hop-by-hop headers (RFC 9110 §7.6.1) and headers we set ourselves.
const DROP_REQUEST = new Set([
  "host", "connection", "keep-alive", "transfer-encoding", "upgrade", "te", "trailer",
  "x-forwarded-for", "x-forwarded-proto", "x-forwarded-host", "x-forwarded-port", "forwarded",
  "accept-encoding", // we ask for identity below
  "expect", // undici rejects it; Next already answered any 100-continue
]);
const DROP_RESPONSE = new Set(["connection", "keep-alive", "transfer-encoding", "upgrade", "te", "trailer"]);

const isProxyHeader = (name: string) => name.startsWith("proxy-");

function clientChain(req: NextRequest): string {
  // Next's own server fills x-forwarded-for with the socket address when no proxy in front set it.
  const chain = (req.headers.get("x-forwarded-for") ?? "").split(",").map((s) => s.trim()).filter(Boolean);
  const real = req.headers.get("x-real-ip")?.trim();
  if (real && !chain.includes(real)) chain.push(real);
  return chain.join(", ");
}

const BAD_GATEWAY = JSON.stringify({ error: "Serwer bilen baglanyşyk ýok" });

export async function proxy(req: NextRequest): Promise<Response> {
  const origin = backendOrigin();
  const url = req.nextUrl;
  const target = `${origin}${url.pathname}${url.search}`;

  const headers = new Headers();
  req.headers.forEach((value, key) => {
    const k = key.toLowerCase();
    if (DROP_REQUEST.has(k) || isProxyHeader(k)) return;
    headers.append(key, value);
  });
  const xff = clientChain(req);
  if (xff) headers.set("x-forwarded-for", xff);
  headers.set("x-forwarded-proto", req.headers.get("x-forwarded-proto")?.split(",")[0].trim() || url.protocol.replace(/:$/, ""));
  const host = req.headers.get("x-forwarded-host")?.split(",")[0].trim() || req.headers.get("host");
  if (host) headers.set("x-forwarded-host", host);
  // Ask for an unencoded body: Content-Length (video seeking, download progress) then passes through
  // unchanged, and Next compresses what it sends to the browser itself.
  headers.set("accept-encoding", "identity");

  const hasBody = req.method !== "GET" && req.method !== "HEAD" && req.body !== null;
  let res: Response;
  try {
    res = await fetch(target, {
      method: req.method,
      headers,
      body: hasBody ? req.body : undefined,
      // Stream the upload straight through (videos up to 60 MB plus images); never buffer it.
      ...(hasBody ? { duplex: "half" } : {}),
      redirect: "manual",
      cache: "no-store",
      signal: req.signal,
    } as RequestInit);
  } catch (e) {
    if (req.signal.aborted) return new Response(null, { status: 499 });
    console.error(`proxy ${req.method} ${url.pathname} -> ${origin}: ${(e as Error).cause ?? e}`);
    return new Response(BAD_GATEWAY, {
      status: 502,
      headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
    });
  }

  const out = new Headers();
  // fetch decodes gzip/br bodies on the fly: the original encoding and length no longer apply.
  const decoded = !!res.headers.get("content-encoding") && res.headers.get("content-encoding") !== "identity";
  res.headers.forEach((value, key) => {
    const k = key.toLowerCase();
    if (DROP_RESPONSE.has(k) || isProxyHeader(k)) return;
    if (decoded && (k === "content-encoding" || k === "content-length")) return;
    if (k === "set-cookie") return; // appended one by one below
    if (k === "location" && value.startsWith(origin)) value = value.slice(origin.length) || "/";
    out.set(key, value);
  });
  for (const c of res.headers.getSetCookie()) out.append("set-cookie", c);

  const noBody = req.method === "HEAD" || res.status === 204 || res.status === 304;
  if (!noBody && res.body && isEventStream(res.headers.get("content-type"))) {
    return new Response(eventStream(res.body, req.signal), { status: res.status, statusText: res.statusText, headers: sseHeaders(out) });
  }
  return new Response(noBody ? null : res.body, { status: res.status, statusText: res.statusText, headers: out });
}

// ---------- Server-Sent Events (GET /api/events) ----------
// In production nginx proxies /api straight to Go; this path is for `next dev` / `node server.js`
// without nginx. Every chunk must reach the browser as soon as the backend writes it.

const isEventStream = (ct: string | null) => !!ct && ct.toLowerCase().startsWith("text/event-stream");

function sseHeaders(h: Headers): Headers {
  h.delete("content-length");
  h.delete("content-encoding");
  // "no-transform" makes Next's built-in compression skip the response: gzip would hold events
  // back until its buffer fills. X-Accel-Buffering does the same for an nginx in front of Next.
  h.set("cache-control", "no-cache, no-transform");
  h.set("x-accel-buffering", "no");
  return h;
}

/**
 * Pipes the backend stream chunk by chunk (no buffering) and cancels the upstream request as soon
 * as the browser goes away, so long-lived connections never pile up on the backend.
 */
function eventStream(body: ReadableStream<Uint8Array>, signal: AbortSignal): ReadableStream<Uint8Array> {
  const reader = body.getReader();
  const stop = () => reader.cancel().catch(() => {});
  signal.addEventListener("abort", stop, { once: true });
  return new ReadableStream<Uint8Array>({
    async pull(ctl) {
      try {
        const { done, value } = await reader.read();
        if (done) {
          signal.removeEventListener("abort", stop);
          ctl.close();
        } else {
          ctl.enqueue(value);
        }
      } catch {
        signal.removeEventListener("abort", stop);
        // Backend restarted or the connection dropped: end the stream; EventSource reconnects.
        try { ctl.close(); } catch { /* already closed */ }
      }
    },
    cancel() {
      signal.removeEventListener("abort", stop);
      return reader.cancel().catch(() => {});
    },
  }, { highWaterMark: 0 });
}
