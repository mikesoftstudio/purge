import { CategoryDefinition, Platform } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

const npmPath = () => {
  if (platform === "windows") return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\npm-cache` : homePath("AppData", "Local", "npm-cache");
  return homePath(".npm");
};

export const npmCategory: CategoryDefinition = {
  id: "npm-cache",
  name: "npm Cache",
  description: "Downloaded package tarballs and registry metadata used by npm install.",
  safety: "safe",
  tradeoff: "The next npm install in each project re-downloads packages.",
  platforms: ["macos", "linux", "windows", "android", "ios"],
  toolRequirement: "npm",
  getPaths: () => [npmPath()],
  cleanCommands: () => [{ command: "npm", args: ["cache", "clean", "--force"], label: "npm cache clean --force" }],
};

const pnpmPlatforms: Platform[] = ["macos", "linux", "windows", "android"];

const pnpmPath = () => {
  const base = platform === "windows" ? (process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\pnpm` : homePath("AppData", "Local", "pnpm")) : homePath(".cache", "pnpm");
  return base;
};

export const pnpmCategory: CategoryDefinition = {
  id: "pnpm-cache",
  name: "pnpm Store",
  description: "Cached package store and metadata used by pnpm.",
  safety: "safe",
  tradeoff: "Packages are re-downloaded on the next pnpm install.",
  platforms: pnpmPlatforms,
  toolRequirement: "pnpm",
  getPaths: () => [pnpmPath()],
  cleanCommands: () => [
    { command: "pnpm", args: ["store", "prune"], label: "pnpm store prune" },
    { command: "rm", args: ["-rf", pnpmPath()], label: "remove pnpm cache dir" },
  ],
};

const yarnPath = () => {
  if (platform === "windows") return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\Yarn\\Cache` : homePath("AppData", "Local", "Yarn", "Cache");
  if (platform === "macos") return homePath("Library", "Caches", "yarn");
  return homePath(".cache", "yarn");
};

export const yarnCategory: CategoryDefinition = {
  id: "yarn-cache",
  name: "Yarn Cache",
  description: "Cached packages used by yarn install.",
  safety: "safe",
  tradeoff: "Packages are re-downloaded on the next yarn install.",
  platforms: ["macos", "linux", "windows", "android"],
  toolRequirement: "yarn",
  getPaths: () => [yarnPath()],
  cleanCommands: () => [{ command: "yarn", args: ["cache", "clean"], label: "yarn cache clean" }],
};