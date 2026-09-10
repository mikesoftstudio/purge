import { CategoryDefinition } from "../types";

export const chocolateyCategory: CategoryDefinition = {
  id: "chocolatey-cache",
  name: "Chocolatey Cache",
  description: "HTTP download cache kept by Chocolatey package installs.",
  safety: "safe",
  tradeoff: "Packages are re-downloaded on the next choco install.",
  platforms: ["windows"],
  toolRequirement: "choco",
  getPaths: () => (process.env.TEMP ? [`${process.env.TEMP}\\chocolatey`] : []),
  cleanCommands: () => [{ command: "choco", args: ["cache", "remove"], label: "choco cache remove" }],
};

export const scoopCategory: CategoryDefinition = {
  id: "scoop-cache",
  name: "Scoop Cache",
  description: "Downloaded installers kept by Scoop for app updates.",
  safety: "safe",
  tradeoff: "Apps re-download installers on the next scoop update.",
  platforms: ["windows"],
  toolRequirement: "scoop",
  getPaths: () => (process.env.USERPROFILE ? [`${process.env.USERPROFILE}\\scoop\\cache`] : []),
  cleanCommands: () => [{ command: "scoop", args: ["cache", "rm", "*"], label: "scoop cache rm *" }],
};