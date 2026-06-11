import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { BadRequestError, NotFoundError } from "@utils/errors";

const router = Router();

// List profiles
router.get("/", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const profiles = await prisma.profile.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: "asc" },
    });

    ApiResponse.success({ res, data: profiles });
  } catch (error) {
    next(error);
  }
});

// Create profile
router.post("/", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const count = await prisma.profile.count({
      where: { userId: req.user!.id },
    });
    if (count >= 5) {
      throw new BadRequestError("Maximum 5 profiles allowed");
    }

    const { name, avatarUrl, isKids, pin, maturityRating, language } = req.body;
    const profile = await prisma.profile.create({
      data: {
        userId: req.user!.id,
        name,
        avatarUrl,
        isKids: isKids || false,
        pin,
        maturityRating: maturityRating || (isKids ? "U" : "U/A 16+"),
        language: language || "en",
      },
    });

    ApiResponse.created(res, profile, "Profile created");
  } catch (error) {
    next(error);
  }
});

// Update profile
router.patch("/:id", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const profile = await prisma.profile.findFirst({
      where: { id: req.params.id as string, userId: req.user!.id },
    });

    if (!profile) {
      throw new NotFoundError("Profile");
    }

    const { name, avatarUrl, isKids, pin, maturityRating, language } = req.body;
    const updated = await prisma.profile.update({
      where: { id: req.params.id as string },
      data: { name, avatarUrl, isKids, pin, maturityRating, language },
    });

    ApiResponse.success({ res, message: "Profile updated", data: updated });
  } catch (error) {
    next(error);
  }
});

// Delete profile
router.delete("/:id", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const profile = await prisma.profile.findFirst({
      where: { id: req.params.id as string, userId: req.user!.id },
    });

    if (!profile) {
      throw new NotFoundError("Profile");
    }

    // Don't allow deleting last profile
    const count = await prisma.profile.count({
      where: { userId: req.user!.id },
    });
    if (count <= 1) {
      throw new BadRequestError("Cannot delete your last profile");
    }

    await prisma.profile.delete({ where: { id: req.params.id as string } });

    ApiResponse.success({ res, message: "Profile deleted" });
  } catch (error) {
    next(error);
  }
});

// Verify profile PIN
router.post(
  "/:id/verify-pin",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const profile = await prisma.profile.findFirst({
        where: { id: req.params.id as string, userId: req.user!.id },
      });

      if (!profile) throw new NotFoundError("Profile");

      if (!profile.pin) {
        ApiResponse.success({ res, data: { verified: true } });
        return;
      }

      const { pin } = req.body;
      const verified = profile.pin === pin;

      if (!verified) {
        throw new BadRequestError("Incorrect PIN");
      }

      ApiResponse.success({ res, data: { verified: true } });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
