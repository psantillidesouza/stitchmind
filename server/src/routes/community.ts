import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { requireAuth, optionalAuth, type AppUser } from "../auth/middleware.ts";
import { BUCKETS, putObject, mediaUrl } from "../storage.ts";
import { imageToWebp } from "../media.ts";
import { pushLiveEvent } from "../realtime.ts";
import { rateLimit } from "../rateLimit.ts";
import { sendToTokens } from "../push/fcm.ts";

export const communityRoutes = new Hono();

const byUser = (c: any) => `u:${(c.get("user") as AppUser).id}`;

// Serve a imagem pelo proxy da própria API (/v1/media/:id). O MinIO não é
// público, então URL assinada direta não é alcançável pelo app.
async function imgUrl(assetId: string | null): Promise<string | null> {
  return assetId ? mediaUrl(assetId) : null;
}

// Push best-effort para um usuário (todos os aparelhos com push_token).
async function notifyUser(
  userId: string | null,
  payload: { title: string; body: string; data?: Record<string, string> },
) {
  if (!userId) return;
  try {
    const rows = await sql`
      SELECT push_token FROM devices
      WHERE user_id = ${userId} AND push_token IS NOT NULL`;
    const tokens = rows.map((r) => r.push_token as string).filter(Boolean);
    if (tokens.length) await sendToTokens(tokens, payload);
  } catch (e) {
    console.error("[community] notify erro", e);
  }
}

// ─── Dicas ──────────────────────────────────────────────────────────

communityRoutes.get("/tips", async (c) => {
  const rows = await sql`
    SELECT id, emoji, title, body FROM tips
    WHERE published = true ORDER BY order_index, created_at`;
  return c.json({ tips: rows });
});

// ─── Feed da comunidade (paginado, exclui bloqueados) ───────────────

communityRoutes.get("/posts", optionalAuth, async (c) => {
  const user = c.get("user") as AppUser | undefined;
  const limit = Math.min(Math.max(Number(c.req.query("limit") ?? 20), 1), 50);
  const cursor = c.req.query("cursor"); // created_at ISO do último item da página anterior
  const category = c.req.query("category"); // filtro opcional
  const type = c.req.query("type"); // finished | wip | help
  const onlySaved = c.req.query("saved") === "1" && !!user;

  const rows = await sql`
    SELECT p.id, p.caption, p.image_asset_id, p.likes_count, p.comments_count,
           p.created_at, p.user_id AS author_id, p.post_type, p.category,
           p.difficulty, p.yarn, p.hook,
           u.name AS author_name, u.photo_url AS author_photo,
           ${user ? sql`EXISTS (SELECT 1 FROM post_likes pl WHERE pl.post_id = p.id AND pl.user_id = ${user.id})` : sql`false`} AS liked,
           ${user ? sql`EXISTS (SELECT 1 FROM post_saves ps WHERE ps.post_id = p.id AND ps.user_id = ${user.id})` : sql`false`} AS saved
    FROM posts p LEFT JOIN users u ON u.id = p.user_id
    WHERE p.status = 'approved'
      ${cursor ? sql`AND p.created_at < ${cursor}` : sql``}
      ${category ? sql`AND p.category = ${category}` : sql``}
      ${type ? sql`AND p.post_type = ${type}` : sql``}
      ${onlySaved ? sql`AND EXISTS (SELECT 1 FROM post_saves ps2 WHERE ps2.post_id = p.id AND ps2.user_id = ${user!.id})` : sql``}
      ${user ? sql`AND (p.user_id IS NULL OR p.user_id NOT IN (
            SELECT blocked_id FROM user_blocks WHERE blocker_id = ${user.id}))` : sql``}
    ORDER BY p.created_at DESC
    LIMIT ${limit}`;

  const posts = await Promise.all(
    rows.map(async (r) => ({
      id: r.id,
      caption: r.caption,
      image_url: await imgUrl(r.image_asset_id),
      likes: r.likes_count,
      comments: r.comments_count,
      liked: r.liked,
      saved: r.saved,
      post_type: r.post_type,
      category: r.category,
      difficulty: r.difficulty,
      yarn: r.yarn,
      hook: r.hook,
      author_id: r.author_id,
      author: r.author_name ?? "Maker",
      author_photo: r.author_photo,
      is_mine: user ? r.author_id === user.id : false,
      created_at: r.created_at,
    })),
  );
  const next = rows.length === limit ? rows[rows.length - 1]!.created_at : null;
  return c.json({ posts, next_cursor: next });
});

