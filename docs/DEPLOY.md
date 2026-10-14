# ModaHouse-y serwere ýerleşdirmek

Bu gollanma ModaHouse-y öz serweriňizde işletmek üçin. Serwerde dört bölek işleýär:

- **PostgreSQL:** maglumatlar binýady;
- **Go API:** `backend/`;
- **Next.js web:** `frontend/`;
- **Caddy:** HTTPS şahadatnamasyny özi alýar we sorag-jogaplary bölekleriň arasynda paýlaýar.

Ähli bölek bir domende işleýär:

- `https://DOMEN/`: web sahypa;
- `https://DOMEN/api/...` we `https://DOMEN/uploads/...`: API we ýüklenen suratlar/wideolar (göni Go serwerine gidýär);
- `https://DOMEN/admin`: admin paneli.

## 1. Talaplar

- **Serwer:** Ubuntu 22.04 ýa-da 24.04 (ýa-da başga Linux). Azyndan 2 GB RAM, 20 GB disk.
- **Domen (maslahat berilýär):** mysal üçin `modahouse.tm`. Domen ýok bolsa, IP salgy bilen HTTP arkaly hem işleýär (aşakda serediň).
- **Açyk portlar:** 80 we 443.

## 2. Docker-i gurnamak

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # soňra serwere täzeden giriň
```

## 3. Kody serwere almak

```bash
git clone https://github.com/Esca6585dev/modahouse.git
cd modahouse/deploy
```

Repo ýapyk (private) bolsa, GitHub-da **Settings → Developer settings → Personal access tokens** bölüminden diňe okamak hukukly token dörediň. Klonlanda paroluň ýerine şol tokeni giriziň.

## 4. Sazlamalar (`.env`)

```bash
cp .env.example .env
openssl rand -hex 32   # POSTGRES_PASSWORD üçin
openssl rand -hex 32   # JWT_SECRET üçin
nano .env
```

Doldurmaly zatlar:

| Ady | Mysal | Düşündiriş |
|---|---|---|
| `DOMAIN` | `modahouse.tm` | Domeniňiz. Domen ýok bolsa `:80` goýuň. |
| `POSTGRES_PASSWORD` | uzyn tötänleýin setir | Binýadyň paroly. |
| `JWT_SECRET` | uzyn tötänleýin setir | Giriş tokenleriniň açary. Soňra üýtgetseňiz, hemme ulanyjy täzeden girmeli bolar. |
| `ADMIN_USERNAME` / `ADMIN_PASSWORD` | `admin` / azyndan 8 simwol | Ilkinji administrator. |
| `PUBLIC_API_URL` / `PUBLIC_WEB_URL` | `https://modahouse.tm` | Programmalar üçin başlangyç salgylar. Admin panelinden hem üýtgedip bolýar. |
| `SEED` | `true` | Ilkinji açylyşda synag postlaryny goşýar. |
| `ANTHROPIC_API_KEY` | | Boş bolsa, AI kömekçisi taýýar nusgalar bilen işleýär. |

**Administrator barada:**
- `ADMIN_USERNAME` atly ulanyjy ýok bolsa, ol şu parol bilen döredilýär. Bar bolsa, admin hukugy berilýär, paroly bolsa üýtgemeýär.
- Başga administratorlary admin panelinden bellemek bolýar.

**Synag maglumatlary barada:**
- Synag hasaplarynyň paroly hemmä belli (`modahouse123`).
- Hakyky işe başlanyňyzda synag ulanyjylaryny admin panelinden petikläň ýa-da serweri `SEED=false` bilen arassa binýatdan başlaň.

## 5. DNS

Domeniňiziň DNS sazlamalarynda `A` ýazgysyny serweriň IP salgysyna görkeziň.

DNS işlemänkä Caddy HTTPS şahadatnamasyny alyp bilmez. Şonuň üçin ilki DNS-i sazlaň, soňra işlediň.

## 6. Işletmek

```bash
docker compose up -d --build
docker compose logs -f backend    # Ctrl+C bilen çykyň
```

Barlamak üçin:

- `https://DOMEN`: web sahypa açylmaly.
- `https://DOMEN/api/health`: `{"status":"ok"}` görkezmeli.
- `https://DOMEN/admin`: `ADMIN_USERNAME` / `ADMIN_PASSWORD` bilen giriň.

## 7. Admin paneli

