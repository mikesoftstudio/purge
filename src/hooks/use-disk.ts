"use client";

import { useEffect, useState } from "react";
import type { DiskInfo } from "@/lib/engine";

export function useDisk() {
  const [disk, setDisk] = useState<DiskInfo | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    setError(null);
    try {
      const res = await fetch("/api/disk");
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      setDisk(await res.json());
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to read disk info");
    }
  };

  useEffect(() => {
    void refresh();
  }, []);

  return { disk, error, refresh };
}