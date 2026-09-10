import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Scan",
  description:
    "Scan your device to find regenerable caches, build artifacts and logs. Read-only — nothing is deleted until you confirm.",
};

export default function ScanLayout({ children }: { children: React.ReactNode }) {
  return children;
}
