import { CategoryDefinition } from "../types";
import { detectPlatform } from "../platform";
import { homePath } from "../scanner";

const platform = detectPlatform();

const pipPath = () => {
  if (platform === "windows") return process.env.LOCALAPPDATA ? `${process.env.LOCALAPPDATA}\\pip\\Cache` : homePath("AppData", "Local", "pip", "Cache");
  if (platform === "macos") return homePath("Library", "Caches", "pip");
  return homePath(".cache", "pip");
};

const pipBinary = () => (process.platform === "win32" ? "pip" : "pip3");

export const pipCategory: CategoryDefinition = {
  id: "pip-cache",
  name: "pip Cache",
  description: "Cached Python package wheels used by pip install.",
  safety: "safe",
  tradeoff: "Python packages are re-downloaded on the next pip install.",
  platforms: ["macos", "linux", "windows", "android", "ios"],
  toolRequirement: pipBinary(),
  getPaths: () => [pipPath()],
  cleanCommands: () => [{ command: pipBinary(), args: ["cache", "purge"], label: `${pipBinary()} cache purge` }],
};