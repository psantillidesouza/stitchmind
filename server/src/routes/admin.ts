import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { requireAdmin, type AppUser } from "../auth/middleware.ts";
import { BUCKETS, putObject, mediaUrl, type AssetKind } from "../storage.ts";
import { imageToWebp, videoToMp4 } from "../media.ts";
import { sendToTokens, isPushConfigured } from "../push/fcm.ts";
import {
  computeNextRun,
  resolveTargetTokens,
  randomPoolMessage,
} from "../push/scheduler.ts";

export const adminRoutes = new Hono();
adminRoutes.use("*", requireAdmin);

function slugify(s: string): string {
  return s
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "")
    .slice(0, 80);
}

// ─── Dashboards ─────────────────────────────────────────────────────

adminRoutes.get("/overview", async (c) => {
  const [[users], [active], [sessions], [crashes24], [analyses]] = await Promise.all([
    sql`SELECT count(*)::int AS n FROM users`,
    sql`SELECT
          count(*) FILTER (WHERE last_seen_at > now() - interval '1 day')::int  AS dau,
          count(*) FILTER (WHERE last_seen_at > now() - interval '7 days')::int AS wau,
          count(*) FILTER (WHERE last_seen_at > now() - interval '30 days')::int AS mau
        FROM users`,
    sql`SELECT count(*)::int AS n FROM app_sessions WHERE started_at > now() - interval '1 day'`,
    sql`SELECT count(*)::int AS n FROM crashes WHERE ts > now() - interval '1 day'`,
    sql`SELECT count(*)::int AS n FROM analyses`,
  ]);

  const topScreens = await sql`
    SELECT screen, count(*)::int AS n FROM events
    WHERE name = 'screen_view' AND screen IS NOT NULL AND ts > now() - interval '7 days'
    GROUP BY screen ORDER BY n DESC LIMIT 10
  `;
  const topLessons = await sql`
    SELECT l.title, count(*)::int AS views FROM lesson_views v
    JOIN lessons l ON l.id = v.lesson_id
    WHERE v.started_at > now() - interval '30 days'
    GROUP BY l.title ORDER BY views DESC LIMIT 10
  `;
  const usageByDay = await sql`
    SELECT date_trunc('day', ts)::date AS day, count(*)::int AS events
    FROM events WHERE ts > now() - interval '14 days'
    GROUP BY day ORDER BY day
  `;

  return c.json({
    total_users: users.n,
    dau: active.dau, wau: active.wau, mau: active.mau,
    sessions_24h: sessions.n,
    crashes_24h: crashes24.n,
    total_analyses: analyses.n,
    top_screens: topScreens,
    top_lessons: topLessons,
    usage_by_day: usageByDay,
  });
});

adminRoutes.get("/users", async (c) => {
  const q = c.req.query("q") ?? "";
  const rows = await sql`
    SELECT id, email, name, role, status, is_premium, created_at, last_seen_at
    FROM users
    ${q ? sql`WHERE email ILIKE ${"%" + q + "%"} OR name ILIKE ${"%" + q + "%"}` : sql``}
    ORDER BY last_seen_at DESC NULLS LAST LIMIT 100
  `;
  return c.json({ users: rows });
});

adminRoutes.get("/users/:id", async (c) => {
  const id = c.req.param("id");
  const [user] = await sql`SELECT * FROM users WHERE id = ${id}`;
  if (!user) return c.json({ error: "Usuário não encontrado." }, 404);
  const sessions = await sql`
    SELECT id, started_at, ended_at, duration_s, platform, app_version
    FROM app_sessions WHERE user_id = ${id} ORDER BY started_at DESC LIMIT 20`;
  const recentEvents = await sql`
    SELECT name, screen, ts FROM events WHERE user_id = ${id} ORDER BY ts DESC LIMIT 50`;
  const lessons = await sql`
    SELECT l.title, p.status, p.progress_pct, p.updated_at
    FROM lesson_progress p JOIN lessons l ON l.id = p.lesson_id
    WHERE p.user_id = ${id} ORDER BY p.updated_at DESC`;
  const crashes = await sql`
    SELECT error_type, message, is_fatal, ts FROM crashes WHERE user_id = ${id}
    ORDER BY ts DESC LIMIT 20`;
  return c.json({ user, sessions, events: recentEvents, lessons, crashes });
});

// Altera o plano do usuário (premium/free) manualmente pelo painel.
// Observação: se o usuário tiver assinatura ativa no RevenueCat, o webhook
// pode sobrescrever isso no próximo evento — serve para concessões manuais.
const UserPatchSchema = z.object({
  is_premium: z.boolean(),
});
adminRoutes.patch("/users/:id", async (c) => {
  const id = c.req.param("id");
  const parsed = UserPatchSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const premium = parsed.data.is_premium;
  const [row] = await sql`
    UPDATE users SET
      is_premium = ${premium},
      premium_product = ${premium ? "admin_grant" : null},
      premium_updated_at = now(),
      updated_at = now()
    WHERE id = ${id}
    RETURNING id, email, name, role, status, is_premium`;
  if (!row) return c.json({ error: "Usuário não encontrado." }, 404);
  return c.json({ user: row });
});

// ─── Notificações push (envio, agendamento e lista aleatória) ───────

