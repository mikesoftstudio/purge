"use client";

import { ScanCategory } from "@/lib/global-types";
import { formatBytes } from "@/lib/utils";
import { cn } from "@/lib/utils";
import { SafetyBadge } from "@/components/ui/badge";
import { Progress } from "@/components/ui/progress";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";

function toneForSize(bytes: number, max: number) {
  const ratio = bytes / (max || 1);
  if (ratio > 0.4) return "red" as const;
  if (ratio > 0.15) return "amber" as const;
  return "emerald" as const;
}

export function CategoryCard({
  category,
  maxSize,
  selected,
  onToggle,
  onDetails,
}: {
  category: ScanCategory;
  maxSize: number;
  selected: boolean;
  onToggle: (id: string) => void;
  onDetails?: (category: ScanCategory) => void;
}) {
  const notApplicable = !category.applicable;
  const disabled = notApplicable || (!category.detected && category.totalSizeBytes === 0);

  return (
    <Card
      className={cn(
        "transition-all",
        selected && !disabled && "border-primary ring-2 ring-primary/30",
        disabled && "opacity-50"
      )}
    >
      <CardHeader className="pb-3">
        <div className="flex items-start justify-between gap-3">
          <input
            type="checkbox"
            className="mt-1 h-4 w-4 rounded border-input text-primary focus:ring-ring disabled:cursor-not-allowed"
            checked={selected && !disabled}
            disabled={disabled}
            onChange={() => onToggle(category.id)}
            aria-label={`Select ${category.name}`}
          />
          <div className="flex-1 space-y-1">
            <CardTitle className="text-base">{category.name}</CardTitle>
            <CardDescription className="line-clamp-2">{category.description}</CardDescription>
            {onDetails && (
              <button
                type="button"
                className="text-xs font-medium text-primary hover:underline"
                onClick={() => onDetails(category)}
              >
                Details
              </button>
            )}
          </div>
          <SafetyBadge tier={category.safety} />
        </div>
      </CardHeader>
      <CardContent>
        <div className="flex items-center justify-between">
          <span className="text-2xl font-bold tracking-tight">{formatBytes(category.totalSizeBytes)}</span>
          {category.toolMissing ? (
            <span className="text-xs text-muted-foreground">requires {category.id.split("-")[0]}</span>
          ) : !category.detected && category.applicable ? (
            <span className="text-xs text-muted-foreground">nothing to clean</span>
          ) : null}
        </div>
        {category.applicable && category.totalSizeBytes > 0 && (
          <Progress value={(category.totalSizeBytes / maxSize) * 100} tone={toneForSize(category.totalSizeBytes, maxSize)} className="mt-3" />
        )}
        <p className="mt-3 text-xs text-muted-foreground">
          Trade-off: {category.tradeoff}
        </p>
      </CardContent>
    </Card>
  );
}