// cria post (imagem + legenda) — multipart, rate-limit anti-spam
communityRoutes.post(
  "/posts",
  requireAuth,
  rateLimit({ max: 10, windowMs: 60_000, prefix: "post_create", keyFn: byUser }),
  async (c) => {
    const user = c.get("user") as AppUser;
    let form: FormData;
    try {
      form = await c.req.formData();
    } catch {
      return c.json({ error: "esperado multipart com 'image'" }, 400);
    }
    const file = form.get("image");
    const caption = ((form.get("caption") as string) ?? "").slice(0, 600);
    if (!(file instanceof File)) return c.json({ error: "imagem ausente" }, 400);
    const mime = file.type.toLowerCase();
    if (!mime.startsWith("image/")) return c.json({ error: "tipo inválido" }, 415);

    // Metadados estilo Ravelry (opcionais, validados contra conjuntos fixos).
    const oneOf = (v: unknown, allowed: string[]) =>
      typeof v === "string" && allowed.includes(v) ? v : null;
    const postType =
      oneOf(form.get("post_type"), ["finished", "wip", "help"]) ?? "finished";
    const category = oneOf(form.get("category"), [
      "amigurumi", "garment", "blanket", "accessory", "granny", "home_decor", "other",
    ]);
    const difficulty = oneOf(form.get("difficulty"), [
      "beginner", "intermediate", "advanced",
    ]);
    const yarn = ((form.get("yarn") as string) ?? "").trim().slice(0, 120) || null;
    const hook = ((form.get("hook") as string) ?? "").trim().slice(0, 60) || null;

    const original = new Uint8Array(await file.arrayBuffer());
    const result = await imageToWebp(original, mime, file.name);
    const key = `${crypto.randomUUID()}.${result.ext}`;
    await putObject(BUCKETS.image, key, result.bytes, result.mime);

    const [asset] = await sql`
      INSERT INTO assets (kind, filename, mime, size_bytes, bucket, storage_key, uploaded_by)
      VALUES ('image', ${file.name}, ${result.mime}, ${result.bytes.byteLength}, ${BUCKETS.image}, ${key}, ${user.id})
      RETURNING id`;
    const [post] = await sql`
      INSERT INTO posts (user_id, caption, image_asset_id, status,
                         post_type, category, difficulty, yarn, hook)
      VALUES (${user.id}, ${caption}, ${asset.id}, 'approved',
              ${postType}, ${category}, ${difficulty}, ${yarn}, ${hook})
      RETURNING id`;

    pushLiveEvent({ kind: "post", name: "nova publicação", user: user.email ?? "alguém" });
    return c.json({ id: post.id, image_url: await imgUrl(asset.id) });
  },
);

// apaga o próprio post (soft-delete)
communityRoutes.delete("/posts/:id", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  const [p] = await sql`SELECT user_id FROM posts WHERE id = ${id}`;
  if (!p) return c.json({ error: "post não encontrado" }, 404);
  if (p.user_id !== user.id) return c.json({ error: "sem permissão" }, 403);
  await sql`UPDATE posts SET status = 'deleted' WHERE id = ${id}`;
  return c.json({ ok: true });
});

// denuncia um post; ao atingir 3 denúncias distintas, esconde automaticamente
communityRoutes.post(
  "/posts/:id/report",
  requireAuth,
  rateLimit({ max: 15, windowMs: 60_000, prefix: "post_report", keyFn: byUser }),
  async (c) => {
    const user = c.get("user") as AppUser;
    const id = c.req.param("id");
    const body = await c.req.json().catch(() => ({}));
    const parsed = z
      .object({
        reason: z.enum(["spam", "offensive", "nudity", "harassment", "other"]),
        note: z.string().max(500).optional(),
      })
      .safeParse(body);
    if (!parsed.success) return c.json({ error: "motivo inválido" }, 400);

    const [exists] = await sql`SELECT 1 FROM posts WHERE id = ${id}`;
    if (!exists) return c.json({ error: "post não encontrado" }, 404);

    await sql`
      INSERT INTO post_reports (post_id, reporter_id, reason, note)
      VALUES (${id}, ${user.id}, ${parsed.data.reason}, ${parsed.data.note ?? null})
      ON CONFLICT (post_id, reporter_id) DO NOTHING`;

    const [{ n }] = await sql`SELECT count(*)::int AS n FROM post_reports WHERE post_id = ${id}`;
    if (n >= 3) {
      await sql`UPDATE posts SET status = 'hidden' WHERE id = ${id} AND status = 'approved'`;
      pushLiveEvent({ kind: "post", name: `post auto-ocultado (${n} denúncias)`, user: "moderação" });
    }
    return c.json({ ok: true });
  },
);

