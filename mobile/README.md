# ModaHouse: Android programmasy (Flutter)

ModaHouse-yň (Modalar öýi) Pinterest bilen Instagram-yň garyndysy bolan mobil programmasy.
Ol web müşderi (`frontend/`) bilen şol bir mümkinçilikleri berýär we `backend/` REST API-si
bilen işleýär (`docs/API.md` serediň). Programmanyň ähli ýazgylary türkmençe.

## Mümkinçilikler

- **Iki görnüş:** baş sahypada Pinterest (masonry) we Instagram (bir sütünli postlar,
  karusel, iki gezek basyp halamak, soňky teswirler) görnüşleri. Saýlanan görnüş ýatda saklanýar.
- **Reels:** doly ekranly wertikal wideo lentasy, sesi açmak/ýapmak, halamak, teswir,
  paýlaşmak we saklamak.
- **"⋯" menýusy:** Sakla, Paýlaş, Ýükle, Baglanyşygy göçür, Meňzeşini tap,
  Gyzyklanmaýaryn, Şikaýat et.
- **Post görnüşleri:** Diňe paýlaşmak, Satlyk, Kärende we Sargyt bilen tikmek. Kärende we
  sargyt üçin "Habarlaş" paneli: jaň, WhatsApp, Telegram, IMO, Instagram.
- **✨ AI bilen ýaz:** post görnüşine laýyk at, düşündiriş, heşteg we baha setirini hödürleýär.
- **Surat bilen gözleg:** surat çek ýa-da galereýadan saýla, çarçuwany süýşür we
  bazadan meňzeş postlary/harytlary tap ("Diňe harytlar" saýlawy bilen).
- **Biznes hasaby:** dükan, atelýe, gelin salony, kärende salony, şaý-sep we gözellik salony;
  sosial ulgamlar, telefon, iş wagty, harytlar, sebet, sargytlar we statistika.
- Wideo we surat story-ler, heşteg sahypalary, halanlarym, gizlenen postlar we bloklamak.

## Talaplar

- Flutter SDK (stable kanal, Dart 3). Barlamak üçin: `flutter --version`.
- Android Studio ýa-da Android SDK (APK ýygnamak we emulýator üçin).
- Işleýän backend: `cd backend && go run ./cmd/server` (`:8080` portda açylýar,
  synag maglumatlaryny özi goşýar).

## Gurnamak

```bash
cd mobile
flutter pub get
```

## Emulýatorda işletmek

Android emulýatory kompýuteriň özüne `10.0.2.2` salgysy arkaly ýüzlenýär:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`API_URL` berilmese hem şu salgy ulanylýar.

Synag hasaby: **aylar.studio / modahouse123**. Beýleki synag hasaplary hem şol parol bilen
açylýar, meselem dükanlar `gyzyl.guyze`, `ak.gelin`, `altyn.gelin` (kärende),
`kesde.atelye` (sargyt bilen tikmek) we döredijiler `aysoltan.style`, `selbi.saclar`,
`nurana.nails`.

## Hakyky telefonda işletmek

Telefon we kompýuter bir Wi-Fi ulgamynda bolmaly. Kompýuteriň LAN salgysyny
tapyň (Linux/macOS: `ip addr` ýa-da `ifconfig`, Windows: `ipconfig`), soňra:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:8080
```

`192.168.1.10` ýerine öz salgyňyzy goýuň. Kompýuteriň brandmaueri 8080 portuny
açyk goýmaly.

## Serweriň salgysy (API)

Serweriň salgysy indi ýygnalanda berk berkidilmeýär, ol programma işläp durka üýtgeýär:

1. **Başlangyç salgy** ýygnalanda berilýär:
   `--dart-define=API_URL=https://api.example.tm` (berilmese release/APK ýygnamasy
   `http://216.250.11.30`, debug ýygnamasy `http://10.0.2.2:8080` ulanýar).
   Programma ilkinji gezek açylanda şu salgyny ulanýar.
