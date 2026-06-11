import { Request } from "express";

// Extend Express Request with auth info
export interface AuthRequest extends Request {
  user?: {
    id: string;
    email?: string | null;
    phone?: string | null;
    name?: string | null;
    isActive: boolean;
    isBanned: boolean;
  };
  admin?: {
    id: string;
    email: string;
    name: string;
    role: string;
    permissions: string[];
  };
  sessionId?: string;
  deviceId?: string;
  profileId?: string;
}

// Content types
export type ContentType = "movie" | "series" | "episode";

// API filter types
export interface ContentFilters {
  genre?: string;
  language?: string;
  year?: number;
  rating?: number;
  maturityRating?: string;
  quality?: string;
  isOriginal?: boolean;
  search?: string;
}

// Video quality
export type VideoQuality = "480p" | "720p" | "1080p" | "4k";

// Subscription plan names
export type PlanName = "mobile" | "basic" | "standard" | "premium" | "family";

// Notification payload
export interface NotificationPayload {
  title: string;
  body: string;
  imageUrl?: string;
  data?: Record<string, string>;
}

// Video processing
export interface VideoProcessingConfig {
  inputPath: string;
  outputDir: string;
  resolutions: VideoQuality[];
  generateHLS: boolean;
  generateDASH: boolean;
  generateThumbnails: boolean;
}

// Analytics event
export interface AnalyticsPayload {
  eventName: string;
  eventData?: Record<string, unknown>;
  userId?: string;
  deviceType?: string;
  platform?: string;
}
