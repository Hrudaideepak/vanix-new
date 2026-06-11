import { Router } from "express";
import {
  authenticateAdmin,
  generateAdminToken,
} from "@middleware/auth.middleware";
import {
  requirePermission,
  requireRole,
  PERMISSIONS,
} from "@middleware/rbac.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { parsePagination, toPrismaQuery } from "@utils/pagination";
import { BadRequestError, UnauthorizedError } from "@utils/errors";
import bcrypt from "bcryptjs";
import { cache } from "@config/redis";
import { sendPushNotification } from "@utils/notificationHelpers";
import { videoQueue } from "@config/queue";

const router = Router();

// ============================================================
// ADMIN AUTH
// ============================================================

router.post("/login", async (req, res, next) => {
  try {
    const { email, password } = req.body;

    const admin = await prisma.admin.findUnique({
      where: { email },
      include: { role: true },
    });

    if (!admin || !admin.isActive) {
      throw new UnauthorizedError("Invalid credentials");
    }

    const valid = await bcrypt.compare(password, admin.passwordHash);
    if (!valid) {
      throw new UnauthorizedError("Invalid credentials");
    }

    const token = generateAdminToken(admin.id, admin.role.name);

    await prisma.admin.update({
      where: { id: admin.id },
      data: { lastLoginAt: new Date() },
    });

    ApiResponse.success({
      res,
      data: {
        admin: {
          id: admin.id,
          email: admin.email,
          name: admin.name,
          role: admin.role.name,
        },
        token,
      },
    });
  } catch (error) {
    next(error);
  }
});

// ============================================================
// CONTENT MANAGEMENT
// ============================================================

// Create movie
router.post(
  "/movies",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const data = req.body;
      const slug = data.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "");

      const movie = await prisma.movie.create({
        data: {
          ...data,
          slug: data.slug || slug,
          genres: data.genreIds
            ? {
                create: data.genreIds.map((genreId: string) => ({ genreId })),
              }
            : undefined,
        },
        include: { genres: { include: { genre: true } } },
      });

      // Invalidate caches
      await cache.delPattern("content:*");

      ApiResponse.created(res, movie, "Movie created");
    } catch (error) {
      next(error);
    }
  },
);

// Update movie
router.patch(
  "/movies/:id",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_UPDATE),
  async (req: AuthRequest, res, next) => {
    try {
      const { genreIds, ...data } = req.body;

      const movie = await prisma.movie.update({
        where: { id: req.params.id as string },
        data,
        include: { genres: { include: { genre: true } } },
      });

      if (genreIds) {
        await prisma.movieGenre.deleteMany({ where: { movieId: movie.id } });
        await prisma.movieGenre.createMany({
          data: genreIds.map((genreId: string) => ({
            movieId: movie.id,
            genreId,
          })),
        });
      }

      await cache.delPattern("content:*");
      ApiResponse.success({ res, message: "Movie updated", data: movie });
    } catch (error) {
      next(error);
    }
  },
);

// Delete movie
router.delete(
  "/movies/:id",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_DELETE),
  async (req: AuthRequest, res, next) => {
    try {
      await prisma.movie.delete({ where: { id: req.params.id as string } });
      await cache.delPattern("content:*");
      ApiResponse.success({ res, message: "Movie deleted" });
    } catch (error) {
      next(error);
    }
  },
);

// Create series
router.post(
  "/series",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const data = req.body;
      const slug = data.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/(^-|-$)/g, "");

      const series = await prisma.series.create({
        data: { ...data, slug: data.slug || slug },
      });

      await cache.delPattern("content:*");
      ApiResponse.created(res, series, "Series created");
    } catch (error) {
      next(error);
    }
  },
);

// Create season
router.post(
  "/series/:seriesId/seasons",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const season = await prisma.season.create({
        data: { seriesId: req.params.seriesId as string, ...req.body },
      });

      await prisma.series.update({
        where: { id: req.params.seriesId as string },
        data: { totalSeasons: { increment: 1 } },
      });

      ApiResponse.created(res, season, "Season created");
    } catch (error) {
      next(error);
    }
  },
);

// Create episode
router.post(
  "/seasons/:seasonId/episodes",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const episode = await prisma.episode.create({
        data: { seasonId: req.params.seasonId as string, ...req.body },
      });

      await prisma.season.update({
        where: { id: req.params.seasonId as string },
        data: { totalEpisodes: { increment: 1 } },
      });

      ApiResponse.created(res, episode, "Episode created");
    } catch (error) {
      next(error);
    }
  },
);

