"use client";

import Link from "next/link";
import { useEffect } from "react";
import { useDisk } from "@/hooks/use-disk";
import { usePlatform } from "@/hooks/use-platform";
import { useScan } from "@/hooks/use-scan";
import { deviceNoun } from "@/lib/platform-meta";
import { formatBytes } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DiskOverview } from "@/components/disk-overview";

export default function DashboardPage() {
  const { disk } = useDisk();
  const { info } = usePlatform();
  const { scan, results, totalReclaimableBytes, scanning } = useScan();

  useEffect(() => {
    if (!results) void scan();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const noun = info ? deviceNoun(info.platform) : "device"; 

  return (
    <div className="space-y-8 animate-fade-in">
      <section className="space-y-2">
        <h1 className="text-4xl font-bold tracking-tight">
          Free disk space on your {noun}
        </h1>
        <p className="max-w-2xl text-muted-foreground">
          Purge safely removes regenerable caches, logs and build artifacts left behind by your
          development tools. It never touches your projects, source code, or personal files.
        </p>
      </section>

      {disk && (
        <Card>
          <CardHeader>
            <CardTitle>Storage</CardTitle>
            <CardDescription>Current state of the volume containing your home directory.</CardDescription>
          </CardHeader>
          <CardContent>
            <DiskOverview disk={disk} reclaimableBytes={totalReclaimableBytes || undefined} />
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Scan now</CardTitle>
            <CardDescription>
              Detect {info?.platformLabel.toLowerCase() ?? "this device"}s' installed tools and measure how much
              space their caches are using.
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap items-center gap-3">
            <Button asChild size="lg">
              <Link href="/scan">Scan my {noun}</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/scan">See what it finds</Link>
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{scanning ? "Scanning…" : results ? "Last scan" : ""}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {scanning && <p className="text-sm text-muted-foreground">Measuring cache sizes…</p>}
            {!scanning && results && (
              <>
                <p className="text-3xl font-bold tracking-tight">{formatBytes(totalReclaimableBytes)}</p>
                <p className="text-sm text-muted-foreground">reclaimable across {results.filter((r) => r.detected).length} categories</p>
              </>
            )}
            {!scanning && !results && <p className="text-sm text-muted-foreground">No scan yet.</p>}
          </CardContent>
        </Card>
      </div>

      <section className="rounded-xl border bg-card p-6">
        <h2 className="text-lg font-semibold">How it stays safe</h2>
        <ul className="mt-3 grid gap-2 text-sm text-muted-foreground md:grid-cols-3">
          <li>Scan is read-only — nothing is deleted until you confirm.</li>
          <li>Every item is a regenerable cache, never your data.</li>
          <li>Deletions are guarded against dangerous paths like{" "}
            <code className="rounded bg-muted px-1 text-xs">/</code> or your home directory.</li>
        </ul>
      </section>
    </div>
  );
}