import { EventEmitter } from "events";
import { randomUUID } from "crypto";
import { CategoryDefinition, CleanProgressEvent } from "./engine/types";
import { runCleanJob } from "./engine/cleaner";

export interface CleanJob {
  id: string;
  running: boolean;
  cancelled: boolean;
  events: CleanProgressEvent[];
  emitter: EventEmitter;
  startedAt: number;
}

const jobs = new Map<string, CleanJob>();

export function createCleanJob(categories: CategoryDefinition[], measuredSizes?: Map<string, number>): CleanJob {
  const job: CleanJob = {
    id: randomUUID(),
    running: true,
    cancelled: false,
    events: [],
    emitter: new EventEmitter(),
    startedAt: Date.now(),
  };
  jobs.set(job.id, job);

  void runCleanJob({
    categories,
    measuredSizes,
    onProgress: (event) => {
      job.events.push(event);
      job.emitter.emit("progress", event);
    },
    isCancelled: () => job.cancelled,
  }).finally(() => {
    job.running = false;
  });

  return job;
}

export function getCleanJob(id: string): CleanJob | undefined {
  return jobs.get(id);
}

export function cancelCleanJob(id: string): boolean {
  const job = jobs.get(id);
  if (!job) return false;
  job.cancelled = true;
  return true;
}

// Cleanup finished jobs after 10 minutes to avoid unbounded memory.
setInterval(() => {
  const cutoff = Date.now() - 10 * 60 * 1000;
  for (const [id, job] of jobs) {
    if (!job.running && job.startedAt < cutoff) {
      jobs.delete(id);
    }
  }
}, 5 * 60 * 1000).unref();