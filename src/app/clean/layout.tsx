import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Clean",
  description:
    "Cleaning selected caches from your device. Progress updates in real time.",
};

export default function CleanLayout({ children }: { children: React.ReactNode }) {
  return children;
}
