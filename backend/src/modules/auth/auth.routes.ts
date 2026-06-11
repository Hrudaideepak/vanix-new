import { Router } from "express";
import { AuthController } from "./auth.controller";
import {
  authRateLimiter,
  otpRateLimiter,
} from "@middleware/rateLimiter.middleware";
import { validate } from "@middleware/validation.middleware";
import { authValidators } from "./auth.validators";
import { authenticate } from "@middleware/auth.middleware";

const router = Router();
const controller = new AuthController();

// OTP endpoints
router.post(
  "/send-otp",
  otpRateLimiter,
  validate({ body: authValidators.sendOtp as any }),
  controller.sendOtp,
);

router.post(
  "/verify-otp",
  authRateLimiter,
  validate({ body: authValidators.verifyOtp as any }),
  controller.verifyOtp,
);

// Google OAuth
router.post(
  "/google",
  authRateLimiter,
  validate({ body: authValidators.googleAuth }),
  controller.googleAuth,
);

// Token management
router.post(
  "/refresh",
  validate({ body: authValidators.refreshToken }),
  controller.refreshToken,
);
router.post("/logout", authenticate, controller.logout);
router.post("/logout-all", authenticate, controller.logoutAll);

export default router;
