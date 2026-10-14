"use client";

import Link from "next/link";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { api, errorMessage } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { compact, timeAgo } from "@/lib/format";
import type { StoryGroup } from "@/lib/types";
import Avatar from "./Avatar";
import { BagIcon, ChevronLeftIcon, ChevronRightIcon, CloseIcon, EyeIcon, MuteIcon, PauseIcon, PlayIcon, TrashIcon, VerifiedIcon, VolumeIcon } from "./Icons";
import { useToast } from "./Toast";

const DURATION = 5000;

type StoriesState = {
  /** Open the viewer on the given groups, starting at group `index`. */
  open: (groups: StoryGroup[], index?: number) => void;
  /** Open a single user's active stories (fetches them). */
  openUser: (username: string) => Promise<boolean>;
  /** Increments whenever stories change (viewed, added, deleted) so lists can refresh. */
  version: number;
  bump: () => void;
  /** Active story groups (GET /stories), null while loading. */
  groups: StoryGroup[] | null;
  /** Ring state for a user's avatar. */
  ringFor: (userId: number) => "unseen" | "seen" | "none";
  /** Opens the user's group from the loaded list (falls back to fetching it). */
  openFor: (user: { id: number; username: string }) => void;
};

const StoriesContext = createContext<StoriesState | null>(null);

export function useStories(): StoriesState {
  const ctx = useContext(StoriesContext);
  if (!ctx) throw new Error("useStories must be used inside <StoriesProvider>");
  return ctx;
}

export function StoriesProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<{ groups: StoryGroup[]; index: number } | null>(null);
  const [version, setVersion] = useState(0);
  const [groups, setGroups] = useState<StoryGroup[] | null>(null);
  const toast = useToast();
  const { user, ready } = useAuth();
  const bump = useCallback(() => setVersion((v) => v + 1), []);

  const viewer = user?.id ?? 0;
  useEffect(() => {
    if (!ready) return;
    let alive = true;
    api.stories().then((g) => alive && setGroups(Array.isArray(g) ? g : []), () => alive && setGroups([]));
    return () => { alive = false; };
  }, [ready, viewer, version]);

  const open = useCallback((groups: StoryGroup[], index = 0) => {
    const usable = groups.filter((g) => g.stories.length > 0);
    if (!usable.length) return;
    const target = groups[index];
    const i = Math.max(0, usable.indexOf(target));
    setSession({ groups: usable, index: i });
  }, []);

  const openUser = useCallback(async (username: string) => {
    try {
      const g = await api.userStories(username);
      if (!g.stories?.length) return false;
      setSession({ groups: [g], index: 0 });
      return true;
    } catch (e) {
      toast(errorMessage(e), "error");
      return false;
    }
  }, [toast]);

  const ringFor = useCallback((userId: number) => {
    const g = groups?.find((x) => x.user.id === userId);
    return g ? (g.allSeen ? "seen" : "unseen") : "none";
  }, [groups]);

  const openFor = useCallback((u: { id: number; username: string }) => {
    const i = groups?.findIndex((x) => x.user.id === u.id) ?? -1;
    if (groups && i >= 0) open(groups, i);
    else openUser(u.username);
  }, [groups, open, openUser]);

  const value = useMemo(
    () => ({ open, openUser, version, bump, groups, ringFor, openFor }),
    [open, openUser, version, bump, groups, ringFor, openFor],
  );

  return (
    <StoriesContext.Provider value={value}>
      {children}
      {session && (
        <StoryViewer
          groups={session.groups}
          startGroup={session.index}
          onClose={() => {
            setSession(null);
            bump();
          }}
        />
      )}
    </StoriesContext.Provider>
  );
}

function firstUnseen(g: StoryGroup): number {
  const i = g.stories.findIndex((s) => !s.seen);
  return i === -1 || g.allSeen ? 0 : i;
}

