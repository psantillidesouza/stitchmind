import { createRemoteJWKSet, jwtVerify } from "jose";
import { env } from "../env.ts";

export interface VerifiedToken {
  uid: string;
  email?: string;
  name?: string;
  picture?: string;
  emailVerified: boolean;
}

// JWKS público do Firebase (chaves rotativas, cacheadas pela lib).
const JWKS = createRemoteJWKSet(new URL(env.firebase.jwksUrl));

/**
 * Valida um ID token do Firebase.
 * Em NODE_ENV=development aceita tokens "dev:<uid>:<email>" para testes locais
 * sem precisar de um login Firebase real no app.
 */
export async function verifyIdToken(token: string): Promise<VerifiedToken> {
  // ─── Dev mode ───
  if (env.firebase.devMode && token.startsWith("dev:")) {
    const [, uid, email] = token.split(":");
    if (!uid) throw new Error("Token dev inválido (use dev:<uid>:<email>)");
    return {
      uid,
      email: email || `${uid}@dev.local`,
      name: email ? email.split("@")[0] : uid,
      emailVerified: true,
    };
  }

  // ─── Firebase real ───
  if (!env.firebase.projectId) {
    throw new Error("FIREBASE_PROJECT_ID não configurado.");
  }

  const { payload } = await jwtVerify(token, JWKS, {
    issuer: env.firebase.issuer,
    audience: env.firebase.projectId,
  });

  const uid = (payload.sub ?? payload.user_id) as string | undefined;
  if (!uid) throw new Error("Token sem uid (sub).");

  return {
    uid,
    email: payload.email as string | undefined,
    name: payload.name as string | undefined,
    picture: payload.picture as string | undefined,
    emailVerified: Boolean(payload.email_verified),
  };
}
