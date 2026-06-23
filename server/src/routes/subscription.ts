import { Hono } from "hono";
import { sql } from "../db.ts";
import { requireAuth, type AppUser } from "../auth/middleware.ts";
import { env } from "../env.ts";

export const subscriptionRoutes = new Hono();

// Estado atual gravado no banco (usado quando não dá pra verificar no RC).
async function currentState(userId: string) {
  const [u] = await sql`
    SELECT is_premium, premium_product FROM users WHERE id = ${userId}`;
  return {
    is_premium: u?.is_premium ?? false,
    product: u?.premium_product ?? null,
    verified: false,
  };
}

// ─── App pede sincronização da assinatura ───────────────────────────────
// IMPORTANTE: NÃO confia no corpo enviado pelo cliente (qualquer um poderia
// mandar {is_premium:true}). Consulta o RevenueCat server-side (fonte de
// verdade) usando o UID do Firebase como app_user_id e grava o resultado.
// Sem REVENUECAT_API_KEY configurada, /sync é somente-leitura.
subscriptionRoutes.post("/subscription/sync", requireAuth, async (c) => {
  const user = c.get("user") as AppUser;
  const apiKey = env.revenueCatApiKey;

  if (!apiKey) return c.json(await currentState(user.id));

  const appUserId = user.firebase_uid;
  if (!appUserId) return c.json(await currentState(user.id));

  let active = false;
  let product: string | null = null;
  try {
    const resp = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      {
        headers: { Authorization: `Bearer ${apiKey}` },
        signal: AbortSignal.timeout(10_000),
      },
    );
    if (!resp.ok) return c.json(await currentState(user.id));

    const data = (await resp.json()) as {
      subscriber?: {
        entitlements?: Record<
          string,
          { expires_date: string | null; product_identifier?: string }
        >;
      };
    };
    const ents = data.subscriber?.entitlements ?? {};
    const now = Date.now();
    for (const ent of Object.values(ents)) {
      const exp = ent.expires_date;
      // expires_date null = vitalício; data futura = ativo.
      if (exp === null || (exp && new Date(exp).getTime() > now)) {
        active = true;
        product = ent.product_identifier ?? null;
        break;
      }
    }
  } catch (err) {
    console.error("[subscription/sync] RevenueCat erro", err);
    return c.json(await currentState(user.id));
  }

  const [u] = await sql`
    UPDATE users
    SET is_premium = ${active},
        premium_product = ${product},
        premium_updated_at = now(),
        updated_at = now()
    WHERE id = ${user.id}
    RETURNING is_premium, premium_product`;
  return c.json({ is_premium: u.is_premium, product: u.premium_product, verified: true });
});

// ─── Webhook do RevenueCat (fonte autoritativa) ─────────────────────────
// Configurar no painel RevenueCat → Webhooks:
//   URL: https://SEU_HOST/v1/revenuecat/webhook
//   Authorization: <valor de REVENUECAT_WEBHOOK_AUTH>
// O app_user_id é o UID do Firebase (definido via Purchases.logIn no app).
const GRANT = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "PRODUCT_CHANGE",
]);
// CANCELLATION = desligou a renovação, mas mantém acesso até expirar.
const REVOKE = new Set(["EXPIRATION"]);

subscriptionRoutes.post("/revenuecat/webhook", async (c) => {
  // Fail-closed: sem o segredo configurado (REVENUECAT_WEBHOOK_AUTH), recusa
  // tudo — evita que qualquer um conceda premium forjando um app_user_id.
  const secret = env.revenueCatWebhookAuth;
  const auth = c.req.header("Authorization") ?? "";
  if (!secret || auth !== secret) {
    return c.json({ error: "unauthorized" }, 401);
  }
  const body = (await c.req.json().catch(() => ({}))) as {
    event?: { app_user_id?: string; type?: string; product_id?: string };
  };
  const event = body.event ?? {};
  const appUserId = event.app_user_id;
  const type = event.type ?? "";
  if (!appUserId) return c.json({ ok: true });

  let premium: boolean | null = null;
  if (GRANT.has(type)) premium = true;
  else if (REVOKE.has(type)) premium = false;
  if (premium === null) return c.json({ ok: true }); // evento irrelevante

  await sql`
    UPDATE users
    SET is_premium = ${premium},
        premium_product = ${event.product_id ?? null},
        premium_updated_at = now(),
        updated_at = now()
    WHERE firebase_uid = ${appUserId}`;
  return c.json({ ok: true });
});
