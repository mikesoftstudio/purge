/**
 * Client-safe category registry (static metadata only — no Node.js imports).
 * Kept server-side, the full engine in "@/lib/engine" exposes bigger
 * definitions plus the live scan/clean logic.
 */
export const CATEGORY_NAMES: Record<string, string> = {
  "homebrew-cache": "Homebrew",
  "npm-cache": "npm Cache",
  "pnpm-cache": "pnpm Store",
  "yarn-cache": "Yarn Cache",
  "pip-cache": "pip Cache",
  "cocoapods-cache": "CocoaPods Cache",
  "flutter-pub-cache": "Dart / Flutter Pub Cache",
  "flutter-sdk-cache": "Flutter Engine Cache",
  "xcode-deriveddata": "Xcode DerivedData",
  "xcode-devicesupport": "Old iOS DeviceSupport",
  "xcode-simulator-caches": "Simulator Caches",
  "ios-simulators": "Unused iOS Simulators",
  "gradle-build-caches": "Gradle Build Caches",
  "gradle-wrapper-dists": "Gradle Wrapper Downloads",
  "docker": "Docker",
  "go-build-cache": "Go Build Cache",
  "cargo-registry-cache": "Cargo Registry Cache",
  "dotnet-nuget": ".NET / NuGet",
  "chocolatey-cache": "Chocolatey Cache",
  "scoop-cache": "Scoop Cache",
  "trash": "Trash",
  "system-caches": "System Caches & Logs",
};

const CATEGORY_SAFETY: Record<string, "safe" | "moderate" | "advanced"> = {
  "trash": "safe",
  "system-caches": "safe",
  "homebrew-cache": "safe",
  "npm-cache": "safe",
  "pnpm-cache": "safe",
  "yarn-cache": "safe",
  "pip-cache": "safe",
  "cocoapods-cache": "safe",
  "flutter-pub-cache": "safe",
  "flutter-sdk-cache": "moderate",
  "xcode-deriveddata": "safe",
  "xcode-devicesupport": "moderate",
  "xcode-simulator-caches": "safe",
  "ios-simulators": "moderate",
  "gradle-build-caches": "safe",
  "gradle-wrapper-dists": "safe",
  "docker": "advanced",
  "go-build-cache": "safe",
  "cargo-registry-cache": "safe",
  "dotnet-nuget": "moderate",
  "chocolatey-cache": "safe",
  "scoop-cache": "safe",
};

export function categoryName(id: string): string {
  return CATEGORY_NAMES[id] ?? id;
}

export function categorySafety(id: string): "safe" | "moderate" | "advanced" {
  return CATEGORY_SAFETY[id] ?? "safe";
}