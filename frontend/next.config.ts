import type { NextConfig } from "next";

// /api/* and /uploads/* are proxied to the Go backend by route handlers (app/api, app/uploads,
// lib/proxy.ts) that read BACKEND_URL at request time, so the build does not depend on it.
const nextConfig: NextConfig = {
  output: "standalone",
};

export default nextConfig;
