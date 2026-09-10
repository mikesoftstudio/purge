"use client";

import { useEffect, useState } from "react";

export interface BrowserStorageEstimate {
  quota: number;
  usage: number;
  usageDetails?: Record<string, number>;
  isRemote: boolean;
}

/**
 * Uses the Storage Manager API to estimate how much browser storage is
 * available and used. Falls back gracefully when the API is unavailable.
 *
 * When `isRemote` is true, the app is hosted on a remote server (not the
 * user's local machine), so we can't access the local filesystem — only
 * browser-managed storage is measurable.
 */
export function useBrowserStorage() {
  const [estimate, setEstimate] = useState<BrowserStorageEstimate | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;

    async function query() {
      try {
        if (typeof navigator !== "undefined" && "storage" in navigator && "estimate" in navigator.storage) {
          const est = await navigator.storage.estimate();
          if (!cancelled) {
            setEstimate({
              quota: est.quota ?? 0,
              usage: est.usage ?? 0,
              usageDetails: (est as Record<string, unknown>).usageDetails as Record<string, number> | undefined,
              isRemote: true,
            });
          }
        } else {
          if (!cancelled) setEstimate({ quota: 0, usage: 0, isRemote: true });
        }
      } catch {
        if (!cancelled) setEstimate({ quota: 0, usage: 0, isRemote: true });
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void query();
    return () => { cancelled = true; };
  }, []);

  return { estimate, loading };
}
