import { meilisearch } from "@config/meilisearch";
import { prisma } from "@config/database";
import { logger } from "@utils/logger";

/**
 * Synchronizes movies and series content to Meilisearch indexes.
 */
export async function syncContentToMeilisearch(): Promise<void> {
  if (!meilisearch) {
    logger.warn(
      "🔍 Meilisearch client not configured. Skipping catalog indexing.",
    );
    return;
  }

  try {
    logger.info("🔍 Syncing content database to Meilisearch...");

    // Fetch movies with genres
    const movies = await prisma.movie.findMany({
      include: { genres: { include: { genre: true } } },
    });

    const movieDocs = movies.map((movie) => ({
      id: movie.id,
      title: movie.title,
      slug: movie.slug,
      description: movie.description || "",
      synopsis: movie.synopsis || "",
      releaseDate: movie.releaseDate?.getTime() || null,
      runtime: movie.runtime || null,
      maturityRating: movie.maturityRating || "",
      language: movie.language,
      posterUrl: movie.posterUrl || "",
      avgRating: movie.avgRating,
      viewCount: movie.viewCount,
      isPublished: movie.isPublished,
      genres: movie.genres.map((mg) => mg.genre.name),
    }));

    // Fetch series with genres
    const series = await prisma.series.findMany({
      include: { genres: { include: { genre: true } } },
    });

    const seriesDocs = series.map((s) => ({
      id: s.id,
      title: s.title,
      slug: s.slug,
      description: s.description || "",
      synopsis: s.synopsis || "",
      startDate: s.startDate?.getTime() || null,
      maturityRating: s.maturityRating || "",
      language: s.language,
      posterUrl: s.posterUrl || "",
      avgRating: s.avgRating,
      viewCount: s.viewCount,
      isPublished: s.isPublished,
      genres: s.genres.map((sg) => sg.genre.name),
    }));

    // Define search settings (filterable, searchable, sortable attributes)
    await meilisearch.index("movies").updateSettings({
      filterableAttributes: ["isPublished", "genres", "language"],
      searchableAttributes: ["title", "description", "synopsis"],
      sortableAttributes: ["releaseDate", "avgRating", "viewCount"],
    });

    await meilisearch.index("series").updateSettings({
      filterableAttributes: ["isPublished", "genres", "language"],
      searchableAttributes: ["title", "description", "synopsis"],
      sortableAttributes: ["startDate", "avgRating", "viewCount"],
    });

    // Push documents to Meilisearch
    if (movieDocs.length > 0) {
      await meilisearch.index("movies").addDocuments(movieDocs);
    }
    if (seriesDocs.length > 0) {
      await meilisearch.index("series").addDocuments(seriesDocs);
    }

    logger.info(
      `✅ Synced ${movieDocs.length} movies and ${seriesDocs.length} series to Meilisearch`,
    );
  } catch (error) {
    logger.error("❌ Error syncing content to Meilisearch:", error);
  }
}
