# ModaHouse: doly taslama prompty

Bu faýl ModaHouse taslamasynyň doly beýany we AI kömekçiler üçin taýýar prompt.
Ony Claude Code ýa-da başga AI kömekçä şu repo açyk wagty bolşy ýaly beriň. Kömekçi bar zady öwrenip, ýetmeýän bölekleri goşar.

Promptyň özi iňlis dilinde ýazyldy, sebäbi tehniki talaplar şeýle has takyk düşünilýär. Programmanyň ähli ýazgylary türkmençe bolmaly.

---

## Prompt

You are building **ModaHouse** ("Modalar öýi"), the fashion home of Turkmen women and girls: a place to
discover, save and share Turkmen dresses (köýnekler), collar styles (ýaka fasonlary), hand embroidery
(el keşdeleri), wedding and bridal wear, hair styles, make-up, nails and jewellery, and to buy, rent or
order them from shops and ateliers. All user-facing text is Turkmen. It must feel as polished as
Pinterest and Instagram combined, on the web and on Android.

The repository is a monorepo. Read these first and follow them:

- `backend/`: Go + Fiber v3 + GORM (PostgreSQL or SQLite). Its README describes the existing features.
- `frontend/`: Next.js web app.
- `mobile/`: Flutter Android app.
- `docs/API.md`: the API contract. Extend it for every new endpoint before implementing it.
- `brand/README.md`: the design system. The logo files are in `brand/`.

### 1. Brand

- **Logo:** Use the owner's logo: thin rounded lowercase "moda" in ink `#262B2F`, a red house roof (^) above the "d", and a red "HOUSE" below.
  - Files: `logo-wordmark.svg`, `logo-wordmark-light.svg` (dark mode), `logo-mark.svg` (app icon: the roofed "d") and `logo-badge.svg`.
- **Colors:** brand red `#D7263D`, ink `#262B2F`, white surfaces and Instagram's gradient for story rings.
- **Overall feel:** Clean, image-first, generous whitespace, rounded 16–24 px media, pill buttons. Light and dark mode.

### 2. Two ways to browse the same content

Every piece of content is a **post** (a "pin"). The home feed has a view switch:

- **Pinterest view:** A masonry grid of media cards with the title and author below.
  - Under every card, on the right, there is a "⋯" button (Pinterest style).
  - The ⋯ menu offers: Sakla (save to a board), Paýlaş (share), Ýükle (download the image), Baglanyşygy göçür (copy link), Gyzyklanmaýaryn (hide), Şikaýat et (report).
- **Instagram view:** A single column of full-width posts. Each post shows:
  - a header with the avatar (with a story ring), the name, a verified tick and the ⋯ menu;
  - the media, as a carousel with dots or a video;
  - an action row: like with a double-tap heart animation, comment, share, and save on the right;
  - the like count, the caption with "… köpräk", "N teswiriň hemmesini gör", the two latest comments and the relative time.

The chosen view is remembered. Profiles offer the same two views (a grid like Instagram, and masonry).

### 3. Posts, video and reels

- **Media:** A post has 1–10 media items. Each one is an image (JPG, PNG or WEBP) or a short video (MP4 or WebM, up to 60 s).
  - Videos have a poster image, which the client generates from the first frame.
- **Reels:** A full-screen vertical video feed with swipe up and down, autoplay muted, tap to unmute, and a like/comment/share/save rail.
  - It has its own entry in the navigation.
  - Videos also appear in both feeds, with a ▶ badge.
