"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { EyeIcon, HashIcon, SearchIcon, SparkIcon, UserIcon } from "@/components/Icons";
import { api, errorMessage } from "@/lib/api";
import { num } from "@/lib/format";
import type { Analytics, AnalyticsDay, InterestStat } from "@/lib/types";
import { AdminHead, LoadError } from "../shared";

const PERIODS = [7, 30, 90];

const shortDay = (d: string) => {
  const [, m, day] = d.split("-");
  return `${Number(day)}.${m}`;
};

/** Daily bars of one metric; the value is in the title for hover and screen readers. */
function DayBars({ days, pick, label }: { days: AnalyticsDay[]; pick: (d: AnalyticsDay) => number; label: string }) {
  const max = Math.max(1, ...days.map(pick));
  const total = days.reduce((s, d) => s + pick(d), 0);
  return (
    <figure className="an-chart">
      <figcaption>
        <span>{label}</span>
        <strong>{num(total)}</strong>
      </figcaption>
      <div className="an-bars" role="img" aria-label={`${label}: ${days.map((d) => `${shortDay(d.day)} ${pick(d)}`).join(", ")}`}>
        {days.map((d) => (
          <span key={d.day} className="an-bar" title={`${shortDay(d.day)}: ${num(pick(d))}`}>
            <span style={{ height: `${(pick(d) / max) * 100}%` }} />
          </span>
        ))}
      </div>
      <div className="an-axis muted small">
        <span>{shortDay(days[0]?.day ?? "")}</span>
        <span>{shortDay(days[days.length - 1]?.day ?? "")}</span>
      </div>
    </figure>
  );
}

/** Horizontal bars: each interest's share of the strongest one. */
function InterestBars({ items, tag }: { items: InterestStat[]; tag?: boolean }) {
  if (items.length === 0) return <p className="muted small">Entek maglumat ýok: ulanyjylar postlara seredip, halap başlanda görüner.</p>;
  const max = Math.max(...items.map((i) => i.score));
  return (
    <ul className="an-list">
      {items.map((i) => (
        <li key={i.key}>
          <Link href={tag ? `/tag/${encodeURIComponent(i.key)}` : `/?c=${encodeURIComponent(i.key)}`} className="an-name">
            {tag ? "#" : ""}{i.name}
          </Link>
          <span className="an-track"><span style={{ width: `${(i.score / max) * 100}%` }} /></span>
          <span className="an-val muted small" title="Iň gyzyklanýan ulanyjylar">{num(i.users)} <UserIcon size={12} /></span>
        </li>
      ))}
    </ul>
  );
}

