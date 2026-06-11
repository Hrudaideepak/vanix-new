import { Request, Response, NextFunction } from "express";
import rateLimit from "express-rate-limit";
import { env } from "@config/env";
import { RateLimitError } from "@utils/errors";

/**
 * General API rate limiter
 */
export const apiRateLimiter = rateLimit({
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  max: env.RATE_LIMIT_MAX_REQUESTS,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    success: false,
    message: "Too many requests, please try again later",
  },
  handler: (_req: Request, _res: Response, next: NextFunction) => {
    next(new RateLimitError());
  },
  keyGenerator: (req: Request) => {
    return req.ip || (req.headers["x-forwarded-for"] as string) || "unknown";
  },
} as any);

/**
 * Strict rate limiter for authentication endpoints
 */
export const authRateLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: env.AUTH_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req: Request, _res: Response, next: NextFunction) => {
    next(
      new RateLimitError(
        "Too many authentication attempts. Please try again in 15 minutes.",
      ),
    );
  },
  keyGenerator: (req: Request) => {
    return req.ip || (req.headers["x-forwarded-for"] as string) || "unknown";
  },
} as any);

/**
 * OTP rate limiter — very strict
 */
export const otpRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req: Request, _res: Response, next: NextFunction) => {
    next(
      new RateLimitError(
        "Too many OTP requests. Please wait before requesting again.",
      ),
    );
  },
  keyGenerator: (req: Request) => {
    const identifier = req.body?.phone || req.body?.email || req.ip;
    return `otp:${identifier}`;
  },
} as any);

/**
 * Streaming rate limiter — relaxed
 */
export const streamingRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 300,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req: Request, _res: Response, next: NextFunction) => {
    next(new RateLimitError("Streaming rate limit exceeded."));
  },
} as any);

/**
 * Search rate limiter
 */
export const searchRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req: Request, _res: Response, next: NextFunction) => {
    next(new RateLimitError("Search rate limit exceeded."));
  },
} as any);
