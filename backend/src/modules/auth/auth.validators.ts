import { z } from "zod";
import { commonSchemas } from "@middleware/validation.middleware";

export const authValidators = {
  sendOtp: z
    .object({
      phone: commonSchemas.phone.optional(),
      email: commonSchemas.email.optional(),
      type: z.enum(["sms", "email"]),
    })
    .refine((data) => data.phone || data.email, {
      message: "Either phone or email is required",
    }),

  verifyOtp: z
    .object({
      phone: commonSchemas.phone.optional(),
      email: commonSchemas.email.optional(),
      otp: commonSchemas.otp,
      deviceName: z.string().min(1).max(100),
      deviceType: z.enum(["MOBILE", "TABLET", "WEB", "TV", "DESKTOP"]),
      deviceId: z.string().min(1).max(255),
      platform: z.string().optional(),
      osVersion: z.string().optional(),
      appVersion: z.string().optional(),
      fcmToken: z.string().optional(),
    })
    .refine((data) => data.phone || data.email, {
      message: "Either phone or email is required",
    }),

  googleAuth: z.object({
    idToken: z.string().min(1, "Google ID token is required"),
    deviceName: z.string().min(1).max(100),
    deviceType: z.enum(["MOBILE", "TABLET", "WEB", "TV", "DESKTOP"]),
    deviceId: z.string().min(1).max(255),
    platform: z.string().optional(),
    osVersion: z.string().optional(),
    appVersion: z.string().optional(),
    fcmToken: z.string().optional(),
  }),

  refreshToken: z.object({
    refreshToken: z.string().min(1, "Refresh token is required"),
  }),
};