export default function AdminAnalytics() {
  const [days, setDays] = useState(30);
  const [data, setData] = useState<Analytics | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setError(null);
    setData(null);
    api.admin.analytics(days).then(setData, (e) => setError(errorMessage(e)));
  }, [days]);
  useEffect(() => {
    document.title = "Analitika · Admin · ModaHouse";
    load();
  }, [load]);

  return (
    <>
      <AdminHead title="Analitika" sub="Ulanyjylar näme bilen gyzyklanýar">
        <div className="feed-toggle" role="tablist" aria-label="Döwür">
          {PERIODS.map((p) => (
            <button key={p} role="tab" aria-selected={days === p} className={days === p ? "active" : ""} onClick={() => setDays(p)}>
              {p} gün
            </button>
          ))}
        </div>
      </AdminHead>
      {error ? (
        <LoadError message={error} onRetry={load} />
      ) : !data ? (
        <div className="skeleton" style={{ height: 420, borderRadius: 24 }} />
      ) : (
        <>
          <div className="admin-stats">
            <div className="stat-card admin-stat tone-blue">
              <span className="stat-icon"><UserIcon size={20} /></span>
              <span className="stat-label">Işjeň ulanyjylar</span>
              <strong className="stat-value">{num(data.activeUsers)}</strong>
              <span className="admin-stat-sub">giren we post açan</span>
            </div>
            <div className="stat-card admin-stat tone-green">
              <span className="stat-icon"><UserIcon size={20} /></span>
              <span className="stat-label">Täze ulanyjylar</span>
              <strong className="stat-value">{num(data.newUsers)}</strong>
            </div>
            <div className="stat-card admin-stat tone-purple">
              <span className="stat-icon"><SearchIcon size={20} /></span>
              <span className="stat-label">Gözlegler</span>
              <strong className="stat-value">{num(data.searches)}</strong>
            </div>
            <div className="stat-card admin-stat tone-red">
              <span className="stat-icon"><SparkIcon size={20} /></span>
              <span className="stat-label">Gyzyklanmasy belli</span>
              <strong className="stat-value">{num(data.usersWithTaste)}</strong>
              <span className="admin-stat-sub">«Saňa» lentasy şahsylaşdyrylan</span>
            </div>
          </div>

          <section className="card an-charts">
            <DayBars days={data.daily} pick={(d) => d.activeUsers} label="Işjeň ulanyjylar (günde)" />
            <DayBars days={data.daily} pick={(d) => d.newUsers} label="Täze ulanyjylar" />
            <DayBars days={data.daily} pick={(d) => d.views} label="Post görülişi" />
            <DayBars days={data.daily} pick={(d) => d.searches} label="Gözlegler" />
          </section>

          <div className="an-grid">
            <section className="card">
              <h2>Iň gyzykly bölümler</h2>
              <InterestBars items={data.categories} />
            </section>
            <section className="card">
              <h2><HashIcon size={18} /> Iň gyzykly bellikler</h2>
              <InterestBars items={data.tags.slice(0, 15)} tag />
            </section>
            <section className="card">
              <h2>Köp gözlenýänler</h2>
              {data.topSearches.length === 0 ? <p className="muted small">Entek gözleg ýok.</p> : (
                <ol className="an-searches">
                  {data.topSearches.map((s) => (
                    <li key={s.query}><Link href={`/?q=${encodeURIComponent(s.query)}`}>{s.query}</Link><span className="muted small">{num(s.count)}×</span></li>
                  ))}
                </ol>
              )}
            </section>
            <section className="card">
              <h2>Gözlenip tapylmadyklar</h2>
              <p className="muted small">Ulanyjylar şulary gözledi, emma hiç zat tapmady: şu temalarda post goşuň.</p>
              {data.emptySearches.length === 0 ? <p className="muted small">Ýok: hemme gözlege netije bar.</p> : (
                <ol className="an-searches">
                  {data.emptySearches.map((s) => (
                    <li key={s.query}><span>{s.query}</span><span className="muted small">{num(s.count)}×</span></li>
                  ))}
                </ol>
              )}
            </section>
            <section className="card">
              <h2>Ussalar</h2>
              {data.crafts.length === 0 ? <p className="muted small">Entek kärini saýlan ýok.</p> : (
                <ol className="an-searches">
                  {data.crafts.map((c) => (
                    <li key={c.slug}><Link href={`/shops?category=${c.slug}`}>{c.name}</Link><span className="muted small">{num(c.count)}</span></li>
                  ))}
                </ol>
              )}
            </section>
          </div>

          <section className="card">
            <h2><EyeIcon size={18} /> Iň köp görlen postlar</h2>
            {data.topPins.length === 0 ? <p className="muted small">Bu döwürde görüliş ýok.</p> : (
              <div className="an-pins">
                {data.topPins.map((p) => (
                  <Link key={p.id} href={`/pin/${p.id}`} className="an-pin">
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={p.imageUrl} alt="" loading="lazy" />
                    <span className="an-pin-title">{p.title}</span>
                    <span className="muted small"><EyeIcon size={12} /> {num(p.views)}</span>
                  </Link>
                ))}
              </div>
            )}
          </section>
        </>
      )}
    </>
  );
}
