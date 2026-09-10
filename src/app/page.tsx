"use client";

import Link from "next/link";
import { useDisk } from "@/hooks/use-disk";
import { usePlatform } from "@/hooks/use-platform";
import { useBrowserStorage } from "@/hooks/use-browser-storage";
import { deviceNoun } from "@/lib/platform-meta";
import { formatBytes } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DiskOverview } from "@/components/disk-overview";

export default function DashboardPage() {
  const { disk, remote } = useDisk();
  const { info } = usePlatform();
  const { estimate } = useBrowserStorage();

  const noun = info ? deviceNoun(info.platform) : "device";

  const browserDisk = estimate
    ? {
        totalBytes: estimate.quota,
        usedBytes: estimate.usage,
        freeBytes: Math.max(0, estimate.quota - estimate.usage),
        home: "~",
        filesystem: "browser",
      }
    : null;

  const showDisk = remote ? browserDisk : disk;

  return (
    <div className="space-y-8 animate-fade-in">
      <section className="space-y-2">
        <h1 className="text-4xl font-bold tracking-tight">
          Free disk space on your {noun}
        </h1>
        <p className="max-w-2xl text-muted-foreground">
          {remote
            ? `Purge detected you're on ${info?.platformLabel ?? "your device"}. Below are the standard cache locations — use the terminal to clean them safely.`
            : "Purge safely removes regenerable caches, logs and build artifacts left behind by your development tools. It never touches your projects, source code, or personal files."}
        </p>
      </section>

      {showDisk && showDisk.totalBytes > 0 && (
        <Card>
          <CardHeader>
            <CardTitle>{remote ? "Browser Storage" : "Storage"}</CardTitle>
            <CardDescription>
              {remote
                ? "Storage available to this browser tab (full disk info requires running Purge locally)."
                : "Current state of the volume containing your home directory."}
            </CardDescription>
          </CardHeader>
          <CardContent>
            <DiskOverview disk={showDisk} />
          </CardContent>
        </Card>
      )}

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>{remote ? "View cache categories" : "Scan now"}</CardTitle>
            <CardDescription>
              {remote
                ? `See which caches exist on ${info?.platformLabel ?? "your platform"} and how to clean them.`
                : `Detect ${info?.platformLabel.toLowerCase() ?? "this device"}s' installed tools and measure how much space their caches are using.`}
            </CardDescription>
          </CardHeader>
          <CardContent className="flex flex-wrap items-center gap-3">
            <Button asChild size="lg">
              <Link href="/scan">{remote ? `Browse ${noun} caches` : `Scan my ${noun}`}</Link>
            </Button>
            <Button asChild variant="outline" size="lg">
              <Link href="/scan">See what it finds</Link>
            </Button>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>{info?.platformLabel ?? "Device"}</CardTitle>
          </CardHeader>
          <CardContent className="space-y-2">
            {info && (
              <>
                <p className="text-sm text-muted-foreground">
                  {remote ? "Running in guidance mode" : "Connected locally"}
                </p>
                <p className="text-xs text-muted-foreground">
                  {info.platformLabel}{info.nodeVersion ? ` · Node ${info.nodeVersion}` : ""}
                </p>
              </>
            )}
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
