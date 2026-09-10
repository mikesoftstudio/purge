import Link from "next/link";
import { navLinks } from "@/lib/nav";

const safety = [
  "Scan is read-only until you confirm",
  "Only regenerable caches, never your files",
  "Dangerous paths are blocked",
];

export function Footer() {
  return (
    <footer className="mt-auto border-t bg-card pb-24 sm:pb-0">
      <div className="h-px bg-gradient-to-r from-transparent via-primary/40 to-transparent" />
      <div className="mx-auto grid max-w-6xl gap-10 px-4 py-10 sm:grid-cols-2 lg:grid-cols-3">
        <div className="space-y-3">
          <Link href="/" className="inline-flex items-center gap-2 font-semibold tracking-tight">
            <span className="flex h-7 w-7 items-center justify-center rounded-md bg-primary text-sm text-white">◆</span>
            Purge
          </Link>
          <p className="max-w-xs text-sm text-muted-foreground">
            Free disk space safely. We only touch regenerable caches, logs, and build artifacts.
          </p>
        </div>

        <div>
          <p className="text-sm font-semibold">Navigate</p>
          <ul className="mt-3 space-y-2">
            {navLinks.map((link) => (
              <li key={link.href}>
                <Link
                  href={link.href}
                  className="text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                  {link.label}
                </Link>
              </li>
            ))}
          </ul>
        </div>

        <div className="sm:col-span-2 lg:col-span-1">
          <p className="text-sm font-semibold">Safe by design</p>
          <ul className="mt-3 space-y-2">
            {safety.map((item) => (
              <li key={item} className="flex items-start gap-2 text-sm text-muted-foreground">
                <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-primary" />
                {item}
              </li>
            ))}
          </ul>
        </div>
      </div>

      <div className="border-t">
        <div className="mx-auto flex max-w-6xl flex-col gap-1 px-4 py-4 text-xs text-muted-foreground sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} Purge</p>
          <p>
            Supported by{" "}
            <a
              href="https://mikesoftstudio.com"
              target="_blank"
              rel="noopener noreferrer"
              className="font-medium text-foreground underline-offset-4 hover:text-primary hover:underline"
            >
              MikeSoft Studio
            </a>
          </p>
        </div>
      </div>
    </footer>
  );
}
