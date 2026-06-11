import { Queue } from "bullmq";
import { env } from "./env";

const redisUrl = new URL(env.REDIS_URL);
const queueConnectionOptions = {
  host: redisUrl.hostname,
  port: parseInt(redisUrl.port) || 6379,
  username: redisUrl.username || undefined,
  password: redisUrl.password || undefined,
  maxRetriesPerRequest: null,
};

export const videoQueue = new Queue("video-processing", {
  connection: queueConnectionOptions,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: "exponential",
      delay: 5000,
    },
  },
});
