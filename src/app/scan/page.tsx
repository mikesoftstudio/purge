"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useScan } from "@/hooks/use-scan";
import { ScanCategory } from "@/lib/global-types";
import { formatBytes, cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { CategoryCard } from "@/components/category-card";
import { ConfirmDialog } from "@/components/ui/dialog";
import { SafetyBadge, type SafetyTier } from "@/components/ui/badge";

type SortKey = "size-desc" | "size-asc" | "name-asc" | "name-desc" | "safety";
type FilterSafety = SafetyTier | "all";
type FilterStatus = "all" | "detected" | "not-detected";

const safetyOrder: Record<SafetyTier, number> = { safe: 0, moderate: 1, advanced: 2 };

function applyFilters(
  items: ScanCategory[],
  sort: SortKey,
  filterSafety: FilterSafety,
  filterStatus: FilterStatus
): ScanCategory[] {
  let list = [...items];

  if (filterSafety !== "all") {
    list = list.filter((r) => r.safety === filterSafety);
  }
  if (filterStatus === "detected") {
    list = list.filter((r) => r.detected);
  } else if (filterStatus === "not-detected") {
    list = list.filter((r) => !r.detected);
  }

  list.sort((a, b) => {
    switch (sort) {
      case "size-desc":
        return b.totalSizeBytes - a.totalSizeBytes;
      case "size-asc":
        return a.totalSizeBytes - b.totalSizeBytes;
      case "name-asc":
        return a.name.localeCompare(b.name);
      case "name-desc":
        return b.name.localeCompare(a.name);
      case "safety":
        return safetyOrder[a.safety] - safetyOrder[b.safety] || b.totalSizeBytes - a.totalSizeBytes;
    }
  });

  return list;
}

export default function ScanPage() {
  const router = useRouter();
  const { results, totalReclaimableBytes, platformLabel, remote, scanning, error, scan } = useScan();
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [confirmOpen, setConfirmOpen] = useState(false);
  const [rescanOpen, setRescanOpen] = useState(false);
  const [detail, setDetail] = useState<ScanCategory | null>(null);
  const [sort, setSort] = useState<SortKey>("size-desc");
  const [filterSafety, setFilterSafety] = useState<FilterSafety>("all");
  const [filterStatus, setFilterStatus] = useState<FilterStatus>("all");

  const selectable = useMemo(
    () => (results ?? []).filter((r) => r.applicable && (r.detected || r.totalSizeBytes > 0)),
    [results]
  );

  const filtered = useMemo(
    () => applyFilters(results ?? [], sort, filterSafety, filterStatus),
    [results, sort, filterSafety, filterStatus]
  );

  const maxSize = useMemo(() => Math.max(...(results ?? []).map((r) => r.totalSizeBytes), 1), [results]);

  const selectedItems = useMemo(
    () => (results ?? []).filter((r) => selected.has(r.id)),
    [results, selected]
  );

  const selectedBytes = useMemo(
    () => selectedItems.filter((r) => r.detected).reduce((acc, r) => acc + r.totalSizeBytes, 0),
    [selectedItems]
  );

  const hasAdvanced = selectedItems.some((r) => r.safety === "advanced");
  const hasTrash = selectedItems.some((r) => r.id === "trash");
  const needsAck = hasAdvanced || hasTrash;

  const hasActiveFilters = filterSafety !== "all" || filterStatus !== "all" || sort !== "size-desc";
  const resultCount = filtered.length;
  const totalCount = results?.length ?? 0;

  const resetFilters = () => {
    setSort("size-desc");
    setFilterSafety("all");
    setFilterStatus("all");
  };

  const toggle = (id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  };

  const selectAll = () => setSelected(new Set(selectable.map((r) => r.id)));
  const clearAll = () => setSelected(new Set());

  const requestRescan = () => {
    if (selected.size > 0) setRescanOpen(true);
    else void scan();
  };

  if (scanning && !results) {
    return (
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Scanning your {platformLabel}…</h1>
        <p className="text-muted-foreground">
          {remote ? "Loading cache categories for your platform…" : "Measuring every tool cache. This only reads — nothing is deleted."}
        </p>
        <div className="h-2 w-full overflow-hidden rounded-full bg-secondary">
          <div className="h-full w-1/3 animate-pulse rounded-full bg-primary" />
        </div>
      </div>
    );
  }

  if (error && !results) {
    return (
      <>
        <div className="space-y-4">
          <h1 className="text-3xl font-bold tracking-tight">Scan failed</h1>
          <p className="text-destructive">{error}</p>
        </div>
        <ConfirmDialog
          open
          onClose={() => void scan()}
          onConfirm={() => void scan()}
          title="Couldn't finish the scan"
          description={error}
          confirmLabel="Try again"
          hideCancel
        />
      </>
    );
  }

  if (!results) {
    return (
      <div className="space-y-4">
        <h1 className="text-3xl font-bold tracking-tight">Scan your device</h1>
        <p className="text-muted-foreground">
          Detect installed toolchains and measure reclaimable space. Read-only — nothing is deleted.
        </p>
        <Button size="lg" onClick={() => void scan()} disabled={scanning}>
          {scanning ? "Scanning…" : "Start scan"}
        </Button>
      </div>
    );
  }

  return (
    <div className="space-y-6 animate-fade-in">
      {remote && (
        <div className="rounded-lg border border-amber-500/30 bg-amber-500/10 px-4 py-3 text-sm text-amber-700 dark:text-amber-400">
          <p className="font-semibold">Run Purge locally to clean your disk</p>
          <p className="mt-1 text-xs">
            Purge is running on a remote server and cannot access your hard disk.
            To scan and clean your actual storage, run Purge on your machine:
          </p>
          <pre className="mt-2 rounded bg-background/80 px-3 py-2 font-mono text-xs">
            git clone https://github.com/mikesoftstudio/purge.git<br/>
            cd purge &amp;&amp; npm install &amp;&amp; npm run dev
          </pre>
          <p className="mt-1 text-xs">
            Then open <span className="font-medium">localhost:3000</span> — Purge will detect your OS and scan your real disk.
          </p>
        </div>
      )}

      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold tracking-tight">Scan results</h1>
          <p className="text-muted-foreground">
            {platformLabel}{" "}
            {remote ? `· ${totalCount} cache categories found` : `· ${formatBytes(totalReclaimableBytes)} reclaimable total`}
          </p>
        </div>
        <Button variant="outline" onClick={requestRescan} disabled={scanning}>
          {scanning ? "Rescanning…" : "Rescan"}
        </Button>
      </div>

      <div className="space-y-3">
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={sort}
            onChange={(e) => setSort(e.target.value as SortKey)}
            className="h-8 rounded-md border bg-background px-2 text-sm text-foreground outline-none focus:ring-2 focus:ring-ring"
          >
            <option value="size-desc">Largest first</option>
            <option value="size-asc">Smallest first</option>
            <option value="name-asc">Name A→Z</option>
            <option value="name-desc">Name Z→A</option>
            <option value="safety">Safety level</option>
          </select>

          <div className="flex gap-1" role="radiogroup" aria-label="Safety filter">
            {(["all", "safe", "moderate", "advanced"] as const).map((tier) => (
              <button
                key={tier}
                type="button"
                role="radio"
                aria-checked={filterSafety === tier}
                onClick={() => setFilterSafety(tier)}
                className={cn(
                  "inline-flex h-8 items-center rounded-md px-2.5 text-xs font-medium transition-colors",
                  filterSafety === tier
                    ? "bg-primary text-primary-foreground"
                    : "border bg-background text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                )}
              >
                {tier === "all" ? "All" : tier.charAt(0).toUpperCase() + tier.slice(1)}
              </button>
            ))}
          </div>

          {!remote && (
            <div className="flex gap-1" role="radiogroup" aria-label="Detection filter">
              {([
                ["all", "All"],
                ["detected", "Detected"],
                ["not-detected", "Empty"],
              ] as const).map(([value, label]) => (
                <button
                  key={value}
                  type="button"
                  role="radio"
                  aria-checked={filterStatus === value}
                  onClick={() => setFilterStatus(value)}
                  className={cn(
                    "inline-flex h-8 items-center rounded-md px-2.5 text-xs font-medium transition-colors",
                    filterStatus === value
                      ? "bg-primary text-primary-foreground"
                      : "border bg-background text-muted-foreground hover:bg-accent hover:text-accent-foreground"
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
          )}
        </div>

        {!remote && (
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="secondary" size="sm" onClick={selectAll}>
              Select all
            </Button>
            <Button variant="ghost" size="sm" onClick={clearAll}>
              Clear
            </Button>
            <div className="flex-1" />
            <span className="text-xs text-muted-foreground">
              {resultCount}{resultCount !== totalCount ? ` of ${totalCount}` : ""} categories
            </span>
            {hasActiveFilters && (
              <button
                type="button"
                onClick={resetFilters}
                className="text-xs font-medium text-primary hover:underline"
              >
                Reset filters
              </button>
            )}
          </div>
        )}
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
        {filtered.length === 0 && (
          <p className="col-span-full py-8 text-center text-sm text-muted-foreground">
            No categories match the current filters.
          </p>
        )}
        {filtered.map((category: ScanCategory) => (
          <CategoryCard
            key={category.id}
            category={category}
            maxSize={maxSize}
            selected={selected.has(category.id)}
            onToggle={toggle}
            onDetails={setDetail}
            remote={remote}
          />
        ))}
      </div>

      {!remote && (
        <div className="sticky bottom-24 sm:bottom-4">
          <Card className="border-primary/30 bg-background/90 backdrop-blur">
            <CardHeader>
              <CardTitle className="text-base">
                {selected.size} selected · {formatBytes(selectedBytes)} will be freed
              </CardTitle>
            </CardHeader>
            <CardContent className="flex flex-wrap gap-3">
              <Button size="lg" disabled={selected.size === 0} className="flex-1 sm:flex-none" onClick={() => setConfirmOpen(true)}>
                Clean selected
              </Button>
              <Link href="/" className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground">
                Back to dashboard
              </Link>
            </CardContent>
          </Card>
        </div>
      )}

      {remote && (
        <div className="sticky bottom-24 sm:bottom-4">
          <Card className="border-amber-500/30 bg-background/90 backdrop-blur">
            <CardContent className="flex flex-col gap-3 py-4">
              <p className="text-sm text-muted-foreground">
                To actually clean these caches, run Purge on your machine — the deployed version can only show you what to clean.
              </p>
              <code className="rounded-lg bg-muted px-3 py-2 font-mono text-xs">
                git clone https://github.com/mikesoftstudio/purge.git &amp;&amp; cd purge &amp;&amp; npm install &amp;&amp; npm run dev
              </code>
            </CardContent>
          </Card>
        </div>
      )}

      <ConfirmDialog
        open={confirmOpen}
        onClose={() => setConfirmOpen(false)}
        onConfirm={() => router.push(`/clean?ids=${Array.from(selected).join(",")}`)}
        tone="critical"
        title="Clean these caches?"
        description={`This will delete ${selected.size} item${selected.size === 1 ? "" : "s"} and free ${formatBytes(selectedBytes)}.`}
        confirmLabel={`Clean ${selected.size} item${selected.size === 1 ? "" : "s"}`}
        acknowledge={needsAck ? { label: "I understand this cannot be undone" } : undefined}
      >
        <ul className="max-h-44 space-y-1.5 overflow-y-auto">
          {selectedItems.map((r) => (
            <li key={r.id} className="flex items-center justify-between gap-3 rounded-lg bg-muted px-3 py-2 text-sm">
              <span className="min-w-0 truncate font-medium">{r.name}</span>
              <span className="flex shrink-0 items-center gap-2">
                <SafetyBadge tier={r.safety} />
                <span className="text-muted-foreground">{formatBytes(r.totalSizeBytes)}</span>
              </span>
            </li>
          ))}
        </ul>
        {hasTrash && (
          <p className="rounded-lg border border-destructive/20 bg-destructive/5 px-3 py-2 text-xs text-destructive">
            Trash items are permanently deleted and cannot be restored.
          </p>
        )}
        {hasAdvanced && (
          <p className="rounded-lg border border-destructive/20 bg-destructive/5 px-3 py-2 text-xs text-destructive">
            Advanced items (like Docker) must be rebuilt or re-downloaded after cleaning.
          </p>
        )}
        {!needsAck && (
          <p className="text-xs text-muted-foreground">
            These are regenerable caches. They come back on next use — nothing personal is lost.
          </p>
        )}
      </ConfirmDialog>

      <ConfirmDialog
        open={rescanOpen}
        onClose={() => setRescanOpen(false)}
        onConfirm={() => {
          setSelected(new Set());
          void scan();
        }}
        title="Rescan this device?"
        description="A new scan replaces these results and clears your current selection."
        confirmLabel="Rescan"
      />

      <ConfirmDialog
        open={detail !== null}
        onClose={() => setDetail(null)}
        onConfirm={() => {
          if (detail && !remote) toggle(detail.id);
          setDetail(null);
        }}
        title={detail?.name ?? ""}
        description={detail?.description}
        confirmLabel={remote ? "Close" : detail && selected.has(detail.id) ? "Deselect" : "Select"}
        cancelLabel={remote ? undefined : "Close"}
        confirmDisabled={
          !remote &&
          !!detail &&
          !selected.has(detail.id) &&
          (!detail.applicable || (!detail.detected && detail.totalSizeBytes === 0))
        }
      >
        {detail && (
          <div className="space-y-3">
            {!remote && (
              <div className="flex items-center justify-between rounded-lg bg-muted px-3 py-2">
                <span className="text-sm text-muted-foreground">Reclaimable</span>
                <span className="text-lg font-semibold">{formatBytes(detail.totalSizeBytes)}</span>
              </div>
            )}
            <div className="flex items-center gap-2">
              <SafetyBadge tier={detail.safety} />
              <span className="text-xs text-muted-foreground">Trade-off: {detail.tradeoff}</span>
            </div>
            {detail.paths.filter((p) => remote || p.exists).length > 0 && (
              <div>
                <p className="text-xs font-medium text-muted-foreground mb-1">
                  {remote ? "Standard cache paths:" : "Existing paths:"}
                </p>
                <ul className="max-h-32 space-y-1 overflow-y-auto font-mono text-[11px] text-muted-foreground">
                  {detail.paths
                    .filter((p) => remote || p.exists)
                    .map((p) => (
                      <li key={p.path} className="truncate rounded bg-muted px-2 py-1">
                        {p.path}
                      </li>
                    ))}
                </ul>
              </div>
            )}
            {remote && detail.cleanupCommands && detail.cleanupCommands.length > 0 && (
              <div>
                <p className="text-xs font-medium text-muted-foreground mb-1">Cleanup commands:</p>
                <ul className="space-y-1">
                  {detail.cleanupCommands.map((cmd) => (
                    <li key={cmd} className="font-mono text-[11px] text-muted-foreground rounded bg-muted px-2 py-1">
                      {cmd}
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </div>
        )}
      </ConfirmDialog>
    </div>
  );
}
