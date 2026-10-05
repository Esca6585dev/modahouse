# ModaHouse: Android programmasy (Flutter)

ModaHouse-yň Pinterest görnüşli mobil programmasy. Ol web müşderi (`frontend/`) bilen
şol bir mümkinçilikleri berýär we `backend/` REST API-si bilen işleýär
(`docs/API.md` serediň). Programmanyň ähli ýazgylary türkmençe.

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

Synag hasaby: **aylar.studio / modahouse123** (beýleki synag ulanyjylary:
`ic.bezeg`, `tagam.tm`, `gezelenc`, `renk.lab`, `yasyl.burc`, paroly şol bir).

## Hakyky telefonda işletmek

Telefon we kompýuter bir Wi-Fi ulgamynda bolmaly. Kompýuteriň LAN salgysyny
tapyň (Linux/macOS: `ip addr` ýa-da `ifconfig`, Windows: `ipconfig`), soňra:

```bash
flutter run --dart-define=API_URL=http://192.168.1.10:8080
```

`192.168.1.10` ýerine öz salgyňyzy goýuň. Kompýuteriň brandmaueri 8080 portuny
açyk goýmaly.

## APK we Play Store bukjasy

```bash
# Gurnap boljak APK
flutter build apk --release --dart-define=API_URL=http://10.0.2.2:8080
# Netije: build/app/outputs/flutter-apk/app-release.apk

# Google Play üçin App Bundle
flutter build appbundle --release --dart-define=API_URL=https://api.example.com
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
flutter test      # JSON modelleri, API ýalňyşlyklary, pin kartoçkasy, giriş formasy
```

Web görnüşinde barlamak hem mümkin (meselem, brauzer bilen awtomatik synag üçin):

```bash
flutter build web --no-web-resources-cdn --dart-define=API_URL=http://localhost:8080
```

`--dart-define=SEMANTICS=true` goşulsa, brauzerde elýeterlilik (semantics) agajy
hemişe açyk bolýar, bu bolsa Playwright ýaly gurallar bilen düwmeleri tapmaga kömek edýär.

## Programma nyşany

Nyşan aksent reňkinde (`#d6336c`) ak "M" harpy. PNG faýllary goşmaça
kitaphanasyz döredilýär, soňra `flutter_launcher_icons` olary Android ölçeglerine
öwürýär:

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
│   ├── config.dart            # API_URL we surat salgylaryny doly salga öwürmek
│   ├── l10n/
│   │   ├── strings.dart       # ähli türkmençe ýazgylar şu ýerde
│   │   └── material_tk.dart   # Flutter-iň öz düwmeleri üçin türkmençe ýazgylar
│   ├── core/                  # Dio müşderisi, ApiException, tema, format, SnackBar
│   ├── models/                # UserBrief, Profile, Me, Pin, Board, Comment,
│   │                          # Notification, Category, Page<T>
│   ├── data/                  # repozitoriýalar: auth, users, pins, boards,
│   │                          # comments, notifications
│   ├── state/                 # Riverpod: giriş ýagdaýy, bildiriş sanawy,
│   │                          # sahypalaýyn ýükleýji, pin üýtgeşmeleri
│   ├── widgets/               # pin kartoçkasy, masonry tor, sakla paneli,
│   │                          # awatar, tagta kartoçkasy, ýagdaý görnüşleri
│   └── screens/               # baş sahypa, gözleg, pin, döret, profil, tagta,
│                              # bildirişler, giriş/hasaba alyş, sazlamalar
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
(pin baglanyşyklary), `timeago` (türkmençe wagt: "3 minut öň", "dün").
