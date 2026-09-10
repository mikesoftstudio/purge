import { useEffect, useState } from "react";
import type { Platform, SafetyTier } from "@/lib/engine";

/** Serializable scan category returned by /api/scan. */
export interface ScanCategory {
  id: string;
  name: string;
  description: string;
  safety: SafetyTier;
  tradeoff: string;
  applicable: boolean;
  detected: boolean;
  toolMissing: boolean;
  totalSizeBytes: number;
  paths: { path: string; sizeBytes: number; exists: boolean }[];
  /** Present in remote/guidance mode — human-readable cleanup commands. */
  cleanupCommands?: string[];
  /** Present in remote mode — tool that must be installed. */
  toolRequirement?: string;
}

export interface ScanResponse {
  platform: Platform;
  platformLabel: string;
  remote: boolean;
  results: ScanCategory[];
  totalReclaimableBytes: number;
  scannedAt: number;
}

export interface CleanEvent {
  categoryId: string;
  status: "cleaning" | "done" | "error" | "skipped";
  label?: string;
  freedBytes?: number;
}

export interface ToolInfoDto {
  name: string;
  installed: boolean;
  version?: string;
}

export interface PlatformInfo {
  platform: Platform;
  platformLabel: string;
  nodeVersion: string;
  home: string;
  tools: ToolInfoDto[];
  remote?: boolean;
}