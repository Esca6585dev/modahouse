"use client";

import { useParams } from "next/navigation";
import ChatList from "@/components/chat/ChatList";
import { useRequireAuth } from "@/lib/hooks";

/** Two panes on wide screens (chats | conversation); on phones the list, then a full-screen conversation. */
export default function MessagesLayout({ children }: { children: React.ReactNode }) {
  const { user } = useRequireAuth();
  const params = useParams<{ id?: string }>();
  const activeId = Number(params?.id) || null;

  if (!user) {
    return (
      <div className="chat-shell" aria-busy="true">
        <aside className="chat-side"><div className="skeleton" style={{ margin: 16, height: 40, borderRadius: 999 }} /></aside>
        <section className="chat-main" />
      </div>
    );
  }

  return (
    <div className={`chat-shell ${activeId ? "has-conv" : ""}`}>
      <aside className="chat-side" aria-label="Habarlaşyklar">
        <ChatList activeId={activeId} />
      </aside>
      <section className="chat-main">{children}</section>
    </div>
  );
}