const NotificationSchema = z.object({
  title: z.string().max(120).optional(),
  body: z.string().max(500).optional(),
  use_pool: z.boolean().default(false), // sorteia da notification_pool
  target_type: z.enum(["all", "region", "user"]).default("all"),
  target_value: z.string().optional(), // país (region) ou user_id (user)
});

// Status do push + histórico + agendadas + lista + regiões.
adminRoutes.get("/notifications", async (c) => {
  const configured = await isPushConfigured();
  const history = await sql`
    SELECT n.id, n.title, n.body, n.target_type, n.target_value, n.sent_count,
           n.created_at, (n.scheduled_id IS NOT NULL) AS from_schedule
    FROM notifications n ORDER BY n.created_at DESC LIMIT 50`;
  const scheduled = await sql`
    SELECT * FROM scheduled_notifications ORDER BY created_at DESC LIMIT 100`;
  const pool = await sql`
    SELECT id, title, body, enabled, created_at
    FROM notification_pool ORDER BY created_at DESC LIMIT 200`;
  const regions = await sql`
    SELECT country,
           count(*) FILTER (WHERE push_token IS NOT NULL)::int AS devices
    FROM devices WHERE country IS NOT NULL AND country <> ''
    GROUP BY country ORDER BY devices DESC`;
  const [tot] = await sql`
    SELECT count(*)::int AS n FROM devices WHERE push_token IS NOT NULL`;
  return c.json({
    configured,
    history,
    scheduled,
    pool,
    regions,
    total_tokens: tot?.n ?? 0,
  });
});

// Envia AGORA para: todos | região | usuário. Mensagem fixa ou 🎲 da lista.
adminRoutes.post("/notifications", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = NotificationSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;

  let title = d.title?.trim() || null;
  let body = d.body?.trim() || null;
  if (d.use_pool) {
    const msg = await randomPoolMessage();
    if (!msg) return c.json({ error: "A lista de mensagens está vazia." }, 400);
    title = msg.title;
    body = msg.body;
  }
  if (!title || !body) {
    return c.json({ error: "Informe título e mensagem (ou use a lista)." }, 400);
  }

  const tokens = await resolveTargetTokens(d.target_type, d.target_value);
  const result = await sendToTokens(tokens, {
    title, body, data: { source: "admin", target_type: d.target_type },
  });

  // Limpa tokens que o FCM reportou como inválidos/expirados.
  if (result.invalidTokens.length) {
    await sql`
      UPDATE devices SET push_token = NULL
      WHERE push_token = ANY(${result.invalidTokens})`.catch(() => {});
  }

  await sql`
    INSERT INTO notifications (title, body, target_type, target_value, sent_count, created_by)
    VALUES (${title}, ${body}, ${d.target_type}, ${d.target_value ?? null},
            ${result.sent}, ${user.id})`.catch(() => {});

  return c.json({
    configured: result.configured,
    candidates: tokens.length,
    sent: result.sent,
    failed: result.failed,
    error: result.error ?? null,
  });
});

// ─── Agendamentos ────────────────────────────────────────────────────

const ScheduleSchema = z.object({
  title: z.string().max(120).optional(),
  body: z.string().max(500).optional(),
  use_pool: z.boolean().default(false),
  target_type: z.enum(["all", "region", "user"]).default("all"),
  target_value: z.string().optional(),
  schedule_kind: z.enum(["once", "daily", "weekly", "interval"]),
  send_at: z.string().optional(), // ISO (once)
  time_of_day: z.string().regex(/^\d{2}:\d{2}$/).optional(), // daily/weekly
  days_of_week: z.array(z.number().int().min(0).max(6)).optional(), // weekly
  interval_minutes: z.number().int().min(1).optional(), // interval
  timezone: z.string().default("America/Sao_Paulo"),
});

adminRoutes.post("/notifications/schedule", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = ScheduleSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;

  if (!d.use_pool && (!d.title?.trim() || !d.body?.trim())) {
    return c.json({ error: "Informe título e mensagem (ou use a lista aleatória)." }, 400);
  }
  if (d.schedule_kind === "once" && !d.send_at) {
    return c.json({ error: "Informe a data/hora do envio." }, 400);
  }
  if ((d.schedule_kind === "daily" || d.schedule_kind === "weekly") && !d.time_of_day) {
    return c.json({ error: "Informe o horário." }, 400);
  }
  if (d.schedule_kind === "weekly" && !(d.days_of_week?.length)) {
    return c.json({ error: "Escolha pelo menos um dia da semana." }, 400);
  }
  if (d.schedule_kind === "interval" && !d.interval_minutes) {
    return c.json({ error: "Informe o intervalo em minutos." }, 400);
  }

  const next = computeNextRun({
    schedule_kind: d.schedule_kind,
    send_at: d.send_at ?? null,
    time_of_day: d.time_of_day ?? null,
    days_of_week: d.days_of_week ?? null,
    interval_minutes: d.interval_minutes ?? null,
    timezone: d.timezone,
  });
  if (!next) return c.json({ error: "Não foi possível calcular o próximo envio." }, 400);

  const [row] = await sql`
    INSERT INTO scheduled_notifications
      (title, body, use_pool, target_type, target_value, schedule_kind,
       send_at, time_of_day, days_of_week, interval_minutes, timezone,
       next_run_at, created_by)
    VALUES (${d.title?.trim() ?? null}, ${d.body?.trim() ?? null}, ${d.use_pool},
            ${d.target_type}, ${d.target_value ?? null}, ${d.schedule_kind},
            ${d.send_at ?? null}, ${d.time_of_day ?? null},
            ${d.days_of_week ?? null}, ${d.interval_minutes ?? null},
            ${d.timezone}, ${next}, ${user.id})
    RETURNING *`;
  return c.json({ schedule: row });
});

