import { Request, Response, NextFunction } from "express";
import jwt from "jsonwebtoken";
import { env } from "@config/env";
import { prisma } from "@config/database";
import { redis } from "@config/redis";
import { UnauthorizedError, ForbiddenError } from "@utils/errors";
import { AuthRequest } from "@custom-types/index";
import { jwtPrivateKey, jwtPublicKey } from "@config/keys";

interface JwtPayload {
  userId: string;
  sessionId: string;
  type: "access" | "refresh";
  iat: number;
  exp: number;
}

/**
 * Authenticate user via JWT access token
 */
export const authenticate = async (
  req: AuthRequest,
  _res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      throw new UnauthorizedError("No token provided");
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
      throw new UnauthorizedError("No token provided");
    }

    // Check if token is blacklisted
    const isBlacklisted = await redis.get(`bl:${token}`);
    if (isBlacklisted) {
      throw new UnauthorizedError("Token has been revoked");
    }

    // Verify JWT using asymmetric RS256 public key
    const decoded = jwt.verify(token, jwtPublicKey, { algorithms: ["RS256"] }) as JwtPayload;
    if (decoded.type !== "access") {
      throw new UnauthorizedError("Invalid token type");
    }

    // Check session is still active
    const session = await prisma.session.findUnique({
      where: { id: decoded.sessionId },
    });

    if (!session || !session.isActive) {
      throw new UnauthorizedError("Session expired or revoked");
    }

    // Get user
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        phone: true,
        name: true,
        isActive: true,
        isBanned: true,
      },
    });

    if (!user) {
      throw new UnauthorizedError("User not found");
    }

    if (!user.isActive || user.isBanned) {
      throw new ForbiddenError("Account is suspended or banned");
    }

    req.user = user;
    req.sessionId = decoded.sessionId;
    req.deviceId = session.deviceId || undefined;

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      next(new UnauthorizedError("Token expired"));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(new UnauthorizedError("Invalid token"));
    } else {
      next(error);
    }
  }
};

/**
 * Optional authentication — sets user if token present, but doesn't block
 */
export const optionalAuth = async (
  req: AuthRequest,
  _res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return next();
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
      return next();
    }

    const decoded = jwt.verify(token, jwtPublicKey, { algorithms: ["RS256"] }) as JwtPayload;
    const user = await prisma.user.findUnique({
      where: { id: decoded.userId },
      select: {
        id: true,
        email: true,
        phone: true,
        name: true,
        isActive: true,
        isBanned: true,
      },
    });

    if (user && user.isActive && !user.isBanned) {
      req.user = user;
      req.sessionId = decoded.sessionId;
    }

    next();
  } catch {
    // Token is invalid/expired but that's okay for optional auth
    next();
  }
};

/**
 * Authenticate admin users
 */
export const authenticateAdmin = async (
  req: AuthRequest,
  _res: Response,
  next: NextFunction,
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      throw new UnauthorizedError("No token provided");
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
      throw new UnauthorizedError("No token provided");
    }

    const decoded = jwt.verify(token, jwtPublicKey, { algorithms: ["RS256"] }) as JwtPayload & {
      adminId: string;
      role: string;
    };

    const admin = await prisma.admin.findUnique({
      where: { id: decoded.adminId },
      include: {
        role: {
          include: {
            permissions: {
              include: {
                permission: true,
              },
            },
          },
        },
      },
    });

    if (!admin || !admin.isActive) {
      throw new UnauthorizedError("Admin account not found or inactive");
    }

    req.admin = {
      id: admin.id,
      email: admin.email,
      name: admin.name,
      role: admin.role.name,
      permissions: admin.role.permissions.map(
        (rp) => `${rp.permission.module}:${rp.permission.action}`,
      ),
    };

    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      next(new UnauthorizedError("Token expired"));
    } else if (error instanceof jwt.JsonWebTokenError) {
      next(new UnauthorizedError("Invalid token"));
    } else {
      next(error);
    }
  }
};

/**
 * Generate JWT tokens
 */
export function generateTokens(userId: string, sessionId: string) {
  const accessToken = jwt.sign(
    { userId, sessionId, type: "access" },
    jwtPrivateKey,
    { algorithm: "RS256", expiresIn: env.JWT_ACCESS_EXPIRY as any, keyid: env.JWT_KEY_ID },
  );

  const refreshToken = jwt.sign(
    { userId, sessionId, type: "refresh" },
    env.JWT_REFRESH_SECRET,
    { expiresIn: env.JWT_REFRESH_EXPIRY as any },
  );

  return { accessToken, refreshToken };
}

/**
 * Generate admin JWT token
 */
export function generateAdminToken(adminId: string, role: string) {
  return jwt.sign({ adminId, role, type: "access" }, jwtPrivateKey, {
    algorithm: "RS256",
    expiresIn: "8h",
    keyid: env.JWT_KEY_ID,
  });
}

/**
 * Blacklist a token (for logout)
 */
export async function blacklistToken(
  token: string,
  expiresInSeconds: number,
): Promise<void> {
  await redis.setex(`bl:${token}`, expiresInSeconds, "1");
}
