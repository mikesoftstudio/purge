import { CategoryDefinition } from "../types";
import { homePath } from "../scanner";

const nugetPackages = () => homePath(".nuget", "packages");

const nugetHttpCache = () => {
  if (process.platform === "win32") {
    return process.env.LOCALAPPDATA
      ? `${process.env.LOCALAPPDATA}\\NuGet\\v3-cache`
      : homePath("AppData", "Local", "NuGet", "v3-cache");
  }
  return homePath(".local", "share", "NuGet", "v3-cache");
};

const nugetTempCache = () => {
  if (process.platform === "win32") {
    return process.env.TEMP ? `${process.env.TEMP}\\NuGetScratch` : "";
  }
  return "/tmp/NuGetScratch";
};

export const dotnetCategory: CategoryDefinition = {
  id: "dotnet-nuget",
  name: ".NET / NuGet",
  description: "Downloaded NuGet packages and HTTP caches used by dotnet restore.",
  safety: "moderate",
  tradeoff: "The next dotnet restore re-downloads packages, which can be slow.",
  platforms: ["macos", "linux", "windows"],
  toolRequirement: "dotnet",
  getPaths: () => [nugetPackages(), nugetHttpCache(), nugetTempCache()],
  cleanCommands: () => [{ command: "dotnet", args: ["nuget", "locals", "all", "--clear"], label: "dotnet nuget locals all --clear" }],
};