import { cn } from "@/lib/utils";
import { HTMLAttributes } from "react";

export function Progress({
  value,
  className,
  tone = "default",
}: { value: number; tone?: "default" | "emerald" | "amber" | "red" } & HTMLAttributes<HTMLDivElement>) {
  const clamped = Math.min(100, Math.max(0, value));
  const barColor =
    tone === "emerald"
      ? "bg-emerald-500"
      : tone === "amber"
        ? "bg-amber-500"
        : tone === "red"
          ? "bg-red-500"
          : "bg-primary";
  return (
    <div className={cn("h-2 w-full overflow-hidden rounded-full bg-secondary", className)}>
      <div className={cn("h-full rounded-full transition-all duration-500", barColor)} style={{ width: `${clamped}%` }} />
    </div>
  );
}