function StoryViewer({ groups: initial, startGroup, onClose }: { groups: StoryGroup[]; startGroup: number; onClose: () => void }) {
  const { user } = useAuth();
  const toast = useToast();
  const [groups, setGroups] = useState(initial);
  const [gi, setGi] = useState(startGroup);
  const [si, setSi] = useState(() => firstUnseen(initial[startGroup]));
  const [paused, setPaused] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [progress, setProgress] = useState(0);
  const holdTimer = useRef<number | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const [svMuted, setSvMuted] = useState(true);
  const held = useRef(false);
  const elapsed = useRef(0);
  const closeRef = useRef(onClose);
  closeRef.current = onClose;

  const group = groups[gi];
  const story = group?.stories[si];
  const isVideo = story?.mediaType === "video" && !!story.videoUrl;
  const isOwner = !!user && group?.user.id === user.id;

  const next = useCallback(() => {
    const g = groups[gi];
    if (!g) return;
    if (si < g.stories.length - 1) setSi(si + 1);
    else if (gi < groups.length - 1) {
      setGi(gi + 1);
      setSi(firstUnseen(groups[gi + 1]));
    } else closeRef.current();
  }, [groups, gi, si]);

  const prev = useCallback(() => {
    if (si > 0) setSi(si - 1);
    else if (gi > 0) {
      setGi(gi - 1);
      setSi(0);
    } else {
      elapsed.current = 0;
      setProgress(0);
    }
  }, [gi, si]);

  // Reset timing when the story changes.
  const storyId = story?.id;
  useEffect(() => {
    elapsed.current = 0;
    setProgress(0);
    setLoaded(false);
  }, [storyId]);

  // Mark as viewed once it is shown.
  useEffect(() => {
    if (!story || !loaded || story.seen || !user) return;
    api.viewStory(story.id).catch(() => {});
    setGroups((gs) => gs.map((g, i) => (i !== gi ? g : {
      ...g,
      stories: g.stories.map((s) => (s.id === story.id ? { ...s, seen: true } : s)),
    })));
  }, [story, loaded, user, gi]);

  // Video stories: progress follows the video and it advances when the video ends.
  useEffect(() => {
    const v = videoRef.current;
    if (!isVideo || !v) return;
    if (paused || !loaded) v.pause();
    else v.play().catch(() => {
      v.muted = true;
      setSvMuted(true);
      v.play().catch(() => {});
    });
  }, [isVideo, paused, loaded, storyId]);

  // Progress animation (images).
  useEffect(() => {
    if (!story || paused || !loaded || isVideo) return;
    let raf = 0;
    let last = performance.now();
    const tick = (now: number) => {
      elapsed.current += now - last;
      last = now;
      const p = Math.min(1, elapsed.current / DURATION);
      setProgress(p);
      if (p >= 1) next();
      else raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [story, paused, loaded, next, isVideo]);

  // Keyboard + scroll lock.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") closeRef.current();
      else if (e.key === "ArrowRight") next();
      else if (e.key === "ArrowLeft") prev();
      else if (e.key === " ") {
        e.preventDefault();
        setPaused((p) => !p);
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [next, prev]);

  useEffect(() => {
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = prevOverflow; };
  }, []);

  if (!group || !story) return null;

  const onPointerDown = () => {
    held.current = false;
    holdTimer.current = window.setTimeout(() => {
      held.current = true;
      setPaused(true);
    }, 220);
  };
  const onPointerUp = (e: React.PointerEvent<HTMLDivElement>) => {
    if (holdTimer.current) window.clearTimeout(holdTimer.current);
    if (held.current) {
      held.current = false;
      setPaused(false);
      return;
    }
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    if (x < rect.width * 0.3) prev();
    else next();
  };

  const remove = async () => {
    if (!window.confirm("Bu story-ny pozmalymy?")) return;
    try {
      await api.deleteStory(story.id);
      toast("Story pozuldy");
      const remaining = group.stories.filter((s) => s.id !== story.id);
      if (!remaining.length) {
        const gs = groups.filter((_, i) => i !== gi);
        if (!gs.length) {
          closeRef.current();
          return;
        }
        setGroups(gs);
        setGi(Math.min(gi, gs.length - 1));
        setSi(0);
      } else {
        setGroups((gs) => gs.map((g, i) => (i === gi ? { ...g, stories: remaining } : g)));
        setSi(Math.min(si, remaining.length - 1));
      }
    } catch (err) {
      toast(errorMessage(err), "error");
    }
  };

  return createPortal(
    <div className="story-viewer" role="dialog" aria-modal="true" aria-label={`${group.user.name} story`}>
      <div className="sv-backdrop" style={{ background: story.color || "#000" }} />
      <button className="sv-close-desktop icon-btn" onClick={onClose} aria-label="Ýap"><CloseIcon size={26} /></button>
      {gi > 0 && (
        <button className="sv-nav sv-prev" onClick={() => { setGi(gi - 1); setSi(0); }} aria-label="Öňki">
          <ChevronLeftIcon size={22} />
        </button>
      )}
      <div className="sv-frame">
        <div className="sv-progress">
          {group.stories.map((s, i) => (
            <span key={s.id} className="sv-bar">
              <span style={{ transform: `scaleX(${i < si ? 1 : i === si ? progress : 0})` }} />
            </span>
          ))}
        </div>
        <div className="sv-head">
          <Link href={`/u/${group.user.username}`} className="sv-user" onClick={onClose}>
            <Avatar user={group.user} size={34} />
            <strong>{group.user.name}</strong>
            {group.user.verified && <VerifiedIcon size={14} />}
            <span>{timeAgo(story.createdAt)}</span>
          </Link>
          <div className="sv-tools">
            {isVideo && (
              <button className="sv-tool" onClick={() => setSvMuted((m) => !m)} aria-label={svMuted ? "Sesi aç" : "Sesi öçür"}>
                {svMuted ? <MuteIcon size={18} /> : <VolumeIcon size={18} />}
              </button>
            )}
            <button className="sv-tool" onClick={() => setPaused((p) => !p)} aria-label={paused ? "Dowam et" : "Saklat"}>
              {paused ? <PlayIcon size={18} /> : <PauseIcon size={18} />}
            </button>
            {isOwner && (
              <button className="sv-tool" onClick={remove} aria-label="Story-ny poz"><TrashIcon size={18} /></button>
            )}
            <button className="sv-tool" onClick={onClose} aria-label="Ýap"><CloseIcon size={22} /></button>
          </div>
        </div>
        <div
          className="sv-media"
          onPointerDown={onPointerDown}
          onPointerUp={onPointerUp}
          onPointerCancel={() => { if (holdTimer.current) window.clearTimeout(holdTimer.current); setPaused(false); }}
          onContextMenu={(e) => e.preventDefault()}
        >
          {isVideo ? (
            <video
              key={story.id}
              ref={videoRef}
              src={story.videoUrl}
              poster={story.imageUrl || undefined}
              muted={svMuted}
              playsInline
              preload="auto"
              onLoadedData={() => setLoaded(true)}
              onError={() => setLoaded(true)}
              onTimeUpdate={(e) => {
                const v = e.currentTarget;
                if (v.duration > 0) setProgress(Math.min(1, v.currentTime / v.duration));
              }}
              onEnded={() => next()}
            />
          ) : (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={story.id}
              src={story.imageUrl}
              alt={story.caption || "Story"}
              draggable={false}
              onLoad={() => setLoaded(true)}
              onError={() => setLoaded(true)}
            />
          )}
          {!loaded && <span className="spinner sv-spinner" />}
        </div>
        <div className="sv-foot">
          {story.caption && <p className="sv-caption">{story.caption}</p>}
          <div className="sv-foot-row">
            {story.pinId && (
              <Link href={`/pin/${story.pinId}`} className="btn btn-primary btn-sm" onClick={onClose}>
                <BagIcon size={16} /> Haryda seret
              </Link>
            )}
            {isOwner && (
              <span className="sv-views"><EyeIcon size={16} /> {compact(story.viewsCount)} gördi</span>
            )}
          </div>
        </div>
      </div>
      {gi < groups.length - 1 && (
        <button className="sv-nav sv-next" onClick={() => { setGi(gi + 1); setSi(firstUnseen(groups[gi + 1])); }} aria-label="Indiki">
          <ChevronRightIcon size={22} />
        </button>
      )}
    </div>,
    document.body,
  );
}
