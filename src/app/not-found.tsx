import Link from "next/link";
import { Button } from "@/components/ui/button";

const debris = [
  { label: "cache.tmp", className: "-left-8 top-8 [animation-delay:0s]" },
  { label: "orphan.log", className: "-right-6 top-16 [animation-delay:1.4s]" },
  { label: "build/", className: "-left-4 bottom-14 [animation-delay:2.2s]" },
  { label: ".DS_Store", className: "-right-10 bottom-8 [animation-delay:0.7s]" },
];

export default function NotFound() {
  return (
    <div className="relative flex min-h-[70vh] flex-col items-center justify-center overflow-hidden py-8 text-center animate-fade-in">
      <div className="pointer-events-none absolute inset-0">
        <div className="absolute left-1/2 top-[18%] h-80 w-80 -translate-x-1/2 rounded-full bg-primary/25 blur-3xl animate-pulse-glow" />
        <div className="absolute right-[18%] bottom-[22%] h-52 w-52 rounded-full bg-emerald-300/20 blur-3xl" />
      </div>

      <div className="relative z-10 flex flex-col items-center gap-8">
        <span className="inline-flex items-center gap-1.5 rounded-full border bg-card/80 px-3 py-1 text-xs font-medium text-muted-foreground backdrop-blur">
          <span className="h-1.5 w-1.5 rounded-full bg-primary" />
          0 B remaining
        </span>

        <div className="relative h-64 w-64 sm:h-72 sm:w-72">
          <div className="absolute inset-0 animate-spin-slow">
            <svg viewBox="0 0 200 200" className="h-full w-full text-primary" aria-hidden>
              <circle
                cx="100"
                cy="100"
                r="88"
                fill="none"
                stroke="currentColor"
                strokeWidth="10"
                className="text-secondary"
              />
              <circle
                cx="100"
                cy="100"
                r="88"
                fill="none"
                stroke="currentColor"
                strokeWidth="10"
                strokeLinecap="round"
                strokeDasharray="553"
                strokeDashoffset="510"
                transform="rotate(-90 100 100)"
              />
              <circle
                cx="100"
                cy="100"
                r="76"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.5"
                strokeDasharray="4 10"
                className="text-primary/30"
              />
            </svg>
          </div>

          <div className="absolute inset-0 flex flex-col items-center justify-center">
            <p className="bg-gradient-to-br from-foreground to-primary bg-clip-text text-7xl font-black tracking-tighter text-transparent sm:text-8xl">
              404
            </p>
            <p className="mt-1 text-[10px] font-medium uppercase tracking-[0.28em] text-muted-foreground">
              already cleaned
            </p>
          </div>

          {debris.map((item) => (
            <span
              key={item.label}
              className={`absolute animate-drift rounded-md border bg-card/90 px-2 py-0.5 font-mono text-[10px] text-muted-foreground shadow-sm backdrop-blur ${item.className}`}
            >
              {item.label}
            </span>
          ))}
        </div>

        <div className="max-w-md space-y-2">
          <h1 className="text-2xl font-bold tracking-tight sm:text-3xl">This page got swept away</h1>
          <p className="text-muted-foreground">
            Nothing here to reclaim — the route doesn&apos;t exist, or it was never on this device.
          </p>
        </div>

        <div className="flex flex-wrap items-center justify-center gap-3">
          <Button asChild size="lg">
            <Link href="/">Back to Dashboard</Link>
          </Button>
          <Button asChild variant="outline" size="lg">
            <Link href="/scan">Scan instead</Link>
          </Button>
        </div>
      </div>
    </div>
  );
}
