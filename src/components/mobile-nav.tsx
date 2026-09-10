"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { navIsActive, navLinks } from "@/lib/nav";
import { cn } from "@/lib/utils";

function HomeIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M4 10.75 12 4l8 6.75V20a1 1 0 0 1-1 1h-5.25v-6.5h-3.5V21H5a1 1 0 0 1-1-1v-9.25Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function ScanIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M8 4H5a1 1 0 0 0-1 1v3M16 4h3a1 1 0 0 1 1 1v3M8 20H5a1 1 0 0 1-1-1v-3M16 20h3a1 1 0 0 0 1-1v-3"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
      <circle cx="12" cy="12" r="3.25" stroke="currentColor" strokeWidth="1.8" />
    </svg>
  );
}

const icons = {
  "/": HomeIcon,
  "/scan": ScanIcon,
} as const;

export function MobileNav() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-0 bottom-0 z-50 px-4 pb-[max(0.75rem,env(safe-area-inset-bottom))] sm:hidden"
    >
      <div className="mx-auto flex max-w-sm items-center gap-1 rounded-2xl border bg-background/90 p-1.5 shadow-lg shadow-black/5 backdrop-blur">
        {navLinks.map((link) => {
          const active = navIsActive(pathname, link.href);
          const Icon = icons[link.href];
          return (
            <Link
              key={link.href}
              href={link.href}
              aria-current={active ? "page" : undefined}
              className={cn(
                "flex min-h-12 flex-1 flex-col items-center justify-center gap-0.5 rounded-xl px-3 py-2 text-[11px] font-medium transition-colors",
                active
                  ? "bg-accent text-accent-foreground"
                  : "text-muted-foreground active:bg-accent/70"
              )}
            >
              <Icon className="h-5 w-5" />
              {link.label}
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
