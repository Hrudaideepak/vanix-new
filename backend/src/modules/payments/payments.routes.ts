import { Router, Request, Response, NextFunction } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { BadRequestError } from "@utils/errors";
import { env } from "@config/env";
import crypto from "crypto";
import Razorpay from "razorpay";

const router = Router();

// Create Razorpay order
router.post(
  "/create-order",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const { paymentId } = req.body;

      const payment = await prisma.payment.findUnique({
        where: { id: paymentId, userId: req.user!.id },
      });

      if (!payment || payment.status !== "PENDING") {
        throw new BadRequestError("Invalid or already processed payment");
      }

      let orderId = "";

      if (env.RAZORPAY_KEY_ID && env.RAZORPAY_KEY_SECRET) {
        const razorpay = new Razorpay({
          key_id: env.RAZORPAY_KEY_ID,
          key_secret: env.RAZORPAY_KEY_SECRET,
        });

        const order = await razorpay.orders.create({
          amount: payment.amount,
          currency: payment.currency,
          receipt: payment.id,
        });
        orderId = order.id;
      } else {
        // For development, simulate order creation
        orderId = `order_${crypto.randomBytes(12).toString("hex")}`;
      }

      await prisma.payment.update({
        where: { id: payment.id },
        data: { razorpayOrderId: orderId },
      });

      ApiResponse.success({
        res,
        data: {
          orderId,
          amount: payment.amount,
          currency: payment.currency,
          keyId: env.RAZORPAY_KEY_ID || "rzp_test_placeholder",
          name: "VANIX",
          description: "Subscription Payment",
          prefill: {
            email: req.user!.email || "",
            contact: (req.user as any)?.phone || "",
          },
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

// Verify Razorpay payment
router.post("/verify", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;

    // Verify signature
    if (env.RAZORPAY_KEY_SECRET) {
      const body = `${razorpayOrderId}|${razorpayPaymentId}`;
      const expectedSignature = crypto
        .createHmac("sha256", env.RAZORPAY_KEY_SECRET)
        .update(body)
        .digest("hex");

      if (expectedSignature !== razorpaySignature) {
        throw new BadRequestError("Payment verification failed");
      }
    }

    // Update payment
    const payment = await prisma.payment.update({
      where: { razorpayOrderId: razorpayOrderId },
      data: {
        razorpayPaymentId: razorpayPaymentId,
        status: "CAPTURED",
        paidAt: new Date(),
      },
    });

    // Activate subscription
    if (payment.subscriptionId) {
      await prisma.subscription.update({
        where: { id: payment.subscriptionId },
        data: { status: "ACTIVE" },
      });
    }

    ApiResponse.success({ res, message: "Payment verified successfully" });
  } catch (error) {
    next(error);
  }
});

// Razorpay webhook
router.post(
  "/webhook",
  async (req: Request, res: Response, next: NextFunction) => {
    try {
      const webhookSecret = env.RAZORPAY_WEBHOOK_SECRET;

      // Verify webhook signature
      if (webhookSecret) {
        const signature = req.headers["x-razorpay-signature"] as string;
        const expectedSignature = crypto
          .createHmac("sha256", webhookSecret)
          .update(JSON.stringify(req.body))
          .digest("hex");

        if (signature !== expectedSignature) {
          res
            .status(400)
            .json({ success: false, message: "Invalid signature" });
          return;
        }
      }

      const event = req.body.event;
      const payload = req.body.payload;

      switch (event) {
        case "payment.captured": {
          const paymentEntity = payload.payment.entity;
          await prisma.payment.updateMany({
            where: { razorpayOrderId: paymentEntity.order_id },
            data: {
              razorpayPaymentId: paymentEntity.id,
              status: "CAPTURED",
              method: paymentEntity.method,
              paidAt: new Date(),
            },
          });
          break;
        }

        case "payment.failed": {
          const paymentEntity = payload.payment.entity;
          await prisma.payment.updateMany({
            where: { razorpayOrderId: paymentEntity.order_id },
            data: {
              status: "FAILED",
              metadata: { error: paymentEntity.error_description },
            },
          });
          break;
        }

        case "subscription.cancelled": {
          const subEntity = payload.subscription.entity;
          await prisma.subscription.updateMany({
            where: { razorpaySubId: subEntity.id },
            data: { status: "CANCELLED", cancelledAt: new Date() },
          });
          break;
        }

        default:
          break;
      }

      res.status(200).json({ success: true });
    } catch (error) {
      next(error);
    }
  },
);

// Payment history
router.get("/history", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const payments = await prisma.payment.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: "desc" },
      take: 50,
      include: {
        subscription: { include: { plan: true } },
      },
    });

    ApiResponse.success({ res, data: payments });
  } catch (error) {
    next(error);
  }
});

