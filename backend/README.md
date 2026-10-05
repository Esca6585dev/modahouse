# ModaHouse backend

Go + [Fiber v3](https://gofiber.io) REST API. Maglumat bazasy GORM arkaly PostgreSQL ýa-da SQLite.
Ähli endpointleriň beýany: [`../docs/API.md`](../docs/API.md).

## Gurluşy

```
cmd/server        programmanyň giriş nokady
internal/config   gurşaw üýtgeýänleri (env)
internal/database GORM birikmesi we migrasiýa
internal/models   maglumat bazasynyň shemasy
internal/api      HTTP marşrutlary, JWT, işleýjiler we testler
internal/storage  suratlary diskde saklamak (JPG/PNG/GIF/WEBP)
internal/seed     demo ulanyjylar, pinler we SVG suratlar
```

## Işletmek

Iň ýönekeý ýol SQLite bilen, goşmaça hiç zat gurnamak gerek däl:

```bash
cd backend
go run ./cmd/server
```

API `http://localhost:8080/api` salgysynda açylýar. Boş baza demo maglumatlar bilen doldurylýar.
Demo hasaplar: `aylar.studio`, `ic.bezeg`, `tagam.tm`, `gezelenc`, `renk.lab`, `yasyl.burc`. Paroly: `modahouse123`.

PostgreSQL bilen:

```bash
cp .env.example .env   # sazlamalary üýtgediň
set -a; . ./.env; set +a
go run ./cmd/server
```

## Testler

```bash
go test ./...
# PostgreSQL bilen. Shema her testden öň arassalanýar, şonuň üçin aýratyn baza ulanyň!
TEST_POSTGRES_URL="postgres://moda:moda@localhost:5432/modahouse_test?sslmode=disable" go test ./internal/api/
```

## Sazlamalar

| Üýtgeýän | Bellik |
|---|---|
| `PORT` | Adaty: 8080 |
| `DB_DRIVER` | `postgres` ýa-da `sqlite` (adaty: sqlite) |
| `DATABASE_URL` | Postgres DSN ýa-da SQLite faýly (adaty: `modahouse.db`) |
| `JWT_SECRET` | Önümçilikde hökman üýtgediň |
| `UPLOAD_DIR` | Suratlaryň bukjasy, `/uploads/...` salgysynda berilýär |
| `CORS_ORIGINS` | Rugsat berlen çeşmeler, otur bilen |
| `SEED` | `true` bolsa boş baza demo maglumatlar bilen doldurylýar |
| `MAX_UPLOAD_MB` | Surat ölçeginiň çägi |
| `TOKEN_TTL_DAYS` | JWT möhleti |
| `TRUSTED_PROXIES` | `X-Forwarded-For` sözbaşysyna ynanylýan proksiler (adaty: `127.0.0.1,::1`). `private` ähli içki torlara ynanýar |
