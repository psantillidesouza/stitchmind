import { Hono } from "hono";
import { AnalysisCore, FeedbackPayload } from "../schemas.ts";
import { getProvider } from "../providers.ts";
import { sql } from "../db.ts";
import { env } from "../env.ts";
import { optionalAuth, type AppUser } from "../auth/middleware.ts";
import { rateLimit } from "../rateLimit.ts";

export const aiRoutes = new Hono();

const ACCEPTED_MIME = new Set(["image/jpeg", "image/jpg", "image/png", "image/webp"]);

// Anti-abuso de custo (IA de visão): 8/min. optionalAuth ANTES do rateLimit
// para podermos limitar por usuário (mais robusto que IP, que é rotacionável);
// anônimos caem no IP real (último valor do X-Forwarded-For).
aiRoutes.post(
  "/analyze",
  optionalAuth,
  rateLimit({
    max: 8,
    windowMs: 60_000,
    prefix: "analyze",
    keyFn: (c) => {
      const u = c.get("user") as AppUser | undefined;
      return u ? `u:${u.id}` : undefined;
    },
  }),
  async (c) => {
  let formData: FormData;
  try {
    formData = await c.req.formData();
  } catch {
    return c.json({ error: "Esperado multipart/form-data com campo 'image'." }, 400);
  }
  const file = formData.get("image");
  if (!(file instanceof File)) return c.json({ error: "Campo 'image' ausente." }, 400);
  if (file.size > env.ai.maxImageMb * 1024 * 1024) {
    return c.json({ error: `Imagem maior que ${env.ai.maxImageMb}MB.` }, 413);
  }
  let mime = file.type.toLowerCase();
  if (mime === "image/jpg") mime = "image/jpeg";
  if (!ACCEPTED_MIME.has(mime)) return c.json({ error: `Tipo não suportado: ${mime}.` }, 415);

  const bytes = new Uint8Array(await file.arrayBuffer());
  const user = c.get("user") as AppUser | undefined;

  try {
    const provider = getProvider();
    const result = await provider.analyze(bytes, mime);
    const core = AnalysisCore.parse(result.raw);

    const [row] = await sql`
      INSERT INTO analyses (user_id, provider, model, latency_ms, result)
      VALUES (${user?.id ?? null}, ${result.provider}, ${result.model},
              ${result.latencyMs}, ${JSON.stringify(core)}::jsonb)
      RETURNING id`;

    return c.json({
      ...core,
      provider: result.provider,
      model: result.model,
      latency_ms: result.latencyMs,
      analysis_id: row.id,
    });
  } catch (err) {
    console.error("[analyze] erro", err);
    return c.json({ error: (err as Error).message ?? "Falha ao analisar imagem." }, 500);
  }
});

aiRoutes.post("/feedback", optionalAuth, async (c) => {
  const body = await c.req.json().catch(() => null);
  const parsed = FeedbackPayload.safeParse(body);
  if (!parsed.success) {
    return c.json({ error: "Payload inválido.", details: parsed.error.flatten() }, 400);
  }
  const user = c.get("user") as AppUser | undefined;
  const d = parsed.data;
  await sql`
    INSERT INTO feedback (analysis_id, user_id, section, rating, note)
    VALUES (${d.analysis_id}, ${user?.id ?? null}, ${d.section}, ${d.rating}, ${d.note ?? null})
  `.catch(async () => {
    // se o analysis_id não existir como uuid (legado), grava sem FK
    await sql`
      INSERT INTO feedback (user_id, section, rating, note)
      VALUES (${user?.id ?? null}, ${d.section}, ${d.rating}, ${d.note ?? null})`;
  });
  return c.json({ ok: true });
});
