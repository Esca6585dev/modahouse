import Avatar from "@/components/Avatar";
import ProfileTabs from "@/components/ProfileTabs";
import { boards, currentUser, getPin, pins, type Pin } from "@/lib/data";

export const metadata = { title: `${currentUser.name} · ModaHouse` };

export default function ProfilePage() {
  const created = pins.filter((p) => p.author === currentUser.handle);
  const boardData = boards.map((b) => ({
    name: b.name,
    pins: b.pinIds.map(getPin).filter((p): p is Pin => Boolean(p)),
  }));

  return (
    <div className="page">
      <section className="profile">
        <Avatar author={currentUser} size={112} />
        <h1>{currentUser.name}</h1>
        <p className="muted">@{currentUser.handle}</p>
        <p className="bio">Moda we gündelik stil boýunça ideýalar. Aşgabat 🇹🇲</p>
        <p className="stats"><strong>{currentUser.followers}</strong> yzarlaýjy · <strong>318</strong> yzarlanýan</p>
        <div className="profile-actions">
          <button className="btn btn-secondary">Paýlaş</button>
          <button className="btn btn-secondary">Profili üýtget</button>
        </div>
      </section>
      <ProfileTabs created={created} boards={boardData} />
    </div>
  );
}
