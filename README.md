# ModaHouse

Pinterest görnüşli ideýalar tagtasy. Next.js we React bilen ýazylan, häzirlikçe diňe UI.

## Sahypalar

- `/` baş sahypa: kategoriýalar, gözleg we masonry pin tory
- `/pin/[id]` pin jikme-jikligi: saklamak, teswirler, meňzeş pinler
- `/create` täze pin döretmek formasy
- `/profile` profil: döredilen pinler we tagtalar

Pinleriň suratlary `components/PinArt.tsx` içinde SVG bilen çyzylýar, şonuň üçin daşarky surat serweri gerek däl.
Maglumatlar `lib/data.ts` faýlynda saklanýar, backend ýok.

## Işletmek

```bash
npm install
npm run dev
```

Soňra brauzerde http://localhost:3000 açyň.
