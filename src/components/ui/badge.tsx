import { HTMLAttributes } from "react";
import { cn } from "@/lib/utils";

export type SafetyTier = "safe" | "moderate" | "advanced";

const tierStyles: Record<SafetyTier, string> = {
  safe: "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/50 dark:text-emerald-300 dark:border-emerald-800",
  moderate: "bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/50 dark:text-amber-300 dark:border-amber-800",
  advanced: "bg-red-50 text-red-700 border-red-200 dark:bg-red-950/50 dark:text-red-300 dark:border-red-800",
};

export function safetyLabel(tier: SafetyTier): string {
  return tier === "safe" ? "Safe" : tier === "moderate" ? "Moderate" : "Advanced";
}

export function SafetyBadge({ tier, className }: { tier: SafetyTier } & HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
        tierStyles[tier],
        className
      )}
    >
      {safetyLabel(tier)}
    </span>
  );
}

export function Badge({ className, ...props }: HTMLAttributes<HTMLSpanElement>) {
  return (
    <span
      className={cn(
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium border-border bg-muted text-muted-foreground",
        className
      )}
      {...props}
    />
  );
}