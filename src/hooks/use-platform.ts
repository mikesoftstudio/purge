"use client";

import { useEffect, useState } from "react";
import { PlatformInfo } from "@/lib/global-types";

export function usePlatform() {
  const [info, setInfo] = useState<PlatformInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    fetch("/api/tools")
      .then((res) => res.json())
      .then((data: PlatformInfo) => {
        if (!cancelled) setInfo(data);
      })
      .catch(() => {})
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { info, loading };
}