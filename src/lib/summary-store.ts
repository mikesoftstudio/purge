"use client";

export interface CleanSummaryData {
  totalFreedBytes: number;
  cleaned: string[];
  skipped: string[];
  errored: string[];
  startedAt: number;
  finishedAt: number;
}

const KEY = "purge.last-summary";

export function saveCleanSummary(summary: CleanSummaryData) {
  if (typeof window === "undefined") return;
  try {
    sessionStorage.setItem(KEY, JSON.stringify(summary));
  } catch {
    /* storage unavailable */
  }
}

export function loadCleanSummary(): CleanSummaryData | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = sessionStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as CleanSummaryData) : null;
  } catch {
    return null;
  }
}