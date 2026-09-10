export * from "./types";
export { detectPlatform } from "./platform";
export { platformLabel, deviceNoun } from "@/lib/platform-meta";
export { scanCategories, sizeOfPath, homePath, pathExists } from "./scanner";
export { runCleanJob, assertSafePath, UnsafePathError } from "./cleaner";
export { detectTools, hasTool } from "./tool-detect";
export { getDiskInfo } from "./disk";
export {
  ALL_CATEGORIES,
  getCategory,
  categoriesForPlatform,
  npmCategory,
  pnpmCategory,
  yarnCategory,
  pipCategory,
  xcodeDerivedDataCategory,
  xcodeDeviceSupportCategory,
  xcodeSimulatorCachesCategory,
  iosSimulatorsCategory,
  cocoapodsCategory,
  flutterCategory,
  flutterSdkCacheCategory,
  gradleCachesCategory,
  gradleWrapperDistsCategory,
  dockerCategory,
  goCategory,
  cargoCategory,
  homebrewCategory,
  dotnetCategory,
  chocolateyCategory,
  scoopCategory,
  trashCategory,
  systemCategory,
} from "./categories";