import { execFile } from "child_process";
import { promisify } from "util";
import { CategoryDefinition } from "../types";
import { finiteBytes, parseDockerSize } from "../bytes";

const execFileP = promisify(execFile);

/** Reclaimable space reported by `docker system df`. */
export async function dockerReclaimableBytes(): Promise<number> {
  try {
    const { stdout } = await execFileP("docker", ["system", "df", "--format", "{{.Type}}\t{{.Reclaimable}}"], {
      timeout: 15000,
      maxBuffer: 1024 * 1024,
    });
    let total = 0;
    for (const line of stdout.split("\n")) {
      const [, reclaimable] = line.split("\t");
      if (!reclaimable) continue;
      total += parseDockerSize(reclaimable);
    }
    return finiteBytes(total);
  } catch {
    return 0;
  }
}

export const dockerCategory: CategoryDefinition = {
  id: "docker",
  name: "Docker",
  description: "Unused images, stopped containers, build cache and local volumes.",
  safety: "advanced",
  tradeoff: "Containers and images are removed and must be re-pulled or rebuilt later.",
  platforms: ["macos", "linux", "windows"],
  toolRequirement: "docker",
  getPaths: () => [],
  getSizeBytes: dockerReclaimableBytes,
  cleanCommands: () => [
    { command: "docker", args: ["system", "prune", "-af", "--volumes"], label: "docker system prune -af --volumes" },
  ],
  skipReason: async () => {
    try {
      await execFileP("docker", ["info"], { timeout: 8000 });
      return null;
    } catch {
      return "Docker daemon is not running";
    }
  },
};