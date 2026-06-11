import { Worker, Job } from "bullmq";
import { env } from "@config/env";
import { prisma } from "@config/database";
import { logger } from "@utils/logger";
const redisUrl = new URL(env.REDIS_URL);
const workerConnectionOptions = {
  host: redisUrl.hostname,
  port: parseInt(redisUrl.port) || 6379,
  username: redisUrl.username || undefined,
  password: redisUrl.password || undefined,
  maxRetriesPerRequest: null,
};

export function startVideoWorker(): Worker {
  const worker = new Worker(
    "video-processing",
    async (job: Job) => {
      const { jobId } = job.data;
      logger.info(`🎞️ Video transcoding started for job: ${jobId}`);

      // 1. Update job status to PROCESSING
      await prisma.videoProcessingJob.update({
        where: { id: jobId },
        data: {
          status: "PROCESSING",
          startedAt: new Date(),
          progress: 0,
        },
      });

      // 2. Simulate progressive transcoding steps
      const resolutions = job.data.resolutions || ["480p", "720p", "1080p"];
      const steps = 10;
      const cdnBase = env.R2_PUBLIC_URL || "https://cdn.vanix.com";

      for (let i = 1; i <= steps; i++) {
        // Sleep 1 second per step
        await new Promise((resolve) => setTimeout(resolve, 1000));
        const progress = i * 10;

        logger.info(`🎞️ Transcoding Job ${jobId} progress: ${progress}%`);

        await prisma.videoProcessingJob.update({
          where: { id: jobId },
          data: { progress },
        });
      }

      // 3. Construct dummy streams output URLs
      const hlsOutput = `${cdnBase}/content/${job.data.contentType}/${job.data.contentId}/manifest.m3u8`;
      const dashOutput = `${cdnBase}/content/${job.data.contentType}/${job.data.contentId}/manifest.mpd`;
      const thumbnailsOutput = `${cdnBase}/content/${job.data.contentType}/${job.data.contentId}/thumbnails.vtt`;

      // 4. Update core content entry with stream link
      if (job.data.contentType === "movie") {
        await prisma.movie.update({
          where: { id: job.data.contentId },
          data: {
            hlsUrl: hlsOutput,
            dashUrl: dashOutput,
            quality: resolutions,
          },
        });
      } else if (job.data.contentType === "episode") {
        await prisma.episode.update({
          where: { id: job.data.contentId },
          data: {
            hlsUrl: hlsOutput,
            dashUrl: dashOutput,
            quality: resolutions,
          },
        });
      }

      // 5. Update job status to COMPLETED
      await prisma.videoProcessingJob.update({
        where: { id: jobId },
        data: {
          status: "COMPLETED",
          progress: 100,
          completedAt: new Date(),
          hlsOutput,
          dashOutput,
          thumbnailsOutput,
        },
      });

      logger.info(`🎞️ Successfully completed transcoding job: ${jobId}`);
    },
    {
      connection: workerConnectionOptions,
      concurrency: 1,
    },
  );

  worker.on("failed", async (job, err) => {
    if (job) {
      const { jobId } = job.data;
      logger.error(`🎞️ Transcoding Job ${jobId} failed:`, err.message);

      await prisma.videoProcessingJob.update({
        where: { id: jobId },
        data: {
          status: "FAILED",
          errorMessage: err.message,
          completedAt: new Date(),
        },
      });
    }
  });

  worker.on("error", (err) => {
    logger.error(
      "🎞️ Video processing worker encountered connection/system error:",
      err,
    );
  });

  logger.info("🎞️ Video processing worker started listener.");
  return worker;
}
