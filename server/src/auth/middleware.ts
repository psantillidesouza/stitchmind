import type { Context, Next } from "hono";
import { sql } from "../db.ts";
import { verifyIdToken } from "./firebase.ts";
import { verifyAdminToken } from "./adminAuth.ts";

export interface AppUser {
  id: string;
  firebase_uid: string;
  email: string | null;
  name: string | null;
  role: "user" | "admin";
  status: "active" | "blocked";
  is_premium: boolean;
}

/** Lê o Bearer token, valida no Firebase e faz upsert do usuário no Postgres. */
async function resolveUser(c: Context): Promise<AppUser | null> {
  const header = c.req.header("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return null;

  // 1) JWT do login admin próprio (painel)
  const adminClaims = await verifyAdminToken(token);
  if (adminClaims) {
    const rows = await sql<AppUser[]>`
      SELECT id, firebase_uid, email, name, role, status, is_premium FROM users WHERE id = ${adminClaims.uid}`;
    if (rows[0] && rows[0].role === "admin") {
      await sql`UPDATE users SET last_seen_at = now() WHERE id = ${adminClaims.uid}`.catch(() => {});
      return rows[0];
    }
  }

  // 2) Firebase ID token (ou dev token em dev-mode)
  let verified;
  try {
    verified = await verifyIdToken(token);
  } catch {
    return null;
  }

  // Re-vincula: se já existe uma conta com este e-mail mas outro firebase_uid
  // (ex.: re-login com o mesmo Google após excluir a conta, ou troca de uid),
  // aponta a linha existente para o uid atual. Sem isso, o INSERT abaixo violava
  // a constraint única de e-mail (users_email_key) e o login dava 500.
  if (verified.email) {
    await sql`
      UPDATE users SET firebase_uid = ${verified.uid}, updated_at = now()
      WHERE email = ${verified.email} AND firebase_uid <> ${verified.uid}
    `.catch(() => {});
  }

  const rows = await sql<AppUser[]>`
    INSERT INTO users (firebase_uid, email, name, photo_url, email_verified, last_seen_at)
    VALUES (${verified.uid}, ${verified.email ?? null}, ${verified.name ?? null},
            ${verified.picture ?? null}, ${verified.emailVerified}, now())
    ON CONFLICT (firebase_uid) DO UPDATE SET
      email = COALESCE(EXCLUDED.email, users.email),
      -- Nome e foto: a conta no app é a fonte da verdade. Uma vez definidos,
      -- o token do Firebase não sobrescreve (evita reverter edições do usuário).
      name = COALESCE(users.name, EXCLUDED.name),
      photo_url = COALESCE(users.photo_url, EXCLUDED.photo_url),
      email_verified = EXCLUDED.email_verified,
      last_seen_at = now(),
      updated_at = now()
    RETURNING id, firebase_uid, email, name, role, status, is_premium
  `;
  return rows[0] ?? null;
}

/** Exige usuário autenticado. Injeta c.set('user', AppUser). */
export async function requireAuth(c: Context, next: Next) {
  const user = await resolveUser(c);
  if (!user) return c.json({ error: "Não autenticado." }, 401);
  if (user.status === "blocked") return c.json({ error: "Conta bloqueada." }, 403);
  c.set("user", user);
  await next();
}

/** Exige role=admin. */
export async function requireAdmin(c: Context, next: Next) {
  const user = await resolveUser(c);
  if (!user) return c.json({ error: "Não autenticado." }, 401);
  if (user.role !== "admin") return c.json({ error: "Acesso restrito a admin." }, 403);
  c.set("user", user);
  await next();
}

/** Auth opcional: injeta user se houver token, mas não bloqueia. */
export async function optionalAuth(c: Context, next: Next) {
  const user = await resolveUser(c);
  if (user) c.set("user", user);
  await next();
}
