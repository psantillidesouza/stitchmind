// Configuração central lida de variáveis de ambiente (.env).

function parseS3Endpoint(url: string) {
  try {
    const u = new URL(url);
    return {
      host: u.hostname,
      port: Number(u.port || (u.protocol === "https:" ? 443 : 80)),
      useSSL: u.protocol === "https:",
    };
  } catch {
    return { host: "localhost", port: 9000, useSSL: false };
  }
}

const s3 = parseS3Endpoint(Bun.env.S3_ENDPOINT ?? "http://localhost:9000");
const nodeEnv = Bun.env.NODE_ENV ?? "development";

export const env = {
  nodeEnv,
  port: Number(Bun.env.PORT ?? 3001),
  databaseUrl:
    Bun.env.DATABASE_URL ??
    "postgresql://stitchmind:stitchmind_dev_pw@localhost:5432/stitchmind",
  databasePoolSize: Number(Bun.env.DATABASE_POOL_SIZE ?? 10),
  runMigrations: (Bun.env.RUN_MIGRATIONS ?? "true") === "true",

  redisUrl: Bun.env.REDIS_URL ?? "redis://localhost:6379",
  redisPrefix: Bun.env.REDIS_PREFIX ?? "stitchmind:",
  adminJwtSecret: Bun.env.ADMIN_JWT_SECRET ?? "dev-admin-secret-change-me",

  // Header Authorization que o webhook do RevenueCat deve enviar (defina no
  // painel RevenueCat → Webhooks → Authorization header). Vazio = não checa.
  revenueCatWebhookAuth: Bun.env.REVENUECAT_WEBHOOK_AUTH ?? "",
  // Secret API key (sk_...) do RevenueCat p/ verificar assinaturas server-side
  // no /subscription/sync. Vazio = /sync vira somente-leitura (não concede).
  revenueCatApiKey: Bun.env.REVENUECAT_API_KEY ?? "",

  s3: {
    endpoint: s3.host,
    port: s3.port,
    useSSL: s3.useSSL,
    accessKey: Bun.env.S3_ACCESS_KEY ?? "minioadmin",
    secretKey: Bun.env.S3_SECRET_KEY ?? "minioadmin",
    region: Bun.env.S3_REGION ?? "us-east-1",
    bucketUploads: Bun.env.S3_BUCKET_UPLOADS ?? "stitchmind-uploads",
    bucketPublic: Bun.env.S3_BUCKET_PUBLIC ?? "stitchmind-public",
    publicUrl: Bun.env.S3_PUBLIC_URL ?? "http://localhost:9000",
  },

  firebase: {
    projectId: Bun.env.FIREBASE_PROJECT_ID ?? "",
    issuer:
      Bun.env.FIREBASE_ISSUER ??
      (Bun.env.FIREBASE_PROJECT_ID
        ? `https://securetoken.google.com/${Bun.env.FIREBASE_PROJECT_ID}`
        : ""),
    jwksUrl:
      Bun.env.FIREBASE_JWKS_URL ??
      "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com",
    // apiKey web (público) p/ o login do painel via Firebase JS SDK
    webApiKey: Bun.env.FIREBASE_WEB_API_KEY ?? "",
    // Service account (Admin SDK) p/ ENVIAR push via FCM. Aceita o JSON inteiro
    // em FIREBASE_SERVICE_ACCOUNT ou um caminho de arquivo em
    // FIREBASE_SERVICE_ACCOUNT_PATH / GOOGLE_APPLICATION_CREDENTIALS.
    serviceAccount: Bun.env.FIREBASE_SERVICE_ACCOUNT ?? "",
    serviceAccountPath:
      Bun.env.FIREBASE_SERVICE_ACCOUNT_PATH ??
      Bun.env.GOOGLE_APPLICATION_CREDENTIALS ??
      "",
    // tokens "dev:<uid>:<email>" aceitos em dev, ou se AUTH_DEV_MODE=true
    devMode: Bun.env.AUTH_DEV_MODE != null
      ? Bun.env.AUTH_DEV_MODE === "true"
      : nodeEnv === "development",
  },

  gemini: {
    apiKey: Bun.env.GEMINI_API_KEY ?? "",
    modelVision: Bun.env.GEMINI_MODEL_VISION ?? "gemini-2.5-pro",
    modelText: Bun.env.GEMINI_MODEL_TEXT ?? "gemini-2.5-flash-lite",
  },

  ai: {
    maxImageMb: Number(Bun.env.MAX_IMAGE_MB ?? 8),
  },
};
