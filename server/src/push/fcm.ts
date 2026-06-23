// Envio de push via Firebase Cloud Messaging (Admin SDK).
//
// Init preguiçoso: só carrega o firebase-admin e a credencial quando o primeiro
// envio acontece. Se não houver service account configurado, o push fica
// desativado (não derruba o servidor) e os endpoints retornam configured=false.
//
// Credencial (qualquer um):
//   • FIREBASE_SERVICE_ACCOUNT       = JSON inteiro do service account
//   • FIREBASE_SERVICE_ACCOUNT_PATH  = caminho do arquivo .json
//   • GOOGLE_APPLICATION_CREDENTIALS = caminho (applicationDefault)

import { env } from "../env.ts";

let messaging: any = null;
let triedInit = false;

function loadServiceAccount(): Record<string, unknown> | null {
  const raw = env.firebase.serviceAccount?.trim();
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (e) {
    console.warn("[fcm] FIREBASE_SERVICE_ACCOUNT não é JSON válido:", (e as Error).message);
    return null;
  }
}

/** Existe alguma fonte REAL de credencial? (sem isso, não dá pra enviar.) */
function hasCredentialSource(): boolean {
  return !!(
    env.firebase.serviceAccount?.trim() ||
    env.firebase.serviceAccountPath?.trim() ||
    Bun.env.GOOGLE_APPLICATION_CREDENTIALS
  );
}

async function ensureInit(): Promise<boolean> {
  if (messaging) return true;
  if (triedInit) return false;
  triedInit = true;
  // Sem credencial explícita não inicializa: o applicationDefault() "inicializa"
  // preguiçosamente mas falha só na hora de enviar (enganoso). Melhor ser claro.
  if (!hasCredentialSource()) {
    console.warn(
      "[fcm] push desativado — defina FIREBASE_SERVICE_ACCOUNT (JSON do service account) no .env.",
    );
    return false;
  }
  try {
    // @ts-ignore — dependência resolvida em runtime (bun install no deploy).
    const mod: any = await import("firebase-admin");
    const admin: any = mod.default ?? mod;
    const sa = loadServiceAccount();
    const path = env.firebase.serviceAccountPath?.trim();

    let credential;
    if (sa) {
      credential = admin.credential.cert(sa);
    } else if (path) {
      credential = admin.credential.cert(path);
    } else {
      credential = admin.credential.applicationDefault();
    }

    const app =
      admin.apps && admin.apps.length
        ? admin.apps[0]
        : admin.initializeApp({
            credential,
            projectId: env.firebase.projectId || undefined,
          });
    messaging = admin.messaging(app);
    console.log("[fcm] Firebase Admin inicializado — push ativo.");
    return true;
  } catch (e) {
    console.warn(
      "[fcm] push desativado (service account ausente/ inválido):",
      (e as Error).message,
    );
    return false;
  }
}

/** Há credencial e o Admin SDK inicializou? (para o painel mostrar o status.) */
export async function isPushConfigured(): Promise<boolean> {
  return ensureInit();
}

export interface PushResult {
  configured: boolean;
  sent: number;
  failed: number;
  invalidTokens: string[];
  error?: string; // motivo da falha (credencial inválida, token, etc.)
}

/** Envia uma notificação para uma lista de FCM tokens (em lotes de 500). */
export async function sendToTokens(
  tokens: string[],
  payload: { title: string; body: string; data?: Record<string, string> },
): Promise<PushResult> {
  const unique = [...new Set(tokens.filter((t) => !!t))];
  const ok = await ensureInit();
  if (!ok) {
    return {
      configured: false,
      sent: 0,
      failed: 0,
      invalidTokens: [],
      error: "Sem service account do Firebase no servidor (FIREBASE_SERVICE_ACCOUNT).",
    };
  }
  if (unique.length === 0) {
    return {
      configured: true,
      sent: 0,
      failed: 0,
      invalidTokens: [],
      error: "Nenhum aparelho com push_token no alvo escolhido.",
    };
  }

  let sent = 0;
  let failed = 0;
  const invalidTokens: string[] = [];
  let firstError: string | undefined;

  // send() individual (HTTP/1.1) em vez de sendEachForMulticast: o multicast
  // usa node:http2, que no Bun é incompleto e estoura NGHTTP2_PROTOCOL_ERROR.
  // Lotes de 25 em paralelo dão vazão suficiente para nossa escala.
  const message = (token: string) => ({
    token,
    notification: { title: payload.title, body: payload.body },
    data: payload.data ?? {},
    apns: { payload: { aps: { sound: "default" } } },
    android: { priority: "high" as const, notification: { sound: "default" } },
  });

  try {
    for (let i = 0; i < unique.length; i += 25) {
      const batch = unique.slice(i, i + 25);
      const results = await Promise.allSettled(
        batch.map((t) => messaging.send(message(t))),
      );
      results.forEach((r, idx) => {
        if (r.status === "fulfilled") {
          sent++;
          return;
        }
        failed++;
        const err: any = r.reason;
        const code: string = err?.errorInfo?.code ?? err?.code ?? "";
        if (!firstError) firstError = err?.message ?? code;
        if (
          code.includes("registration-token-not-registered") ||
          code.includes("invalid-registration-token") ||
          code.includes("invalid-argument")
        ) {
          invalidTokens.push(batch[idx]!);
        }
      });
    }
  } catch (e) {
    // Falha global (ex.: credencial não consegue gerar access token).
    return {
      configured: true,
      sent,
      failed,
      invalidTokens,
      error: (e as Error).message,
    };
  }
  return { configured: true, sent, failed, invalidTokens, error: firstError };
}
