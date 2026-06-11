import { Request } from "express";

export interface PaginationOptions {
  page: number;
  limit: number;
  sortBy: string;
  sortOrder: "asc" | "desc";
}

export interface PaginationResult {
  skip: number;
  take: number;
  orderBy: Record<string, "asc" | "desc">;
}

export function parsePagination(
  req: Request,
  defaults: Partial<PaginationOptions> = {},
): PaginationOptions {
  const page = Math.max(
    1,
    parseInt(req.query.page as string) || defaults.page || 1,
  );
  const limit = Math.min(
    100,
    Math.max(1, parseInt(req.query.limit as string) || defaults.limit || 20),
  );
  const sortBy = (req.query.sortBy as string) || defaults.sortBy || "createdAt";
  const sortOrder = ((req.query.sortOrder as string) ||
    defaults.sortOrder ||
    "desc") as "asc" | "desc";

  return { page, limit, sortBy, sortOrder };
}

export function toPrismaQuery(options: PaginationOptions): PaginationResult {
  return {
    skip: (options.page - 1) * options.limit,
    take: options.limit,
    orderBy: { [options.sortBy]: options.sortOrder },
  };
}

export function buildPaginationMeta(
  total: number,
  page: number,
  limit: number,
) {
  const totalPages = Math.ceil(total / limit);
  return {
    page,
    limit,
    total,
    totalPages,
    hasNext: page < totalPages,
    hasPrev: page > 1,
  };
}
