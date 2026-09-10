const SI_FACTORS: Record<string, number> = {
  b: 1,
  k: 1e3,
  kb: 1e3,
  m: 1e6,
  mb: 1e6,
  g: 1e9,
  gb: 1e9,
  t: 1e12,
  tb: 1e12,
  p: 1e15,
  pb: 1e15,
};

const BINARY_FACTORS: Record<string, number> = {
  b: 1,
  k: 1024,
  kb: 1024,
  kib: 1024,
  m: 1024 ** 2,
  mb: 1024 ** 2,
  mib: 1024 ** 2,
  g: 1024 ** 3,
  gb: 1024 ** 3,
  gib: 1024 ** 3,
  t: 1024 ** 4,
  tb: 1024 ** 4,
  tib: 1024 ** 4,
  p: 1024 ** 5,
  pb: 1024 ** 5,
  pib: 1024 ** 5,
};

function parseHumanSize(text: string, factors: Record<string, number>): number {
  const cleaned = text.replace(/\([^)]*\)/g, "").trim();
  const match = cleaned.match(/([\d.]+)\s*([a-z]+)?/i);
  if (!match) return 0;
  const value = Number.parseFloat(match[1]);
  if (!Number.isFinite(value) || value < 0) return 0;
  const unit = (match[2] || "b").toLowerCase();
  const factor = factors[unit] ?? 0;
  if (!factor) return 0;
  return Math.round(value * factor);
}

/** Docker `system df` uses SI units (1000), e.g. `1.5GB (40%)`. */
export function parseDockerSize(text: string): number {
  return parseHumanSize(text, SI_FACTORS);
}

/** Homebrew and similar tools print 1024-based KB/MB/GB. */
export function parseBinarySize(text: string): number {
  return parseHumanSize(text, BINARY_FACTORS);
}

/** First column of `du -sk` output (1024-byte blocks). */
export function parseDuKilobytes(stdout: string): number | null {
  const first = stdout.trim().split(/\s+/)[0];
  if (!first) return null;
  const k = Number.parseInt(first, 10);
  if (!Number.isFinite(k) || k < 0) return null;
  return k;
}

export interface DfSizes {
  filesystem: string;
  totalBytes: number;
  usedBytes: number;
  freeBytes: number;
}

/**
 * Parse POSIX `df -kP` output. Uses 1024-byte blocks from df, converted to
 * actual bytes. Filesystem names may contain spaces; Capacity is always `\d+%`.
 */
export function parseDfPosix(stdout: string): DfSizes | null {
  const lines = stdout.trim().split("\n").filter(Boolean);
  if (lines.length < 2) return null;
  const data = lines.slice(1).join(" ");
  const match = data.match(/^(.*?)\s+(\d+)\s+(\d+)\s+(\d+)\s+\d+%\s+(.*)$/);
  if (!match) return null;
  const totalKb = Number.parseInt(match[2], 10);
  const usedKb = Number.parseInt(match[3], 10);
  const availKb = Number.parseInt(match[4], 10);
  if (![totalKb, usedKb, availKb].every((n) => Number.isFinite(n) && n >= 0)) return null;
  return {
    filesystem: match[1].trim() || match[5].trim(),
    totalBytes: totalKb * 1024,
    usedBytes: usedKb * 1024,
    freeBytes: availKb * 1024,
  };
}

export function finiteBytes(n: number): number {
  return Number.isFinite(n) && n > 0 ? n : 0;
}
