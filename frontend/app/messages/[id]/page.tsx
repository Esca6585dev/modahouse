"use client";

import { useParams } from "next/navigation";
import { Suspense } from "react";
import Conversation from "@/components/chat/Conversation";

export default function ConversationPage() {
  const { id } = useParams<{ id: string }>();
  const chatId = Number(id);
  if (!Number.isInteger(chatId) || chatId <= 0) {
    return <div className="chat-conv"><div className="conv-missing"><h2>Habarlaşyk tapylmady</h2></div></div>;
  }
  return (
    <Suspense fallback={<div className="chat-conv" />}>
      <Conversation key={chatId} chatId={chatId} />
    </Suspense>
  );
}
