import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Summary",
  description:
    "See how much disk space was freed and which caches were cleaned.",
};

export default function SummaryLayout({ children }: { children: React.ReactNode }) {
  return children;
}
