import crypto from "crypto";
import { env } from "./env";
import { logger } from "@utils/logger";

let privateKey: string = "";
let publicKey: string = "";
let jwk: any = null;

if (env.JWT_PRIVATE_KEY && env.JWT_PUBLIC_KEY) {
  try {
    privateKey = env.JWT_PRIVATE_KEY.replace(/\\n/g, "\n");
    publicKey = env.JWT_PUBLIC_KEY.replace(/\\n/g, "\n");
    
    // Parse the public key to JWK
    const pubKeyObj = crypto.createPublicKey(publicKey);
    jwk = pubKeyObj.export({ format: "jwk" });
    logger.info("🔑 Asymmetric JWT keys loaded successfully from environment");
  } catch (error: any) {
    logger.error("❌ Failed to parse JWT_PUBLIC_KEY to JWK, generating fallback:", error.message);
    generateFallbackKeys();
  }
} else {
  logger.warn(
    "⚠️ JWT_PRIVATE_KEY and JWT_PUBLIC_KEY are missing. Generating temporary RSA-2048 key pair in memory."
  );
  generateFallbackKeys();
}

function generateFallbackKeys() {
  try {
    const { privateKey: priv, publicKey: pub } = crypto.generateKeyPairSync("rsa", {
      modulusLength: 2048,
      publicKeyEncoding: {
        type: "spki",
        format: "pem",
      },
      privateKeyEncoding: {
        type: "pkcs8",
        format: "pem",
      },
    });
    privateKey = priv;
    publicKey = pub;
    
    const pubKeyObj = crypto.createPublicKey(pub);
    jwk = pubKeyObj.export({ format: "jwk" });
  } catch (error: any) {
    logger.error("❌ Critical: Failed to generate fallback RSA keys:", error.message);
    process.exit(1);
  }
}

// Add metadata properties to JWK for JWKS standard compliance
jwk.kid = env.JWT_KEY_ID;
jwk.use = "sig";
jwk.alg = "RS256";

export { privateKey as jwtPrivateKey, publicKey as jwtPublicKey, jwk as jwtJWK };
