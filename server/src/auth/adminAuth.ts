import { SignJWT, jwtVerify } from "jose";
import { env } from "../env.ts";

const secret = new TextEncoder().encode(env.adminJwtSecret);

export interface AdminClaims {
  uid: string; // users.id
  email: string;
}

/** Emite um JWT de admin (HS256), válido por 12h. */
export async function signAdminToken(claims: AdminClaims): Promise<string> {
  return new SignJWT({ email: claims.email, typ: "admin" })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.uid)
    .setIssuedAt()
    .setExpirationTime("12h")
    .sign(secret);
}

/** Valida um JWT de admin. Retorna o uid ou null. */
export async function verifyAdminToken(token: string): Promise<AdminClaims | null> {
  try {
    const { payload } = await jwtVerify(token, secret);
    if (payload.typ !== "admin" || !payload.sub) return null;
    return { uid: payload.sub as string, email: (payload.email as string) ?? "" };
  } catch {
    return null;
  }
}
