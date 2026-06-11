import { Router } from "express";
import { optionalAuth } from "@middleware/auth.middleware";
import { ApiResponse } from "@utils/apiResponse";
import { prisma } from "@config/database";
import { cache } from "@config/redis";
import {
  parsePagination,
  toPrismaQuery,
  buildPaginationMeta,
} from "@utils/pagination";

const router = Router();

// Get hero banners
router.get("/banners", async (_req, res, next) => {
  try {
    const cached = await cache.get("content:banners");
    if (cached) {
      ApiResponse.success({ res, data: cached });
      return;
    }

    const banners = await prisma.banner.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: "asc" },
    });

    await cache.set("content:banners", banners, 300); // 5 min cache
    ApiResponse.success({ res, data: banners });
  } catch (error) {
    next(error);
  }
});

// List movies
router.get("/movies", optionalAuth, async (req, res, next) => {
  try {
    const pagination = parsePagination(req, { sortBy: "releaseDate" });
    const { genre, language, year } = req.query;

    const where: any = { isPublished: true };
    if (genre) {
      where.genres = { some: { genre: { slug: genre as string } } };
    }
    if (language) where.language = language;
    if (year)
      where.releaseDate = {
        gte: new Date(`${year}-01-01`),
        lt: new Date(`${Number(year) + 1}-01-01`),
      };

    const [movies, total] = await Promise.all([
      prisma.movie.findMany({
        where,
        ...toPrismaQuery(pagination),
        include: {
          genres: { include: { genre: true } },
        },
      }),
      prisma.movie.count({ where }),
    ]);

    ApiResponse.paginated(
      res,
      movies,
      total,
      pagination.page,
      pagination.limit,
    );
  } catch (error) {
    next(error);
  }
});

// Get movie by ID or slug
router.get("/movies/:idOrSlug", optionalAuth, async (req, res, next) => {
  try {
    const idOrSlug = req.params.idOrSlug as string;
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        idOrSlug,
      );

    const movie = await prisma.movie.findFirst({
      where: isUuid
        ? { id: idOrSlug, isPublished: true }
        : { slug: idOrSlug, isPublished: true },
      include: {
        genres: { include: { genre: true } },
        castMembers: {
          include: { castMember: true },
          orderBy: { displayOrder: "asc" },
        },
        crewMembers: {
          include: { crewMember: true },
          orderBy: { displayOrder: "asc" },
        },
      },
    });

    if (!movie) {
      res.status(404).json({ success: false, message: "Movie not found" });
      return;
    }

    // Increment view count
    await prisma.movie.update({
      where: { id: movie.id },
      data: { viewCount: { increment: 1 } },
    });

    ApiResponse.success({ res, data: movie });
  } catch (error) {
    next(error);
  }
});

// List series
router.get("/series", optionalAuth, async (req, res, next) => {
  try {
    const pagination = parsePagination(req, { sortBy: "startDate" });
    const { genre, language } = req.query;

    const where: any = { isPublished: true };
    if (genre) {
      where.genres = { some: { genre: { slug: genre as string } } };
    }
    if (language) where.language = language;

    const [series, total] = await Promise.all([
      prisma.series.findMany({
        where,
        ...toPrismaQuery(pagination),
        include: {
          genres: { include: { genre: true } },
          _count: { select: { seasons: true } },
        },
      }),
      prisma.series.count({ where }),
    ]);

    ApiResponse.paginated(
      res,
      series,
      total,
      pagination.page,
      pagination.limit,
    );
  } catch (error) {
    next(error);
  }
});

