import Redis from "ioredis";
import { env } from "./env";
import { logger } from "@utils/logger";

class RedisClient {
  private static instance: Redis | null = null;

  static getInstance(): Redis {
    if (!RedisClient.instance) {
      RedisClient.instance = new Redis(env.REDIS_URL, {
        maxRetriesPerRequest: 3,
        retryStrategy(times: number) {
          const delay = Math.min(times * 50, 2000);
          return delay;
        },
        reconnectOnError(err: Error) {
          const targetErrors = ["READONLY", "ECONNRESET", "ECONNREFUSED"];
          return targetErrors.some((e) => err.message.includes(e));
        },
        lazyConnect: true,
      });

      RedisClient.instance.on("connect", () => {
        logger.info("✅ Redis connected successfully");
      });

      RedisClient.instance.on("error", (err: Error) => {
        logger.error("❌ Redis connection error:", err.message);
      });

      RedisClient.instance.on("close", () => {
        logger.warn("Redis connection closed");
      });
    }

    return RedisClient.instance;
  }

  static async disconnect(): Promise<void> {
    if (RedisClient.instance) {
      await RedisClient.instance.quit();
      RedisClient.instance = null;
      logger.info("Redis disconnected");
    }
  }
}

export const redis = RedisClient.getInstance();

// Helper functions for common Redis patterns
export const cache = {
  async get<T>(key: string): Promise<T | null> {
    const data = await redis.get(key);
    if (!data) return null;
    try {
      return JSON.parse(data) as T;
    } catch {
      return data as unknown as T;
    }
  },

  async set(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
    const serialized =
      typeof value === "string" ? value : JSON.stringify(value);
    if (ttlSeconds) {
      await redis.setex(key, ttlSeconds, serialized);
    } else {
      await redis.set(key, serialized);
    }
  },

  async del(key: string): Promise<void> {
    await redis.del(key);
  },

  async delPattern(pattern: string): Promise<void> {
    const keys = await redis.keys(pattern);
    if (keys.length > 0) {
      await redis.del(...keys);
    }
  },

  async exists(key: string): Promise<boolean> {
    const result = await redis.exists(key);
    return result === 1;
  },

  async incr(key: string): Promise<number> {
    return redis.incr(key);
  },

  async expire(key: string, ttlSeconds: number): Promise<void> {
    await redis.expire(key, ttlSeconds);
  },
};