// curtir / descurtir (toggle) + push pro autor
communityRoutes.post("/posts/:id/like", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  const existing = await sql`SELECT 1 FROM post_likes WHERE post_id = ${id} AND user_id = ${user.id}`;
  if (existing.length > 0) {
    await sql`DELETE FROM post_likes WHERE post_id = ${id} AND user_id = ${user.id}`;
    const [p] = await sql`SELECT likes_count FROM posts WHERE id = ${id}`;
    return c.json({ liked: false, likes: p?.likes_count ?? 0 });
  }
  await sql`INSERT INTO post_likes (post_id, user_id) VALUES (${id}, ${user.id}) ON CONFLICT DO NOTHING`;
  const [p] = await sql`SELECT user_id, likes_count FROM posts WHERE id = ${id}`;
  if (p && p.user_id && p.user_id !== user.id) {
    void notifyUser(p.user_id, {
      title: "Nova curtida 🧶",
      body: `${user.name ?? "Alguém"} curtiu sua publicação.`,
      data: { type: "post_like", post_id: id as string },
    });
  }
  return c.json({ liked: true, likes: p?.likes_count ?? 1 });
});

// salvar / remover dos salvos (toggle)
communityRoutes.post("/posts/:id/save", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  const existing = await sql`SELECT 1 FROM post_saves WHERE post_id = ${id} AND user_id = ${user.id}`;
  if (existing.length > 0) {
    await sql`DELETE FROM post_saves WHERE post_id = ${id} AND user_id = ${user.id}`;
    return c.json({ saved: false });
  }
  await sql`INSERT INTO post_saves (post_id, user_id) VALUES (${id}, ${user.id}) ON CONFLICT DO NOTHING`;
  return c.json({ saved: true });
});

// ─── Comentários ────────────────────────────────────────────────────

communityRoutes.get("/posts/:id/comments", optionalAuth, async (c) => {
  const viewer = c.get("user") as AppUser | undefined;
  const id = c.req.param("id");
  const rows = await sql`
    SELECT cm.id, cm.body, cm.created_at, cm.user_id AS author_id,
           u.name AS author_name, u.photo_url AS author_photo
    FROM post_comments cm LEFT JOIN users u ON u.id = cm.user_id
    WHERE cm.post_id = ${id} AND cm.status = 'visible'
    ORDER BY cm.created_at ASC LIMIT 200`;
  return c.json({
    comments: rows.map((r) => ({
      id: r.id,
      body: r.body,
      author_id: r.author_id,
      author: r.author_name ?? "Maker",
      author_photo: r.author_photo,
      is_mine: viewer ? r.author_id === viewer.id : false,
      created_at: r.created_at,
    })),
  });
});

communityRoutes.post(
  "/posts/:id/comments",
  requireAuth,
  rateLimit({ max: 20, windowMs: 60_000, prefix: "comment_create", keyFn: byUser }),
  async (c) => {
    const user = c.get("user") as AppUser;
    const id = c.req.param("id");
    const parsed = z
      .object({ body: z.string().trim().min(1).max(1000) })
      .safeParse(await c.req.json().catch(() => ({})));
    if (!parsed.success) return c.json({ error: "comentário vazio ou longo demais" }, 400);

    const [post] = await sql`SELECT user_id FROM posts WHERE id = ${id} AND status = 'approved'`;
    if (!post) return c.json({ error: "post não encontrado" }, 404);

    const [cm] = await sql`
      INSERT INTO post_comments (post_id, user_id, body)
      VALUES (${id}, ${user.id}, ${parsed.data.body})
      RETURNING id, body, created_at`;
    await sql`UPDATE posts SET comments_count = comments_count + 1 WHERE id = ${id}`;

    if (post.user_id && post.user_id !== user.id) {
      void notifyUser(post.user_id, {
        title: "Novo comentário 💬",
        body: `${user.name ?? "Alguém"} comentou na sua publicação.`,
        data: { type: "post_comment", post_id: id as string },
      });
    }
    return c.json({
      id: cm.id,
      body: cm.body,
      author_id: user.id,
      author: user.name ?? "Maker",
      created_at: cm.created_at,
    });
  },
);

