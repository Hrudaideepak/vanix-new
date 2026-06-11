import { createApp } from "./app";
import { env } from "@config/env";
import { connectDatabase, disconnectDatabase } from "@config/database";
import { redis } from "@config/redis";
import { logger } from "@utils/logger";
import { startVideoWorker } from "./workers/videoWorker";
import { syncContentToMeilisearch } from "./utils/searchSync";

async function bootstrap(): Promise<void> {
  try {
    // Connect to database
    await connectDatabase();

    // Connect to Redis
    await redis.connect();

    // Start video transcoding background worker
    startVideoWorker();

    // Run Meilisearch sync in background
    syncContentToMeilisearch().catch((err) => {
      logger.error("Failed to sync content to Meilisearch on startup:", err);
    });

    // Create Express app
    const app = createApp();

    // Start server
    const server = app.listen(env.PORT, () => {
      logger.info(`
╔══════════════════════════════════════════════════╗
║                                                  ║
║   🎬 VANIX API Server                            ║
║                                                  ║
║   Environment : ${env.NODE_ENV.padEnd(30)}║
║   Port        : ${String(env.PORT).padEnd(30)}║
║   API Prefix  : ${env.API_PREFIX.padEnd(30)}║
║   Health      : http://localhost:${env.PORT}/health       ║
║                                                  ║
╚══════════════════════════════════════════════════╝
      `);
    });

    // Graceful shutdown
    const gracefulShutdown = async (signal: string) => {
      logger.info(`${signal} received. Starting graceful shutdown...`);

      server.close(async () => {
        logger.info("HTTP server closed");

        // Close database connection
        await disconnectDatabase();

        // Close Redis connection
        await redis.quit();
        logger.info("Redis connection closed");

        logger.info("Graceful shutdown complete");
        process.exit(0);
      });

      // Force shutdown after 30 seconds
      setTimeout(() => {
        logger.error("Forced shutdown due to timeout");
        process.exit(1);
      }, 30000);
    };

    process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
    process.on("SIGINT", () => gracefulShutdown("SIGINT"));

    // Unhandled rejection handler
    process.on("unhandledRejection", (reason: unknown) => {
      logger.error("Unhandled Rejection:", reason);
    });

    // Uncaught exception handler
    process.on("uncaughtException", (error: Error) => {
      logger.error("Uncaught Exception:", error);
      process.exit(1);
    });
  } catch (error) {
    logger.error("❌ Failed to start server:", error);
    process.exit(1);
  }
}

bootstrap();
