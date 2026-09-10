import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

const goBuildCachePath = () => {
  if (platform === "windows") return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\go-build` : homePath("AppData", "Local", "go-build");
  if (platform === "macos") return homePath("Library", "Caches", "go-build");
  return homePath(".cache", "go-build");
};

const goModCachePath = () => {
  if (platform === "windows") return process.env.USERPROFILE ? `${process.env.USERPROFILE}\\go\\pkg\\mod` : homePath("go", "pkg", "mod");
  return homePath("go", "pkg", "mod");
};

export const goCategory: CategoryDefinition = {
  id: "go-build-cache",
  name: "Go Build Cache",
  description: "Compiled Go package artifacts and downloaded module sources.",
  safety: "safe",
  tradeoff: "The first go build after cleaning is slower.",
  platforms: ["macos", "linux", "windows", "android"],
  toolRequirement: "go",
  getPaths: () => [goBuildCachePath(), goModCachePath()],
  cleanCommands: () => [
    { command: "go", args: ["clean", "-cache"], label: "go clean -cache" },
    { command: "go", args: ["clean", "-modcache"], label: "go clean -modcache" },
  ],
};