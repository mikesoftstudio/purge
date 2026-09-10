import { CategoryDefinition } from "../types";
import { homePath } from "../scanner";

const cargoRegistry = () => {
  const home = process.env.CARGO_HOME || homePath(".cargo");
  return `${home}/registry/cache`;
};

export const cargoCategory: CategoryDefinition = {
  id: "cargo-registry-cache",
  name: "Cargo Registry Cache",
  description: "Downloaded crate archives used by cargo build.",
  safety: "safe",
  tradeoff: "Crates are re-downloaded on the next cargo build.",
  platforms: ["macos", "linux", "windows", "android"],
  toolRequirement: "cargo",
  getPaths: () => [cargoRegistry()],
  cleanCommands: () => [{ command: "rm", args: ["-rf", cargoRegistry()], label: "remove cargo registry cache" }],
};