2. **Admin paneli:** admin web admin panelinde (`/admin` → sazlamalar) `apiUrl` we
   `webUrl` bellese, programma fonda `GET {häzirki salgy}/api/config` soraýar.
   `apiUrl` başga bolsa, ilki `GET {täze salgy}/api/health` barlanýar we diňe
   `{"status":"ok"}` jogap gelse täze salga geçilýär we ol ýatda saklanýar.
   Ýalňyş ýazylan salgy programmany serwersiz galdyrmaýar. Barlag programma
   açylanda we yzyna gaýdyp gelnende (iň köp 10 minutda bir gezek) geçirilýär.
   Paýlaşylýan baglanyşyklar (`/pin/…`) `webUrl` boýunça ýasalýar, ol boş bolsa
   `--dart-define=WEB_URL=https://modahouse.tm` ulanylýar.
3. **Ätiýaçlyk:** häzirki serwer jogap bermese, programma başlangyç `API_URL`-a, soňra
   `--dart-define=CONFIG_URL=https://example.tm/modahouse.json` faýlyna ýüzlenýär.
   Bu faýl `GET /api/config` bilen birmeňzeş JSON:
   `{"apiUrl": "https://api.example.tm", "webUrl": "https://example.tm"}`.
   `CONFIG_URL` hökman däl, boş bolsa ulanylmaýar.
4. **Serwer sahypasy:** Sazlamalar → Serwer (ýa-da giriş sahypasyndaky
   "Serwer sazlamalary"). Bu ýerde häzirki salgy we onuň çeşmesi (ýatda saklanan,
   serwerden alnan ýa-da başlangyç) görünýär. Täze salgyny ýazyp **Barla we sakla**
   bassaňyz, programma ony barlaýar we geçýär; **Başlangyç salgy** ýygnalandaky
   `API_URL`-a gaýtarýar; **Täzeden barla** admin panelindäki salgyny häzir barlaýar.
   Üns beriň: admin panelinde başga `apiUrl` bellenen bolsa, programma indiki
   barlagda şol salga geçer.

Admin hasaby bilen girilende Sazlamalarda **Admin paneli** düwmesi peýda bolýar,
ol `{webUrl}/admin` sahypasyny brauzerde açýar.

GitHub Actions-da ýygnalýan APK başlangyç salgyny repozitoriýanyň `API_URL`
üýtgeýjisinden (Settings → Secrets and variables → Actions → Variables) alýar.
Serwer üýtgände APK-ny täzeden ýygnamak hökman däl: admin panelinde täze `apiUrl`
bellemek ýeterlik (köne serwer täze salgyny habar berer ýaly işläp durmaly).

## APK we Play Store bukjasy

```bash
# Gurnap boljak APK (API_URL berilmese, http://216.250.11.30 serwerine baglanýar)
flutter build apk --release
# Netije: build/app/outputs/flutter-apk/app-release.apk

# Google Play üçin App Bundle
flutter build appbundle --release --dart-define=API_URL=https://api.example.tm
# Netije: build/app/outputs/bundle/release/app-release.aab
```

Üns beriň:

- Häzir release ýygnamasy `debug` açary bilen gol çekilýär. Play Store-a ýüklemezden
  öň öz açaryňyzy dörediň we `android/app/build.gradle.kts` içinde `signingConfig`
  sazlaň.
- `AndroidManifest.xml` içindäki `android:usesCleartextTraffic="true"` diňe
  `http://` bilen işleýän synag serwerleri üçin. Önümçilikde API-ni `https://`
  arkaly beriň we bu sazlamany aýyryň (ýa-da `networkSecurityConfig` bilen
  çäklendiriň).
- Programmanyň ID-si `tm.modahouse.app`, ady `ModaHouse`, iň pes Android
  wersiýasy API 24 (Android 7.0).

## Barlaglar

```bash
flutter analyze   # ýalňyşlyk we duýduryş bolmaly däl
flutter test      # JSON modelleri (v1–v4), API ýalňyşlyklary, serweriň salgysy, kartoçkalar, post, ⋯ menýu, çarçuwa, giriş formasy, Serwer sahypasy
```

Web görnüşinde barlamak hem mümkin (meselem, brauzer bilen awtomatik synag üçin):

```bash
flutter build web --no-web-resources-cdn --dart-define=API_URL=http://localhost:8080
```

