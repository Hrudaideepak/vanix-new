import { prisma } from "@config/database";
import { cache } from "@config/redis";
import { env } from "@config/env";
import { generateTokens, blacklistToken } from "@middleware/auth.middleware";
import {
  BadRequestError,
  UnauthorizedError,
  ConflictError,
} from "@utils/errors";
import { logger } from "@utils/logger";
import jwt from "jsonwebtoken";
import { sendSMS, sendEmail } from "@utils/notificationHelpers";
import { OAuth2Client } from "google-auth-library";
import { DeviceType } from "@prisma/client";

const googleClient = new OAuth2Client(env.GOOGLE_CLIENT_ID);

interface SendOtpInput {
  phone?: string;
  email?: string;
  type: "sms" | "email";
}

interface VerifyOtpInput {
  phone?: string;
  email?: string;
  otp: string;
  deviceName: string;
  deviceType: string;
  deviceId: string;
  platform?: string;
  osVersion?: string;
  appVersion?: string;
  fcmToken?: string;
}

interface GoogleAuthInput {
  idToken: string;
  deviceName: string;
  deviceType: string;
  deviceId: string;
  platform?: string;
  osVersion?: string;
  appVersion?: string;
  fcmToken?: string;
}

export class AuthService {
  /**
   * Send OTP to phone or email
   */
  async sendOtp(input: SendOtpInput): Promise<void> {
    const identifier = input.phone || input.email;
    if (!identifier) {
      throw new BadRequestError("Phone or email is required");
    }

    // Check rate limit in Redis
    const rateLimitKey = `otp_rate:${identifier}`;
    const attempts = await cache.get<number>(rateLimitKey);
    if (attempts && attempts >= env.OTP_MAX_ATTEMPTS) {
      throw new BadRequestError(
        "Too many OTP requests. Please try again later.",
      );
    }

    // Check cooldown
    const cooldownKey = `otp_cooldown:${identifier}`;
    const hasCooldown = await cache.exists(cooldownKey);
    if (hasCooldown) {
      throw new BadRequestError(
        `Please wait ${env.OTP_RESEND_COOLDOWN_SECONDS} seconds before requesting a new OTP.`,
      );
    }

    // Generate 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Store OTP in Redis with TTL
    const otpKey = `otp:${identifier}`;
    await cache.set(otpKey, otp, env.OTP_EXPIRY_MINUTES * 60);

    // Set cooldown
    await cache.set(cooldownKey, "1", env.OTP_RESEND_COOLDOWN_SECONDS);

    // Increment rate limit
    await cache.incr(rateLimitKey);
    await cache.expire(rateLimitKey, 3600); // 1 hour window

    // Send OTP via SMS or Email
    if (input.type === "sms" && input.phone) {
      await sendSMS(input.phone, otp);
      logger.info(`📱 OTP for ${input.phone}: ${otp}`);
    } else if (input.type === "email" && input.email) {
      await sendEmail(
        input.email,
        "VANIX Verification OTP",
        `<p>Your verification OTP for VANIX is: <strong>${otp}</strong>. It will expire in ${env.OTP_EXPIRY_MINUTES} minutes.</p>`,
      );
      logger.info(`📧 OTP for ${input.email}: ${otp}`);
    }
  }

  /**
   * Verify OTP and create session
   */
  async verifyOtp(input: VerifyOtpInput) {
    const identifier = input.phone || input.email;
    if (!identifier) {
      throw new BadRequestError("Phone or email is required");
    }

    // Get stored OTP
    const otpKey = `otp:${identifier}`;
    const storedOtp = await cache.get<string>(otpKey);

    if (!storedOtp) {
      throw new BadRequestError(
        "OTP expired or not found. Please request a new one.",
      );
    }

    if (storedOtp !== input.otp) {
      throw new BadRequestError("Invalid OTP");
    }

    // Clear OTP
    await cache.del(otpKey);

    // Find or create user
    let user = await prisma.user.findFirst({
      where: input.phone ? { phone: input.phone } : { email: input.email },
    });

    if (!user) {
      user = await prisma.user.create({
        data: {
          phone: input.phone || null,
          email: input.email || null,
          isVerified: true,
          // Create default profile
          profiles: {
            create: {
              name: input.phone || input.email || "User",
              avatarUrl: null,
            },
          },
        },
      });
    } else {
      // Update last login
      await prisma.user.update({
        where: { id: user.id },
        data: { lastLoginAt: new Date(), isVerified: true },
      });
    }

    // Register/update device
    const device = await this.upsertDevice(user.id, input);

    // Create session
    const session = await this.createSession(user.id, device.id, input);

    // Generate tokens
    const tokens = generateTokens(user.id, session.id);

    // Update session with refresh token
    await prisma.session.update({
      where: { id: session.id },
      data: { refreshToken: tokens.refreshToken },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        name: user.name,
        avatarUrl: user.avatarUrl,
        isVerified: user.isVerified,
      },
      tokens,
      isNewUser: !user.name,
    };
  }

