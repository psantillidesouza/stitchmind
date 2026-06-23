import { Hono } from "hono";
import { z } from "zod";
import { createHash } from "node:crypto";
import { sql } from "../db.ts";
import { optionalAuth, type AppUser } from "../auth/middleware.ts";

export const crashRoutes = new Hono();

const CrashSchema = z.object({
  error_type: z.string().optional(),
  message: z.string().optional(),
  stack_trace: z.string().optional(),
  is_fatal: z.boolean().optional(),
  breadcrumbs: z.array(z.any()).optional(),
  app_version: z.string().optional(),
  platform: z.string().optional(),
  os_version: z.string().optional(),
  device_id: z.string().uuid().optional(),
});

/** Assinatura estável p/ agrupar crashes iguais (tipo + 1ª linha do stack). */
function fingerprint(errorType?: string, stack?: string): string {
  const firstFrame = (stack ?? "").split("\n").find((l) => l.trim().startsWith("#")) ?? "";
  return createHash("sha1")
    .update(`${errorType ?? "Error"}|${firstFrame.trim()}`)
    .digest("hex")
    .slice(0, 16);
}

crashRoutes.post("/", optionalAuth, async (c) => {
  const parsed = CrashSchema.safeParse(await c.req.json().catch(() => ({})));
  if (!parsed.success) return c.json({ error: "payload inválido" }, 400);
  const d = parsed.data;
  const user = c.get("user") as AppUser | undefined;
  const fp = fingerprint(d.error_type, d.stack_trace);

  await sql`
    INSERT INTO crashes (user_id, device_id, app_version, platform, os_version,
                         error_type, message, stack_trace, is_fatal, breadcrumbs, fingerprint)
    VALUES (${user?.id ?? null}, ${d.device_id ?? null}, ${d.app_version ?? null},
            ${d.platform ?? null}, ${d.os_version ?? null}, ${d.error_type ?? null},
            ${d.message ?? null}, ${d.stack_trace ?? null}, ${d.is_fatal ?? false},
            ${JSON.stringify(d.breadcrumbs ?? [])}::jsonb, ${fp})
  `;
  return c.json({ ok: true, fingerprint: fp });
});
