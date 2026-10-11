import type { Metadata, Viewport } from "next";
import Header, { BottomNav } from "@/components/Header";
import Providers from "@/components/Providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "ModaHouse — moda ideýalary we dükanlar",
  description: "Köýnekler, tikinçiler we moda ideýalary: tap, sakla we sargyt et.",
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
