import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { signStreamUrl } from "@utils/s3";

const router = Router();

// Get streaming manifest (HLS/DASH URL)
router.get(
  "/:contentId/manifest",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const contentId = req.params.contentId as string;
      const { type = "movie" } = req.query;

      let streamUrl: string | null = null;

      if (type === "movie") {
        const movie = await prisma.movie.findUnique({
          where: { id: contentId },
          select: { hlsUrl: true, dashUrl: true, quality: true },
        });
        streamUrl = movie?.hlsUrl || movie?.dashUrl || null;
      } else if (type === "episode") {
        const episode = await prisma.episode.findUnique({
          where: { id: contentId },
          select: { hlsUrl: true, dashUrl: true, quality: true },
        });
        streamUrl = episode?.hlsUrl || episode?.dashUrl || null;
      }

      if (!streamUrl) {
        res
          .status(404)
          .json({ success: false, message: "Stream not available" });
        return;
      }

      // Generate signed URL from Cloudflare R2 for security
      const signedUrl = await signStreamUrl(streamUrl);
      ApiResponse.success({
        res,
        data: {
          streamUrl: signedUrl,
          type: streamUrl.includes(".m3u8") ? "hls" : "dash",
        },
      });
    } catch (error) {
      next(error);
    }
  },
);

// Get AES-128 decryption key for HLS streaming
router.get(
  "/:contentId/key",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const contentId = req.params.contentId as string;
      const { type = "movie" } = req.query;

      // 1. Check if user has an active/trial subscription
      const subscription = await prisma.subscription.findFirst({
        where: {
          userId: req.user!.id,
          status: { in: ["ACTIVE", "TRIAL"] },
          currentPeriodEnd: { gte: new Date() },
        },
      });

      if (!subscription) {
        res.status(403).json({
          success: false,
          message: "Active subscription required to access content",
        });
        return;
      }

      // 2. Fetch the encryption key from database
      const encryptionKey = await prisma.videoEncryptionKey.findUnique({
        where: {
          contentType_contentId: {
            contentType: type as string,
            contentId: contentId,
          },
        },
      });

      if (!encryptionKey) {
        res.status(404).json({
          success: false,
          message: "Decryption key not found for this content",
        });
        return;
      }

      // 3. Return the key as raw binary sequence of 16 octets (bytes)
      const keyBuffer = Buffer.from(encryptionKey.key, "hex");
      res.setHeader("Content-Type", "application/octet-stream");
      res.setHeader("Cache-Control", "no-store, private");
      res.status(200).send(keyBuffer);
    } catch (error) {
      next(error);
    }
  },
);

// Update watch progress
router.post(
  "/:contentId/progress",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const contentId = req.params.contentId as string;
      const {
        progressSeconds,
        totalSeconds,
        type = "movie",
        profileId,
      } = req.body;
      const progressPercent =
        totalSeconds > 0 ? (progressSeconds / totalSeconds) * 100 : 0;

      // Update or create continue watching record
      const data: any = {
        userId: req.user!.id,
        profileId: profileId || null,
        progressSeconds,
        totalSeconds,
        progressPercent,
      };

      if (type === "movie") {
        data.movieId = contentId;
        await prisma.continueWatching.upsert({
          where: {
            userId_profileId_movieId: {
              userId: req.user!.id,
              profileId: profileId || "",
              movieId: contentId,
            },
          },
          create: data,
          update: { progressSeconds, totalSeconds, progressPercent },
        });
      } else {
        data.episodeId = contentId;
        await prisma.continueWatching.upsert({
          where: {
            userId_profileId_episodeId: {
              userId: req.user!.id,
              profileId: profileId || "",
              episodeId: contentId,
            },
          },
          create: data,
          update: { progressSeconds, totalSeconds, progressPercent },
        });
      }

      // If completed (>95%), add to watch history and remove from continue watching
      if (progressPercent > 95) {
        await prisma.watchHistory.create({
          data: {
            userId: req.user!.id,
            profileId: profileId || null,
            movieId: type === "movie" ? contentId : null,
            episodeId: type === "episode" ? contentId : null,
            watchedDuration: progressSeconds,
            totalDuration: totalSeconds,
            completedAt: new Date(),
          },
        });
      }

      ApiResponse.success({ res, message: "Progress updated" });
    } catch (error) {
      next(error);
    }
  },
);

// Get resume position
router.get(
  "/:contentId/resume",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const contentId = req.params.contentId as string;
      const { type = "movie", profileId } = req.query;

      let record = null;
      if (type === "movie") {
        record = await prisma.continueWatching.findFirst({
          where: {
            userId: req.user!.id,
            movieId: contentId,
            profileId: (profileId as string) || undefined,
          },
        });
      } else {
        record = await prisma.continueWatching.findFirst({
          where: {
            userId: req.user!.id,
            episodeId: contentId,
            profileId: (profileId as string) || undefined,
          },
        });
      }

      ApiResponse.success({
        res,
        data: record
          ? {
              progressSeconds: record.progressSeconds,
              totalSeconds: record.totalSeconds,
              progressPercent: record.progressPercent,
            }
          : null,
      });
    } catch (error) {
      next(error);
    }
  },
);

export default router;
