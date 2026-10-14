// Runtime proxy to the Go backend (BACKEND_URL is read on every request; see lib/proxy.ts).
import { proxy } from "@/lib/proxy";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

export const GET = proxy;
export const HEAD = proxy;
export const POST = proxy;
export const PUT = proxy;
export const PATCH = proxy;
export const DELETE = proxy;
export const OPTIONS = proxy;
