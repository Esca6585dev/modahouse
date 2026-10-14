"use client";

import { useState } from "react";
import { useAuth } from "@/lib/auth";
import AddStoryModal from "./AddStoryModal";
import { PlusIcon } from "./Icons";
import StoryAvatar from "./StoryAvatar";
import { useStories } from "./StoryViewer";

export default function StoriesBar() {
  const { user, ready } = useAuth();
  const { open, bump, groups } = useStories();
  const [adding, setAdding] = useState(false);

  if (!ready) return null;
  if (groups === null) {
    return (
      <div className="stories" aria-busy="true">
        {[0, 1, 2, 3, 4, 5, 6].map((i) => (
          <div key={i} className="story-item">
            <span className="skeleton story-skel" />
            <span className="skeleton skeleton-line" style={{ width: 52, margin: "6px auto 0" }} />
          </div>
        ))}
      </div>
    );
  }

  const own = user ? groups.find((g) => g.user.id === user.id) : undefined;
  const others = groups.filter((g) => g !== own);
  if (!user && others.length === 0) return null;

  return (
    <>
      <div className="stories" role="list" aria-label="Story-lar">
        {user && (
          <div className="story-item" role="listitem">
            <div className="story-own">
              {own ? (
                <StoryAvatar
                  user={user}
                  size={64}
                  ring={own.allSeen ? "seen" : "unseen"}
                  onClick={() => open(groups, groups.indexOf(own))}
                />
              ) : (
                <button className="story-avatar-btn" onClick={() => setAdding(true)} aria-label="Story goş">
                  <StoryAvatar user={user} size={64} ring="none" />
                </button>
              )}
              <button className="story-plus" onClick={() => setAdding(true)} aria-label="Story goş"><PlusIcon size={14} /></button>
            </div>
            <span className="story-name">Siziň story</span>
          </div>
        )}
        {others.map((g) => (
          <div key={g.user.id} className="story-item" role="listitem">
            <StoryAvatar user={g.user} size={64} ring={g.allSeen ? "seen" : "unseen"} onClick={() => open(groups, groups.indexOf(g))} />
            <span className="story-name">{g.user.username}</span>
          </div>
        ))}
      </div>
      {adding && (
        <AddStoryModal
          onClose={() => setAdding(false)}
          onCreated={() => {
            setAdding(false);
            bump();
          }}
        />
      )}
    </>
  );
}
