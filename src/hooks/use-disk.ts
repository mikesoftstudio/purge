"use client";

import { useEffect, useState } from "react";
import { detectClientPlatform } from "@/lib/client-platform";
import type { DiskInfo } from "@/lib/engine";

export function useDisk() {
  const [disk, setDisk] = useState<DiskInfo | null>(null);
  const [remote, setRemote] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    setError(null);
    try {
      const clientPlatform = detectClientPlatform();
      const res = await fetch(`/api/disk?platform=${clientPlatform}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      setDisk(data);
      setRemote(data.remote ?? false);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Failed to read disk info");
    }
  };

  useEffect(() => {
    void refresh();
  }, []);

  return { disk, remote, error, refresh };
}
