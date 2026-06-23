import { Hono } from "hono";
import { z } from "zod";
import { sql } from "../db.ts";
import { optionalAuth, type AppUser } from "../auth/middleware.ts";
import { pushLiveEvent } from "../realtime.ts";

export const tapRoutes = new Hono();

const TapSchema = z.object({
  screen: z.string().optional(),
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
  label: z.string().optional(),
  is_rage: z.boolean().optional(),
  is_dead: z.boolean().optional(),
  app_version: z.string().optional(),
  platform: z.string().optional(),
  ts: z.string().optional(),
  device_id: z.string().uuid().optional(),
  session_id: z.string().uuid().optional(),
});
const TapsBatch = z.object({ taps: z.array(TapSchema).max(300) });

tapRoutes.post("/taps", optionalAuth, async (c) => {
  const parsed = TapsBatch.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "payload inválido" }, 400);
  const user = c.get("user") as AppUser | undefined;
  const taps = parsed.data.taps;
  if (taps.length === 0) return c.json({ ok: true, inserted: 0 });

  const rows = taps.map((t) => ({
    user_id: user?.id ?? null,
    device_id: t.device_id ?? null,
    session_id: t.session_id ?? null,
    screen: t.screen ?? null,
    x: t.x,
    y: t.y,
    label: t.label ?? null,
    is_rage: t.is_rage ?? false,
    is_dead: t.is_dead ?? false,
    app_version: t.app_version ?? null,
    platform: t.platform ?? null,
    ts: t.ts ? new Date(t.ts) : new Date(),
  }));

  await sql`INSERT INTO taps ${sql(rows, "user_id", "device_id", "session_id", "screen", "x", "y", "label", "is_rage", "is_dead", "app_version", "platform", "ts")}`;

  // sinaliza rage taps no feed ao vivo
  for (const t of taps) {
    if (t.is_rage) {
      pushLiveEvent({ kind: "rage", screen: t.screen ?? null, name: "rage tap 😡" });
    }
  }
  return c.json({ ok: true, inserted: rows.length });
});
