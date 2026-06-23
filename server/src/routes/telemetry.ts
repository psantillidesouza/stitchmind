import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { optionalAuth, type AppUser } from "../auth/middleware.ts";
import { pushLiveEvent } from "../realtime.ts";

export const telemetryRoutes = new Hono();

// ─── Devices ────────────────────────────────────────────────────────

const DeviceSchema = z.object({
  platform: z.enum(["ios", "android", "web"]).optional(),
  model: z.string().optional(),
  os_version: z.string().optional(),
  app_version: z.string().optional(),
  push_token: z.string().optional(),
  country: z.string().max(8).optional(), // país/região (ex.: "BR") p/ segmentar push
  device_id: z.string().uuid().optional(), // se já registrado
});

telemetryRoutes.post("/devices/register", optionalAuth, async (c) => {
  const body = DeviceSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!body.success) return c.json({ error: "payload inválido" }, 400);
  const d = body.data;
  const user = c.get("user") as AppUser | undefined;

  if (d.device_id) {
    const [row] = await sql`
      UPDATE devices SET
        user_id = COALESCE(${user?.id ?? null}, user_id),
        platform = COALESCE(${d.platform ?? null}, platform),
        model = COALESCE(${d.model ?? null}, model),
        os_version = COALESCE(${d.os_version ?? null}, os_version),
        app_version = COALESCE(${d.app_version ?? null}, app_version),
        push_token = COALESCE(${d.push_token ?? null}, push_token),
        country = COALESCE(${d.country ?? null}, country),
        last_seen_at = now()
      WHERE id = ${d.device_id}
      RETURNING id
    `;
    if (row) return c.json({ device_id: row.id });
  }

  const [row] = await sql`
    INSERT INTO devices (user_id, platform, model, os_version, app_version, push_token, country)
    VALUES (${user?.id ?? null}, ${d.platform ?? null}, ${d.model ?? null},
            ${d.os_version ?? null}, ${d.app_version ?? null}, ${d.push_token ?? null},
            ${d.country ?? null})
    RETURNING id
  `;
  return c.json({ device_id: row.id });
});

// ─── Sessões ────────────────────────────────────────────────────────

telemetryRoutes.post("/sessions/start", optionalAuth, async (c) => {
  const body = await c.req.json().catch(() => ({}));
  const user = c.get("user") as AppUser | undefined;
  const [row] = await sql`
    INSERT INTO app_sessions (user_id, device_id, app_version, platform)
    VALUES (${user?.id ?? null}, ${body.device_id ?? null},
            ${body.app_version ?? null}, ${body.platform ?? null})
    RETURNING id
  `;
  return c.json({ session_id: row.id });
});

telemetryRoutes.post("/sessions/end", optionalAuth, async (c) => {
  const body = await c.req.json().catch(() => ({}));
  if (!body.session_id) return c.json({ error: "session_id obrigatório" }, 400);
  await sql`
    UPDATE app_sessions
    SET ended_at = now(),
        duration_s = EXTRACT(EPOCH FROM (now() - started_at))::int
    WHERE id = ${body.session_id}
  `;
  return c.json({ ok: true });
});

// ─── Eventos (batch) ────────────────────────────────────────────────

const EventSchema = z.object({
  name: z.string().min(1),
  screen: z.string().optional(),
  props: z.record(z.any()).optional(),
  app_version: z.string().optional(),
  platform: z.string().optional(),
  ts: z.string().optional(),
  device_id: z.string().uuid().optional(),
  session_id: z.string().uuid().optional(),
});
const EventsBatch = z.object({ events: z.array(EventSchema).max(200) });

telemetryRoutes.post("/events", optionalAuth, async (c) => {
  const parsed = EventsBatch.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "payload inválido" }, 400);
  const user = c.get("user") as AppUser | undefined;
  const evs = parsed.data.events;
  if (evs.length === 0) return c.json({ ok: true, inserted: 0 });

  const rows = evs.map((e) => ({
    user_id: user?.id ?? null,
    device_id: e.device_id ?? null,
    session_id: e.session_id ?? null,
    name: e.name,
    screen: e.screen ?? null,
    props: e.props ?? {},
    app_version: e.app_version ?? null,
    platform: e.platform ?? null,
    ts: e.ts ? new Date(e.ts) : new Date(),
  }));

  await sql`INSERT INTO events ${sql(rows, "user_id", "device_id", "session_id", "name", "screen", "props", "app_version", "platform", "ts")}`;

  // alimenta o feed ao vivo (eventos custom, não os screen_view repetidos)
  for (const e of evs) {
    if (e.name !== "screen_view") {
      pushLiveEvent({ kind: "action", name: e.name, screen: e.screen ?? null });
    }
  }
  return c.json({ ok: true, inserted: rows.length });
});
