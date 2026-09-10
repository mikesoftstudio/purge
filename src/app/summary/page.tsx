"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { loadCleanSummary, CleanSummaryData } from "@/lib/summary-store";
import { categoryName, categorySafety } from "@/lib/categories-client";
import { formatBytes } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { SafetyBadge, type SafetyTier } from "@/components/ui/badge";

export default function SummaryPage() {
  const [summary, setSummary] = useState<CleanSummaryData | null>(null);

  useEffect(() => {
    setSummary(loadCleanSummary());
  }, []);

  return (
    <div className="mx-auto max-w-3xl space-y-6 animate-fade-in">
      <div className="text-center">
        <div className="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-emerald-100 text-3xl dark:bg-emerald-950/60 dark:text-emerald-300">
          ✓
        </div>
        <h1 className="text-4xl font-bold tracking-tight">
          <span className="text-emerald-600 dark:text-emerald-400">{formatBytes(summary?.totalFreedBytes ?? 0)}</span> freed
        </h1>
        <p className="mt-2 text-muted-foreground">
          Your device has more room. Everything that was cleaned regenerates on next use.
        </p>
      </div>

      {summary && (summary.cleaned.length > 0 || summary.skipped.length > 0) && (
        <Card>
          <CardHeader>
            <CardTitle>What happened</CardTitle>
          </CardHeader>
          <CardContent className="space-y-3">
            {summary.cleaned.map((id) => (
              <div key={id} className="flex items-center justify-between gap-3 rounded-md bg-muted px-3 py-2">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-emerald-500" />
                  <span className="font-medium">{categoryName(id)}</span>
                </div>
                <SafetyBadge tier={categorySafety(id)} />
              </div>
            ))}
            {summary.skipped.map((id) => (
              <div key={id} className="flex items-center justify-between gap-3 rounded-md bg-muted px-3 py-2 opacity-70">
                <div className="flex items-center gap-2">
                  <span className="h-2 w-2 rounded-full bg-muted-foreground" />
                  <span className="font-medium">{categoryName(id)}</span>
                </div>
                <span className="text-xs text-muted-foreground">skipped during clean job</span>
              </div>
            ))}
            {summary.errored.length > 0 && (
              <div className="rounded-md border border-destructive/30 bg-destructive/5 px-3 py-2 text-sm text-destructive">
                {summary.errored.length} item(s) could not be cleaned — you can retry them from the scan page.
              </div>
            )}
          </CardContent>
        </Card>
      )}

      <div className="flex flex-wrap justify-center gap-3">
        <Button asChild size="lg">
          <Link href="/scan">Scan again</Link>
        </Button>
        <Button asChild variant="outline" size="lg">
          <Link href="/">Back to dashboard</Link>
        </Button>
      </div>
    </div>
  );
}