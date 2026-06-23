import type { Context, Next } from "hono";

// Rate limit em memória (instância única). Janela deslizante por chave.
const buckets = new Map<string, number[]>();

// Limpeza periódica para não vazar memória.
setInterval(() => {
  const now = Date.now();
  for (const [k, arr] of buckets) {
    const live = arr.filter((t) => now - t < 600_000);
    if (live.length === 0) buckets.delete(k);
    else buckets.set(k, live);
  }
}, 120_000);

function clientIp(c: Context): string {
  // O proxy reverso (Caddy) ANEXA o IP real do cliente ao FIM do
  // X-Forwarded-For. Pegar o primeiro valor é inseguro — o cliente pode
  // forjá-lo e furar o rate limit. Usamos o último, escrito pelo nosso proxy.
  const xff = c.req.header("x-forwarded-for");
  if (xff) {
    const parts = xff.split(",").map((s) => s.trim()).filter(Boolean);
    if (parts.length) return parts[parts.length - 1];
  }
  return c.req.header("x-real-ip") ?? "unknown";
}

function take(key: string, max: number, windowMs: number): boolean {
  const now = Date.now();
  const arr = (buckets.get(key) ?? []).filter((t) => now - t < windowMs);
  if (arr.length >= max) {
    buckets.set(key, arr);
    return false; // bloqueado
  }
  arr.push(now);
  buckets.set(key, arr);
  return true;
}

/**
 * Middleware de rate limit por IP (e prefixo opcional).
 *
 * Use `keyFn` para limitar por usuário autenticado (mais robusto que IP, que
 * pode ser rotacionado). Quando `keyFn` devolve algo, ele é usado como chave;
 * senão cai no IP do cliente. Coloque `keyFn` depois do middleware de auth.
 */
export function rateLimit(opts: {
  max: number;
  windowMs: number;
  prefix?: string;
  keyFn?: (c: Context) => string | undefined;
}) {
  return async (c: Context, next: Next) => {
    const custom = opts.keyFn?.(c);
    const key = `${opts.prefix ?? "rl"}:${custom ?? clientIp(c)}`;
    if (!take(key, opts.max, opts.windowMs)) {
      return c.json(
        { error: "Muitas requisições. Tente novamente em instantes." },
        429,
      );
    }
    await next();
  };
}
