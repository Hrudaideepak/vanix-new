import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";
import { parsePagination, toPrismaQuery } from "@utils/pagination";

const router = Router();

// ============================================================
// WATCHLIST
// ============================================================

router.get("/watchlist", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { profileId } = req.query;
    const pagination = parsePagination(req, { sortBy: "addedAt" });

    const where: any = { userId: req.user!.id };
    if (profileId) where.profileId = profileId;

    const [items, total] = await Promise.all([
      prisma.watchlist.findMany({
        where,
        ...toPrismaQuery(pagination),
        include: {
          movie: {
            select: {
              id: true,
              title: true,
              posterUrl: true,
              slug: true,
              runtime: true,
              avgRating: true,
            },
          },
          series: {
            select: {
              id: true,
              title: true,
              posterUrl: true,
              slug: true,
              totalSeasons: true,
              avgRating: true,
            },
          },
        },
      }),
      prisma.watchlist.count({ where }),
    ]);

    ApiResponse.paginated(res, items, total, pagination.page, pagination.limit);
  } catch (error) {
    next(error);
  }
});

router.post("/watchlist", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { movieId, seriesId, profileId } = req.body;
    const item = await prisma.watchlist.create({
      data: {
        userId: req.user!.id,
        profileId: profileId || null,
        movieId: movieId || null,
        seriesId: seriesId || null,
      },
    });

    ApiResponse.created(res, item, "Added to watchlist");
  } catch (error) {
    next(error);
  }
});

router.delete(
  "/watchlist/:id",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      await prisma.watchlist.delete({
        where: { id: req.params.id as string, userId: req.user!.id },
      });

      ApiResponse.success({ res, message: "Removed from watchlist" });
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// CONTINUE WATCHING
// ============================================================

router.get(
  "/continue-watching",
  authenticate,
  async (req: AuthRequest, res, next) => {
    try {
      const { profileId } = req.query;
      const where: any = { userId: req.user!.id, progressPercent: { lt: 95 } };
      if (profileId) where.profileId = profileId;

      const items = await prisma.continueWatching.findMany({
        where,
        orderBy: { updatedAt: "desc" },
        take: 20,
        include: {
          movie: {
            select: {
              id: true,
              title: true,
              posterUrl: true,
              slug: true,
              runtime: true,
            },
          },
          episode: {
            select: {
              id: true,
              title: true,
              thumbnailUrl: true,
              episodeNumber: true,
              runtime: true,
              season: {
                select: {
                  seasonNumber: true,
                  series: {
                    select: {
                      id: true,
                      title: true,
                      posterUrl: true,
                      slug: true,
                    },
                  },
                },
              },
            },
          },
        },
      });

      ApiResponse.success({ res, data: items });
    } catch (error) {
      next(error);
    }
  },
);

// ============================================================
// WATCH HISTORY
// ============================================================

router.get("/history", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const pagination = parsePagination(req, { sortBy: "watchedAt" });
    const { profileId } = req.query;

    const where: any = { userId: req.user!.id };
    if (profileId) where.profileId = profileId;

    const [items, total] = await Promise.all([
      prisma.watchHistory.findMany({
        where,
        ...toPrismaQuery(pagination),
        include: {
          movie: {
            select: { id: true, title: true, posterUrl: true, slug: true },
          },
          episode: {
            select: {
              id: true,
              title: true,
              thumbnailUrl: true,
              episodeNumber: true,
              season: {
                select: {
                  seasonNumber: true,
                  series: { select: { title: true, slug: true } },
                },
              },
            },
          },
        },
      }),
      prisma.watchHistory.count({ where }),
    ]);

    ApiResponse.paginated(res, items, total, pagination.page, pagination.limit);
  } catch (error) {
    next(error);
  }
});

// ============================================================
// REVIEWS
// ============================================================

router.post("/reviews", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { movieId, seriesId, content, isSpoiler } = req.body;
    const review = await prisma.review.create({
      data: {
        userId: req.user!.id,
        movieId: movieId || null,
        seriesId: seriesId || null,
        content,
        isSpoiler: isSpoiler || false,
      },
    });

    ApiResponse.created(res, review, "Review submitted");
  } catch (error) {
    next(error);
  }
});

router.get("/reviews/:contentId", async (req, res, next) => {
  try {
    const { contentId } = req.params;
    const { type = "movie" } = req.query;
    const pagination = parsePagination(req);

    const where: any = { isApproved: true };
    if (type === "movie") where.movieId = contentId;
    else where.seriesId = contentId;

    const [reviews, total] = await Promise.all([
      prisma.review.findMany({
        where,
        ...toPrismaQuery(pagination),
        include: {
          user: { select: { id: true, name: true, avatarUrl: true } },
        },
      }),
      prisma.review.count({ where }),
    ]);

    ApiResponse.paginated(
      res,
      reviews,
      total,
      pagination.page,
      pagination.limit,
    );
  } catch (error) {
    next(error);
  }
});

// ============================================================
// RATINGS
// ============================================================

router.post("/ratings", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { movieId, seriesId, score } = req.body;

    const data: any = {
      userId: req.user!.id,
      score: Math.min(10, Math.max(1, score)),
    };
    if (movieId) data.movieId = movieId;
    if (seriesId) data.seriesId = seriesId;

    const rating = await prisma.rating.upsert({
      where: movieId
        ? { userId_movieId: { userId: req.user!.id, movieId } }
        : { userId_seriesId: { userId: req.user!.id, seriesId } },
      create: data,
      update: { score: data.score },
    });

    // Recalculate average rating
    if (movieId) {
      const agg = await prisma.rating.aggregate({
        where: { movieId },
        _avg: { score: true },
        _count: true,
      });
      await prisma.movie.update({
        where: { id: movieId },
        data: { avgRating: agg._avg.score || 0, totalRatings: agg._count },
      });
    }

    ApiResponse.success({ res, message: "Rating submitted", data: rating });
  } catch (error) {
    next(error);
  }
});

export default router;
