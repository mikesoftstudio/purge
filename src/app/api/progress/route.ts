import { getCleanJob } from "@/lib/jobs";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const jobId = searchParams.get("jobId");
  const job = jobId ? getCleanJob(jobId) : undefined;

  if (!job) {
    return new Response(JSON.stringify({ error: "Job not found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const encoder = new TextEncoder();

  const stream = new ReadableStream<Uint8Array>({
    start(controller) {
      const send = (event: Record<string, unknown>) => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(event)}\n\n`));
      };
      const toRecord = (e: unknown) => e as Record<string, unknown>;

      for (const past of job.events) {
        send(toRecord(past));
      }

      if (!job.running) {
        send({ status: "complete", running: false, cancelled: job.cancelled });
        controller.close();
        return;
      }

      const onProgress = (event: unknown) => send(toRecord(event));
      job.emitter.on("progress", onProgress);

      const checkDone = setInterval(() => {
        if (!job.running) {
          send({ status: "complete", running: false, cancelled: job.cancelled });
          job.emitter.off("progress", onProgress);
          clearInterval(checkDone);
          controller.close();
        }
      }, 500);
    },
    cancel() {
      /* client disconnected — the job continues server-side */
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
    },
  });
}