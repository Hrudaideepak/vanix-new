import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { parsePagination, toPrismaQuery } from "@utils/pagination";

const router = Router();

// Get user notifications
router.get("/", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const pagination = parsePagination(req, { sortBy: "createdAt" });

    const [notifications, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where: { userId: req.user!.id },
        ...toPrismaQuery(pagination),
      }),
      prisma.notification.count({ where: { userId: req.user!.id } }),
      prisma.notification.count({
        where: { userId: req.user!.id, isRead: false },
      }),
    ]);

    ApiResponse.success({
      res,
      data: notifications,
      meta: {
        ...pagination,
        total,
        totalPages: Math.ceil(total / pagination.limit),
        hasNext: pagination.page < Math.ceil(total / pagination.limit),
        hasPrev: pagination.page > 1,
      },
    });
  } catch (error) {
    next(error);
  }
});

// Get unread count
router.get(
  "/unread-count",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const count = await prisma.notification.count({
        where: { userId: req.user!.id, isRead: false },
      });

      ApiResponse.success({ res, data: { count } });
    } catch (error) {
      next(error);
    }
  },
);

// Mark notification as read
router.patch("/:id/read", authenticate, async (req: AuthRequest, res, next) => {
  try {
    await prisma.notification.update({
      where: { id: req.params.id as string, userId: req.user!.id },
      data: { isRead: true, readAt: new Date() },
    });

    ApiResponse.success({ res, message: "Notification marked as read" });
  } catch (error) {
    next(error);
  }
});

// Mark all as read
router.patch("/read-all", authenticate, async (req: AuthRequest, res, next) => {
  try {
    await prisma.notification.updateMany({
      where: { userId: req.user!.id, isRead: false },
      data: { isRead: true, readAt: new Date() },
    });

    ApiResponse.success({ res, message: "All notifications marked as read" });
  } catch (error) {
    next(error);
  }
});

// Delete notification
router.delete("/:id", authenticate, async (req: AuthRequest, res, next) => {
  try {
    await prisma.notification.delete({
      where: { id: req.params.id as string, userId: req.user!.id },
    });

    ApiResponse.success({ res, message: "Notification deleted" });
  } catch (error) {
    next(error);
  }
});

export default router;
