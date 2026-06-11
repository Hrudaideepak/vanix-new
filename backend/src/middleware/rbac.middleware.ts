import { Response, NextFunction } from "express";
import { AuthRequest } from "@custom-types/index";
import { ForbiddenError, UnauthorizedError } from "@utils/errors";

/**
 * Check if admin has required permission
 */
export const requirePermission = (...requiredPermissions: string[]) => {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    if (!req.admin) {
      return next(new UnauthorizedError("Admin authentication required"));
    }

    // Super Admin bypasses all permission checks
    if (req.admin.role === "super_admin") {
      return next();
    }

    const hasPermission = requiredPermissions.every((perm) =>
      req.admin!.permissions.includes(perm),
    );

    if (!hasPermission) {
      return next(
        new ForbiddenError(
          `Missing required permissions: ${requiredPermissions.join(", ")}`,
        ),
      );
    }

    next();
  };
};

/**
 * Check if admin has any of the required roles
 */
export const requireRole = (...roles: string[]) => {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    if (!req.admin) {
      return next(new UnauthorizedError("Admin authentication required"));
    }

    if (!roles.includes(req.admin.role)) {
      return next(
        new ForbiddenError(
          `This action requires one of the following roles: ${roles.join(", ")}`,
        ),
      );
    }

    next();
  };
};

/**
 * Ensure the authenticated user can only access their own resources
 */
export const requireOwnership = (paramKey: string = "userId") => {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(new UnauthorizedError());
    }

    const resourceUserId = req.params[paramKey];
    if (resourceUserId && resourceUserId !== req.user.id) {
      return next(new ForbiddenError("You can only access your own resources"));
    }

    next();
  };
};

// Pre-defined permission constants
export const PERMISSIONS = {
  // Content
  CONTENT_CREATE: "content:create",
  CONTENT_READ: "content:read",
  CONTENT_UPDATE: "content:update",
  CONTENT_DELETE: "content:delete",
  CONTENT_MANAGE: "content:manage",

  // Users
  USERS_READ: "users:read",
  USERS_UPDATE: "users:update",
  USERS_DELETE: "users:delete",
  USERS_MANAGE: "users:manage",

  // Subscriptions
  SUBSCRIPTIONS_READ: "subscriptions:read",
  SUBSCRIPTIONS_UPDATE: "subscriptions:update",
  SUBSCRIPTIONS_MANAGE: "subscriptions:manage",

  // Analytics
  ANALYTICS_READ: "analytics:read",
  ANALYTICS_MANAGE: "analytics:manage",

  // Admin
  ADMIN_READ: "admin:read",
  ADMIN_CREATE: "admin:create",
  ADMIN_UPDATE: "admin:update",
  ADMIN_DELETE: "admin:delete",
  ADMIN_MANAGE: "admin:manage",

  // Notifications
  NOTIFICATIONS_CREATE: "notifications:create",
  NOTIFICATIONS_MANAGE: "notifications:manage",
} as const;
