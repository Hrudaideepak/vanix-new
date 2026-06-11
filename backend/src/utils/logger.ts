import winston from "winston";
import { env, isProd } from "@config/env";

const { combine, timestamp, printf, colorize, errors, json } = winston.format;

// Custom log format for development
const devFormat = printf(({ level, message, timestamp, stack, ...meta }) => {
  const metaStr = Object.keys(meta).length
    ? `\n${JSON.stringify(meta, null, 2)}`
    : "";
  return `${timestamp} [${level}] ${stack || message}${metaStr}`;
});

// Create logger instance
export const logger = winston.createLogger({
  level: isProd ? "info" : "debug",
  defaultMeta: { service: "vanix-api" },
  format: combine(
    errors({ stack: true }),
    timestamp({ format: "YYYY-MM-DD HH:mm:ss" }),
  ),
  transports: [
    // Console transport
    new winston.transports.Console({
      format: isProd ? combine(json()) : combine(colorize(), devFormat),
    }),

    // File transports for production
    ...(isProd
      ? [
          new winston.transports.File({
            filename: "logs/error.log",
            level: "error",
            maxsize: 5 * 1024 * 1024, // 5MB
            maxFiles: 5,
            format: combine(json()),
          }),
          new winston.transports.File({
            filename: "logs/combined.log",
            maxsize: 10 * 1024 * 1024, // 10MB
            maxFiles: 10,
            format: combine(json()),
          }),
        ]
      : []),
  ],
  // Don't exit on uncaught exceptions
  exitOnError: false,
});

// Stream for Morgan HTTP request logging
export const morganStream = {
  write: (message: string) => {
    logger.http(message.trim());
  },
};
