import type { Metadata, Viewport } from "next";
import Header, { BottomNav } from "@/components/Header";
import Providers from "@/components/Providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "ModaHouse — fasonlar, köýnekler we tikinçiler",
  description:
    "Fasonlar we köýnek fasonlary: milli köýnekler, ştapel fasonlar, gelin we toý köýnekleri, ýaka fasonlary, el keşdeleri. " +
    "Tikinçiler, el keşdeçiler, kirpikçiler we dyrnakçylar bir ýerde.",
  keywords: [
    "fasonlar", "köýnek fasonlary", "ştapel fasonlar", "milli köýnekler", "türkmen fasonlar", "gelin köýnekleri", "kürte", "bukja", "dyrnak", "tikinçi",
    "фасоны платьев", "туркменские платья", "свадебные платья", "маникюр",
    "dress styles", "turkmen dress", "wedding dresses", "nail art", "ModaHouse",
  ],
  applicationName: "ModaHouse",
  openGraph: { siteName: "ModaHouse", locale: "tk_TM", type: "website" },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#111111" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tk">
      <body>
        <Providers>
          <Header />
          <main>{children}</main>
          <BottomNav />
        </Providers>
      </body>
    </html>
  );
}