// Manage banners
router.post(
  "/banners",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const banner = await prisma.banner.create({ data: req.body });
      await cache.del("content:banners");
      ApiResponse.created(res, banner, "Banner created");
    } catch (error) {
      next(error);
    }
  },
);

router.patch(
  "/banners/:id",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_UPDATE),
  async (req: AuthRequest, res, next) => {
    try {
      const banner = await prisma.banner.update({
        where: { id: req.params.id as string },
        data: req.body,
      });
      await cache.del("content:banners");
      ApiResponse.success({ res, data: banner });
    } catch (error) {
      next(error);
    }
  },
);

router.delete(
  "/banners/:id",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_DELETE),
  async (req: AuthRequest, res, next) => {
    try {
      await prisma.banner.delete({ where: { id: req.params.id as string } });
      await cache.del("content:banners");
      ApiResponse.success({ res, message: "Banner deleted" });
    } catch (error) {
      next(error);
    }
  },
);

// Manage genres
router.post(
  "/genres",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const { name, description, iconUrl } = req.body;
      const slug = name.toLowerCase().replace(/[^a-z0-9]+/g, "-");
      const genre = await prisma.genre.create({
        data: { name, slug, description, iconUrl },
      });
      await cache.del("content:genres");
      ApiResponse.created(res, genre, "Genre created");
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// USER MANAGEMENT
// ============================================================

router.get(
  "/users",
  authenticateAdmin,
  requirePermission(PERMISSIONS.USERS_READ),
  async (req: AuthRequest, res, next) => {
    try {
      const pagination = parsePagination(req);
      const { search, status } = req.query;

      const where: any = {};
      if (search) {
        where.OR = [
          { name: { contains: search as string, mode: "insensitive" } },
          { email: { contains: search as string, mode: "insensitive" } },
          { phone: { contains: search as string } },
        ];
      }
      if (status === "banned") where.isBanned = true;
      if (status === "inactive") where.isActive = false;

      const [users, total] = await Promise.all([
        prisma.user.findMany({
          where,
          ...toPrismaQuery(pagination),
          select: {
            id: true,
            email: true,
            phone: true,
            name: true,
            avatarUrl: true,
            isActive: true,
            isBanned: true,
            createdAt: true,
            lastLoginAt: true,
            _count: { select: { devices: true, subscriptions: true } },
          },
        }),
        prisma.user.count({ where }),
      ]);

      ApiResponse.paginated(
        res,
        users,
        total,
        pagination.page,
        pagination.limit,
      );
    } catch (error) {
      next(error);
    }
  },
);

// Ban/Suspend user
router.post(
  "/users/:id/ban",
  authenticateAdmin,
  requirePermission(PERMISSIONS.USERS_MANAGE),
  async (req: AuthRequest, res, next) => {
    try {
      const { reason } = req.body;
      await prisma.user.update({
        where: { id: req.params.id as string },
        data: { isBanned: true, banReason: reason || "Banned by admin" },
      });

      // Deactivate all sessions
      await prisma.session.updateMany({
        where: { userId: req.params.id as string },
        data: { isActive: false },
      });

      // Audit log
      await prisma.auditLog.create({
        data: {
          adminId: req.admin!.id,
          action: "BAN_USER",
          entity: "users",
          entityId: req.params.id as string,
          newData: { reason },
        },
      });

      ApiResponse.success({ res, message: "User banned" });
    } catch (error) {
      next(error);
    }
  },
);

// Unban user
router.post(
  "/users/:id/unban",
  authenticateAdmin,
  requirePermission(PERMISSIONS.USERS_MANAGE),
  async (req: AuthRequest, res, next) => {
    try {
      await prisma.user.update({
        where: { id: req.params.id as string },
        data: { isBanned: false, banReason: null },
      });

      await prisma.auditLog.create({
        data: {
          adminId: req.admin!.id,
          action: "UNBAN_USER",
          entity: "users",
          entityId: req.params.id as string,
        },
      });

      ApiResponse.success({ res, message: "User unbanned" });
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// SUBSCRIPTION MANAGEMENT
// ============================================================

// Manage plans
router.patch(
  "/plans/:id",
  authenticateAdmin,
  requirePermission(PERMISSIONS.SUBSCRIPTIONS_MANAGE),
  async (req: AuthRequest, res, next) => {
    try {
      const plan = await prisma.subscriptionPlan.update({
        where: { id: req.params.id as string },
        data: req.body,
      });
      await cache.del("subscription:plans");
      ApiResponse.success({ res, data: plan });
    } catch (error) {
      next(error);
    }
  },
);

// Create coupon
router.post(
  "/coupons",
  authenticateAdmin,
  requirePermission(PERMISSIONS.SUBSCRIPTIONS_MANAGE),
  async (req: AuthRequest, res, next) => {
    try {
      const { planIds, ...couponData } = req.body;
      const coupon = await prisma.coupon.create({
        data: {
          ...couponData,
          plans: planIds
            ? {
                create: planIds.map((planId: string) => ({ planId })),
              }
            : undefined,
        },
      });
      ApiResponse.created(res, coupon, "Coupon created");
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// NOTIFICATIONS (ADMIN BROADCAST)
// ============================================================

router.post(
  "/notifications/send",
  authenticateAdmin,
  requirePermission(PERMISSIONS.NOTIFICATIONS_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const {
        title,
        body,
        imageUrl,
        type = "PROMOTIONAL",
        userIds,
        segment,
      } = req.body;

      let targetUsers: string[];

      if (userIds && userIds.length > 0) {
        targetUsers = userIds;
      } else if (segment === "all") {
        const users = await prisma.user.findMany({
          where: { isActive: true },
          select: { id: true },
        });
        targetUsers = users.map((u) => u.id);
      } else if (segment === "subscribers") {
        const subs = await prisma.subscription.findMany({
          where: { status: "ACTIVE" },
          select: { userId: true },
        });
        targetUsers = [...new Set(subs.map((s) => s.userId))];
      } else {
        targetUsers = [];
      }

      if (targetUsers.length > 0) {
        await prisma.notification.createMany({
          data: targetUsers.map((userId) => ({
            userId,
            title,
            body,
            imageUrl: imageUrl || null,
            type,
          })),
        });
      }

      // Send FCM push notifications
      if (targetUsers.length > 0) {
        await sendPushNotification(
          targetUsers,
          title,
          body,
          imageUrl || undefined,
        );
      }

      ApiResponse.success({
        res,
        message: `Notification sent to ${targetUsers.length} users`,
      });
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// VIDEO PROCESSING JOBS
// ============================================================

router.get(
  "/video-jobs",
  authenticateAdmin,
  async (req: AuthRequest, res, next) => {
    try {
      const pagination = parsePagination(req);
      const { status } = req.query;

      const where: any = {};
      if (status) where.status = status;

      const [jobs, total] = await Promise.all([
        prisma.videoProcessingJob.findMany({
          where,
          ...toPrismaQuery(pagination),
        }),
        prisma.videoProcessingJob.count({ where }),
      ]);

      ApiResponse.paginated(
        res,
        jobs,
        total,
        pagination.page,
        pagination.limit,
      );
    } catch (error) {
      next(error);
    }
  },
);

router.post(
  "/video-jobs",
  authenticateAdmin,
  requirePermission(PERMISSIONS.CONTENT_CREATE),
  async (req: AuthRequest, res, next) => {
    try {
      const { contentType, contentId, sourceUrl, resolutions } = req.body;

      const job = await prisma.videoProcessingJob.create({
        data: {
          contentType,
          contentId,
          sourceUrl,
          resolutions: resolutions || ["480p", "720p", "1080p"],
          status: "QUEUED",
        },
      });

      // Add to BullMQ processing queue
      await videoQueue.add("process-video", {
        jobId: job.id,
        contentType,
        contentId,
        sourceUrl,
        resolutions: job.resolutions,
      });

      ApiResponse.created(res, job, "Video processing job queued");
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// AUDIT LOGS
// ============================================================

router.get(
  "/audit-logs",
  authenticateAdmin,
  requireRole("super_admin"),
  async (req: AuthRequest, res, next) => {
    try {
      const pagination = parsePagination(req);
      const [logs, total] = await Promise.all([
        prisma.auditLog.findMany({ ...toPrismaQuery(pagination) }),
        prisma.auditLog.count(),
      ]);

      ApiResponse.paginated(
        res,
        logs,
        total,
        pagination.page,
        pagination.limit,
      );
    } catch (error) {
      next(error);
    }
  },
);

export default router;
