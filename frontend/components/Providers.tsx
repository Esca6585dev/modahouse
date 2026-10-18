"use client";

import { AuthProvider } from "@/lib/auth";
import { CartProvider } from "@/lib/cart";
import { RealtimeProvider } from "@/lib/realtime";
import { ChatProvider } from "./chat/ChatProvider";
import { ShareProvider } from "./ShareSheet";
import { StoriesProvider } from "./StoryViewer";
import { ToastProvider } from "./Toast";

export default function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <RealtimeProvider>
        <CartProvider>
          <ToastProvider>
            <ChatProvider>
              <ShareProvider>
                <StoriesProvider>{children}</StoriesProvider>
              </ShareProvider>
            </ChatProvider>
          </ToastProvider>
        </CartProvider>
      </RealtimeProvider>
    </AuthProvider>
  );
}