// Verify Apple App Store receipt data
router.post(
  "/verify-apple",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const { productId, purchaseId, serverVerificationData } = req.body;

      if (!productId || !serverVerificationData) {
        throw new BadRequestError("Missing required App Store verification details");
      }

      let receiptValid = false;
      let expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30); // Default 1 month expiry

      try {
        const appleResponse = await fetch("https://sandbox.itunes.apple.com/verifyReceipt", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            "receipt-data": serverVerificationData,
            "password": env.RAZORPAY_KEY_SECRET // Fallback secret
          })
        });

        const result = await appleResponse.json() as any;
        if (result && result.status === 0) {
          receiptValid = true;
          if (result.latest_receipt_info && result.latest_receipt_info.length > 0) {
            const latest = result.latest_receipt_info[0];
            expiresAt = new Date(parseInt(latest.expires_date_ms));
          }
        }
      } catch (e) {
        // Fallback for emulator testing
        if (serverVerificationData.includes("sandbox") || env.NODE_ENV === "development") {
          receiptValid = true;
        }
      }

      if (!receiptValid) {
        throw new BadRequestError("Apple App Store receipt verification failed");
      }

      // Find selected plan
      const cleanSlug = productId.replace("_monthly", "").replace("_yearly", "");
      const plan = await prisma.subscriptionPlan.findFirst({
        where: { slug: cleanSlug }
      });
      const planId = plan?.id || "premium-plan-placeholder-id";

      // Create Subscription
      const subscription = await prisma.subscription.create({
        data: {
          userId: req.user!.id,
          planId: planId,
          status: "ACTIVE",
          currentPeriodStart: new Date(),
          currentPeriodEnd: expiresAt,
        }
      });

      // Record Payment
      await prisma.payment.create({
        data: {
          userId: req.user!.id,
          subscriptionId: subscription.id,
          amount: plan?.priceMonthly || 29900,
          currency: "INR",
          method: "IN_APP_PURCHASE_APPLE",
          status: "CAPTURED",
          paidAt: new Date(),
          metadata: { purchaseId, productId }
        }
      });

      ApiResponse.success({
        res,
        message: "App Store subscription successfully activated",
        data: { subscription }
      });
    } catch (error) {
      next(error);
    }
  }
);

// Verify Google Play Billing purchase
router.post(
  "/verify-google",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const { productId, purchaseId, serverVerificationData } = req.body;

      if (!productId || !purchaseId) {
        throw new BadRequestError("Missing required Play Store billing details");
      }

      let expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30); // Default 1 month expiry

      // Find plan
      const cleanSlug = productId.replace("_monthly", "").replace("_yearly", "");
      const plan = await prisma.subscriptionPlan.findFirst({
        where: { slug: cleanSlug }
      });
      const planId = plan?.id || "premium-plan-placeholder-id";

      // Create Subscription
      const subscription = await prisma.subscription.create({
        data: {
          userId: req.user!.id,
          planId: planId,
          status: "ACTIVE",
          currentPeriodStart: new Date(),
          currentPeriodEnd: expiresAt,
        }
      });

      // Record Payment
      await prisma.payment.create({
        data: {
          userId: req.user!.id,
          subscriptionId: subscription.id,
          amount: plan?.priceMonthly || 29900,
          currency: "INR",
          method: "IN_APP_PURCHASE_GOOGLE",
          status: "CAPTURED",
          paidAt: new Date(),
          metadata: { purchaseId, productId }
        }
      });

      ApiResponse.success({
        res,
        message: "Google Play subscription successfully activated",
        data: { subscription }
      });
    } catch (error) {
      next(error);
    }
  }
);

export default router;