| Bölüm | Näme edýär |
|---|---|
| **Umumy** | Ulanyjy, post, haryt, wideo, sargyt we şikaýat sanlary. |
| **Sazlamalar** | **API salgysy (programmalar üçin):** Android programmalary şu salgyny serwerden okaýarlar we täze salgy jogap berenden soň oňa geçýärler. Ýazyp, "Barla" düwmesine basyň, ✓ çykandan soň saklaň.<br>**Web salgysy:** paýlaşylan baglanyşyklar üçin.<br>**Täze hasap açmak:** ýapyp ýa-da açyp bolýar. |
| **Ulanyjylar** | Gözleg, admin bellemek, tassyklamak (✓ nyşan) we petiklemek. |
| **Şikaýatlar** | Şikaýat edilen postlar. Postuň özüni pozmak ýa-da şikaýatlary ýapmak bolýar. |

Web serweriniň öz API salgysy `BACKEND_URL` üýtgeýjisi bilen berilýär. Ol diňe serwer işläp başlanda okalýar. Üýtgetmek üçin `deploy/docker-compose.yml` faýlyny düzediň we `docker compose up -d` buýrugyny işlediň. Täzeden ýygnamak (rebuild) gerek däl.

## 8. Android APK

APK-nyň içine ilkinji açylyş üçin başlangyç salgy ýazylýar. Soňra programma salgyny admin panelinden özi alýar.

1. GitHub-da repo → **Settings → Secrets and variables → Actions → Variables** bölümine giriň.
2. Şu üýtgeýjileri goşuň:
   - `API_URL` = `https://modahouse.tm`
   - `WEB_URL` = `https://modahouse.tm`
   - `CONFIG_URL` (hökman däl): serwer düýbünden işlemese, programmalar täze salgyny şu JSON faýldan okaýar. Mysal: `{"apiUrl":"https://new.modahouse.tm","webUrl":"https://modahouse.tm"}`. Faýl açyk elýeterli ýerde bolmaly.
3. **Actions** bölüminde iň soňky "CI" işini açyň we **Re-run all jobs** basyň.
4. Iş gutaranda `modahouse-apk` artefaktyny ýükläň.

Köne APK gurnalan telefonlarda serweriň salgysyny programmanyň içinden üýtgedip bolýar: **Sazlamalar → Serwer**.

## 9. Serweri ýa-da domeni üýtgetmek

1. Täze serwerde ModaHouse-y işlediň (maglumatlary göçürmek üçin aşakdaky ätiýaçlyk bölümine serediň).
2. Köne serweriň admin panelinde **API salgysy** meýdanyna täze salgyny ýazyň, "Barla" basyň we saklaň.
3. Programmalar indiki gezek açylanda täze salgynyň işleýändigini barlaýarlar we oňa geçýärler.
4. Ähli ulanyjy geçenden soň köne serweri öçürip bilersiňiz.

## 10. Täzelemek

```bash
cd modahouse && git pull
cd deploy && docker compose up -d --build
```

## 11. Ätiýaçlyk nusga (backup)

```bash
cd modahouse/deploy
# Binýat
docker compose exec -T db pg_dump -U moda modahouse > modahouse-$(date +%F).sql
# Ýüklenen suratlar we wideolar
docker run --rm -v modahouse_uploads:/data -v "$PWD":/backup alpine \
  tar czf /backup/uploads-$(date +%F).tgz -C /data .
```

Dikeltmek (täze, boş serwerde):

```bash
docker compose exec -T db psql -U moda modahouse < modahouse-2026-10-14.sql
docker run --rm -v modahouse_uploads:/data -v "$PWD":/backup alpine \
  tar xzf /backup/uploads-2026-10-14.tgz -C /data
```

## Domen ýok bolsa (diňe IP)

`.env` faýlynda şeýle goýuň:

```
DOMAIN=:80
PUBLIC_API_URL=http://SERWERIŇ_IP_SALGYSY
PUBLIC_WEB_URL=http://SERWERIŇ_IP_SALGYSY
```

Bu ýagdaýda HTTPS bolmaz, şonuň üçin diňe synag üçin ulanyň.

Domen alanyňyzdan soň şeýle ediň:

1. `DOMAIN` setirini domen bilen çalşyp, `docker compose up -d` buýrugyny işlediň.
2. Admin panelinde API salgysyny `https://DOMEN` bilen çalşyň. Programmalar özleri geçerler.

## Kömekçi buýruklar

```bash
docker compose ps                  # haýsy bölekler işleýär
docker compose logs -f caddy       # HTTPS / domen ýalňyşlyklary
docker compose restart backend     # API-ni täzeden başlatmak
sudo ufw allow 80,443/tcp          # brandmauer ulanylýan bolsa
```
