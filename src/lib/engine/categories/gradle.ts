import { CategoryDefinition } from "../types";
import { homePath } from "../scanner";

const gradleRoot = () => {
  if (process.platform === "win32") return process.env.USERPROFILE ? `${process.env.USERPROFILE}\\.gradle` : homePath(".gradle");
  return homePath(".gradle");
};

const caches = () => `${gradleRoot()}/caches`;
const wrapperDists = () => `${gradleRoot()}/wrapper/dists`;

export const gradleCachesCategory: CategoryDefinition = {
  id: "gradle-build-caches",
  name: "Gradle Build Caches",
  description: "Compiled module and dependency caches shared across Android/JVM builds.",
  safety: "safe",
  tradeoff: "The first build after cleaning is slower while dependencies reload.",
  platforms: ["macos", "linux", "windows", "android"],
  getPaths: () => [caches()],
  cleanCommands: () => [{ command: "rm", args: ["-rf", caches()], label: "remove Gradle caches" }],
};

export const gradleWrapperDistsCategory: CategoryDefinition = {
  id: "gradle-wrapper-dists",
  name: "Gradle Wrapper Downloads",
  description: "Downloaded Gradle distributions used by ./gradlew.",
  safety: "safe",
  tradeoff: "The next ./gradlew run re-downloads the bundled Gradle version.",
  platforms: ["macos", "linux", "windows", "android"],
  getPaths: () => [wrapperDists()],
  cleanCommands: () => [{ command: "rm", args: ["-rf", wrapperDists()], label: "remove Gradle wrapper dists" }],
};