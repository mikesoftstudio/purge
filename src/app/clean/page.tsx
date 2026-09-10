"use client";

import { Suspense, useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useClean } from "@/hooks/use-clean";
import { sizeMapFromScan, loadScanResults } from "@/lib/scan-store";
import { categoryName } from "@/lib/categories-client";
import { formatBytes } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { saveCleanSummary } from "@/lib/summary-store";
import { ConfirmDialog } from "@/components/ui/dialog";

function CleanPageInner() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const { events, running, startedAt, start, cancel } = useClean();
  const startedRef = useRef(false);
  const [firedError, setFiredError] = useState(false);
  const [stopOpen, setStopOpen] = useState(false);

  const ids = useMemo(() => (searchParams.get("ids") ?? "").split(",").filter(Boolean), [searchParams]);
  const sizes = useMemo(() => sizeMapFromScan(), []);
  const nameOf = useMemo(() => {
    const scan = loadScanResults();
    const map: Record<string, string> = {};
    if (scan) for (const r of scan.results) map[r.id] = r.name;
    return (id: string) => map[id] ?? categoryName(id);
  }, []);

  useEffect(() => {
    if (!startedRef.current && ids.length > 0) {
      startedRef.current = true;
      void start(ids, sizes).catch(() => setFiredError(true));
    }
  }, [ids, sizes, start]);

  const doneEvents = events.filter((e) => e.status === "done");
  const totalFreed = events.reduce((acc, e) => acc + (e.freedBytes ?? 0), 0);
  const percent = ids.length > 0 ? Math.min(100, Math.round((events.length / ids.length) * 100)) : 0;

  const finished = !running;

  useEffect(() => {
    if (finished && startedRef.current) {
      saveCleanSummary({
        totalFreedBytes: totalFreed,
        cleaned: doneEvents.map((e) => e.categoryId),
        skipped: events.filter((e) => e.status === "skipped").map((e) => e.categoryId),
        errored: events.filter((e) => e.status === "error").map((e) => e.categoryId),
        startedAt: startedAt ?? Date.now(),
        finishedAt: Date.now(),
      });
      router.replace("/summary");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [finished]);

  return (
    <div className="mx-auto max-w-3xl space-y-6 animate-fade-in">
      <div>
        <h1 className="text-3xl font-bold tracking-tight">Cleaning your device</h1>
        <p className="mt-1 text-muted-foreground">
          {firedError
            ? "The cleanup request failed."
            : running
              ? "Working through the selected items…"
              : "All done."}
        </p>
      </div>

      {firedError ? (
        <Button variant="outline" onClick={() => router.push("/scan")}>
          Back to scan
        </Button>
      ) : (
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Progress</span>
              <span className="text-2xl">{percent}%</span>
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Progress value={percent} tone={running ? "emerald" : "default"} />

            {running && (
              <Button variant="outline" size="sm" onClick={() => setStopOpen(true)}>
                Stop cleaning
              </Button>
            )}

            <ul className="divide-y">
              {ids.map((id) => {
                const ev = events.find((e) => e.categoryId === id);
                return (
                  <li key={id} className="flex items-center justify-between gap-3 py-3">
                    <div className="flex min-w-0 items-center gap-3">
                      <StatusDot status={ev?.status} />
                      <div className="min-w-0">
                        <p className="truncate font-medium">{nameOf(id)}</p>
                        {ev?.label && ev.status === "cleaning" && (
                          <p className="truncate text-xs text-muted-foreground">{ev.label}</p>
                        )}
                      </div>
                    </div>
                    <div className="text-right text-sm">
                      {ev?.status === "done" && (
                        <span className="font-semibold text-emerald-600 dark:text-emerald-400">{formatBytes(ev.freedBytes ?? 0)} freed</span>
                      )}
                      {ev?.status === "skipped" && (
                        <span className="text-muted-foreground">
                          {ev.label && ev.label !== "Cancelled" ? ev.label : "skipped"}
                        </span>
                      )}
                      {ev?.status === "error" && <span className="text-destructive">could not clean</span>}
                      {ev?.status === "cleaning" && (
                        <span className="text-muted-foreground">
                          cleaning… {sizes[id] ? `(up to ${formatBytes(sizes[id])})` : ""}
                        </span>
                      )}
                      {!ev && <span className="text-muted-foreground">pending</span>}
                    </div>
                  </li>
                );
              })}
            </ul>
          </CardContent>
        </Card>
      )}

      <ConfirmDialog
        open={stopOpen}
        onClose={() => setStopOpen(false)}
        onConfirm={() => void cancel()}
        tone="critical"
        title="Stop cleaning?"
        description="Items already cleaned stay deleted. Anything still pending will be skipped."
        confirmLabel="Stop cleaning"
      />

      <ConfirmDialog
        open={firedError}
        onClose={() => router.push("/scan")}
        onConfirm={() => router.push("/scan")}
        title="Cleanup could not start"
        description="The cleanup request failed. Go back to the scan results and try again."
        confirmLabel="Back to scan"
        hideCancel
      />
    </div>
  );
}

function StatusDot({ status }: { status?: string }) {
  const cls =
    status === "done"
      ? "bg-emerald-500"
      : status === "cleaning"
        ? "animate-pulse bg-primary"
        : status === "error"
          ? "bg-red-500"
          : "bg-muted";
  return <span className={`h-2.5 w-2.5 shrink-0 rounded-full ${cls}`} />;
}

export default function CleanPage() {
  return (
    <Suspense>
      <CleanPageInner />
    </Suspense>
  );
}