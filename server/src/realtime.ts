import { createBunWebSocket } from "hono/bun";
import type { ServerWebSocket } from "bun";
import Redis from "ioredis";

import { env } from "./env.ts";
import { verifyIdToken } from "./auth/firebase.ts";
import { sql } from "./db.ts";

export const { upgradeWebSocket, websocket } =
  createBunWebSocket<ServerWebSocket>();

// ─── Redis (best-effort: presença sobrevive em memória se cair) ─────
let redis: Redis | null = null;
try {
  redis = new Redis(env.redisUrl, {
    maxRetriesPerRequest: 1,
    enableOfflineQueue: false,
    lazyConnect: false,
  });
  redis.on("error", () => {}); // não derruba o processo
} catch {
  redis = null;
}

// ─── Estado em memória (autoritativo p/ broadcast em instância única) ─
interface AppConn {
  id: string;
  screen: string | null;
  userId: string | null;
  email: string | null;
  platform?: string;
  appVersion?: string;
  since: number;
  lastPing: number;
}

const appConns = new Map<string, AppConn>();
const adminSockets = new Set<{ send: (s: string) => void }>();
// id da conexão associado ao socket bruto
const idBySocket = new WeakMap<object, string>();

function rawOf(ws: any): object {
  return (ws.raw as object) ?? ws;
}

function snapshot() {
  const byScreen: Record<string, number> = {};
  for (const c of appConns.values()) {
    const s = c.screen ?? "—";
    byScreen[s] = (byScreen[s] ?? 0) + 1;
  }
  return { total_online: appConns.size, by_screen: byScreen };
}

export function liveSnapshot() {
  return snapshot();
}

function broadcastPresence() {
  const msg = JSON.stringify({ type: "presence", ...snapshot() });
  for (const ws of adminSockets) {
    try {
      ws.send(msg);
    } catch {}
  }
  redis?.set(`${env.redisPrefix}presence:counts`, JSON.stringify(snapshot()), "EX", 60).catch(() => {});
}

/** Empurra um item para o feed ao vivo dos admins. */
export function pushLiveEvent(item: Record<string, unknown>) {
  const msg = JSON.stringify({ type: "event", ts: new Date().toISOString(), ...item });
  for (const ws of adminSockets) {
    try {
      ws.send(msg);
    } catch {}
  }
}

// Sweep: derruba conexões sem ping há > 30s (app fechou/caiu).
setInterval(() => {
  const now = Date.now();
  let changed = false;
  for (const [id, c] of appConns) {
    if (now - c.lastPing > 30000) {
      appConns.delete(id);
      changed = true;
    }
  }
  if (changed) broadcastPresence();
}, 10000);

// ─── Handler do app ─────────────────────────────────────────────────
export function appWsHandler() {
  return upgradeWebSocket((c) => {
    const token = c.req.query("token");
    return {
      async onOpen(_evt, ws) {
        const id = crypto.randomUUID();
        idBySocket.set(rawOf(ws), id);
        // registra a conexão SÍNCRONO (antes de qualquer await) para que
        // mensagens que cheguem durante a verificação do token não se percam.
        appConns.set(id, {
          id,
          screen: null,
          userId: null,
          email: null,
          since: Date.now(),
          lastPing: Date.now(),
        });
        broadcastPresence();
        // identifica o usuário em background
        if (token) {
          try {
            const v = await verifyIdToken(token);
            const [u] = await sql`SELECT id, email FROM users WHERE firebase_uid = ${v.uid}`;
            const conn = appConns.get(id);
            if (conn) {
              conn.userId = u?.id ?? null;
              conn.email = u?.email ?? v.email ?? null;
            }
          } catch {}
        }
      },
      onMessage(evt, ws) {
        const id = idBySocket.get(rawOf(ws));
        if (!id) return;
        const conn = appConns.get(id);
        if (!conn) return;
        conn.lastPing = Date.now();
        let msg: any;
        try {
          msg = JSON.parse(String(evt.data));
        } catch {
          return;
        }
        if (msg.type === "screen" && typeof msg.name === "string") {
          conn.screen = msg.name;
          conn.platform = msg.platform ?? conn.platform;
          conn.appVersion = msg.app_version ?? conn.appVersion;
          broadcastPresence();
          pushLiveEvent({
            kind: "screen",
            screen: msg.name,
            user: conn.email ?? "anônimo",
          });
        } else if (msg.type === "event") {
          pushLiveEvent({
            kind: "action",
            name: msg.name,
            screen: conn.screen,
            user: conn.email ?? "anônimo",
          });
        }
        // ping apenas renova lastPing (já feito acima)
      },
      onClose(_evt, ws) {
        const id = idBySocket.get(rawOf(ws));
        if (id && appConns.delete(id)) broadcastPresence();
      },
    };
  });
}

// ─── Handler do admin ───────────────────────────────────────────────
export function adminWsHandler() {
  return upgradeWebSocket((c) => {
    const token = c.req.query("token");
    return {
      async onOpen(_evt, ws) {
        // valida admin
        let ok = false;
        if (token) {
          try {
            const v = await verifyIdToken(token);
            const [u] = await sql`SELECT role FROM users WHERE firebase_uid = ${v.uid}`;
            ok = u?.role === "admin";
          } catch {}
        }
        if (!ok) {
          try {
            ws.send(JSON.stringify({ type: "error", error: "não autorizado" }));
            ws.close(1008, "unauthorized");
          } catch {}
          return;
        }
        adminSockets.add(ws as any);
        // snapshot inicial
        ws.send(JSON.stringify({ type: "presence", ...snapshot() }));
      },
      onClose(_evt, ws) {
        adminSockets.delete(ws as any);
      },
    };
  });
}
