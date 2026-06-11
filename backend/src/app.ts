import express, { Express } from "express";
import cors from "cors";
import compression from "compression";
import cookieParser from "cookie-parser";
import morgan from "morgan";
import { env } from "@config/env";
import { apiRateLimiter } from "@middleware/rateLimiter.middleware";
import {
  securityHeaders,
  parameterPollutionProtection,
  requestId,
} from "@middleware/security.middleware";
import {
  errorHandler,
  notFoundHandler,
} from "@middleware/errorHandler.middleware";
import { morganStream } from "@utils/logger";

// Import route modules
import authRoutes from "@modules/auth/auth.routes";
import userRoutes from "@modules/users/users.routes";
import profileRoutes from "@modules/profiles/profiles.routes";
import contentRoutes from "@modules/content/content.routes";
import streamingRoutes from "@modules/streaming/streaming.routes";
import engagementRoutes from "@modules/engagement/engagement.routes";
import searchRoutes from "@modules/search/search.routes";
import recommendationRoutes from "@modules/recommendations/recommendations.routes";
import subscriptionRoutes from "@modules/subscriptions/subscriptions.routes";
import paymentRoutes from "@modules/payments/payments.routes";
import notificationRoutes from "@modules/notifications/notifications.routes";
import analyticsRoutes from "@modules/analytics/analytics.routes";
import adminRoutes from "@modules/admin/admin.routes";

export function createApp(): Express {
  const app = express();

  // ============================================================
  // GLOBAL MIDDLEWARE
  // ============================================================

  // Request ID
  app.use(requestId);

  // Security headers
  app.use(securityHeaders);

  // CORS
  app.use(
    cors({
      origin: env.CORS_ORIGINS.split(",").map((o) => o.trim()),
      credentials: true,
      methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
      allowedHeaders: ["Content-Type", "Authorization", "X-Request-Id"],
      exposedHeaders: ["X-Request-Id"],
      maxAge: 86400,
    }),
  );

  // Body parsing
  app.use(express.json({ limit: "10mb" }));
  app.use(express.urlencoded({ extended: true, limit: "10mb" }));
  app.use(cookieParser());

  // Compression
  app.use(compression());

  // HTTP request logging
  app.use(
    morgan(":method :url :status :res[content-length] - :response-time ms", {
      stream: morganStream,
    }),
  );

  // Security
  app.use(parameterPollutionProtection);

  // Rate limiting
  app.use(`${env.API_PREFIX}`, apiRateLimiter);

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  app.get("/health", (_req, res) => {
    res.status(200).json({
      success: true,
      message: "VANIX API is running",
      version: "1.0.0",
      timestamp: new Date().toISOString(),
      environment: env.NODE_ENV,
    });
  });

  // ============================================================
  // API ROUTES
  // ============================================================

  const prefix = env.API_PREFIX;

  app.use(`${prefix}/auth`, authRoutes);
  app.use(`${prefix}/users`, userRoutes);
  app.use(`${prefix}/profiles`, profileRoutes);
  app.use(`${prefix}/content`, contentRoutes);
  app.use(`${prefix}/streaming`, streamingRoutes);
  app.use(`${prefix}/engagement`, engagementRoutes);
  app.use(`${prefix}/search`, searchRoutes);
  app.use(`${prefix}/recommendations`, recommendationRoutes);
  app.use(`${prefix}/subscriptions`, subscriptionRoutes);
  app.use(`${prefix}/payments`, paymentRoutes);
  app.use(`${prefix}/notifications`, notificationRoutes);
  app.use(`${prefix}/analytics`, analyticsRoutes);
  app.use(`${prefix}/admin`, adminRoutes);

  // ============================================================
  // ERROR HANDLING
  // ============================================================

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
