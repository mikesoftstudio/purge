"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { CleanEvent } from "@/lib/global-types";

export function useClean() {
  const [jobId, setJobId] = useState<string | null>(null);
  const [events, setEvents] = useState<CleanEvent[]>([]);
  const [running, setRunning] = useState(false);
  const [completed, setCompleted] = useState(false);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const eventSourceRef = useRef<EventSource | null>(null);

  const start = useCallback(async (categoryIds: string[], sizes?: Record<string, number>) => {
    if (categoryIds.length === 0) return;
    setEvents([]);
    setRunning(true);
    setCompleted(false);
    setStartedAt(Date.now());

    const res = await fetch("/api/clean", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ categories: categoryIds, sizes }),
    });
    if (!res.ok) {
      setRunning(false);
      throw new Error(`HTTP ${res.status}`);
    }
    const { jobId } = await res.json();
    setJobId(jobId);

    eventSourceRef.current?.close();
    const es = new EventSource(`/api/progress?jobId=${jobId}`);
    eventSourceRef.current = es;

    es.onmessage = (msg) => {
      const data = JSON.parse(msg.data) as { categoryId: string; status: string; label?: string; freedBytes?: number };
      if (data.status === "complete") {
        setRunning(false);
        setCompleted(true);
        es.close();
        eventSourceRef.current = null;
        return;
      }
      setEvents((prev) => {
        const without = prev.filter((e) => e.categoryId !== data.categoryId);
        const ev: CleanEvent = {
          categoryId: data.categoryId,
          status: data.status as CleanEvent["status"],
          label: data.label,
          freedBytes: data.freedBytes,
        };
        return [...without, ev];
      });
    };

    es.onerror = () => {
      setRunning(false);
      setCompleted(true);
      es.close();
      eventSourceRef.current = null;
    };
  }, []);

  const cancel = useCallback(async () => {
    if (!jobId) return;
    try {
      await fetch("/api/cancel", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ jobId }),
      });
    } catch {
      /* ignore */
    }
  }, [jobId]);

  useEffect(() => {
    return () => {
      eventSourceRef.current?.close();
    };
  }, []);

  return { jobId, events, running, completed, startedAt, start, cancel };
}