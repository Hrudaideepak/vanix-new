import { Request, Response, NextFunction } from "express";
import { AnyZodObject, ZodError, z } from "zod";
import { ValidationError } from "@utils/errors";

/**
 * Validate request body, query, and params using Zod schemas
 */
export const validate = (schema: {
  body?: z.ZodTypeAny;
  query?: z.ZodTypeAny;
  params?: z.ZodTypeAny;
}) => {
  return async (
    req: Request,
    _res: Response,
    next: NextFunction,
  ): Promise<void> => {
    try {
      if (schema.body) {
        req.body = await schema.body.parseAsync(req.body);
      }
      if (schema.query) {
        req.query = (await schema.query.parseAsync(req.query)) as any;
      }
      if (schema.params) {
        req.params = (await schema.params.parseAsync(req.params)) as any;
      }
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        const formattedErrors: Record<string, string[]> = {};
        error.errors.forEach((err) => {
          const path = err.path.join(".");
          if (!formattedErrors[path]) {
            formattedErrors[path] = [];
          }
          formattedErrors[path].push(err.message);
        });
        next(new ValidationError("Validation failed", formattedErrors));
      } else {
        next(error);
      }
    }
  };
};

// ============================================================
// Common validation schemas
// ============================================================

export const commonSchemas = {
  id: z.object({
    id: z.string().uuid("Invalid ID format"),
  }),

  pagination: z.object({
    page: z.coerce.number().min(1).default(1).optional(),
    limit: z.coerce.number().min(1).max(100).default(20).optional(),
    sortBy: z.string().optional(),
    sortOrder: z.enum(["asc", "desc"]).default("desc").optional(),
  }),

  search: z.object({
    q: z.string().min(1).max(200),
    page: z.coerce.number().min(1).default(1).optional(),
    limit: z.coerce.number().min(1).max(50).default(20).optional(),
  }),

  email: z.string().email("Invalid email address"),

  phone: z.string().regex(/^\+?[1-9]\d{9,14}$/, "Invalid phone number"),

  otp: z
    .string()
    .length(6, "OTP must be 6 digits")
    .regex(/^\d{6}$/, "OTP must be numeric"),

  password: z.string().min(8).max(128),

  slug: z.string().regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "Invalid slug format"),
};
