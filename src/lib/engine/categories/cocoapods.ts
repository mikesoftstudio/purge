import { CategoryDefinition } from "../types";
import { homePath } from "../scanner";

export const cocoapodsCategory: CategoryDefinition = {
  id: "cocoapods-cache",
  name: "CocoaPods Cache",
  description: "Downloaded CocoaPods spec and pod archives.",
  safety: "safe",
  tradeoff: "Pods are re-downloaded on the next pod install.",
  platforms: ["macos"],
  toolRequirement: "pod",
  getPaths: () => [homePath("Library", "Caches", "CocoaPods")],
  cleanCommands: () => [{ command: "rm", args: ["-rf", homePath("Library", "Caches", "CocoaPods")], label: "remove CocoaPods cache" }],
};