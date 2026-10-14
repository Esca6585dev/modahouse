# ModaHouse

[![CI](https://github.com/Esca6585dev/modahouse/actions/workflows/ci.yml/badge.svg)](https://github.com/Esca6585dev/modahouse/actions/workflows/ci.yml)

**ModaHouse (Modalar öýi):** türkmen gelin-gyzlarynyň moda öýi. Pinterest bilen Instagram-yň garyndysy.

- Köýnekleri, ýaka fasonlaryny, el keşdelerini, saç, makiýaž we dyrnak ideýalaryny tapyp, saklap we paýlaşyp bolýar.
- Reels, biznes hasaplary, satlyk, kärende we sargyt bilen tikmek, AI kömekçisi we surat boýunça gözleg bar.
- Administratorlar üçin admin paneli bar.

Ähli bölekler şu bir repoda ýerleşýär.

```
modahouse/
├── backend/    Go + Fiber v3 REST API (PostgreSQL ýa-da SQLite)
├── frontend/   Next.js + React web programmasy
├── mobile/     Flutter Android programmasy
├── deploy/     önümçilik serweri: Docker Compose + Caddy (HTTPS)
├── docs/       API resminamasy, serwere ýerleşdirmek we promptlar
└── docker-compose.yml   ýerli işletmek üçin
```

| Bukja | Tehnologiýa | Jikme-jiklik |
|---|---|---|
| `backend/` | Go 1.26, Fiber v3, GORM, JWT | [backend/README.md](backend/README.md) |
| `frontend/` | Next.js 16, React 19, TypeScript | [frontend/](frontend/) |
| `mobile/` | Flutter, Dart 3 | [mobile/README.md](mobile/README.md) |
| `deploy/` | Docker Compose, Caddy | [docs/DEPLOY.md](docs/DEPLOY.md) |
| `docs/` | API beýany | [docs/API.md](docs/API.md) |

## Çalt başlamak

1. Backend-i işlediň. SQLite bilen goşmaça hiç zat gerek däl, boş baza demo maglumatlar bilen doldurylýar:

   ```bash
   cd backend
   go run ./cmd/server
   ```

2. Web programmany işlediň we http://localhost:3000 açyň:

   ```bash
   cd frontend
   npm install
   npm run dev
   ```

3. Android programmany emulýatorda işlediň:

   ```bash
   cd mobile
   flutter pub get
   flutter run --dart-define=API_URL=http://10.0.2.2:8080
   ```

Demo hasaplar: `aylar.studio`, `gyzyl.guyze`, `ak.gelin`, `altyn.gelin`, `aysoltan.style`, `selbi.saclar`. Paroly: `modahouse123`.
Admin paneli (`/admin`) üçin backend-i `ADMIN_USERNAME=aylar.studio` bilen işlediň.

## Docker bilen

PostgreSQL, backend we web programmany bilelikde işletmek üçin:

```bash
JWT_SECRET=uzyn-tötänleýin-setir docker compose up --build
```

Web: http://localhost:3000, API: http://localhost:8080/api.

## Serwere ýerleşdirmek

Öz serweriňizde domen we HTTPS bilen işletmek üçin [docs/DEPLOY.md](docs/DEPLOY.md) gollanmasyna serediň:

```bash
cd deploy && cp .env.example .env   # doldurmaly
docker compose up -d --build
```

**Serweriň salgysy programmalara gaty ýazylmaýar:**
- Web serwer API salgysyny (`BACKEND_URL`) diňe işläp başlanda okaýar, şonuň üçin ony üýtgetmek üçin täzeden ýygnamak gerek däl.
- Android programmalary salgyny `GET /api/config` arkaly alýarlar. Ony admin panelinden üýtgedip bolýar.

## CI

Her `push` we PR-da GitHub Actions şulary barlaýar:

- **Backend:** `gofmt`, `go vet`, SQLite we PostgreSQL 16 bilen testler.
- **Frontend:** `npm ci` we `npm run build`, şol sanda TypeScript barlagy.
- **Mobile:** `dart format`, `flutter analyze`, `flutter test` we release APK gurmak. APK faýly işiň "Artifacts" bölüminden ýüklenip alynýar.
- **Docker:** backend we frontend obrazlaryny gurmak.
