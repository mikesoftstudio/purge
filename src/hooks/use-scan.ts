"use client";

import { useCallback, useState } from "react";
import { detectClientPlatform } from "@/lib/client-platform";
import { ScanCategory, ScanResponse } from "@/lib/global-types";
import { saveScanResults } from "@/lib/scan-store";

export function useScan() {
  const [results, setResults] = useState<ScanCategory[] | null>(null);
  const [totalReclaimableBytes, setTotalReclaimableBytes] = useState(0);
  const [platformLabel, setPlatformLabel] = useState("");
  const [scanning, setScanning] = useState(false);
  const [scannedAt, setScannedAt] = useState<number | null>(null);
  const [error, setError] = useState<string | null>(null);

  const scan = useCallback(async () => {
    setScanning(true);
    setError(null);
    try {
      const clientPlatform = detectClientPlatform();
      const res = await fetch(`/api/scan?platform=${clientPlatform}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data: ScanResponse = await res.json();
      setResults(data.results);
      setTotalReclaimableBytes(data.totalReclaimableBytes);
      setPlatformLabel(data.platformLabel);
      setScannedAt(data.scannedAt);
      saveScanResults(data.results, data.platformLabel, data.totalReclaimableBytes, data.scannedAt);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Scan failed");
    } finally {
      setScanning(false);
    }
  }, []);

  return {
    results,
    totalReclaimableBytes,
    platformLabel,
    scanning,
    scannedAt,
    error,
    scan,
  };
}
