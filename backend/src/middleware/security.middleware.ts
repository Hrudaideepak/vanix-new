import { Request, Response, NextFunction } from "express";
import helmet from "helmet";
import hpp from "hpp";

/**
 * Security headers via Helmet
 */
export const securityHeaders = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "blob:", "*.cloudflare.com", "*.vanix.com"],
      mediaSrc: ["'self'", "*.cloudflare.com", "*.vanix.com"],
      connectSrc: ["'self'", "*.vanix.com"],
      fontSrc: ["'self'", "fonts.googleapis.com", "fonts.gstatic.com"],
      objectSrc: ["'none'"],
      frameSrc: ["'none'"],
    },
  },
  crossOriginEmbedderPolicy: false,
  crossOriginResourcePolicy: { policy: "cross-origin" },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true,
  },
  referrerPolicy: { policy: "strict-origin-when-cross-origin" },
  xssFilter: true,
  noSniff: true,
  dnsPrefetchControl: { allow: true },
  frameguard: { action: "deny" },
});

/**
 * HTTP Parameter Pollution protection
 */
export const parameterPollutionProtection = hpp({
  whitelist: ["genre", "language", "quality", "year"],
});

/**
 * Request ID middleware — attach unique ID to each request
 */
export const requestId = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const id = (req.headers["x-request-id"] as string) || crypto.randomUUID();
  req.headers["x-request-id"] = id;
  res.setHeader("X-Request-Id", id);
  next();
};
