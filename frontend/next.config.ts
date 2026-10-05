import type { NextConfig } from "next";

// Rewrites are baked into the build output, so BACKEND_URL must be set at `next build` time.
const backend = (process.env.BACKEND_URL ?? "http://localhost:8080").replace(/\/+$/, "");

const nextConfig: NextConfig = {
  output: "standalone",
  async rewrites() {
    return [
      { source: "/api/:path*", destination: `${backend}/api/:path*` },
      { source: "/uploads/:path*", destination: `${backend}/uploads/:path*` },
    ];
  },
};

export default nextConfig;
