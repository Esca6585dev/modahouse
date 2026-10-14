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

## Mümkinçilikler

- **Pinterest bölegi:** pinler, tagtalar, halamak, teswirler, yzarlamak, gözleg we bildirişler.
- **Biznes hasaby:** Instagram-yň hünärmen hasaby ýaly. Kategoriýa, telefon, şäher, iş wagty we eltip bermek möhleti görkezilýär.
- **Harytlar:** her harydyň 8-e çenli suraty, bahasy, köne bahasy, reňkleri, ölçegleri, galyndysy we materialy bolýar.
- **Sebet we sargyt:** sargyt her dükan üçin aýratyn döredilýär. Galyndy sargyt wagtynda saklanýar we sargyt ýatyrylsa yzyna gaýtarylýar.
- **Sargyt ýagdaýlary:** Täze → Tassyklandy → Ýolda → Gowşuryldy ýa-da Ýatyryldy.
- **Synlar:** harydy alan müşderiler 1-5 ýyldyz bilen baha berip bilýär.
- **Top 10 reýtingi:** görülme, halanma, sargyt we baha boýunça hasaplanýar. Ol hepde, aý we ähli wagt üçin bar.
- **Story:** 24 sagatlyk, görlen ýa-da görülmedik ýagdaýy bilen.

Demo dükanlar: `gyzyl.guyze`, `soygi.tikincilik`, `ak.gelin`, `merjen.tikincilik`, `mahri.stili`, `aylar.studio` we `yyldyz.butik`.
Olaryň paroly `modahouse123`. Demo story-lar baza döredilenden 24 sagat soň gutarýar.

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
| `MAX_VIDEO_MB` | Wideo ölçeginiň çägi (adaty: 60) |
| `ANTHROPIC_API_KEY`, `AI_MODEL` | AI kömekçisi (Claude). Açar ýok bolsa taýýar nusgalar ulanylýar |
| `ADMIN_USERNAME`, `ADMIN_PASSWORD` | Serwer açylanda bu ulanyjy admin bolýar; ýok bolsa we parol (≥ 8 simwol) berlen bolsa döredilýär. Bar bolan paroly üýtgetmeýär |
| `PUBLIC_API_URL`, `PUBLIC_WEB_URL` | `GET /api/config` üçin başlangyç salgylar; admin panelinden berlen bahalar bulardan öňde durýar |

Ýerli synag üçin demo ulanyjyny admin etmek: `ADMIN_USERNAME=aylar.studio go run ./cmd/server`, soňra `http://localhost:3000/admin`.
