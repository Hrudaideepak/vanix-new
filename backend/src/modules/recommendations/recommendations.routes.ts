import { Router } from "express";
import { authenticate } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { AuthRequest } from "@custom-types/index";

const router = Router();

// Get personalized recommendations
router.get("/", authenticate, async (req: AuthRequest, res, next) => {
  try {
    const { profileId, limit = 20 } = req.query;

    // Get user's watch history to understand preferences
    const watchHistory = await prisma.watchHistory.findMany({
      where: { userId: req.user!.id },
      include: {
        movie: { include: { genres: { include: { genre: true } } } },
      },
      orderBy: { watchedAt: "desc" },
      take: 50,
    });

    // Extract genre preferences
    const genreScores: Record<string, number> = {};
    watchHistory.forEach((entry) => {
      if (entry.movie) {
        entry.movie.genres.forEach((mg) => {
          genreScores[mg.genre.id] = (genreScores[mg.genre.id] || 0) + 1;
        });
      }
    });

    // Get top genres
    const topGenreIds = Object.entries(genreScores)
      .sort(([, a], [, b]) => b - a)
      .slice(0, 5)
      .map(([id]) => id);

    // Get watched movie IDs to exclude
    const watchedMovieIds = watchHistory
      .filter((e) => e.movieId)
      .map((e) => e.movieId!);

    // Fetch recommendations based on genre preferences
    let recommendations;
    if (topGenreIds.length > 0) {
      recommendations = await prisma.movie.findMany({
        where: {
          isPublished: true,
          id: { notIn: watchedMovieIds },
          genres: { some: { genreId: { in: topGenreIds } } },
        },
        orderBy: [{ avgRating: "desc" }, { viewCount: "desc" }],
        take: Number(limit),
        include: { genres: { include: { genre: true } } },
      });
    } else {
      // Fallback: popular content
      recommendations = await prisma.movie.findMany({
        where: { isPublished: true, id: { notIn: watchedMovieIds } },
        orderBy: [{ viewCount: "desc" }, { avgRating: "desc" }],
        take: Number(limit),
        include: { genres: { include: { genre: true } } },
      });
    }

    ApiResponse.success({
      res,
      data: recommendations.map((movie) => ({
        ...movie,
        reason:
          topGenreIds.length > 0
            ? `Because you watched ${watchHistory[0]?.movie?.title || "similar content"}`
            : "Popular on VANIX",
      })),
    });
  } catch (error) {
    next(error);
  }
});

export default router;
