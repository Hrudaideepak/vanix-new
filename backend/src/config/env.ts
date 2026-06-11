import { z } from "zod";
import dotenv from "dotenv";

dotenv.config();

const envSchema = z.object({
  // Server
  NODE_ENV: z
    .enum(["development", "production", "test"])
    .default("development"),
  PORT: z.coerce.number().default(4000),
  API_PREFIX: z.string().default("/api/v1"),
  CORS_ORIGINS: z.string().default("http://localhost:3000"),

  // Database
  DATABASE_URL: z.string().url(),

  // Redis
  REDIS_URL: z.string().default("redis://localhost:6379"),

  // JWT
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ACCESS_EXPIRY: z.string().default("15m"),
  JWT_REFRESH_EXPIRY: z.string().default("7d"),

  // OTP
  OTP_EXPIRY_MINUTES: z.coerce.number().default(5),
  OTP_MAX_ATTEMPTS: z.coerce.number().default(5),
  OTP_RESEND_COOLDOWN_SECONDS: z.coerce.number().default(60),

  // Google OAuth
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),

  // Email
  SMTP_HOST: z.string().optional(),
  SMTP_PORT: z.coerce.number().optional(),
  SMTP_USER: z.string().optional(),
  SMTP_PASS: z.string().optional(),
  SMTP_FROM: z.string().optional(),

  // SMS
  SMS_PROVIDER: z.enum(["msg91", "twilio"]).default("msg91"),
  MSG91_AUTH_KEY: z.string().optional(),
  MSG91_TEMPLATE_ID: z.string().optional(),
  MSG91_SENDER_ID: z.string().default("VANIX"),

  // Cloudflare R2
  R2_ACCOUNT_ID: z.string().optional(),
  R2_ACCESS_KEY_ID: z.string().optional(),
  R2_SECRET_ACCESS_KEY: z.string().optional(),
  R2_BUCKET_NAME: z.string().default("vanix-content"),
  R2_PUBLIC_URL: z.string().optional(),

  // Razorpay
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),

  // Firebase
  FIREBASE_PROJECT_ID: z.string().optional(),
  FIREBASE_PRIVATE_KEY: z.string().optional(),
  FIREBASE_CLIENT_EMAIL: z.string().optional(),

  // Meilisearch
  MEILISEARCH_HOST: z.string().default("http://localhost:7700"),
  MEILISEARCH_API_KEY: z.string().optional(),

  // Sentry
  SENTRY_DSN: z.string().optional(),

  // PostHog
  POSTHOG_API_KEY: z.string().optional(),
  POSTHOG_HOST: z.string().default("https://app.posthog.com"),

  // Rate Limiting
  RATE_LIMIT_WINDOW_MS: z.coerce.number().default(900000),
  RATE_LIMIT_MAX_REQUESTS: z.coerce.number().default(100),
  AUTH_RATE_LIMIT_MAX: z.coerce.number().default(10),

  // Encryption
  ENCRYPTION_KEY: z.string().optional(),

  // CloudFront Signed Cookies
  CLOUDFRONT_PRIVATE_KEY: z.string().optional(),
  CLOUDFRONT_KEY_PAIR_ID: z.string().optional(),
  CLOUDFRONT_COOKIE_DOMAIN: z.string().optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error("❌ Invalid environment variables:");
  console.error(parsed.error.flatten().fieldErrors);
  process.exit(1);
}

export const env = parsed.data;

export const isProd = env.NODE_ENV === "production";
export const isDev = env.NODE_ENV === "development";
export const isTest = env.NODE_ENV === "test";
