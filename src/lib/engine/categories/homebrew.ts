import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

const brewCache = () => {
  if (platform === "macos") return homePath("Library", "Caches", "Homebrew");
  return homePath(".cache", "Homebrew");
};

export const homebrewCategory: CategoryDefinition = {
  id: "homebrew-cache",
  name: "Homebrew",
  description: "Downloaded bottle archive cache plus old package versions.",
  safety: "safe",
  tradeoff: "The next brew install re-downloads bottles; brew cleanup keeps current installs.",
  platforms: ["macos", "linux"],
  toolRequirement: "brew",
  getPaths: () => [brewCache()],
  cleanCommands: () => [
    { command: "rm", args: ["-rf", brewCache()], label: "remove brew download cache" },
    { command: "brew", args: ["cleanup", "--prune=all"], label: "brew cleanup --prune=all" },
  ],
};