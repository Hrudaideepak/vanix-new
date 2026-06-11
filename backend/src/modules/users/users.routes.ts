import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";

const router = Router();

// Get current user
router.get("/me", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user!.id },
      select: {
        id: true,
        email: true,
        phone: true,
        name: true,
        avatarUrl: true,
        isVerified: true,
        createdAt: true,
        profiles: {
          select: { id: true, name: true, avatarUrl: true, isKids: true },
        },
        subscriptions: {
          where: { status: "ACTIVE" },
          include: { plan: true },
          take: 1,
        },
      },
    });

    ApiResponse.success({ res, data: user });
  } catch (error) {
    next(error);
  }
});

// Update current user
router.patch("/me", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { name, avatarUrl } = req.body;
    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: { name, avatarUrl },
      select: {
        id: true,
        email: true,
        phone: true,
        name: true,
        avatarUrl: true,
      },
    });

    ApiResponse.success({ res, message: "Profile updated", data: user });
  } catch (error) {
    next(error);
  }
});

// Get user devices
router.get("/devices", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const devices = await prisma.device.findMany({
      where: { userId: req.user!.id, isActive: true },
      orderBy: { lastActiveAt: "desc" },
    });

    ApiResponse.success({ res, data: devices });
  } catch (error) {
    next(error);
  }
});

// Remove device
router.delete(
  "/devices/:id",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      await prisma.device.update({
        where: { id: req.params.id as string, userId: req.user!.id },
        data: { isActive: false },
      });

      // Deactivate sessions on that device
      await prisma.session.updateMany({
        where: { deviceId: req.params.id as string, userId: req.user!.id },
        data: { isActive: false },
      });

      ApiResponse.success({ res, message: "Device removed" });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
