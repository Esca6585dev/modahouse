"use client";

import { AuthProvider } from "@/lib/auth";
import { CartProvider } from "@/lib/cart";
import { StoriesProvider } from "./StoryViewer";
import { ToastProvider } from "./Toast";

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <CartProvider>
        <ToastProvider>
          <StoriesProvider>{children}</StoriesProvider>
        </ToastProvider>
      </CartProvider>
    </AuthProvider>
  );
}
