import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { cache } from "@config/redis";
import { AuthRequest } from "@custom-types/index";
import { BadRequestError } from "@utils/errors";

const router = Router();

// Get all subscription plans
router.get("/plans", async (_req, res, next) => {
  try {
    const cached = await cache.get("subscription:plans");
    if (cached) {
      ApiResponse.success({ res, data: cached });
      return;
    }

    const plans = await prisma.subscriptionPlan.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: "asc" },
    });

    await cache.set("subscription:plans", plans, 3600);
    ApiResponse.success({ res, data: plans });
  } catch (error) {
    next(error);
  }
});

// Get current subscription status
router.get("/status", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const subscription = await prisma.subscription.findFirst({
      where: { userId: req.user!.id, status: "ACTIVE" },
      include: { plan: true },
      orderBy: { createdAt: "desc" },
    });

    ApiResponse.success({
      res,
      data: subscription
        ? {
            id: subscription.id,
            plan: subscription.plan,
            status: subscription.status,
            currentPeriodStart: subscription.currentPeriodStart,
            currentPeriodEnd: subscription.currentPeriodEnd,
            isExpired: subscription.currentPeriodEnd < new Date(),
            daysRemaining: Math.max(
              0,
              Math.ceil(
                (subscription.currentPeriodEnd.getTime() - Date.now()) /
                  (1000 * 60 * 60 * 24),
              ),
            ),
          }
        : null,
    });
  } catch (error) {
    next(error);
  }
});

// Subscribe to a plan
router.post("/subscribe", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { planId, couponCode } = req.body;

    // Check existing active subscription
    const existing = await prisma.subscription.findFirst({
      where: { userId: req.user!.id, status: "ACTIVE" },
    });

    if (existing) {
      throw new BadRequestError(
        "You already have an active subscription. Please upgrade instead.",
      );
    }

    const plan = await prisma.subscriptionPlan.findUnique({
      where: { id: planId },
    });
    if (!plan || !plan.isActive) {
      throw new BadRequestError("Invalid or inactive plan");
    }

    // Apply coupon if provided
    let discount = 0;
    let coupon = null;
    if (couponCode) {
      coupon = await prisma.coupon.findUnique({ where: { code: couponCode } });
      if (!coupon || !coupon.isActive || coupon.validUntil < new Date()) {
        throw new BadRequestError("Invalid or expired coupon");
      }
      if (coupon.maxUses && coupon.usedCount >= coupon.maxUses) {
        throw new BadRequestError("Coupon usage limit reached");
      }

      if (coupon.discountType === "PERCENTAGE") {
        discount = Math.floor((plan.priceMonthly * coupon.discountValue) / 100);
        if (coupon.maxDiscount)
          discount = Math.min(discount, coupon.maxDiscount);
      } else {
        discount = coupon.discountValue;
      }
    }

    const finalAmount = Math.max(0, plan.priceMonthly - discount);

    // Create subscription
    const now = new Date();
    const periodEnd = new Date(now);
    periodEnd.setMonth(periodEnd.getMonth() + 1);

    const subscription = await prisma.subscription.create({
      data: {
        userId: req.user!.id,
        planId: plan.id,
        status: "ACTIVE",
        currentPeriodStart: now,
        currentPeriodEnd: periodEnd,
      },
      include: { plan: true },
    });

    // Create payment record
    await prisma.payment.create({
      data: {
        userId: req.user!.id,
        subscriptionId: subscription.id,
        amount: finalAmount,
        currency: "INR",
        status: "PENDING",
        couponId: coupon?.id || null,
        discountAmount: discount,
      },
    });

    // Increment coupon usage
    if (coupon) {
      await prisma.coupon.update({
        where: { id: coupon.id },
        data: { usedCount: { increment: 1 } },
      });
    }

    ApiResponse.created(
      res,
      {
        subscription,
        payment: {
          amount: finalAmount,
          currency: "INR",
          discount,
        },
      },
      "Subscription created",
    );
  } catch (error) {
    next(error);
  }
});

// Upgrade subscription
router.post("/upgrade", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { planId } = req.body;

    const current = await prisma.subscription.findFirst({
      where: { userId: req.user!.id, status: "ACTIVE" },
      include: { plan: true },
    });

    if (!current) {
      throw new BadRequestError("No active subscription found");
    }

    const newPlan = await prisma.subscriptionPlan.findUnique({
      where: { id: planId },
    });
    if (!newPlan || !newPlan.isActive) {
      throw new BadRequestError("Invalid plan");
    }

    if (newPlan.priceMonthly <= current.plan.priceMonthly) {
      throw new BadRequestError("Can only upgrade to a higher plan");
    }

    // Update subscription
    const updated = await prisma.subscription.update({
      where: { id: current.id },
      data: { planId: newPlan.id },
      include: { plan: true },
    });

    // Create prorated payment
    const remaining = Math.max(
      0,
      current.currentPeriodEnd.getTime() - Date.now(),
    );
    const totalPeriod =
      current.currentPeriodEnd.getTime() - current.currentPeriodStart.getTime();
    const proratedCredit = Math.floor(
      (remaining / totalPeriod) * current.plan.priceMonthly,
    );
    const upgradeAmount = Math.max(0, newPlan.priceMonthly - proratedCredit);

    await prisma.payment.create({
      data: {
        userId: req.user!.id,
        subscriptionId: updated.id,
        amount: upgradeAmount,
        currency: "INR",
        status: "PENDING",
        metadata: {
          type: "upgrade",
          from: current.plan.name,
          to: newPlan.name,
        },
      },
    });

    ApiResponse.success({
      res,
      message: "Subscription upgraded",
      data: { subscription: updated, upgradeAmount },
    });
  } catch (error) {
    next(error);
  }
});

// Cancel subscription
router.post("/cancel", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { reason } = req.body;

    const subscription = await prisma.subscription.findFirst({
      where: { userId: req.user!.id, status: "ACTIVE" },
    });

    if (!subscription) {
      throw new BadRequestError("No active subscription found");
    }

    await prisma.subscription.update({
      where: { id: subscription.id },
      data: {
        status: "CANCELLED",
        cancelledAt: new Date(),
        cancelReason: reason || null,
      },
    });

    ApiResponse.success({
      res,
      message:
        "Subscription cancelled. You can still access content until the end of your billing period.",
      data: { accessUntil: subscription.currentPeriodEnd },
    });
  } catch (error) {
    next(error);
  }
});

// Validate coupon
router.post(
  "/validate-coupon",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const { code, planId } = req.body;

      const coupon = await prisma.coupon.findUnique({
        where: { code },
        include: { plans: true },
      });

      if (!coupon || !coupon.isActive) {
        throw new BadRequestError("Invalid coupon code");
      }

      if (coupon.validFrom > new Date() || coupon.validUntil < new Date()) {
        throw new BadRequestError("Coupon has expired");
      }

      if (coupon.maxUses && coupon.usedCount >= coupon.maxUses) {
        throw new BadRequestError("Coupon usage limit reached");
      }

      // Check plan eligibility
      if (coupon.plans.length > 0 && planId) {
        const eligible = coupon.plans.some((cp) => cp.planId === planId);
        if (!eligible) {
          throw new BadRequestError("Coupon not valid for this plan");
        }
      }

      ApiResponse.success({
        res,
        data: {
          code: coupon.code,
          discountType: coupon.discountType,
          discountValue: coupon.discountValue,
          maxDiscount: coupon.maxDiscount,
          description: coupon.description,
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
