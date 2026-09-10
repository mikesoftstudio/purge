"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { usePlatform } from "@/hooks/use-platform";
import { navIsActive, navLinks } from "@/lib/nav";
import { cn } from "@/lib/utils";
import { ThemeToggle } from "@/components/theme-toggle";

export function Header() {
  const pathname = usePathname();
  const { info } = usePlatform();

  return (
    <header className="sticky top-0 z-40 w-full border-b bg-background/80 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-6xl items-center justify-between gap-3 px-4">
        <div className="flex min-w-0 items-center gap-6">
          <Link href="/" className="flex shrink-0 items-center gap-2 font-semibold tracking-tight">
            <span className="flex h-7 w-7 items-center justify-center rounded-md bg-primary text-sm text-white">◆</span>
            Purge
          </Link>
          <nav className="hidden items-center gap-1 sm:flex" aria-label="Primary">
            {navLinks.map((link) => {
              const active = navIsActive(pathname, link.href);
              return (
                <Link
                  key={link.href}
                  href={link.href}
                  aria-current={active ? "page" : undefined}
                  className={cn(
                    "rounded-md px-3 py-1.5 text-sm font-medium transition-colors",
                    active
                      ? "bg-accent text-accent-foreground"
                      : "text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                  )}
                >
                  {link.label}
                </Link>
              );
            })}
          </nav>
        </div>
        <div className="flex min-w-0 items-center gap-1.5">
          {info && (
            <span className="inline-flex max-w-[36vw] shrink-0 items-center gap-1.5 truncate rounded-full border px-2.5 py-0.5 text-xs font-medium text-muted-foreground">
              <span className="h-1.5 w-1.5 shrink-0 rounded-full bg-emerald-500" />
              <span className="truncate">{info.platformLabel}</span>
            </span>
          )}
          <ThemeToggle />
        </div>
      </div>
    </header>
  );
}
