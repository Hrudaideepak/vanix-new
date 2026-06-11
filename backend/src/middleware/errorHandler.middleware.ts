import { Request, Response, NextFunction } from "express";
import { AppError, ValidationError } from "@utils/errors";
import { logger } from "@utils/logger";
import { isProd } from "@config/env";

/**
 * Global error handler middleware
 */
export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  // Default error values
  let statusCode = 500;
  let message = "Internal server error";
  let code = "INTERNAL_ERROR";
  let errors: unknown = undefined;
  let stack: string | undefined = undefined;

  // Handle known operational errors
  if (err instanceof AppError) {
    statusCode = err.statusCode;
    message = err.message;
    code = err.code;

    if (err instanceof ValidationError) {
      errors = err.errors;
    }
  }
  // Handle Prisma errors
  else if (err.name === "PrismaClientKnownRequestError") {
    const prismaErr = err as any;
    switch (prismaErr.code) {
      case "P2002":
        statusCode = 409;
        message = `Duplicate entry for: ${prismaErr.meta?.target?.join(", ")}`;
        code = "CONFLICT";
        break;
      case "P2025":
        statusCode = 404;
        message = "Record not found";
        code = "NOT_FOUND";
        break;
      case "P2003":
        statusCode = 400;
        message = "Related record not found";
        code = "FOREIGN_KEY_ERROR";
        break;
      default:
        statusCode = 400;
        message = "Database error";
        code = "DATABASE_ERROR";
    }
  }
  // Handle JSON parse errors
  else if (err.name === "SyntaxError" && "body" in err) {
    statusCode = 400;
    message = "Invalid JSON in request body";
    code = "INVALID_JSON";
  }

  // Log error
  if (statusCode >= 500) {
    logger.error(`[${code}] ${message}`, {
      error: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
      ip: req.ip,
      requestId: req.headers["x-request-id"],
    });
  } else {
    logger.warn(`[${code}] ${message}`, {
      path: req.path,
      method: req.method,
      statusCode,
    });
  }

  // Include stack trace in development
  if (!isProd) {
    stack = err.stack;
  }

  // Send response
  const response: Record<string, unknown> = {
    success: false,
    message,
    code,
  };

  if (errors) {
    response.errors = errors;
  }

  if (stack) {
    response.stack = stack;
  }

  res.status(statusCode).json(response);
};

/**
 * Handle 404 — route not found
 */
export const notFoundHandler = (req: Request, res: Response): void => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.path} not found`,
    code: "ROUTE_NOT_FOUND",
  });
};
