import { Client } from "minio";
import { env } from "./env.ts";

export const minio = new Client({
  endPoint: env.s3.endpoint,
  port: env.s3.port,
  useSSL: env.s3.useSSL,
  accessKey: env.s3.accessKey,
  secretKey: env.s3.secretKey,
  region: env.s3.region,
});

// Toda mídia vai para o bucket de uploads (privado, servido via URL assinada).
// O bucket público fica disponível p/ assets servidos diretamente no futuro.
export const BUCKETS = {
  video: env.s3.bucketUploads,
  image: env.s3.bucketUploads,
  pdf: env.s3.bucketUploads,
} as const;

export type AssetKind = keyof typeof BUCKETS;

/** Política de leitura anônima para o bucket público (avatares, capas). */
function publicReadPolicy(bucket: string): string {
  return JSON.stringify({
    Version: "2012-10-17",
    Statement: [
      {
        Effect: "Allow",
        Principal: { AWS: ["*"] },
        Action: ["s3:GetObject"],
        Resource: [`arn:aws:s3:::${bucket}/*`],
      },
    ],
  });
}

/** Garante que os buckets existem (idempotente). O público recebe leitura anônima. */
export async function ensureBuckets(): Promise<void> {
  for (const bucket of [env.s3.bucketUploads, env.s3.bucketPublic]) {
    try {
      const exists = await minio.bucketExists(bucket);
      if (!exists) await minio.makeBucket(bucket, env.s3.region);
    } catch (err) {
      console.warn(`[storage] não pôde garantir bucket ${bucket}:`, (err as Error).message);
    }
  }
  // O bucket público é servível direto (sem URL assinada) — ideal p/ CDN e escala.
  try {
    await minio.setBucketPolicy(env.s3.bucketPublic, publicReadPolicy(env.s3.bucketPublic));
  } catch (err) {
    console.warn(`[storage] não pôde aplicar política pública:`, (err as Error).message);
  }
}

/** URL pública estável (não expira) para um objeto do bucket público. */
export function publicObjectUrl(key: string): string {
  const base = env.s3.publicUrl.replace(/\/+$/, "");
  return `${base}/${env.s3.bucketPublic}/${key}`;
}

/**
 * URL de mídia servida PELA PRÓPRIA API (faz stream do MinIO internamente).
 * Usada porque o MinIO não é exposto publicamente — URLs assinadas diretas ao
 * MinIO não são alcançáveis pelo app. A API (em stitchmindapp.com) é.
 */
export function mediaUrl(assetId: string): string {
  const base = env.s3.publicUrl.replace(/\/+$/, "");
  return `${base}/v1/media/${assetId}`;
}

/** Sobe um objeto e devolve a chave. */
export async function putObject(
  bucket: string,
  key: string,
  data: Buffer | Uint8Array,
  mime: string,
): Promise<void> {
  await minio.putObject(bucket, key, Buffer.from(data), data.byteLength, {
    "Content-Type": mime,
  });
}

/** URL assinada (temporária) para leitura. */
export async function signedUrl(
  bucket: string,
  key: string,
  expirySeconds = 60 * 60,
): Promise<string> {
  const url = await minio.presignedGetObject(bucket, key, expirySeconds);
  const internal = `${env.s3.useSSL ? "https" : "http"}://${env.s3.endpoint}:${env.s3.port}`;
  return url.replace(internal, env.s3.publicUrl);
}
