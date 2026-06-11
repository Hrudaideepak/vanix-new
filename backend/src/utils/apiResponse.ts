import { Response } from "express";

interface ApiResponseOptions<T> {
  res: Response;
  statusCode?: number;
  success?: boolean;
  message?: string;
  data?: T;
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    totalPages?: number;
    hasNext?: boolean;
    hasPrev?: boolean;
  };
}

export class ApiResponse {
  static success<T>(options: ApiResponseOptions<T>): Response {
    const { res, statusCode = 200, message = "Success", data, meta } = options;

    const response: Record<string, unknown> = {
      success: true,
      message,
    };

    if (data !== undefined) {
      response.data = data;
    }

    if (meta) {
      response.meta = meta;
    }

    return res.status(statusCode).json(response);
  }

  static created<T>(
    res: Response,
    data: T,
    message = "Created successfully",
  ): Response {
    return ApiResponse.success({ res, statusCode: 201, message, data });
  }

  static noContent(res: Response): Response {
    return res.status(204).send();
  }

  static error(
    res: Response,
    statusCode: number,
    message: string,
    errors?: unknown,
  ): Response {
    const response: Record<string, unknown> = {
      success: false,
      message,
    };

    if (errors) {
      response.errors = errors;
    }

    return res.status(statusCode).json(response);
  }

  static paginated<T>(
    res: Response,
    data: T[],
    total: number,
    page: number,
    limit: number,
    message = "Success",
  ): Response {
    const totalPages = Math.ceil(total / limit);

    return ApiResponse.success({
      res,
      message,
      data,
      meta: {
        page,
        limit,
        total,
        totalPages,
        hasNext: page < totalPages,
        hasPrev: page > 1,
      },
    });
  }
}
