"use client";

import { useEffect, useState } from "react";
import { detectClientPlatform, clientPlatformLabel } from "@/lib/client-platform";
import { PlatformInfo } from "@/lib/global-types";

export function usePlatform() {
  const [info, setInfo] = useState<PlatformInfo | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    const clientPlatform = detectClientPlatform();

    fetch(`/api/tools?platform=${clientPlatform}`)
      .then((res) => res.json())
      .then((data: PlatformInfo) => {
        if (!cancelled) {
          setInfo({
            ...data,
            platform: clientPlatform,
            platformLabel: clientPlatformLabel(clientPlatform),
          });
        }
      })
      .catch(() => {
        if (!cancelled) {
          setInfo({
            platform: clientPlatform,
            platformLabel: clientPlatformLabel(clientPlatform),
            nodeVersion: "",
            home: "",
            tools: [],
          });
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return { info, loading };
}
