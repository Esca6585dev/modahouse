# ModaHouse

Pinterest görnüşli ideýalar tagtasy: pinleri tap, sakla, tagtalara ýygna we paýlaş.
Ähli bölekler şu bir repoda ýerleşýär.

```
modahouse/
├── backend/    Go + Fiber v3 REST API (PostgreSQL ýa-da SQLite)
├── frontend/   Next.js + React web programmasy
├── mobile/     Flutter Android programmasy
├── docs/       API resminamasy we Flutter prompty
└── docker-compose.yml
```

| Bukja | Tehnologiýa | Jikme-jiklik |
|---|---|---|
| `backend/` | Go 1.26, Fiber v3, GORM, JWT | [backend/README.md](backend/README.md) |
| `frontend/` | Next.js 16, React 19, TypeScript | [frontend/](frontend/) |
| `mobile/` | Flutter, Dart 3 | [mobile/README.md](mobile/README.md) |
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

Demo hasaplar: `aylar.studio`, `ic.bezeg`, `tagam.tm`, `gezelenc`, `renk.lab`, `yasyl.burc`. Paroly: `modahouse123`.

## Docker bilen

PostgreSQL, backend we web programmany bilelikde işletmek üçin:

```bash
JWT_SECRET=uzyn-tötänleýin-setir docker compose up --build
```

Web: http://localhost:3000, API: http://localhost:8080/api.
