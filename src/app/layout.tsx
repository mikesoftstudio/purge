import type { Metadata } from "next";
import { Sora } from "next/font/google";
import { Header } from "@/components/header";
import { Footer } from "@/components/footer";
import { MobileNav } from "@/components/mobile-nav";
import { ThemeProvider } from "@/components/theme-provider";
import { themeInitScript } from "@/lib/theme";
import "./globals.css";

const sora = Sora({
  subsets: ["latin"],
  variable: "--font-sora",
  display: "swap",
});

const SITE_URL = "https://purge.dev";
const TITLE = "Purge — Free disk space safely";
const DESCRIPTION =
  "Scan your device for regenerable caches, build artifacts and logs, then clean them in one click. Never touches your source code or personal files.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: TITLE,
    template: "%s | Purge",
  },
  description: DESCRIPTION,
  keywords: [
    "disk cleanup",
    "free disk space",
    "cache cleaner",
    "developer tools",
    "build cache",
    "npm cache",
    "docker cleanup",
    "xcode derived data",
    "gradle cache",
    "system cleanup",
    "macOS",
    "Windows",
    "Linux",
    "Android",
    "iOS",
  ],
  authors: [{ name: "MikeSoft Studio", url: "https://mikesoftstudio.com" }],
  creator: "MikeSoft Studio",
  publisher: "MikeSoft Studio",
  formatDetection: { telephone: false },
  openGraph: {
    type: "website",
    locale: "en_US",
    url: SITE_URL,
    siteName: "Purge",
    title: TITLE,
    description: DESCRIPTION,
    images: [
      {
        url: "/opengraph-image",
        width: 1200,
        height: 630,
        alt: "Purge — Free disk space safely",
        type: "image/png",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: DESCRIPTION,
    images: ["/opengraph-image"],
    creator: "@mikesoftstudio",
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-video-preview": -1,
      "max-image-preview": "large",
      "max-snippet": -1,
    },
  },
  icons: {
    icon: "/icon",
    apple: "/icon",
  },
  manifest: "/manifest.json",
  other: {
    "application-name": "Purge",
    "apple-mobile-web-app-capable": "yes",
    "apple-mobile-web-app-status-bar-style": "black-translucent",
    "theme-color": "#16a364",
  },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={sora.variable} suppressHydrationWarning>
      <body className={`${sora.className} flex min-h-screen flex-col bg-background`}>
        <script dangerouslySetInnerHTML={{ __html: themeInitScript }} />
        <ThemeProvider>
          <Header />
          <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-8 pb-12 sm:pb-8">{children}</main>
          <Footer />
          <MobileNav />
        </ThemeProvider>
      </body>
    </html>
  );
}