communityRoutes.delete("/comments/:id", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  const [cm] = await sql`SELECT user_id, post_id, status FROM post_comments WHERE id = ${id}`;
  if (!cm) return c.json({ error: "comentário não encontrado" }, 404);
  if (cm.user_id !== user.id) return c.json({ error: "sem permissão" }, 403);
  if (cm.status !== "deleted") {
    await sql`UPDATE post_comments SET status = 'deleted' WHERE id = ${id}`;
    await sql`UPDATE posts SET comments_count = GREATEST(0, comments_count - 1) WHERE id = ${cm.post_id}`;
  }
  return c.json({ ok: true });
});

// ─── Bloquear / seguir / perfil ─────────────────────────────────────

communityRoutes.post("/users/:id/block", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  if (id === user.id) return c.json({ error: "não dá pra bloquear você mesma" }, 400);
  await sql`
    INSERT INTO user_blocks (blocker_id, blocked_id) VALUES (${user.id}, ${id})
    ON CONFLICT DO NOTHING`;
  return c.json({ blocked: true });
});

communityRoutes.delete("/users/:id/block", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  await sql`DELETE FROM user_blocks WHERE blocker_id = ${user.id} AND blocked_id = ${c.req.param("id")}`;
  return c.json({ blocked: false });
});

communityRoutes.post("/users/:id/follow", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const id = c.req.param("id");
  if (id === user.id) return c.json({ error: "não dá pra seguir você mesma" }, 400);
  await sql`
    INSERT INTO follows (follower_id, followee_id) VALUES (${user.id}, ${id})
    ON CONFLICT DO NOTHING`;
  return c.json({ following: true });
});

communityRoutes.delete("/users/:id/follow", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  await sql`DELETE FROM follows WHERE follower_id = ${user.id} AND followee_id = ${c.req.param("id")}`;
  return c.json({ following: false });
});

communityRoutes.get("/users/:id/profile", optionalAuth, async (c) => {
  const viewer = c.get("user") as AppUser | undefined;
  const id = c.req.param("id");
  const [target] = await sql`SELECT id, name, photo_url FROM users WHERE id = ${id}`;
  if (!target) return c.json({ error: "usuário não encontrado" }, 404);

  const [{ posts_count }] = await sql`
    SELECT count(*)::int AS posts_count FROM posts WHERE user_id = ${id} AND status = 'approved'`;
  const [{ followers }] = await sql`SELECT count(*)::int AS followers FROM follows WHERE followee_id = ${id}`;
  const [{ following }] = await sql`SELECT count(*)::int AS following FROM follows WHERE follower_id = ${id}`;

  let isFollowing = false;
  let isBlocked = false;
  if (viewer) {
    isFollowing = (await sql`SELECT 1 FROM follows WHERE follower_id = ${viewer.id} AND followee_id = ${id}`).length > 0;
    isBlocked = (await sql`SELECT 1 FROM user_blocks WHERE blocker_id = ${viewer.id} AND blocked_id = ${id}`).length > 0;
  }

  const postRows = await sql`
    SELECT id, image_asset_id, likes_count FROM posts
    WHERE user_id = ${id} AND status = 'approved'
    ORDER BY created_at DESC LIMIT 30`;
  const posts = await Promise.all(
    postRows.map(async (r) => ({ id: r.id, image_url: await imgUrl(r.image_asset_id), likes: r.likes_count })),
  );

  return c.json({
    id: target.id,
    name: target.name ?? "Maker",
    photo_url: target.photo_url,
    posts_count,
    followers,
    following,
    is_following: isFollowing,
    is_blocked: isBlocked,
    is_me: viewer?.id === target.id,
    posts,
  });
});
