import { Response, NextFunction } from "express";
import { AuthRequest } from "@custom-types/index";
import { AuthService } from "./auth.service";
import { ApiResponse } from "@utils/apiResponse";

const authService = new AuthService();

export class AuthController {
  async sendOtp(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const { phone, email, type } = req.body;
      await authService.sendOtp({ phone, email, type });

      ApiResponse.success({
        res,
        message: `OTP sent successfully to your ${type === "sms" ? "phone" : "email"}`,
        data: { sent: true },
      });
    } catch (error) {
      next(error);
    }
  }

  async verifyOtp(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const result = await authService.verifyOtp(req.body);

      ApiResponse.success({
        res,
        message: "Login successful",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async googleAuth(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const result = await authService.googleAuth(req.body);

      ApiResponse.success({
        res,
        message: "Login successful",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async refreshToken(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const { refreshToken } = req.body;
      const result = await authService.refreshToken(refreshToken);

      ApiResponse.success({
        res,
        message: "Token refreshed",
        data: result,
      });
    } catch (error) {
      next(error);
    }
  }

  async logout(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      const token = req.headers.authorization?.split(" ")[1] || "";
      await authService.logout(req.user!.id, req.sessionId!, token);

      ApiResponse.success({
        res,
        message: "Logged out successfully",
      });
    } catch (error) {
      next(error);
    }
  }

  async logoutAll(
    req: AuthRequest,
    res: Response,
    next: NextFunction,
  ): Promise<void> {
    try {
      await authService.logoutAll(req.user!.id);

      ApiResponse.success({
        res,
        message: "Logged out from all devices",
      });
    } catch (error) {
      next(error);
    }
  }
}
