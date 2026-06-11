import AWS from "aws-sdk";
import { env } from "@config/env";
import { logger } from "@utils/logger";

let s3: AWS.S3 | null = null;

if (env.R2_ACCOUNT_ID && env.R2_ACCESS_KEY_ID && env.R2_SECRET_ACCESS_KEY) {
  s3 = new AWS.S3({
    endpoint: `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY,
    signatureVersion: "v4",
  });
}

/**
 * Returns a signed URL from Cloudflare R2 if it is a cloud asset, otherwise returns the original URL.
 */
export async function signStreamUrl(url: string): Promise<string> {
  try {
    if (!s3 || !env.R2_BUCKET_NAME) {
      return url;
    }

    // Check if the URL is from our R2/CDN configuration
    const isCloudflareUrl = url.includes(".r2.cloudflarestorage.com");
    const isCdnUrl = env.R2_PUBLIC_URL && url.startsWith(env.R2_PUBLIC_URL);

    if (!isCloudflareUrl && !isCdnUrl) {
      return url;
    }

    const urlObj = new URL(url);
    const bucket = env.R2_BUCKET_NAME;

    // The key is the pathname after the bucket or slash
    let key = decodeURIComponent(urlObj.pathname);
    if (key.startsWith("/")) {
      key = key.substring(1);
    }

    const signedUrl = await s3.getSignedUrlPromise("getObject", {
      Bucket: bucket,
      Key: key,
      Expires: 3600 * 2, // 2 hours validity
    });

    return signedUrl;
  } catch (error: any) {
    logger.error("❌ Error generating signed R2 URL:", error.message);
    return url; // Fallback to original url
  }
}