`--dart-define=SEMANTICS=true` goşulsa, brauzerde elýeterlilik (semantics) agajy
hemişe açyk bolýar, bu bolsa Playwright ýaly gurallar bilen düwmeleri tapmaga kömek edýär.

## Programma nyşany

Nyşan `brand/logo-mark.svg` esasynda çyzylýar: ak tegelekde gara (`#262B2F`)
"d" harpy we onuň üstünde gyzyl (`#D7263D`) öý üçegi. Programmanyň içindäki
logo (`assets/brand/`) "moda HOUSE" ýazgysy. PNG faýllary goşmaça kitaphanasyz
döredilýär, soňra `flutter_launcher_icons` olary Android ölçeglerine öwürýär:

```bash
python3 tool/make_icon.py --web     # assets/icon/*.png we web/icons/*.png
dart run flutter_launcher_icons     # android/app/src/main/res/mipmap-*
```

## Bukjalaryň gurluşy

```
mobile/
├── lib/
│   ├── main.dart              # giriş nokady (ProviderScope)
│   ├── app.dart               # MaterialApp.router, ýagtylyk/garaňkylyk temalary
│   ├── router.dart            # go_router: aşaky 5 bölüm we beýleki sahypalar
│   ├── config.dart            # häzirki serweriň salgysy, URL normalizasiýasy, surat salgylary
│   ├── l10n/
│   │   ├── strings.dart       # ähli türkmençe ýazgylar şu ýerde
│   │   └── material_tk.dart   # Flutter-iň öz düwmeleri üçin türkmençe ýazgylar
│   ├── core/                  # Dio müşderisi, ApiException, serweri saýlamak (server_config),
│   │                          # tema, format, SnackBar,
│   │                          # ýükläp almak we wideo maglumatlary (platforma boýunça)
│   ├── models/                # UserBrief, Profile, Me, Pin, Board, Comment,
│   │                          # Notification, Category, Page<T>, Business,
│   │                          # Product, Cart, Order, Review, Story, TopEntry,
│   │                          # surat bilen gözlegiň netijeleri
│   ├── data/                  # repozitoriýalar: auth, users, pins, boards,
│   │                          # comments, notifications, business, cart,
│   │                          # orders, reviews, stories, ai
│   ├── state/                 # Riverpod: giriş ýagdaýy, bildiriş sanawy,
│   │                          # sahypalaýyn ýükleýji, pin üýtgeşmeleri,
│   │                          # ýatda saklanýan sazlamalar (lenta görnüşi)
│   ├── widgets/               # pin kartoçkasy, Instagram posty, masonry tor,
│   │                          # ⋯ menýu, wideo, çarçuwa, AI paneli, habarlaşmak
│   │                          # paneli, sakla paneli, awatar, ýagdaý görnüşleri
│   └── screens/               # baş sahypa (story), gözleg, reels, surat bilen
│                              # gözleg, heşteg, pin/haryt, döret,
│                              # Top 10, dükanlar, profil, sebet, sargyt,
│                              # sargytlarym, biznes paneli, bildirişler,
│                              # giriş/hasaba alyş, sazlamalar, serwer
├── test/                      # unit we widget testleri
├── assets/icon/               # nyşanyň çeşme PNG faýllary
├── tool/make_icon.py          # nyşan döredijisi
├── android/                   # Android taslamasy
└── web/                       # web görnüşi (synag üçin)
```

## Ulanylýan bukjalar

`flutter_riverpod` (ýagdaý), `go_router` (nawigasiýa), `dio` (HTTP),
`flutter_secure_storage` (JWT saklamak), `cached_network_image` we `flutter_svg`
(suratlar; synag suratlary SVG), `flutter_staggered_grid_view` (masonry tor),
`image_picker` (galereýa we kamera), `share_plus` (paýlaşmak), `url_launcher`
(baglanyşyklar, jaň we habarlaşmak), `timeago` (türkmençe wagt: "3 minut öň", "dün"),
`video_player` (reels we wideo postlar), `shared_preferences` (lenta görnüşini we serweriň salgysyny ýatda saklamak).

Üns beriň: synag reels-leri WebM formatynda. Android-de işleýär, iOS üçin MP4 gerek bolar.
