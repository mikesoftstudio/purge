import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

function formatByteValue(bytes: number, units: string[], spacer: string): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 B";
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const value = bytes / Math.pow(1024, i);
  const shown = i === 0 ? String(Math.round(value)) : value >= 100 ? value.toFixed(0) : value >= 10 ? value.toFixed(1) : value.toFixed(2);
  return `${shown}${spacer}${units[i]}`;
}

export function formatBytes(bytes: number): string {
  return formatByteValue(bytes, ["B", "KB", "MB", "GB", "TB"], " ");
}

export function formatBytesShort(bytes: number): string {
  return formatByteValue(bytes, ["B", "K", "M", "G", "T"], "");
}