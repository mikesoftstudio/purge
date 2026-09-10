import { CategoryDefinition, Platform } from "../types";
import { detectPlatform } from "../platform";
import { npmCategory, pnpmCategory, yarnCategory } from "./npm";
import { pipCategory } from "./python";
import {
  xcodeDerivedDataCategory,
  xcodeDeviceSupportCategory,
  xcodeSimulatorCachesCategory,
  iosSimulatorsCategory,
} from "./xcode";
import { cocoapodsCategory } from "./cocoapods";
import { flutterCategory, flutterSdkCacheCategory } from "./flutter";
import { gradleCachesCategory, gradleWrapperDistsCategory } from "./gradle";
import { dockerCategory } from "./docker";
import { goCategory } from "./go";
import { cargoCategory } from "./rust";
import { homebrewCategory } from "./homebrew";
import { dotnetCategory } from "./dotnet";
import { chocolateyCategory, scoopCategory } from "./windows-tools";
import { trashCategory } from "./trash";
import { systemCategory } from "./system";

/** Full registry in display order (roughly grouped by relevance). */
export const ALL_CATEGORIES: CategoryDefinition[] = [
  trashCategory,
  systemCategory,
  homebrewCategory,
  npmCategory,
  pnpmCategory,
  yarnCategory,
  pipCategory,
  cocoapodsCategory,
  flutterCategory,
  flutterSdkCacheCategory,
  xcodeDerivedDataCategory,
  xcodeDeviceSupportCategory,
  xcodeSimulatorCachesCategory,
  iosSimulatorsCategory,
  gradleCachesCategory,
  gradleWrapperDistsCategory,
  dockerCategory,
  goCategory,
  cargoCategory,
  dotnetCategory,
  chocolateyCategory,
  scoopCategory,
];

const byId = new Map<string, CategoryDefinition>(ALL_CATEGORIES.map((c) => [c.id, c]));

export function getCategory(id: string): CategoryDefinition | undefined {
  return byId.get(id);
}

/** Categories that can be cleaned on the running platform. */
export function categoriesForPlatform(platform: Platform = detectPlatform()): CategoryDefinition[] {
  return ALL_CATEGORIES.filter((c) => c.platforms.includes(platform));
}

export * from "./npm";
export * from "./python";
export * from "./xcode";
export * from "./cocoapods";
export * from "./flutter";
export * from "./gradle";
export * from "./docker";
export * from "./go";
export * from "./rust";
export * from "./homebrew";
export * from "./dotnet";
export * from "./windows-tools";
export * from "./trash";
export * from "./system";