"use client";

import type { DiskInfo } from "@/lib/engine/types";
import { formatBytes } from "@/lib/utils";

export function DiskOverview({ disk, reclaimableBytes }: { disk: DiskInfo; reclaimableBytes?: number }) {
  const usedPct = disk.totalBytes > 0 ? Math.min(100, (disk.usedBytes / disk.totalBytes) * 100) : 0;
  const reclaimPct =
    disk.totalBytes > 0 && reclaimableBytes
      ? Math.min(usedPct, (reclaimableBytes / disk.totalBytes) * 100)
      : 0;

  return (
    <div className="space-y-3">
      <div className="flex items-end justify-between">
        <div>
          <p className="text-sm text-muted-foreground">
            {formatBytes(disk.usedBytes)} used of {formatBytes(disk.totalBytes)}
          </p>
          <p className="text-2xl font-semibold tracking-tight">
            {formatBytes(disk.freeBytes)} free
          </p>
        </div>
        <p className="text-right text-xs text-muted-foreground">
          {disk.filesystem}
          <br />
          {disk.home}
        </p>
      </div>

      <div className="h-3 w-full overflow-hidden rounded-full bg-secondary">
        <div className="relative h-full w-full">
          <div
            className="absolute h-full rounded-full bg-primary transition-all duration-700"
            style={{ width: `${usedPct - reclaimPct > 0 ? usedPct - reclaimPct : usedPct}%` }}
          />
          <div
            className="absolute h-full rounded-r-full bg-emerald-400/80 transition-all duration-700"
            style={{ left: `${usedPct - reclaimPct > 0 ? usedPct - reclaimPct : usedPct}%`, width: `${reclaimPct}%` }}
          />
        </div>
      </div>

      <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-primary" /> used
        </span>
        {reclaimableBytes ? (
          <span className="inline-flex items-center gap-1.5">
            <span className="h-2 w-2 rounded-full bg-emerald-400" /> reclaimable ({formatBytes(reclaimableBytes)})
          </span>
        ) : null}
        <span className="inline-flex items-center gap-1.5">
          <span className="h-2 w-2 rounded-full bg-secondary" /> free
        </span>
      </div>
    </div>
  );
}