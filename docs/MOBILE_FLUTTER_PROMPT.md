# ModaHouse Android programmasy (Flutter) üçin prompt

Bu faýl ModaHouse-yň Flutter-däki Android programmasyny döretmek üçin taýýar prompt.
Ony Claude Code ýa-da başga AI kömekçä şu repo açyk wagty bolşy ýaly beriň.
Promptyň özi iňlis dilinde ýazyldy, sebäbi tehniki talaplar şeýle has takyk düşünilýär.
Programmanyň ähli ýazgylary türkmençe bolar.

Talaplar: Flutter SDK (stable), Android Studio ýa-da Android SDK we işleýän backend (`backend/README.md` serediň).

---

## Prompt

You are working in the `modahouse` repository: a Pinterest-style app. All user-facing text is in **Turkmen**.
The repo already contains:

- `backend/`: Go Fiber v3 REST API. Run it with `cd backend && go run ./cmd/server`. It listens on `:8080`, auto-seeds demo data and allows all CORS origins.
- `docs/API.md`: the **complete API contract** (types, endpoints, auth, pagination, errors). Read it fully before writing code and follow it exactly.
- `frontend/`: the Next.js web client. Use its `app/globals.css` as the design reference.

Your task: create the Android mobile app with **Flutter** in a new folder `mobile/`, with feature parity with the web client.

### Rules

- Only create or edit files inside `mobile/`. Do not change `backend/`, `frontend/` or `docs/`. If you find a backend bug, report it instead of fixing it.
- Create the project with `flutter create --org tm.modahouse --project-name modahouse --platforms android mobile`. The Android application id must be `tm.modahouse.app` and the app label `ModaHouse`.
- Use the latest stable Flutter and Dart 3 with null safety. Keep `flutter analyze` free of warnings.
- All UI strings are Turkmen. Put them in one file (`lib/l10n/strings.dart`) so they are easy to change later.

### Packages

Use these and keep other dependencies to a minimum:

- `flutter_riverpod` for state, `go_router` for navigation.
- `dio` for HTTP with an interceptor that adds `Authorization: Bearer <token>`.
- `flutter_secure_storage` for the JWT.
- `cached_network_image` for JPG/PNG/WEBP/GIF and `flutter_svg` for SVG. **Seed images are SVG files**, so pick the widget by the `.svg` extension of the URL.
- `flutter_staggered_grid_view` (`MasonryGridView`) for the 2-column masonry feed.
- `image_picker` for gallery and camera, `share_plus` for sharing, `url_launcher` for pin links.
- `timeago` with a custom Turkmen messages class for relative times ("3 minut öň", "2 sagat öň", "dün").

### API layer