// Get series details with seasons & episodes
router.get("/series/:idOrSlug", optionalAuth, async (req, res, next) => {
  try {
    const idOrSlug = req.params.idOrSlug as string;
    const isUuid =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        idOrSlug,
      );

    const series = await prisma.series.findFirst({
      where: isUuid
        ? { id: idOrSlug, isPublished: true }
        : { slug: idOrSlug, isPublished: true },
      include: {
        genres: { include: { genre: true } },
        castMembers: {
          include: { castMember: true },
          orderBy: { displayOrder: "asc" },
        },
        crewMembers: {
          include: { crewMember: true },
          orderBy: { displayOrder: "asc" },
        },
        seasons: {
          orderBy: { seasonNumber: "asc" },
          include: {
            episodes: {
              where: { isPublished: true },
              orderBy: { episodeNumber: "asc" },
            },
          },
        },
      },
    });

    if (!series) {
      res.status(404).json({ success: false, message: "Series not found" });
      return;
    }

    await prisma.series.update({
      where: { id: series.id },
      data: { viewCount: { increment: 1 } },
    });

    ApiResponse.success({ res, data: series });
  } catch (error) {
    next(error);
  }
});

// Get genres
router.get("/genres", async (_req, res, next) => {
  try {
    const cached = await cache.get("content:genres");
    if (cached) {
      ApiResponse.success({ res, data: cached });
      return;
    }

    const genres = await prisma.genre.findMany({
      where: { isActive: true },
      orderBy: { displayOrder: "asc" },
    });

    await cache.set("content:genres", genres, 3600);
    ApiResponse.success({ res, data: genres });
  } catch (error) {
    next(error);
  }
});

// Trending content
router.get("/trending", async (_req, res, next) => {
  try {
    const cached = await cache.get("content:trending");
    if (cached) {
      ApiResponse.success({ res, data: cached });
      return;
    }

    const [movies, series] = await Promise.all([
      prisma.movie.findMany({
        where: { isPublished: true },
        orderBy: { viewCount: "desc" },
        take: 20,
        include: { genres: { include: { genre: true } } },
      }),
      prisma.series.findMany({
        where: { isPublished: true },
        orderBy: { viewCount: "desc" },
        take: 10,
        include: { genres: { include: { genre: true } } },
      }),
    ]);

    const trending = { movies, series };
    await cache.set("content:trending", trending, 600); // 10 min cache
    ApiResponse.success({ res, data: trending });
  } catch (error) {
    next(error);
  }
});

// Top 10
router.get("/top10", async (req, res, next) => {
  try {
    const region = (req.query.region as string) || "india";
    const cacheKey = `content:top10:${region}`;
    const cached = await cache.get(cacheKey);
    if (cached) {
      ApiResponse.success({ res, data: cached });
      return;
    }

    const movies = await prisma.movie.findMany({
      where: {
        isPublished: true,
        ...(region === "india" ? { country: "IN" } : {}),
      },
      orderBy: { viewCount: "desc" },
      take: 10,
      include: { genres: { include: { genre: true } } },
    });

    await cache.set(cacheKey, movies, 3600);
    ApiResponse.success({ res, data: movies });
  } catch (error) {
    next(error);
  }
});

// Coming soon
router.get("/coming-soon", async (_req, res, next) => {
  try {
    const movies = await prisma.movie.findMany({
      where: {
        isPublished: false,
        releaseDate: { gt: new Date() },
      },
      orderBy: { releaseDate: "asc" },
      take: 20,
    });

    ApiResponse.success({ res, data: movies });
  } catch (error) {
    next(error);
  }
});

// Originals
router.get("/originals", async (_req, res, next) => {
  try {
    const [movies, series] = await Promise.all([
      prisma.movie.findMany({
        where: { isPublished: true, isOriginal: true },
        orderBy: { releaseDate: "desc" },
        take: 20,
        include: { genres: { include: { genre: true } } },
      }),
      prisma.series.findMany({
        where: { isPublished: true, isOriginal: true },
        orderBy: { startDate: "desc" },
        take: 10,
        include: { genres: { include: { genre: true } } },
      }),
    ]);

    ApiResponse.success({ res, data: { movies, series } });
  } catch (error) {
    next(error);
  }
});

export default router;
