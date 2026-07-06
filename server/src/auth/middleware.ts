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
  panel_role: "admin" | "editor" | null;
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
      SELECT id, firebase_uid, email, name, role, panel_role, status, is_premium FROM users WHERE id = ${adminClaims.uid}`;
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

  // Upsert race-safe que respeita AS DUAS constraints únicas (firebase_uid E
  // email). Antes, um `ON CONFLICT (firebase_uid)` com `email = EXCLUDED.email`
  // ainda podia violar users_email_key (quando outra linha já tinha o e-mail) e
  // derrubava o login com 500 — bloqueando login E assinatura do usuário. Aqui
  // resolvemos a colisão de e-mail explicitamente, numa transação.
  const email = verified.email ?? null;
  const id = await sql.begin(async (tx) => {
    // a) Já existe linha para este firebase_uid → atualiza.
    const [byUid] = await tx<{ id: string }[]>`
      SELECT id FROM users WHERE firebase_uid = ${verified.uid}`;
    if (byUid) {
      // Só grava o e-mail do token se NENHUMA outra linha já o tiver
      // (senão mantém o atual e evita users_email_key).
      await tx`
        UPDATE users SET
          email = CASE
            WHEN ${email}::text IS NULL THEN users.email
            WHEN EXISTS (SELECT 1 FROM users u2
                          WHERE u2.email = ${email} AND u2.id <> users.id) THEN users.email
            ELSE ${email}
          END,
          name = COALESCE(users.name, ${verified.name ?? null}),
          photo_url = COALESCE(users.photo_url, ${verified.picture ?? null}),
          email_verified = ${verified.emailVerified},
          last_seen_at = now(),
          updated_at = now()
        WHERE id = ${byUid.id}`;
      return byUid.id;
    }
    // b) Não há linha para o uid, mas existe uma com este e-mail (re-login com
    //    outro método, ou troca de uid): re-vincula essa linha ao uid atual.
    if (email) {
      const [byEmail] = await tx<{ id: string }[]>`
        SELECT id FROM users WHERE email = ${email}`;
      if (byEmail) {
        await tx`
          UPDATE users SET
            firebase_uid = ${verified.uid},
            name = COALESCE(users.name, ${verified.name ?? null}),
            photo_url = COALESCE(users.photo_url, ${verified.picture ?? null}),
            email_verified = ${verified.emailVerified},
            last_seen_at = now(),
            updated_at = now()
          WHERE id = ${byEmail.id}`;
        return byEmail.id;
      }
    }
    // c) Usuário novo.
    const [created] = await tx<{ id: string }[]>`
      INSERT INTO users (firebase_uid, email, name, photo_url, email_verified, last_seen_at)
      VALUES (${verified.uid}, ${email}, ${verified.name ?? null},
              ${verified.picture ?? null}, ${verified.emailVerified}, now())
      RETURNING id`;
    return created.id;
  });

  const rows = await sql<AppUser[]>`
    SELECT id, firebase_uid, email, name, role, panel_role, status, is_premium
    FROM users WHERE id = ${id}`;
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
