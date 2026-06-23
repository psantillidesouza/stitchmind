import { Hono } from "hono";
import { sql } from "../db.ts";
import { requireAuth, type AppUser } from "../auth/middleware.ts";
import { rateLimit } from "../rateLimit.ts";
import {
  extractFromText,
  extractFromImage,
  extractFromPdf,
  type ExtractResult,
} from "../patternExtractor.ts";

export const patternRoutes = new Hono();

// Mapeia uma linha da tabela `patterns` para o contrato que o app espera
// (Pattern.fromJson): sections já vem como JSON do Postgres.
function patternJson(r: Record<string, unknown>) {
  return {
    id: r.id,
    name: r.name,
    author: r.author,
    technique: r.technique,
    difficulty: r.difficulty,
    yarn_requirement: r.yarn_requirement,
    estimated_hours: r.estimated_hours,
    suggested_needle: r.suggested_needle,
    description: r.description,
    sections: r.sections ?? [],
  };
}

// ─── Biblioteca de receitas (curada, servida do banco) ──────────────
// Público: o app baixa a lista e segue carreira-a-carreira.
patternRoutes.get("/patterns", async (c) => {
  const rows = await sql`
    SELECT id, name, author, technique, difficulty, yarn_requirement,
           estimated_hours, suggested_needle, description, sections
    FROM patterns
    WHERE status = 'published'
    ORDER BY order_index, created_at`;
  return c.json({ patterns: rows.map(patternJson) });
});

const MAX_TEXT = 20_000;
const MAX_FILE_MB = 15;
const ACCEPTED_IMAGE = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
]);

// Importa uma receita: texto colado, link, foto ou PDF.
// Custo de IA → rate limit (mais apertado que o analyze).
patternRoutes.post(
  "/patterns/import",
  requireAuth,
  rateLimit({
    max: 6,
    windowMs: 60_000,
    prefix: "pattern_import",
    keyFn: (c) => `u:${(c.get("user") as AppUser).id}`,
  }),
  async (c) => {
    const contentType = c.req.header("content-type") ?? "";
    try {
      const result = contentType.includes("multipart/form-data")
        ? await importFile(c)
        : await importJson(c);
      if ("error" in result) return c.json({ error: result.error }, result.status);
      const { pattern, model, latencyMs } = result.ok;
      return c.json({ pattern, model, latency_ms: latencyMs });
    } catch (err) {
      console.error("[patterns/import] erro", err);
      return c.json(
        { error: (err as Error).message ?? "Falha ao importar receita." },
        500,
      );
    }
  },
);

type Outcome =
  | { ok: ExtractResult }
  | { error: string; status: 400 | 413 | 415 | 422 };

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function importJson(c: any): Promise<Outcome> {
  const body = await c.req.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return { error: "Esperado JSON com 'text' ou 'url'.", status: 400 };
  }
  let text: string | null = null;
  if (typeof body.text === "string" && body.text.trim()) {
    text = body.text.trim();
  } else if (typeof body.url === "string" && body.url.trim()) {
    try {
      text = await fetchAsText(body.url.trim());
    } catch (err) {
      return { error: `Não consegui ler o link: ${(err as Error).message}`, status: 422 };
    }
  }
  if (!text) return { error: "Forneça 'text' (cola) ou 'url' (link).", status: 400 };
  if (text.length > MAX_TEXT) text = text.slice(0, MAX_TEXT);
  return { ok: await extractFromText(text) };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
async function importFile(c: any): Promise<Outcome> {
  let form: FormData;
  try {
    form = await c.req.formData();
  } catch {
    return { error: "multipart inválido.", status: 400 };
  }
  const file = form.get("file") ?? form.get("image");
  if (!(file instanceof File)) return { error: "Campo 'file' ausente.", status: 400 };
  if (file.size > MAX_FILE_MB * 1024 * 1024) {
    return { error: `Arquivo maior que ${MAX_FILE_MB}MB.`, status: 413 };
  }

  let mime = file.type.toLowerCase();
  if (mime === "image/jpg") mime = "image/jpeg";
  const bytes = new Uint8Array(await file.arrayBuffer());

  if (mime === "application/pdf") {
    return { ok: await extractFromPdf(bytes) };
  }
  if (ACCEPTED_IMAGE.has(mime)) {
    return { ok: await extractFromImage(bytes, mime) };
  }
  return { error: `Tipo não suportado: ${mime || "desconhecido"}.`, status: 415 };
}

// Baixa uma página e devolve o texto limpo. Guard básico de SSRF (bloqueia
// hosts locais/privados óbvios). TODO Fase 2: resolução de DNS + allowlist.
async function fetchAsText(rawUrl: string): Promise<string> {
  const u = new URL(rawUrl); // lança se inválido
  if (u.protocol !== "http:" && u.protocol !== "https:") {
    throw new Error("protocolo inválido");
  }
  const host = u.hostname.toLowerCase();
  const blocked =
    host === "localhost" ||
    host === "0.0.0.0" ||
    host.endsWith(".local") ||
    /^127\./.test(host) ||
    /^10\./.test(host) ||
    /^192\.168\./.test(host) ||
    /^169\.254\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host);
  if (blocked) throw new Error("host não permitido");

  const res = await fetch(u, {
    headers: { "user-agent": "StitchMind/1.0 (pattern-import)" },
    signal: AbortSignal.timeout(15_000),
    redirect: "follow",
  });
  if (!res.ok) throw new Error(`status ${res.status}`);

  const html = await res.text();
  const stripped = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/\s+/g, " ")
    .trim();
  if (!stripped) throw new Error("página vazia");
  return stripped.slice(0, MAX_TEXT);
}
