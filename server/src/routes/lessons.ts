import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { requireAuth, optionalAuth, type AppUser } from "../auth/middleware.ts";
import { minio, mediaUrl } from "../storage.ts";
import { Readable } from "node:stream";

export const lessonRoutes = new Hono();

/** URL de capa servida pela API (stream do MinIO), se houver asset. */
async function coverUrl(assetId: string | null): Promise<string | null> {
  if (!assetId) return null;
  const [a] = await sql`SELECT id FROM assets WHERE id = ${assetId}`;
  if (!a) return null;
  return mediaUrl(assetId);
}

// ─── Mídia (stream do MinIO pela API) ───────────────────────────────
// O MinIO não é exposto publicamente; a API faz o intermédio. Público
// (sem auth) porque é carregado por <img>/player no app, por UUID.
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

lessonRoutes.get("/media/:id", async (c) => {
  const id = c.req.param("id");
  // id inválido → 404 (evita 500 do Postgres "invalid input syntax for uuid").
  if (!UUID_RE.test(id)) return c.json({ error: "Mídia não encontrada." }, 404);
  const [a] = await sql`SELECT bucket, storage_key, mime FROM assets WHERE id = ${id}`;
  if (!a) return c.json({ error: "Mídia não encontrada." }, 404);
  try {
    const obj = await minio.getObject(a.bucket, a.storage_key);
    return new Response(Readable.toWeb(obj) as unknown as ReadableStream, {
      headers: {
        "Content-Type": a.mime || "application/octet-stream",
        "Cache-Control": "public, max-age=31536000, immutable",
      },
    });
  } catch (err) {
    console.warn("[media] falha ao servir asset", id, (err as Error).message);
    return c.json({ error: "Falha ao carregar mídia." }, 502);
  }
});

// ─── Cursos ─────────────────────────────────────────────────────────

lessonRoutes.get("/courses", async (c) => {
  const rows = await sql`
    SELECT id, title, slug, description, technique, level, order_index, cover_asset_id
    FROM courses WHERE published = true
    ORDER BY order_index, created_at
  `;
  const out = await Promise.all(
    rows.map(async (r) => ({ ...r, cover_url: await coverUrl(r.cover_asset_id) })),
  );
  return c.json({ courses: out });
});

// ─── Categorias ─────────────────────────────────────────────────────

lessonRoutes.get("/categories", async (c) => {
  const rows = await sql`
    SELECT id, name, slug, order_index
    FROM categories
    ORDER BY order_index, name
  `;
  return c.json({ categories: rows });
});

// ─── Aulas ──────────────────────────────────────────────────────────

lessonRoutes.get("/lessons", optionalAuth, async (c) => {
  const technique = c.req.query("technique");
  const category = c.req.query("category");
  const user = c.get("user") as AppUser | undefined;

  const rows = await sql`
    SELECT l.id, l.course_id, l.title, l.slug, l.description, l.technique,
           l.difficulty, l.duration_min, l.order_index, l.cover_asset_id, l.cover_url,
           l.is_premium, l.category_id, l.created_at, c.title AS course_title,
           cat.name AS category, cat.slug AS category_slug
    FROM lessons l
    LEFT JOIN courses c ON c.id = l.course_id
    LEFT JOIN categories cat ON cat.id = l.category_id
    WHERE l.status = 'published'
      ${technique ? sql`AND l.technique = ${technique}` : sql``}
      ${category ? sql`AND cat.slug = ${category}` : sql``}
    ORDER BY l.order_index, l.created_at
  `;

  // progresso do usuário (se logado)
  const progressMap = new Map<string, any>();
  if (user) {
    const prog = await sql`
      SELECT lesson_id, status, progress_pct, last_position_s
      FROM lesson_progress WHERE user_id = ${user.id}
    `;
    for (const p of prog) progressMap.set(p.lesson_id, p);
  }

  const out = await Promise.all(
    rows.map(async (r) => ({
      ...r,
      cover_url: r.cover_url || (await coverUrl(r.cover_asset_id)),
      progress: progressMap.get(r.id) ?? null,
    })),
  );
  return c.json({ lessons: out });
});

lessonRoutes.get("/lessons/:slug", optionalAuth, async (c) => {
  const slug = c.req.param("slug");
  const [lesson] = await sql`
    SELECT * FROM lessons WHERE slug = ${slug} AND status = 'published'
  `;
  if (!lesson) return c.json({ error: "Aula não encontrada." }, 404);

  // categoria (nome/slug) para exibição no detalhe
  let category: string | null = null;
  let categorySlug: string | null = null;
  if (lesson.category_id) {
    const [cat] = await sql`
      SELECT name, slug FROM categories WHERE id = ${lesson.category_id}
    `;
    if (cat) {
      category = cat.name;
      categorySlug = cat.slug;
    }
  }

  const blocks = await sql`
    SELECT id, position, type, content, asset_id
    FROM lesson_blocks WHERE lesson_id = ${lesson.id}
    ORDER BY position
  `;
  // resolve URLs assinadas dos blocos de mídia
  const resolvedBlocks = await Promise.all(
    blocks.map(async (b) => {
      const url: string | null = b.asset_id ? mediaUrl(b.asset_id) : null;
      return { ...b, url };
    }),
  );

  // registra view
  const user = c.get("user") as AppUser | undefined;
  await sql`
    INSERT INTO lesson_views (user_id, lesson_id) VALUES (${user?.id ?? null}, ${lesson.id})
  `.catch(() => {});

  return c.json({
    lesson: {
      ...lesson,
      cover_url: lesson.cover_url || (await coverUrl(lesson.cover_asset_id)),
      category,
      category_slug: categorySlug,
    },
    blocks: resolvedBlocks,
  });
});

// ─── Progresso ──────────────────────────────────────────────────────

const ProgressSchema = z.object({
  status: z.enum(["not_started", "in_progress", "completed"]).optional(),
  progress_pct: z.number().int().min(0).max(100).optional(),
  last_position_s: z.number().int().min(0).optional(),
});

lessonRoutes.post("/lessons/:id/progress", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const lessonId = c.req.param("id");
  const parsed = ProgressSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "payload inválido" }, 400);
  const p = parsed.data;
  const completed = p.status === "completed";

  await sql`
    INSERT INTO lesson_progress (user_id, lesson_id, status, progress_pct, last_position_s, completed_at)
    VALUES (${user.id}, ${lessonId}, ${p.status ?? "in_progress"},
            ${p.progress_pct ?? 0}, ${p.last_position_s ?? 0},
            ${completed ? sql`now()` : null})
    ON CONFLICT (user_id, lesson_id) DO UPDATE SET
      status = COALESCE(${p.status ?? null}, lesson_progress.status),
      progress_pct = GREATEST(lesson_progress.progress_pct, ${p.progress_pct ?? 0}),
      last_position_s = ${p.last_position_s ?? 0},
      completed_at = CASE WHEN ${completed} THEN now() ELSE lesson_progress.completed_at END,
      updated_at = now()
  `;
  return c.json({ ok: true });
});
