import type { Metadata, Viewport } from "next";
import Header from "@/components/Header";
import Providers from "@/components/Providers";
import "./globals.css";

export const metadata: Metadata = {
  title: "ModaHouse — ideýalary tap we sakla",
  description: "Moda, içki bezeg, tagamlar we syýahat üçin ideýalar tagtasy.",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#ffffff" },
    { media: "(prefers-color-scheme: dark)", color: "#121212" },
  ],
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="tk">
      <body>
        <Providers>
          <Header />
          <main>{children}</main>
        </Providers>
      </body>
    </html>
  );
}