- **Captions:** An Instagram-style caption with hashtags (#toýköýnek) and mentions (@ady).
- **Stories:** 24-hour stories (already implemented) can be images or videos.

### 4. Listing types (what the post is for)

When creating a post, the author picks its purpose. The form changes accordingly:

| Type | Turkmen | Who | Extra fields | Primary button |
|---|---|---|---|---|
| post | Diňe paýlaşmak | everyone | none | none |
| sale | Satlyk | business | price, old price, colors, sizes, stock, delivery/return days, material | "Sebede goş" / "Zakaz et" (cart and checkout, already implemented) |
| rent | Kärende | business | price per day, deposit, min. days, sizes, colors | "Kärendä al" → contact sheet |
| custom | Sargyt bilen tikmek | business | price "…-dan başlap", ready in N days, fabric options | "Sargyt et" → contact sheet |

The contact sheet lists the business's phone (call), WhatsApp, Telegram, IMO and Instagram, and copies a prefilled message: "Salam! ModaHouse-da «{title}» gördüm…".

### 5. AI writing assistant

The create screen has a "✨ AI bilen ýaz" button. It sends the chosen listing type, the category, the title so far, short notes (for example a price or a fabric) and the first image to `POST /api/ai/suggest`. The server calls Claude with the image and returns, in Turkmen:

- a title and an Instagram-style description that fits the listing type;
- 5–10 hashtags;
- the suggested category;
- for sale, rent and custom: suggested wording for the price line, condition and the details buyers ask about. Examples: "Günlük kärende: 250 TMT, girew: 500 TMT"; "Ölçegiňize görä 10 günde tikilýär".

The user can insert, edit or regenerate the suggestion. Without an API key the server returns good template suggestions per listing type, so the feature never breaks.

### 6. Business accounts (Instagram-style professional profile)

- **Who it is for:** shops, ateliers (atelýe), bridal salons, rental salons, jewellers and beauty salons.
- **What it adds:** A category, city, address, working hours, phone, and social links (Instagram, TikTok, Telegram, WhatsApp, IMO, YouTube, website), all shown as buttons on the profile. There is also a verified tick, plus the dashboard, orders and stats that already exist.
- **Discovery:** The Top 10 ranking and the shop directory already exist. Extend them with the new business categories.

### 7. Categories (Turkmen fashion first)

| Slug | Turkmen |
|---|---|
| `toy` | Toý köýnekleri |
| `gelin` | Gelin lybaslary |
| `milli` | Milli köýnekler |
| `yaka` | Ýaka fasonlary |
| `keshde` | El keşdeleri |
| `gundelik` | Gündelik moda |
| `sac` | Saç düzümleri |
| `makiyaj` | Makiýaž |
| `dyrnak` | Dyrnak dizaýny |
| `shay` | Şaý-sepler |
| `aksessuar` | Aksessuarlar |

Remove categories unrelated to fashion. Chips on the home feed use these categories.

### 8. Everything a user needs

- **Account:** Registration and login, an Instagram-style profile with an edit screen, and follow and unfollow.
- **Content:** Boards (Pinterest "tagtalar") and saving from anywhere. Search across posts, people, shops and hashtags.
- **Activity:** Notifications, and a list of liked posts.
- **Managing posts:** Edit and delete your own posts, and download or share any post.
- **Safety:** Report a post, hide a post, and block a user.

### 9. Demo content

The seed must make the app look alive on first start:

- at least 150 posts across all categories, written in Turkmen with hashtags;
- about 20 creators (fictional Turkmen names);
- 7+ businesses, each with products for sale, rent and custom tailoring;
- likes, comments, saves, follows, delivered orders with reviews, stories and at least 6 reels.

No real people or real brands. Illustrations are generated (SVG); reels are short generated WebM clips.

### 10. Search by photo (Pinduoduo / TikTok style)

The search bar and the create flow have a camera button.

1. The user takes or picks a photo. They can also take one of a post on screen ("Meňzeşini tap" in the ⋯ menu and on every product page).
2. An adjustable crop frame shows around the main item, and the user can drag its corners.
3. The app shows similar posts and products from the database right away, with a "Diňe harytlar" switch.
4. Moving the frame searches again.

The server implements `POST /api/search/image` and `GET /api/pins/:id/visual`. It uses its own visual descriptors (colour, shape, pattern), and Claude-detected categories boost the ranking when an API key is set.

### 11. Admin panel and server address

- **Admin panel:** `/admin` on the web, for admins only. It has four sections:
  - **Umumy:** statistics;
  - **Sazlamalar:** the public API address for apps, the web address for shared links, and whether registration is open;
  - **Ulanyjylar:** search, appoint admins, verify and suspend users;
  - **Şikaýatlar:** reported posts, which can be deleted or dismissed.
  The first admin comes from `ADMIN_USERNAME`/`ADMIN_PASSWORD`.
- **No hard-coded server address:**
  - The web server reads `BACKEND_URL` when it starts.
  - Android apps read `GET /api/config` and switch to a new `apiUrl` only after its `/api/health` answers. If the server is unreachable, they fall back to the build default and the optional `CONFIG_URL`.
  - Users can also set the address by hand (Sazlamalar → Serwer).
- **Production:** `deploy/` (Docker Compose, PostgreSQL, Caddy with automatic HTTPS, one domain for web and API). The guide is `docs/DEPLOY.md`.

### 12. Platforms and quality bar

- Web (Next.js), Android (Flutter, release APK built in CI) and the shared Go API.
- Pixel-level polish at 390 px phone width and on desktop.
- Every screen has loading, empty and error states. Likes, saves and follows are optimistic.
- Accessible labels, keyboard navigation on the web, and no layout shift (use aspect ratios and placeholder colors).
- CI must stay green:
  - Go: `gofmt`, `go vet`, and tests on SQLite and PostgreSQL;
  - web: `npm run build`;
  - Flutter: `dart format`, `flutter analyze`, `flutter test` and the APK build;
  - Docker image builds.
- Add tests for every new backend endpoint and for new client models and widgets. Verify end to end in a browser at phone and desktop sizes and look at the screenshots.

### Deliverables

- The extended `docs/API.md`.
- Backend, web and Android implementations.
- Updated READMEs in Turkmen.
- Screenshots of: home in both views, reels, post detail, the ⋯ menu, create with AI, rent listing with the contact sheet, business profile, Top 10, cart and orders.
