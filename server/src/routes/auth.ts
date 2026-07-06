import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { requireAuth, type AppUser } from "../auth/middleware.ts";
import { signAdminToken } from "../auth/adminAuth.ts";
import { rateLimit } from "../rateLimit.ts";
import { imageToWebp } from "../media.ts";
import { putObject, mediaUrl } from "../storage.ts";
import { env } from "../env.ts";

export const authRoutes = new Hono();

// ─── Login admin do painel (email + senha próprios) ─────────────────
const AdminLogin = z.object({ email: z.string().email(), password: z.string().min(1) });

// Anti brute-force: máx. 8 tentativas por IP a cada 5 min.
authRoutes.post("/admin-login", rateLimit({ max: 8, windowMs: 5 * 60_000, prefix: "login" }), async (c) => {
  const parsed = AdminLogin.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "Informe email e senha." }, 400);
  const { email, password } = parsed.data;

  const [u] = await sql`
    SELECT id, email, name, password_hash, COALESCE(panel_role, 'admin') AS panel_role FROM users
    WHERE lower(email) = lower(${email}) AND role = 'admin' AND password_hash IS NOT NULL`;
  if (!u) return c.json({ error: "Credenciais inválidas." }, 401);

  const ok = await Bun.password.verify(password, u.password_hash as string);
  if (!ok) return c.json({ error: "Credenciais inválidas." }, 401);

  const token = await signAdminToken({ uid: u.id, email: u.email });
  return c.json({ token, user: { email: u.email, name: u.name, panel_role: u.panel_role } });
});

// O register/login/reset acontecem no Firebase (no app). Aqui só sincronizamos
// e devolvemos o perfil de aplicação.

authRoutes.post("/sync", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  return c.json({ user });
});

authRoutes.get("/me", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const [progress] = await sql`
    SELECT
      count(*) FILTER (WHERE status = 'completed') AS completed,
      count(*) FILTER (WHERE status = 'in_progress') AS in_progress
    FROM lesson_progress WHERE user_id = ${user.id}
  `;
  return c.json({ user, progress });
});

// ─── Editar perfil: nome de exibição ────────────────────────────────
const UpdateProfile = z.object({
  name: z.string().trim().min(1, "Informe um nome.").max(40, "Nome muito longo."),
});

authRoutes.patch("/me", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = UpdateProfile.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) {
    return c.json({ error: parsed.error.issues[0]?.message ?? "Dados inválidos." }, 400);
  }
  const { name } = parsed.data;
  const [updated] = await sql`
    UPDATE users SET name = ${name}, updated_at = now()
    WHERE id = ${user.id}
    RETURNING id, firebase_uid, email, name, role, status`;
  return c.json({ user: updated });
});

// ─── Editar perfil: foto (avatar) ───────────────────────────────────
// Recebe multipart 'image', converte p/ WebP e guarda no bucket público
// (URL estável, sem assinatura — pronto p/ CDN). Atualiza users.photo_url.
authRoutes.post("/avatar", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;

  let form: FormData;
  try {
    form = await c.req.formData();
  } catch {
    return c.json({ error: "esperado multipart com 'image'" }, 400);
  }
  const file = form.get("image");
  if (!(file instanceof File)) return c.json({ error: "imagem ausente" }, 400);

  const mime = file.type.toLowerCase();
  if (!mime.startsWith("image/")) return c.json({ error: "tipo inválido" }, 415);
  if (file.size > env.ai.maxImageMb * 1024 * 1024) {
    return c.json({ error: `imagem acima de ${env.ai.maxImageMb}MB` }, 413);
  }

  const original = new Uint8Array(await file.arrayBuffer());
  const result = await imageToWebp(original, mime, file.name);
  const key = `avatars/${user.id}/${crypto.randomUUID()}.${result.ext}`;
  await putObject(env.s3.bucketPublic, key, result.bytes, result.mime);

  const [asset] = await sql`
    INSERT INTO assets (kind, filename, mime, size_bytes, bucket, storage_key, uploaded_by)
    VALUES ('image', ${file.name}, ${result.mime}, ${result.bytes.byteLength},
            ${env.s3.bucketPublic}, ${key}, ${user.id})
    RETURNING id`;

  // Serve via proxy da API (/v1/media/:id), igual às capas de aula. O MinIO
  // não é exposto publicamente, então a URL direta do bucket (publicObjectUrl)
  // não era alcançável pelo app — o avatar caía no ícone.
  const photoUrl = mediaUrl(asset.id);
  await sql`
    UPDATE users SET photo_url = ${photoUrl}, photo_asset_id = ${asset.id}, updated_at = now()
    WHERE id = ${user.id}`;

  return c.json({ photo_url: photoUrl });
});

// ─── Exclusão de conta (exigência App Store 5.1.1 e Google Play) ─────
// Apaga o conteúdo autoral do usuário e a própria conta. A telemetria fica
// anonimizada (FKs ON DELETE SET NULL). O usuário do Firebase é removido no
// app (FirebaseUser.delete()); aqui limpamos os dados de aplicação.
authRoutes.delete("/me", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  if (user.role === "admin") {
    return c.json({ error: "Conta admin não pode ser excluída por aqui." }, 403);
  }
  await sql.begin(async (tx) => {
    await tx`DELETE FROM posts WHERE user_id = ${user.id}`;
    await tx`DELETE FROM users WHERE id = ${user.id}`;
  });
  return c.json({ ok: true });
});
