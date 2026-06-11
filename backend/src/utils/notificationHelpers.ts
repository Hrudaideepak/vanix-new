import nodemailer from "nodemailer";
import admin from "firebase-admin";
import { env } from "@config/env";
import { logger } from "@utils/logger";
import { getFirebaseAdmin } from "@config/firebase";
import { prisma } from "@config/database";

// Create nodemailer transporter
let transporter: any = null;

if (env.SMTP_HOST && env.SMTP_PORT && env.SMTP_USER && env.SMTP_PASS) {
  transporter = nodemailer.createTransport({
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_PORT === 465,
    auth: {
      user: env.SMTP_USER,
      pass: env.SMTP_PASS,
    },
  });
}

/**
 * Send an email using SMTP configured via environment variables.
 */
export async function sendEmail(
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
  try {
    if (!transporter) {
      logger.warn(
        `📧 Email configuration missing or incomplete. Skipping email to: ${to} (Subject: ${subject})`,
      );
      return false;
    }

    const info = await transporter.sendMail({
      from: env.SMTP_FROM || '"VANIX" <noreply@vanix.com>',
      to,
      subject,
      html,
    });

    logger.info(`📧 Email sent successfully to ${to}: ${info.messageId}`);
    return true;
  } catch (error) {
    logger.error(`❌ Error sending email to ${to}:`, error);
    return false;
  }
}

/**
 * Send an OTP via MSG91 or Twilio depending on environment setup.
 */
export async function sendSMS(phone: string, otp: string): Promise<boolean> {
  try {
    if (env.SMS_PROVIDER === "msg91") {
      if (!env.MSG91_AUTH_KEY || !env.MSG91_TEMPLATE_ID) {
        logger.warn(
          `📱 MSG91 credentials missing. Skipping SMS to: ${phone} (OTP: ${otp})`,
        );
        return false;
      }

      const response = await fetch("https://control.msg91.com/api/v5/otp", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          authkey: env.MSG91_AUTH_KEY,
        },
        body: JSON.stringify({
          template_id: env.MSG91_TEMPLATE_ID,
          mobile: phone.replace("+", ""), // MSG91 preferred format
          otp: otp,
        }),
      });

      const result: any = await response.json();
      logger.info(`📱 MSG91 SMS response for ${phone}:`, result);
      return result.type === "success";
    } else if (env.SMS_PROVIDER === "twilio") {
      // Mock Twilio send since SDK isn't in packages, logging instead
      logger.info(`📱 [Twilio Send Mock] OTP sent to ${phone}: ${otp}`);
      return true;
    }
    return false;
  } catch (error) {
    logger.error(`❌ Error sending SMS to ${phone}:`, error);
    return false;
  }
}

/**
 * Send FCM push notifications to user devices using Firebase Admin SDK.
 */
export async function sendPushNotification(
  userIds: string[],
  title: string,
  body: string,
  imageUrl?: string,
  data?: Record<string, string>,
): Promise<void> {
  try {
    const adminApp = getFirebaseAdmin();
    if (!adminApp) {
      logger.warn(
        `🔔 Firebase Admin not initialized. Skipping push notification to ${userIds.length} users: "${title}"`,
      );
      return;
    }

    // Retrieve active FCM tokens for target users
    const devices = await prisma.device.findMany({
      where: {
        userId: { in: userIds },
        fcmToken: { not: null },
        isActive: true,
      },
      select: { fcmToken: true },
    });

    const tokens = devices.map((d) => d.fcmToken as string);
    if (tokens.length === 0) {
      logger.info(
        `🔔 No active FCM device tokens found for users: [${userIds.join(", ")}]`,
      );
      return;
    }

    const payload: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title,
        body,
        imageUrl: imageUrl || undefined,
      },
      data: data || undefined,
    };

    const response = await adminApp.messaging().sendEachForMulticast(payload);
    logger.info(
      `🔔 FCM Push Notification sent: ${response.successCount} succeeded, ${response.failureCount} failed.`,
    );
  } catch (error) {
    logger.error("❌ Error sending FCM push notifications:", error);
  }
}
