import { Router } from "express";
import { authenticate, authenticateAdmin } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";

const router = Router();

// Track analytics event (from client)
router.post("/event", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { eventName, eventData, deviceType, platform } = req.body;

    await prisma.analyticsEvent.create({
      data: {
        userId: req.user!.id,
        eventName,
        eventData: eventData || null,
        deviceType: deviceType || null,
        platform: platform || null,
        ipAddress: req.ip || null,
      },
    });

    ApiResponse.success({ res, statusCode: 201, message: "Event tracked" });
  } catch (error) {
    next(error);
  }
});

// Admin: Dashboard analytics
router.get(
  "/dashboard",
  authenticateAdmin,
  async (_req: AuthRequest, res, next) => {
    try {
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
      const monthAgo = new Date(today.getTime() - 30 * 24 * 60 * 60 * 1000);

      const [
        totalUsers,
        dau,
        wau,
        mau,
        activeSubscriptions,
        totalRevenue,
        totalMovies,
        totalSeries,
      ] = await Promise.all([
        prisma.user.count({ where: { isActive: true } }),
        prisma.user.count({ where: { lastLoginAt: { gte: today } } }),
        prisma.user.count({ where: { lastLoginAt: { gte: weekAgo } } }),
        prisma.user.count({ where: { lastLoginAt: { gte: monthAgo } } }),
        prisma.subscription.count({ where: { status: "ACTIVE" } }),
        prisma.payment.aggregate({
          where: { status: "CAPTURED" },
          _sum: { amount: true },
        }),
        prisma.movie.count({ where: { isPublished: true } }),
        prisma.series.count({ where: { isPublished: true } }),
      ]);

      ApiResponse.success({
        res,
        data: {
          users: { total: totalUsers, dau, wau, mau },
          subscriptions: { active: activeSubscriptions },
          revenue: { total: totalRevenue._sum.amount || 0 },
          content: { movies: totalMovies, series: totalSeries },
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

// Admin: Revenue analytics over time
router.get(
  "/revenue",
  authenticateAdmin,
  async (req: AuthRequest, res, next) => {
    try {
      const { period = "30" } = req.query;
      const daysAgo = new Date(
        Date.now() - Number(period) * 24 * 60 * 60 * 1000,
      );

      const payments = await prisma.payment.findMany({
        where: { status: "CAPTURED", paidAt: { gte: daysAgo } },
        select: { amount: true, paidAt: true, method: true },
        orderBy: { paidAt: "asc" },
      });

      ApiResponse.success({ res, data: payments });
    } catch (error) {
      next(error);
    }
  },
);

// Admin: Content performance
router.get(
  "/content-performance",
  authenticateAdmin,
  async (_req: AuthRequest, res, next) => {
    try {
      const topMovies = await prisma.movie.findMany({
        where: { isPublished: true },
        orderBy: { viewCount: "desc" },
        take: 20,
        select: {
          id: true,
          title: true,
          viewCount: true,
          avgRating: true,
          totalRatings: true,
        },
      });

      const topSeries = await prisma.series.findMany({
        where: { isPublished: true },
        orderBy: { viewCount: "desc" },
        take: 10,
        select: {
          id: true,
          title: true,
          viewCount: true,
          avgRating: true,
          totalRatings: true,
        },
      });

      ApiResponse.success({ res, data: { topMovies, topSeries } });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
