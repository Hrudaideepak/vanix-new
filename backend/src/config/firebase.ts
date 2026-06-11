import admin from "firebase-admin";
import { env } from "./env";
import { logger } from "@utils/logger";

let firebaseApp: admin.app.App | null = null;

export function getFirebaseAdmin(): admin.app.App | null {
  if (
    !firebaseApp &&
    env.FIREBASE_PROJECT_ID &&
    env.FIREBASE_CLIENT_EMAIL &&
    env.FIREBASE_PRIVATE_KEY
  ) {
    try {
      const privateKey = env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n");
      firebaseApp = admin.initializeApp({
        credential: admin.credential.cert({
          projectId: env.FIREBASE_PROJECT_ID,
          clientEmail: env.FIREBASE_CLIENT_EMAIL,
          privateKey: privateKey,
        }),
      });
      logger.info("✅ Firebase Admin initialized successfully");
    } catch (error: any) {
      logger.error("❌ Failed to initialize Firebase Admin:", error.message);
    }
  }
  return firebaseApp;
}