  /**
   * Google OAuth login
   */
  async googleAuth(input: GoogleAuthInput) {
    // Verify Google ID token
    const ticket = await googleClient.verifyIdToken({
      idToken: input.idToken,
      audience: env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      throw new UnauthorizedError("Invalid Google token");
    }

    // Find or create user
    let user = await prisma.user.findFirst({
      where: {
        OR: [{ googleId: payload.sub }, { email: payload.email }],
      },
    });

    if (!user) {
      user = await prisma.user.create({
        data: {
          email: payload.email,
          googleId: payload.sub,
          name: payload.name || null,
          avatarUrl: payload.picture || null,
          isVerified: true,
          profiles: {
            create: {
              name: payload.name || payload.email,
              avatarUrl: payload.picture || null,
            },
          },
        },
      });
    } else {
      // Link Google account if not linked
      await prisma.user.update({
        where: { id: user.id },
        data: {
          googleId: payload.sub,
          lastLoginAt: new Date(),
          name: user.name || payload.name || null,
          avatarUrl: user.avatarUrl || payload.picture || null,
        },
      });
    }

    // Register/update device
    const device = await this.upsertDevice(user.id, input);

    // Create session
    const session = await this.createSession(user.id, device.id, input);

    // Generate tokens
    const tokens = generateTokens(user.id, session.id);

    await prisma.session.update({
      where: { id: session.id },
      data: { refreshToken: tokens.refreshToken },
    });

    return {
      user: {
        id: user.id,
        email: user.email,
        phone: user.phone,
        name: user.name,
        avatarUrl: user.avatarUrl,
        isVerified: user.isVerified,
      },
      tokens,
      isNewUser: false,
    };
  }

  /**
   * Refresh access token
   */
  async refreshToken(refreshToken: string) {
    // Verify refresh token
    let decoded: any;
    try {
      decoded = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET);
    } catch {
      throw new UnauthorizedError("Invalid or expired refresh token");
    }

    if (decoded.type !== "refresh") {
      throw new UnauthorizedError("Invalid token type");
    }

    // Find session
    const session = await prisma.session.findUnique({
      where: { refreshToken },
    });

    if (!session || !session.isActive) {
      throw new UnauthorizedError("Session not found or revoked");
    }

    // Check expiry
    if (session.expiresAt < new Date()) {
      await prisma.session.update({
        where: { id: session.id },
        data: { isActive: false },
      });
      throw new UnauthorizedError("Session expired");
    }

    // Generate new tokens (rotation)
    const tokens = generateTokens(decoded.userId, session.id);

    // Update session with new refresh token
    await prisma.session.update({
      where: { id: session.id },
      data: { refreshToken: tokens.refreshToken },
    });

    return tokens;
  }

  /**
   * Logout — invalidate current session
   */
  async logout(
    userId: string,
    sessionId: string,
    accessToken: string,
  ): Promise<void> {
    // Deactivate session
    await prisma.session.update({
      where: { id: sessionId },
      data: { isActive: false },
    });

    // Blacklist current access token (15 min)
    await blacklistToken(accessToken, 900);
  }

  /**
   * Logout all — invalidate all sessions
   */
  async logoutAll(userId: string): Promise<void> {
    await prisma.session.updateMany({
      where: { userId, isActive: true },
      data: { isActive: false },
    });
  }

  /**
   * Helper: Create or update device record
   */
  private async upsertDevice(
    userId: string,
    input: {
      deviceName: string;
      deviceType: string;
      deviceId: string;
      platform?: string;
      osVersion?: string;
      appVersion?: string;
      fcmToken?: string;
    },
  ) {
    return prisma.device.upsert({
      where: {
        userId_deviceId: {
          userId,
          deviceId: input.deviceId,
        },
      },
      create: {
        userId,
        deviceName: input.deviceName,
        deviceType: input.deviceType as DeviceType,
        deviceId: input.deviceId,
        platform: input.platform,
        osVersion: input.osVersion,
        appVersion: input.appVersion,
        fcmToken: input.fcmToken,
        isActive: true,
        lastActiveAt: new Date(),
      },
      update: {
        deviceName: input.deviceName,
        platform: input.platform,
        osVersion: input.osVersion,
        appVersion: input.appVersion,
        fcmToken: input.fcmToken,
        isActive: true,
        lastActiveAt: new Date(),
      },
    });
  }

  /**
   * Helper: Create session
   */
  private async createSession(userId: string, deviceId: string, input: any) {
    // Calculate expiry (7 days)
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    return prisma.session.create({
      data: {
        userId,
        deviceId,
        refreshToken: "pending", // Will be updated after token generation
        ipAddress: null,
        userAgent: null,
        isActive: true,
        expiresAt,
      },
    });
  }
}
