import AWS from "aws-sdk";
import { env } from "@config/env";
import { logger } from "@utils/logger";

let signer: AWS.CloudFront.Signer | null = null;

if (env.CLOUDFRONT_KEY_PAIR_ID && env.CLOUDFRONT_PRIVATE_KEY) {
  try {
    const privateKey = env.CLOUDFRONT_PRIVATE_KEY.replace(/\\n/g, "\n");
    signer = new AWS.CloudFront.Signer(env.CLOUDFRONT_KEY_PAIR_ID, privateKey);
    logger.info("🔒 CloudFront Signed Cookie generator initialized successfully");
  } catch (error: any) {
    logger.error("❌ Failed to initialize CloudFront Cookie Signer:", error.message);
  }
} else {
  logger.warn(
    "⚠️ CloudFront credentials missing (CLOUDFRONT_KEY_PAIR_ID, CLOUDFRONT_PRIVATE_KEY). Signed cookies will be bypassed in development."
  );
}

export interface CloudFrontCookies {
  "CloudFront-Policy": string;
  "CloudFront-Signature": string;
  "CloudFront-Key-Pair-Id": string;
}

/**
 * Generates CloudFront Signed Cookies for a wildcard resource pattern (e.g. https://cdn.vanix.com/content/movie/123/*)
 * Valid for 2 hours.
 */
export function generateCloudFrontCookies(resourceUrlPattern: string): CloudFrontCookies | null {
  if (!signer) {
    return null;
  }

  try {
    const expiryTime = Math.floor(Date.now() / 1000) + 7200; // 2 hours validity

    const policy = JSON.stringify({
      Statement: [
        {
          Resource: resourceUrlPattern,
          Condition: {
            DateLessThan: {
              "AWS:EpochTime": expiryTime,
            },
          },
        },
      ],
    });

    const cookies = signer.getSignedCookie({ policy });
    
    return cookies as unknown as CloudFrontCookies;
  } catch (error: any) {
    logger.error("❌ Error generating CloudFront signed cookies:", error.message);
    return null;
  }
}
