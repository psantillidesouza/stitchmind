import { readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import http from "node:http";

import { Hono } from "hono";
import { cors } from "hono/cors";

import { env } from "./env.ts";
import { sql, runMigrations, waitForDb } from "./db.ts";
import { ensureBuckets } from "./storage.ts";

import { authRoutes } from "./routes/auth.ts";
import { lessonRoutes } from "./routes/lessons.ts";
import { adminRoutes } from "./routes/admin.ts";
import { telemetryRoutes } from "./routes/telemetry.ts";
import { crashRoutes } from "./routes/crashes.ts";
import { tapRoutes } from "./routes/taps.ts";
import { communityRoutes } from "./routes/community.ts";
import { chatRoutes } from "./routes/chat.ts";
import { aiRoutes } from "./routes/ai.ts";
import { patternRoutes } from "./routes/patterns.ts";
import { reviewRoutes } from "./routes/reviews.ts";
import { subscriptionRoutes } from "./routes/subscription.ts";
import {
  websocket,
  appWsHandler,
  adminWsHandler,
  liveSnapshot,
} from "./realtime.ts";
import { requireAdmin } from "./auth/middleware.ts";
import { startNotificationScheduler } from "./push/scheduler.ts";

const PUBLIC_DIR = join(dirname(fileURLToPath(import.meta.url)), "..", "public");

// ─── Boot ───────────────────────────────────────────────────────────
await waitForDb();
if (env.runMigrations) await runMigrations();
await ensureBuckets();
startNotificationScheduler();

const app = new Hono();
// CORS em tudo, MENOS no /blog: o middleware pós-processa/clona a resposta e
// estava quebrando o 302 do POST de login do WordPress (virava 200 vazio).
// O WordPress é servido por proxy e não precisa do CORS do app.
const corsMw = cors();
app.use("*", (c, next) =>
  c.req.path.startsWith("/blog") ? next() : corsMw(c, next));

app.get("/health", async (c) => {
  let db = "ok";
  try {
    await sql`SELECT 1`;
  } catch {
    db = "down";
  }
  // Enxuto: não expõe provider/modelos/config publicamente.
  return c.json({ ok: true, db });
});

// ─── API v1 ─────────────────────────────────────────────────────────
const v1 = new Hono();
v1.route("/auth", authRoutes);
v1.route("/", lessonRoutes); // /courses, /lessons, /lessons/:id/progress
v1.route("/", telemetryRoutes); // /devices, /sessions, /events
v1.route("/", tapRoutes); // /taps
v1.route("/", communityRoutes); // /tips, /posts
v1.route("/", chatRoutes); // /chat
v1.route("/crashes", crashRoutes);
v1.route("/", aiRoutes); // /analyze, /feedback
v1.route("/", patternRoutes); // /patterns/import
v1.route("/", reviewRoutes); // /reviews (App Store + Google Play)
v1.route("/", subscriptionRoutes); // /subscription/sync, /revenuecat/webhook
v1.route("/admin", adminRoutes);

// WebSocket: presença em tempo real
v1.get("/rt/app", appWsHandler());
v1.get("/rt/admin", adminWsHandler());
// snapshot REST (só admin — evita vazar presença publicamente)
v1.get("/live", requireAdmin, (c) => c.json(liveSnapshot()));

// API pública em /api (oficial) + /v1 (compat com o app atual)
app.route("/api", v1);
app.route("/v1", v1);

// Compat: endpoints antigos do app atual (sem prefixo)
app.route("/", aiRoutes); // /analyze, /feedback continuam funcionando

// ─── Páginas web (estáticas) ────────────────────────────────────────
async function serveFile(path: string, type: string, c: any) {
  try {
    const content = await readFile(join(PUBLIC_DIR, path), "utf-8");
    return c.body(content, 200, { "Content-Type": type });
  } catch {
    return c.text("not found", 404);
  }
}
const html = (p: string) => (c: any) => serveFile(p, "text/html; charset=utf-8", c);

// Servir binários (imagens) de public/
async function serveBinary(path: string, type: string, c: any) {
  try {
    const content = await readFile(join(PUBLIC_DIR, path));
    return c.body(content, 200, {
      "Content-Type": type,
      "Cache-Control": "public, max-age=86400",
    });
  } catch {
    return c.text("not found", 404);
  }
}

// Imagens ilustrativas das aulas (passo a passo + capa), servidas de
// public/lessons/<aula>/<arquivo>.png. Nomes restritos por segurança.
app.get("/lessons/:dir/:file", (c) => {
  const dir = c.req.param("dir");
  const file = c.req.param("file");
  if (!/^[\w-]+$/.test(dir) || !/^[\w.-]+\.png$/.test(file)) {
    return c.text("not found", 404);
  }
  return serveBinary(`lessons/${dir}/${file}`, "image/png", c);
});

// Imagens do site (homepage de marketing) — public/img/<arquivo>.
app.get("/img/:file", (c) => {
  const file = c.req.param("file");
  if (!/^[\w.-]+\.(png|jpe?g|webp|svg)$/i.test(file)) {
    return c.text("not found", 404);
  }
  const ext = file.split(".").pop()!.toLowerCase();
  const mime =
    ext === "svg" ? "image/svg+xml"
    : ext === "webp" ? "image/webp"
    : ext === "jpg" || ext === "jpeg" ? "image/jpeg"
    : "image/png";
  return serveBinary(`img/${file}`, mime, c);
});

// ── Blog WordPress em /blog ─────────────────────────────────────────
// Reverse-proxy interno: o app já recebe o tráfego de stitchmindapp.com (via
// o Caddy compartilhado), então servimos o WordPress sob /blog SEM tocar no
// proxy compartilhado nem em outras pastas. Tira o prefixo /blog e repassa
// pro container sm-blog-wp (que tem WP_HOME=/blog).
// Usa node:http (não o fetch): o fetch do Bun com redirect:"manual" transforma
// o 302 de um POST em "opaque redirect" (status 0 → vira 200 vazio), o que
// quebrava o login do WordPress. Com http.request temos o 302 real, todos os
// headers e os múltiplos Set-Cookie (array) preservados.
async function proxyBlog(c: any) {
  const url = new URL(c.req.url);
  let path = url.pathname.replace(/^\/blog/, ""); // /blog/x → /x ; /blog → ""
  if (path === "") path = "/";

  const reqHeaders: Record<string, string> = {};
  c.req.raw.headers.forEach((v: string, k: string) => {
    const lk = k.toLowerCase();
    if (lk === "host" || lk === "accept-encoding") return;
    reqHeaders[k] = v;
  });
  reqHeaders["x-forwarded-proto"] = "https";
  reqHeaders["x-forwarded-host"] = url.host;

  const method = c.req.method;
  let body: Buffer | null = null;
  try {
    body =
      method === "GET" || method === "HEAD"
        ? null
        : Buffer.from(await c.req.raw.arrayBuffer());
  } catch (e) {
    console.error("[blog] body read error", (e as Error).message);
  }

  return await new Promise<Response>((resolve) => {
    const upstream = http.request(
      { host: "sm-blog-wp", port: 80, method, path: path + url.search, headers: reqHeaders },
      (res) => {
        const out = new Headers();
        for (const [k, v] of Object.entries(res.headers)) {
          const lk = k.toLowerCase();
          if (lk === "set-cookie" || lk === "content-encoding" ||
              lk === "content-length" || lk === "transfer-encoding") continue;
          if (Array.isArray(v)) v.forEach((vv) => out.append(k, vv));
          else if (v != null) out.set(k, String(v));
        }
        const sc = res.headers["set-cookie"]; // array de cookies individuais
        if (Array.isArray(sc)) for (const ck of sc) out.append("set-cookie", ck);
        else if (sc) out.append("set-cookie", sc as string);
        const chunks: Buffer[] = [];
        res.on("data", (d) => chunks.push(d as Buffer));
        res.on("end", () =>
          resolve(new Response(Buffer.concat(chunks), { status: res.statusCode ?? 502, headers: out })),
        );
      },
    );
    upstream.on("error", (e) => {
      console.error("[blog] upstream error", (e as Error).message);
      resolve(c.text("Blog temporariamente indisponível.", 502));
    });
    if (body) upstream.write(body);
    upstream.end();
  });
}
app.get("/blog", (c) => c.redirect("/blog/", 301));
app.all("/blog/*", proxyBlog);

// Home (padrão) + páginas legais
app.get("/", html("home.html"));
app.get("/privacidade", html("privacidade.html"));
app.get("/termos", html("termos.html"));

// Link de convite: sempre serve a página (ícone + animações). O redirect é
// feito no client — iOS abre a App Store após 2s; Android/desktop ficam na
// página (Play Store desativada por enquanto / botão "coming soon").
app.get("/invite", (c) => {
  return serveFile("invite.html", "text/html; charset=utf-8", c);
});

// Quiz funnel de aquisição: 5 perguntas (estética do /invite) → redireciona
// pro /invite no fim, que abre a loja certa por dispositivo.
app.get("/quiz-download", html("quiz-download.html"));
// Variações A/B do funil (cada uma marca quiz_variant no GA): ângulo + visual
// + formato diferentes. Todas redirecionam pro /invite no fim.
app.get("/quiz-pattern", html("quiz-pattern.html"));   // IA foto→padrão · 3Q · berry
app.get("/quiz-beginner", html("quiz-beginner.html")); // do zero · 5Q · sage
app.get("/quiz-count", html("quiz-count.html"));       // contador · 7Q · teal
app.get("/quiz-project", html("quiz-project.html"));   // próximo projeto · 5Q+insight · ochre
app.get("/quiz-gift", html("quiz-gift.html"));         // presente/relaxar · 3Q+depoimentos · rose

// Painel admin
app.get("/admin", html("admin/index.html"));
app.get("/admin/app.js", (c) => serveFile("admin/app.js", "text/javascript", c));
app.get("/admin/styles.css", (c) => serveFile("admin/styles.css", "text/css", c));
// Config pública do Firebase web (apiKey é público; só funciona p/ contas válidas).
app.get("/admin/firebase-config", (c) =>
  c.json({
    apiKey: env.firebase.webApiKey || null,
    authDomain: env.firebase.projectId ? `${env.firebase.projectId}.firebaseapp.com` : null,
    projectId: env.firebase.projectId || null,
  }),
);

console.log(
  `🧶 StitchMind API on :${env.port} · provider=${env.gemini.apiKey ? "gemini" : "none"} · ` +
    `auth=${env.firebase.projectId ? "firebase" : "dev"} (dev=${env.firebase.devMode})`,
);

export default { port: env.port, fetch: app.fetch, websocket };