- Base URL comes from `--dart-define=API_URL=...`. Default to `http://10.0.2.2:8080` (the Android emulator's address for the host machine). On a real phone the user passes the computer's LAN IP.
- Image URLs from the API are relative (`/uploads/...`). Prefix them with the base URL in one helper.
- Errors are `{"error": "..."}` in Turkmen. Convert every failed response into an `ApiException(message, statusCode)` and show that message in a SnackBar.
- On a 401 for an authenticated request, clear the token and send the user to login.
- Write Dart model classes with `fromJson` for every type in `docs/API.md`: `UserBrief`, `Profile`, `Me`, `Pin`, `Board`, `Comment`, `Notification`, `Category`, and a generic `Page<T>` with `items`, `page`, `limit` and `hasMore`.
- Repositories per area: auth, users, pins, boards, comments, notifications.
- Pin upload is `multipart/form-data` on `POST /api/pins` with the field `image` plus `title`, `category`, `description`, `link`, `tags` and optional `boardId`. Avatar upload uses the field `avatar` on `POST /api/me/avatar`.

### Design

- Accent color `#d6336c`, pill-shaped buttons, 16 px rounded cards, 16 px side padding.
- Light and dark themes that follow the system (`ThemeMode.system`). Light background `#ffffff`, surface `#efefef`. Dark background `#121212`, surface `#262626`.
- Show the pin's `color` as a placeholder background and use `width`/`height` for the aspect ratio, so the masonry layout does not jump while images load.
- An avatar is the image when `avatarUrl` is set, otherwise a colored circle with the first letter of `name`.

### Screens

Bottom navigation with 5 tabs: **Baş sahypa**, **Gözleg**, **Döret** (a "+" button), **Bildirişler** (badge from `GET /notifications/unread-count`, polled every 60 seconds while logged in) and **Profil**.

1. **Baş sahypa**: horizontal category chips from `GET /categories`, a "Saňa" / "Yzarlanýanlar" switch (`feed=following`, only when logged in), a masonry feed with infinite scroll driven by `hasMore`, pull-to-refresh, loading skeletons and an empty state. Each card shows the image, title and author. Long-press opens the save sheet.
2. **Gözleg**: search field plus category chips. Results come from `GET /pins?q=&category=` in the same masonry grid.
3. **Pin jikme-jikligi** (`/pin/:id`): large image, title, description, tags, an "open link" button, the author row with a follow toggle (hidden on your own pin), a like toggle with count, share, and a **Sakla** button. Below are comments (list, add, delete when `canDelete`) and a "Şuňa meňzeşler" masonry from `/pins/:id/similar`. The owner gets a menu with **Üýtget** and **Poz** (confirm dialog).
4. **Save sheet** (bottom sheet): lists `GET /me/boards`. Tapping a board toggles save or unsave with `POST`/`DELETE /boards/:id/pins/:pinId`, using `savedBoardIds` to show a check mark. Include an inline "Täze tagta" field that creates a board and saves the pin into it. Logged-out users are sent to login.
5. **Pin üýtgetmek** (`/pin/:id/edit`): edit title, description, link, category and tags with `PUT /pins/:id`.
6. **Döret**: pick from gallery or camera, preview, then title, description, link, category dropdown, tags and an optional board dropdown. Show upload progress and open the new pin on success. Logged-out users see a login prompt.
7. **Profil** (own tab, plus `/user/:username` for others): avatar, name, @username, bio, follower and following counts (tapping opens a user list screen), a follow toggle for others, and a settings button on your own profile. Two tabs: **Döredilen** (user pins, masonry, infinite) and **Saklanan** (boards grid with a 3-image cover collage and a lock icon on private boards). The owner can create a board (name, description, private switch).
8. **Tagta** (`/board/:id`): header with name, description, owner, pin count and a private badge, then the board's pins in masonry. The owner can edit the board, delete it (confirm) and remove a pin from it.
9. **Bildirişler**: list with the actor avatar and a Turkmen text per type: like = "piniňizi halady", comment = "piniňize teswir ýazdy", save = "piniňizi tagtasyna sakladý", follow = "sizi yzarlap başlady". Show the pin thumbnail and relative time. Tapping opens the pin or the profile. Call `POST /notifications/read-all` when the screen opens and reset the badge.
10. **Giriş** and **Hasaba alyş**: login accepts a username or email. Show the demo hint "aylar.studio / modahouse123". Show server validation messages. Return to the screen that required login after success.
11. **Sazlamalar**: edit name, username and bio (`PUT /me`), change or remove the avatar, change the password (`PUT /me/password`) and log out.

Every screen needs loading, error (with a retry button) and empty states. Disable buttons while a request is running. Update likes, follows and saves optimistically and roll back on error.

### Android configuration

- `INTERNET` permission in `AndroidManifest.xml`.
- `android:usesCleartextTraffic="true"` so `http://` development servers work. Add a comment saying to remove it or restrict it with a network security config for production.
- The camera and photo permissions `image_picker` needs.
- `minSdk` 23 or higher. A launcher icon in the accent color (use `flutter_launcher_icons` with a locally generated PNG).

### Tests and verification

- `flutter analyze` must report no issues.
- Write unit tests for the JSON models and the API error mapping, and widget tests for the pin card and the login form. `flutter test` must pass.
- `flutter build apk --release --dart-define=API_URL=http://10.0.2.2:8080` must succeed. Note where the APK is written.
- Run the app on an emulator against the local backend. Log in as `aylar.studio`, browse the feed, open a pin, like it, comment, save it to a board, create a pin with a photo, open your profile, a board, notifications and settings, register a new user, then log out. Fix every error you see.

### Documentation

Write `mobile/README.md` in Turkmen covering:

- installing dependencies (`flutter pub get`),
- running against the emulator (`flutter run --dart-define=API_URL=http://10.0.2.2:8080`),
- running on a real phone with the computer's LAN IP,
- building the APK (`flutter build apk --release`) and the Play Store bundle (`flutter build appbundle`),
- the folder structure.

### Final report

List the files you created, the Flutter version, the result of each verification step, any backend bugs or API gaps you found, and anything left undone.