// Pausar/retomar (enabled) — ao retomar, recalcula o próximo envio.
adminRoutes.patch("/notifications/schedule/:id", async (c) => {
  const id = c.req.param("id");
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`SELECT * FROM scheduled_notifications WHERE id = ${id}`;
  if (!row) return c.json({ error: "Agendamento não encontrado." }, 404);

  const enabled = typeof d.enabled === "boolean" ? d.enabled : row.enabled;
  let next = row.next_run_at;
  if (enabled && !row.next_run_at) next = computeNextRun(row);
  if (!enabled) next = null;

  const [updated] = await sql`
    UPDATE scheduled_notifications SET enabled = ${enabled}, next_run_at = ${next}
    WHERE id = ${id} RETURNING *`;
  return c.json({ schedule: updated });
});

adminRoutes.delete("/notifications/schedule/:id", async (c) => {
  await sql`DELETE FROM scheduled_notifications WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Lista de mensagens (sorteio) ────────────────────────────────────

const PoolSchema = z.object({
  title: z.string().min(1).max(120),
  body: z.string().min(1).max(500),
});

adminRoutes.post("/notifications/pool", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = PoolSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const [row] = await sql`
    INSERT INTO notification_pool (title, body, created_by)
    VALUES (${parsed.data.title}, ${parsed.data.body}, ${user.id})
    RETURNING *`;
  return c.json({ message: row });
});

adminRoutes.patch("/notifications/pool/:id", async (c) => {
  const id = c.req.param("id");
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`
    UPDATE notification_pool SET
      title = COALESCE(${(d.title as string) ?? null}, title),
      body = COALESCE(${(d.body as string) ?? null}, body),
      enabled = COALESCE(${(d.enabled as boolean) ?? null}, enabled)
    WHERE id = ${id} RETURNING *`;
  return c.json({ message: row });
});

adminRoutes.delete("/notifications/pool/:id", async (c) => {
  await sql`DELETE FROM notification_pool WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

adminRoutes.get("/analytics/screens", async (c) => {
  const rows = await sql`
    SELECT screen, count(*)::int AS views,
           count(DISTINCT user_id)::int AS users
    FROM events
    WHERE name = 'screen_view' AND screen IS NOT NULL AND ts > now() - interval '30 days'
    GROUP BY screen ORDER BY views DESC`;
  return c.json({ screens: rows });
});

adminRoutes.get("/analytics/events", async (c) => {
  const rows = await sql`
    SELECT name, count(*)::int AS n, count(DISTINCT user_id)::int AS users
    FROM events WHERE ts > now() - interval '30 days'
    GROUP BY name ORDER BY n DESC LIMIT 50`;
  return c.json({ events: rows });
});

adminRoutes.get("/crashes", async (c) => {
  const rows = await sql`
    SELECT fingerprint,
           (array_agg(error_type ORDER BY ts DESC))[1] AS error_type,
           (array_agg(message ORDER BY ts DESC))[1]    AS message,
           count(*)::int AS occurrences,
           count(DISTINCT user_id)::int AS users,
           count(DISTINCT app_version)::int AS versions,
           max(ts) AS last_seen,
           bool_or(is_fatal) AS fatal
    FROM crashes WHERE ts > now() - interval '30 days'
    GROUP BY fingerprint ORDER BY last_seen DESC`;
  return c.json({ crashes: rows });
});

adminRoutes.get("/crashes/:fingerprint", async (c) => {
  const fp = c.req.param("fingerprint");
  const rows = await sql`
    SELECT * FROM crashes WHERE fingerprint = ${fp} ORDER BY ts DESC LIMIT 50`;
  return c.json({ crashes: rows });
});

// ─── Cursos (CRUD) ──────────────────────────────────────────────────

const CourseSchema = z.object({
  title: z.string().min(1),
  description: z.string().optional(),
  technique: z.enum(["crochet", "knit"]).optional(),
  level: z.enum(["beginner", "intermediate", "advanced"]).optional(),
  published: z.boolean().optional(),
  order_index: z.number().int().optional(),
  is_premium: z.boolean().optional(),
});

adminRoutes.get("/courses", async (c) => {
  const rows = await sql`
    SELECT c.*, (SELECT count(*)::int FROM lessons l WHERE l.course_id = c.id) AS lesson_count
    FROM courses c ORDER BY order_index, created_at`;
  return c.json({ courses: rows });
});

adminRoutes.post("/courses", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = CourseSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const [row] = await sql`
    INSERT INTO courses (title, slug, description, technique, level, published, order_index, is_premium, created_by)
    VALUES (${d.title}, ${slugify(d.title)}, ${d.description ?? ""}, ${d.technique ?? null},
            ${d.level ?? "beginner"}, ${d.published ?? false}, ${d.order_index ?? 0},
            ${d.is_premium ?? false}, ${user.id})
    RETURNING *`;
  return c.json({ course: row });
});

adminRoutes.patch("/courses/:id", async (c) => {
  const id = c.req.param("id");
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`
    UPDATE courses SET
      title = COALESCE(${(d.title as string) ?? null}, title),
      description = COALESCE(${(d.description as string) ?? null}, description),
      technique = COALESCE(${(d.technique as string) ?? null}, technique),
      level = COALESCE(${(d.level as string) ?? null}, level),
      published = COALESCE(${(d.published as boolean) ?? null}, published),
      order_index = COALESCE(${(d.order_index as number) ?? null}, order_index),
      is_premium = COALESCE(${(d.is_premium as boolean) ?? null}, is_premium),
      updated_at = now()
    WHERE id = ${id} RETURNING *`;
  return c.json({ course: row });
});

adminRoutes.delete("/courses/:id", async (c) => {
  await sql`DELETE FROM courses WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Categorias (CRUD) ──────────────────────────────────────────────

const CategorySchema = z.object({
  name: z.string().min(1),
});

adminRoutes.get("/categories", async (c) => {
  const rows = await sql`
    SELECT cat.id, cat.name, cat.slug, cat.order_index, cat.created_at,
           (SELECT count(*)::int FROM lessons l WHERE l.category_id = cat.id) AS lesson_count
    FROM categories cat
    ORDER BY cat.order_index, cat.name`;
  return c.json({ categories: rows });
});

adminRoutes.post("/categories", async (c) => {
  const parsed = CategorySchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const [row] = await sql`
    INSERT INTO categories (name, slug)
    VALUES (${d.name}, ${slugify(d.name)})
    ON CONFLICT (slug) DO NOTHING
    RETURNING *`;
  if (!row) return c.json({ error: "Categoria já existe." }, 409);
  return c.json({ category: row });
});

adminRoutes.patch("/categories/:id", async (c) => {
  const id = c.req.param("id");
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`
    UPDATE categories SET
      name = COALESCE(${(d.name as string) ?? null}, name),
      order_index = COALESCE(${(d.order_index as number) ?? null}, order_index)
    WHERE id = ${id} RETURNING *`;
  return c.json({ category: row });
});

adminRoutes.delete("/categories/:id", async (c) => {
  await sql`DELETE FROM categories WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Aulas (CRUD) ───────────────────────────────────────────────────

const LessonSchema = z.object({
  course_id: z.string().uuid().nullable().optional(),
  title: z.string().min(1),
  description: z.string().optional(),
  technique: z.enum(["crochet", "knit"]).optional(),
  difficulty: z.enum(["beginner", "intermediate", "advanced"]).optional(),
  duration_min: z.number().int().optional(),
  status: z.enum(["draft", "published"]).optional(),
  order_index: z.number().int().optional(),
  is_premium: z.boolean().optional(),
  category_id: z.string().uuid().nullable().optional(),
});

adminRoutes.get("/lessons", async (c) => {
  const rows = await sql`
    SELECT l.*, c.title AS course_title,
           cat.name AS category, cat.slug AS category_slug,
           (SELECT count(*)::int FROM lesson_blocks b WHERE b.lesson_id = l.id) AS block_count,
           (SELECT count(*)::int FROM lesson_views v WHERE v.lesson_id = l.id) AS views
    FROM lessons l
    LEFT JOIN courses c ON c.id = l.course_id
    LEFT JOIN categories cat ON cat.id = l.category_id
    ORDER BY l.order_index, l.created_at`;
  return c.json({ lessons: rows });
});

adminRoutes.post("/lessons", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = LessonSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const [row] = await sql`
    INSERT INTO lessons (course_id, title, slug, description, technique, difficulty,
                         duration_min, status, order_index, is_premium, category_id, created_by)
    VALUES (${d.course_id ?? null}, ${d.title}, ${slugify(d.title) + "-" + Date.now().toString(36)},
            ${d.description ?? ""}, ${d.technique ?? null}, ${d.difficulty ?? "beginner"},
            ${d.duration_min ?? null}, ${d.status ?? "draft"}, ${d.order_index ?? 0},
            ${d.is_premium ?? false}, ${d.category_id ?? null}, ${user.id})
    RETURNING *`;
  return c.json({ lesson: row });
});

adminRoutes.patch("/lessons/:id", async (c) => {
  const id = c.req.param("id");
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const publishing = d.status === "published";
  const [row] = await sql`
    UPDATE lessons SET
      course_id = COALESCE(${(d.course_id as string) ?? null}, course_id),
      title = COALESCE(${(d.title as string) ?? null}, title),
      description = COALESCE(${(d.description as string) ?? null}, description),
      technique = COALESCE(${(d.technique as string) ?? null}, technique),
      difficulty = COALESCE(${(d.difficulty as string) ?? null}, difficulty),
      duration_min = COALESCE(${(d.duration_min as number) ?? null}, duration_min),
      status = COALESCE(${(d.status as string) ?? null}, status),
      order_index = COALESCE(${(d.order_index as number) ?? null}, order_index),
      cover_url = COALESCE(${(d.cover_url as string) ?? null}, cover_url),
      cover_asset_id = COALESCE(${(d.cover_asset_id as string) ?? null}, cover_asset_id),
      is_premium = COALESCE(${(d.is_premium as boolean) ?? null}, is_premium),
      category_id = COALESCE(${(d.category_id as string) ?? null}, category_id),
      meta = COALESCE(${d.meta != null ? sql.json(d.meta) : null}, meta),
      published_at = CASE WHEN ${publishing} AND published_at IS NULL THEN now() ELSE published_at END,
      updated_at = now()
    WHERE id = ${id} RETURNING *`;
  return c.json({ lesson: row });
});

// Aula única (com meta) — para o editor do painel.
adminRoutes.get("/lessons/:id", async (c) => {
  const [row] = await sql`SELECT * FROM lessons WHERE id = ${c.req.param("id")}`;
  if (!row) return c.json({ error: "Aula não encontrada." }, 404);
  return c.json({ lesson: row });
});

adminRoutes.delete("/lessons/:id", async (c) => {
  await sql`DELETE FROM lessons WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Aula completa (modelo rico, num envio só) ──────────────────────
// Cria a aula com metadados estruturados (materiais, sequência de cores,
// método de construção, pontos, análise do padrão) + os passos detalhados.

const StitchSchema = z.object({
  name: z.string().min(1),
  confidence: z.string().optional(),
});

const FullStepSchema = z.object({
  title: z.string().optional(),
  goal: z.string().optional(),
  visual_description: z.string().optional(),
  stitches_used: z.string().optional(),
  pattern_used: z.string().optional(),
  expected_result: z.string().optional(),
  instruction: z.string().optional(),
  image_url: z.string().optional(),
  image_asset_id: z.string().uuid().nullable().optional(),
});

const LessonMetaSchema = z.object({
  product_name: z.string().optional(),
  overview: z.string().optional(),
  difficulty_label: z.string().optional(),
  finished_size: z.string().optional(),
  materials: z.array(z.string()).optional(),
  color_sequence: z.string().optional(),
  construction_method: z.string().optional(),
  stitches: z.array(StitchSchema).optional(),
  pattern_analysis: z.string().optional(),
  confidence_note: z.string().optional(),
});

const FullLessonSchema = z.object({
  course_id: z.string().uuid().nullable().optional(),
  title: z.string().min(1),
  description: z.string().optional(),
  technique: z.enum(["crochet", "knit"]).optional(),
  difficulty: z.enum(["beginner", "intermediate", "advanced"]).optional(),
  duration_min: z.number().int().nullable().optional(),
  cover_url: z.string().optional(),
  cover_asset_id: z.string().uuid().nullable().optional(),
  status: z.enum(["draft", "published"]).optional(),
  order_index: z.number().int().optional(),
  is_premium: z.boolean().optional(),
  category_id: z.string().uuid().nullable().optional(),
  meta: LessonMetaSchema.optional(),
  steps: z.array(FullStepSchema).optional(),
});

adminRoutes.post("/lessons/full", async (c) => {
  const user = c.get("user") as AppUser;
  const parsed = FullLessonSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const slug = `${slugify(d.title)}-${Date.now().toString(36)}`;
  const publishing = d.status === "published";

  const lesson = await sql.begin(async (tx) => {
    const [row] = await tx`
      INSERT INTO lessons (course_id, title, slug, description, technique, difficulty,
                           duration_min, cover_url, cover_asset_id, status, order_index,
                           is_premium, category_id, meta, created_by, published_at)
      VALUES (${d.course_id ?? null}, ${d.title}, ${slug}, ${d.description ?? ""},
              ${d.technique ?? "crochet"}, ${d.difficulty ?? "beginner"},
              ${d.duration_min ?? null}, ${d.cover_url ?? null}, ${d.cover_asset_id ?? null},
              ${d.status ?? "draft"}, ${d.order_index ?? 0},
              ${d.is_premium ?? false}, ${d.category_id ?? null}, ${sql.json(d.meta ?? {})}, ${user.id},
              ${publishing ? sql`now()` : null})
      RETURNING *`;

    const steps = d.steps ?? [];
    for (let i = 0; i < steps.length; i++) {
      const s = steps[i]!;
      const content = {
        number: i + 1,
        title: s.title ?? null,
        goal: s.goal ?? null,
        visual_description: s.visual_description ?? null,
        stitches_used: s.stitches_used ?? null,
        pattern_used: s.pattern_used ?? null,
        expected_result: s.expected_result ?? null,
        // instrução de exibição: mantém compatibilidade com o renderizador atual
        instruction: s.instruction ?? [s.goal, s.pattern_used].filter(Boolean).join(" "),
        image_url: s.image_url ?? null,
      };
      await tx`
        INSERT INTO lesson_blocks (lesson_id, position, type, content, asset_id)
        VALUES (${row.id}, ${i}, 'step', ${sql.json(content)}, ${s.image_asset_id ?? null})`;
    }
    return row;
  });

  return c.json({ lesson });
});

// ─── Blocos (conteúdo misto) ────────────────────────────────────────

adminRoutes.get("/lessons/:id/blocks", async (c) => {
  const rows = await sql`
    SELECT b.*, a.bucket, a.storage_key, a.mime, a.kind
    FROM lesson_blocks b LEFT JOIN assets a ON a.id = b.asset_id
    WHERE b.lesson_id = ${c.req.param("id")} ORDER BY position`;
  // URL servida pela API (stream do MinIO) para preview no painel
  const blocks = rows.map((b) => ({
    ...b,
    url: b.asset_id ? mediaUrl(b.asset_id) : null,
  }));
  return c.json({ blocks });
});

const BlockSchema = z.object({
  type: z.enum(["text", "image", "video", "material", "step"]),
  position: z.number().int().optional(),
  content: z.record(z.any()).optional(),
  asset_id: z.string().uuid().nullable().optional(),
});

adminRoutes.post("/lessons/:id/blocks", async (c) => {
  const lessonId = c.req.param("id");
  const parsed = BlockSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const [pos] = await sql`
    SELECT COALESCE(max(position) + 1, 0) AS p FROM lesson_blocks WHERE lesson_id = ${lessonId}`;
  const [row] = await sql`
    INSERT INTO lesson_blocks (lesson_id, position, type, content, asset_id)
    VALUES (${lessonId}, ${d.position ?? pos.p}, ${d.type},
            ${sql.json(d.content ?? {})}, ${d.asset_id ?? null})
    RETURNING *`;
  return c.json({ block: row });
});

const BlockPatchSchema = z.object({
  content: z.record(z.any()).optional(),  // substitui o content inteiro
  asset_id: z.string().uuid().nullable().optional(),
  position: z.number().int().optional(),
});

adminRoutes.patch("/blocks/:id", async (c) => {
  const id = c.req.param("id");
  const parsed = BlockPatchSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: parsed.error.flatten() }, 400);
  const d = parsed.data;
  const setAsset = d.asset_id !== undefined; // permite limpar (null) ou trocar
  const [row] = await sql`
    UPDATE lesson_blocks SET
      content    = COALESCE(${d.content != null ? sql.json(d.content) : null}, content),
      asset_id   = CASE WHEN ${setAsset} THEN ${d.asset_id ?? null} ELSE asset_id END,
      position   = COALESCE(${d.position ?? null}, position)
    WHERE id = ${id} RETURNING *`;
  if (!row) return c.json({ error: "Bloco não encontrado." }, 404);
  return c.json({ block: row });
});

adminRoutes.delete("/blocks/:id", async (c) => {
  await sql`DELETE FROM lesson_blocks WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Upload de mídia ────────────────────────────────────────────────

adminRoutes.post("/assets", async (c) => {
  const user = c.get("user") as AppUser;
  let form: FormData;
  try {
    form = await c.req.formData();
  } catch {
    return c.json({ error: "esperado multipart/form-data com 'file'" }, 400);
  }
  const file = form.get("file");
  if (!(file instanceof File)) return c.json({ error: "campo 'file' ausente" }, 400);

  const mime = file.type.toLowerCase();
  let kind: AssetKind;
  if (mime.startsWith("video/")) kind = "video";
  else if (mime.startsWith("image/")) kind = "image";
  else if (mime === "application/pdf") kind = "pdf";
  else return c.json({ error: `tipo não suportado: ${mime}` }, 415);

  const bucket = BUCKETS[kind];
  const original = new Uint8Array(await file.arrayBuffer());

  // Imagens → WebP, vídeos → MP4; PDF (e formatos não suportados) passam direto.
  const result =
    kind === "image"
      ? await imageToWebp(original, mime, file.name)
      : kind === "video"
        ? await videoToMp4(original, mime, file.name)
        : {
            bytes: original,
            mime,
            ext: file.name.includes(".") ? file.name.split(".").pop()!.toLowerCase() : "bin",
            converted: false,
          };

  const key = `${crypto.randomUUID()}.${result.ext}`;
  await putObject(bucket, key, result.bytes, result.mime);

  const [row] = await sql`
    INSERT INTO assets (kind, filename, mime, size_bytes, bucket, storage_key, uploaded_by)
    VALUES (${kind}, ${file.name}, ${result.mime}, ${result.bytes.byteLength}, ${bucket}, ${key}, ${user.id})
    RETURNING id, kind, filename, mime, size_bytes`;
  return c.json({ asset: row });
});

adminRoutes.get("/lessons/:id/metrics", async (c) => {
  const id = c.req.param("id");
  const [m] = await sql`
    SELECT
      (SELECT count(*)::int FROM lesson_views WHERE lesson_id = ${id}) AS views,
      (SELECT count(*)::int FROM lesson_progress WHERE lesson_id = ${id} AND status = 'completed') AS completions,
      (SELECT count(*)::int FROM lesson_progress WHERE lesson_id = ${id}) AS starts`;
  return c.json({ metrics: m });
});

// ─── Heatmaps + frustração ──────────────────────────────────────────

adminRoutes.get("/screens-with-taps", async (c) => {
  const rows = await sql`
    SELECT screen, count(*)::int AS taps,
           count(*) FILTER (WHERE is_rage)::int AS rage,
           count(*) FILTER (WHERE is_dead)::int AS dead
    FROM taps WHERE screen IS NOT NULL AND ts > now() - interval '30 days'
    GROUP BY screen ORDER BY taps DESC`;
  return c.json({ screens: rows });
});

adminRoutes.get("/heatmap/:screen", async (c) => {
  const screen = c.req.param("screen");
  const rows = await sql`
    SELECT x, y, is_rage FROM taps
    WHERE screen = ${screen} AND ts > now() - interval '30 days'
    ORDER BY ts DESC LIMIT 3000`;
  return c.json({ screen, points: rows });
});

adminRoutes.get("/frustration", async (c) => {
  // rage/dead por tela
  const byScreen = await sql`
    SELECT screen,
           count(*) FILTER (WHERE is_rage)::int AS rage,
           count(*) FILTER (WHERE is_dead)::int AS dead
    FROM taps WHERE ts > now() - interval '30 days' AND screen IS NOT NULL
    GROUP BY screen HAVING count(*) FILTER (WHERE is_rage) > 0
                         OR count(*) FILTER (WHERE is_dead) > 0
    ORDER BY rage DESC, dead DESC`;
  // quick-backs: screen_view seguido de saída em < 3s (mesma sessão)
  const quickBacks = await sql`
    WITH ordered AS (
      SELECT session_id, screen, ts,
             lead(ts) OVER (PARTITION BY session_id ORDER BY ts) AS next_ts
      FROM events WHERE name = 'screen_view' AND session_id IS NOT NULL
        AND ts > now() - interval '30 days'
    )
    SELECT screen, count(*)::int AS quick_backs
    FROM ordered
    WHERE next_ts IS NOT NULL AND next_ts - ts < interval '3 seconds'
    GROUP BY screen ORDER BY quick_backs DESC LIMIT 20`;
  return c.json({ by_screen: byScreen, quick_backs: quickBacks });
});

// ─── Session replay (timeline) ──────────────────────────────────────

adminRoutes.get("/sessions", async (c) => {
  const rows = await sql`
    SELECT s.id, s.started_at, s.ended_at, s.duration_s, s.platform, s.app_version,
           u.email, u.name,
           (SELECT count(*)::int FROM events e WHERE e.session_id = s.id) AS events,
           (SELECT count(*)::int FROM taps t WHERE t.session_id = s.id) AS taps,
           EXISTS (SELECT 1 FROM crashes cr WHERE cr.user_id = s.user_id
                   AND cr.ts BETWEEN s.started_at AND COALESCE(s.ended_at, now())) AS has_crash
    FROM app_sessions s LEFT JOIN users u ON u.id = s.user_id
    ORDER BY s.started_at DESC LIMIT 100`;
  return c.json({ sessions: rows });
});

adminRoutes.get("/sessions/:id/timeline", async (c) => {
  const id = c.req.param("id");
  const [session] = await sql`
    SELECT s.*, u.email, u.name FROM app_sessions s
    LEFT JOIN users u ON u.id = s.user_id WHERE s.id = ${id}`;
  if (!session) return c.json({ error: "sessão não encontrada" }, 404);

  const events = await sql`
    SELECT 'event' AS kind, name, screen, props, ts FROM events WHERE session_id = ${id}`;
  const taps = await sql`
    SELECT 'tap' AS kind, screen, x, y, label, is_rage, is_dead, ts FROM taps WHERE session_id = ${id}`;
  const crashes = await sql`
    SELECT 'crash' AS kind, error_type, message, ts FROM crashes
    WHERE user_id = ${session.user_id}
      AND ts BETWEEN ${session.started_at} AND COALESCE(${session.ended_at}, now())`;

  const timeline = [...events, ...taps, ...crashes].sort(
    (a, b) => new Date(a.ts as string).getTime() - new Date(b.ts as string).getTime(),
  );
  return c.json({ session, timeline });
});

// ─── Funil + retenção + insights ────────────────────────────────────

adminRoutes.get("/funnel", async (c) => {
  const [r] = await sql`
    SELECT
      (SELECT count(DISTINCT user_id)::int FROM events
        WHERE name = 'screen_view' AND screen = 'painel') AS abriu_painel,
      (SELECT count(DISTINCT user_id)::int FROM lesson_views) AS abriu_aula,
      (SELECT count(DISTINCT user_id)::int FROM lesson_progress WHERE status = 'in_progress' OR status = 'completed') AS comecou,
      (SELECT count(DISTINCT user_id)::int FROM lesson_progress WHERE status = 'completed') AS concluiu`;
  return c.json({
    steps: [
      { label: "Abriu o painel", users: r.abriu_painel },
      { label: "Abriu uma aula", users: r.abriu_aula },
      { label: "Começou a aula", users: r.comecou },
      { label: "Concluiu a aula", users: r.concluiu },
    ],
  });
});

adminRoutes.get("/retention", async (c) => {
  // % de usuários vistos de novo D1/D7/D30 após o cadastro
  const [r] = await sql`
    WITH base AS (SELECT id, created_at FROM users)
    SELECT
      count(*)::int AS total,
      count(*) FILTER (WHERE last_seen_at >= created_at + interval '1 day')::int AS d1,
      count(*) FILTER (WHERE last_seen_at >= created_at + interval '7 days')::int AS d7,
      count(*) FILTER (WHERE last_seen_at >= created_at + interval '30 days')::int AS d30
    FROM users`;
  return c.json(r);
});

// ─── Dicas (admin) ──────────────────────────────────────────────────

adminRoutes.get("/tips", async (c) => {
  const rows = await sql`SELECT * FROM tips ORDER BY order_index, created_at`;
  return c.json({ tips: rows });
});
adminRoutes.post("/tips", async (c) => {
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`
    INSERT INTO tips (emoji, title, body, order_index)
    VALUES (${(d.emoji as string) ?? "🧶"}, ${d.title as string}, ${(d.body as string) ?? ""}, ${(d.order_index as number) ?? 0})
    RETURNING *`;
  return c.json({ tip: row });
});
adminRoutes.delete("/tips/:id", async (c) => {
  await sql`DELETE FROM tips WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// ─── Posts da comunidade (moderação) ────────────────────────────────

adminRoutes.get("/posts", async (c) => {
  const rows = await sql`
    SELECT p.id, p.caption, p.status, p.likes_count, p.created_at, p.image_asset_id,
           u.email AS author, a.bucket, a.storage_key
    FROM posts p LEFT JOIN users u ON u.id = p.user_id
    LEFT JOIN assets a ON a.id = p.image_asset_id
    ORDER BY p.created_at DESC LIMIT 100`;
  return c.json({ posts: rows });
});
adminRoutes.patch("/posts/:id", async (c) => {
  const d = (await c.req.json().catch(() => ({}))) as Record<string, unknown>;
  const [row] = await sql`
    UPDATE posts SET status = COALESCE(${(d.status as string) ?? null}, status)
    WHERE id = ${c.req.param("id")} RETURNING id, status`;
  return c.json({ post: row });
});
adminRoutes.delete("/posts/:id", async (c) => {
  await sql`DELETE FROM posts WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

// Denúncias: posts denunciados, agrupados, com contagem e motivos.
adminRoutes.get("/reports", async (c) => {
  const rows = await sql`
    SELECT p.id, p.caption, p.status, p.created_at, p.image_asset_id,
           u.email AS author,
           count(r.id)::int AS report_count,
           array_agg(DISTINCT r.reason) AS reasons,
           max(r.created_at) AS last_report_at
    FROM post_reports r
    JOIN posts p ON p.id = r.post_id
    LEFT JOIN users u ON u.id = p.user_id
    GROUP BY p.id, u.email
    ORDER BY (p.status = 'approved') DESC, report_count DESC, last_report_at DESC
    LIMIT 100`;
  return c.json({ reports: rows });
});

// ─── Receitas / Patterns (biblioteca curada) ────────────────────────
adminRoutes.get("/patterns", async (c) => {
  const rows = await sql`
    SELECT id, name, author, technique, difficulty, status, order_index,
           jsonb_array_length(sections) AS section_count, updated_at
    FROM patterns ORDER BY order_index, created_at`;
  return c.json({ patterns: rows });
});

adminRoutes.get("/patterns/:id", async (c) => {
  const [p] = await sql`SELECT * FROM patterns WHERE id = ${c.req.param("id")}`;
  if (!p) return c.json({ error: "não encontrado" }, 404);
  return c.json({ pattern: p });
});

// Cria OU substitui (upsert) — o painel manda o pattern completo em JSON.
adminRoutes.post("/patterns", async (c) => {
  const d = (await c.req.json().catch(() => ({}))) as Record<string, any>;
  if (!d.name || !d.technique || !d.difficulty) {
    return c.json({ error: "name, technique e difficulty são obrigatórios" }, 400);
  }
  if (!["crochet", "knit"].includes(d.technique)) {
    return c.json({ error: "technique inválida (crochet|knit)" }, 400);
  }
  if (!["beginner", "intermediate", "advanced"].includes(d.difficulty)) {
    return c.json({ error: "difficulty inválida" }, 400);
  }
  const id = typeof d.id === "string" && d.id.trim()
    ? d.id.trim()
    : `p-${crypto.randomUUID().slice(0, 8)}`;
  const sections = Array.isArray(d.sections) ? d.sections : [];
  const [row] = await sql`
    INSERT INTO patterns (id, name, author, technique, difficulty, yarn_requirement,
                          estimated_hours, suggested_needle, description, sections, status, order_index)
    VALUES (${id}, ${d.name}, ${d.author ?? "StitchMind"}, ${d.technique}, ${d.difficulty},
            ${d.yarn_requirement ?? ""}, ${Number(d.estimated_hours ?? 0)}, ${d.suggested_needle ?? null},
            ${d.description ?? ""}, ${JSON.stringify(sections)}::jsonb,
            ${d.status ?? "published"}, ${Number(d.order_index ?? 0)})
    ON CONFLICT (id) DO UPDATE SET
      name = EXCLUDED.name, author = EXCLUDED.author, technique = EXCLUDED.technique,
      difficulty = EXCLUDED.difficulty, yarn_requirement = EXCLUDED.yarn_requirement,
      estimated_hours = EXCLUDED.estimated_hours, suggested_needle = EXCLUDED.suggested_needle,
      description = EXCLUDED.description, sections = EXCLUDED.sections,
      status = EXCLUDED.status, order_index = EXCLUDED.order_index, updated_at = now()
    RETURNING id`;
  return c.json({ id: row.id });
});

adminRoutes.delete("/patterns/:id", async (c) => {
  await sql`DELETE FROM patterns WHERE id = ${c.req.param("id")}`;
  return c.json({ ok: true });
});

adminRoutes.get("/insights", async (c) => {
  const dwell = await sql`
    WITH ordered AS (
      SELECT session_id, screen, ts,
             lead(ts) OVER (PARTITION BY session_id ORDER BY ts) AS next_ts
      FROM events WHERE name = 'screen_view' AND session_id IS NOT NULL
        AND ts > now() - interval '30 days'
    )
    SELECT screen, round(avg(EXTRACT(EPOCH FROM (next_ts - ts))))::int AS avg_seconds,
           count(*)::int AS samples
    FROM ordered WHERE next_ts IS NOT NULL
    GROUP BY screen ORDER BY samples DESC LIMIT 20`;
  const rageScreens = await sql`
    SELECT screen, count(*)::int AS rage FROM taps
    WHERE is_rage AND ts > now() - interval '30 days' AND screen IS NOT NULL
    GROUP BY screen ORDER BY rage DESC LIMIT 10`;
  return c.json({ dwell, rage_screens: rageScreens });
});
