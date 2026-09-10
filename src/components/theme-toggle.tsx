"use client";

import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { useTheme, type Theme } from "@/components/theme-provider";

function SunIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <circle cx="12" cy="12" r="4" stroke="currentColor" strokeWidth="1.8" />
      <path
        d="M12 3v1.5M12 19.5V21M4.93 4.93l1.06 1.06M18.01 18.01l1.06 1.06M3 12h1.5M19.5 12H21M4.93 19.07l1.06-1.06M18.01 5.99l1.06-1.06"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinecap="round"
      />
    </svg>
  );
}

function MoonIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M17.5 15.5A7.5 7.5 0 0 1 8.5 6.5 6.5 6.5 0 1 0 17.5 15.5Z"
        stroke="currentColor"
        strokeWidth="1.8"
        strokeLinejoin="round"
      />
    </svg>
  );
}

function SystemIcon({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <rect x="3.5" y="4.5" width="17" height="12" rx="2" stroke="currentColor" strokeWidth="1.8" />
      <path d="M8 19.5h8" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
    </svg>
  );
}

const order: Theme[] = ["light", "dark", "system"];
const labels: Record<Theme, string> = {
  light: "Light",
  dark: "Dark",
  system: "System",
};

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  const Icon = theme === "dark" ? MoonIcon : theme === "light" ? SunIcon : SystemIcon;
  const next = order[(order.indexOf(theme) + 1) % order.length];

  return (
    <Button
      variant="ghost"
      size="icon"
      className="h-9 w-9 shrink-0 text-muted-foreground"
      aria-label={mounted ? `Theme: ${labels[theme]}. Switch to ${labels[next]}` : "Toggle theme"}
      title={mounted ? `${labels[theme]} theme` : "Theme"}
      onClick={() => setTheme(next)}
    >
      {mounted ? <Icon className="h-[18px] w-[18px]" /> : <span className="h-[18px] w-[18px]" />}
    </Button>
  );
}
