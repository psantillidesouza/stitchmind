// Scheduler de notificações agendadas/recorrentes.
//
// Loop a cada 60s: pega agendamentos vencidos (next_run_at <= now), faz claim
// atômico (UPDATE … RETURNING) para nunca disparar duplicado, resolve a
// mensagem (sorteio da notification_pool quando use_pool), envia via FCM,
// grava no histórico (notifications) e calcula a próxima execução.
//
// Fusos: time_of_day/days_of_week são interpretados no fuso do agendamento
// (default America/Sao_Paulo) e convertidos para UTC via Intl.

import { sql } from "../db.ts";
import { sendToTokens } from "./fcm.ts";

// ─── Fuso horário ───────────────────────────────────────────────────

interface TzParts { y: number; mo: number; d: number; h: number; mi: number; dow: number }

const DOW: Record<string, number> = {
  Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
};

function partsInTz(at: Date, tz: string): TzParts {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz, hourCycle: "h23", weekday: "short",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit",
  });
  const p: Record<string, string> = {};
  for (const part of dtf.formatToParts(at)) {
    if (part.type !== "literal") p[part.type] = part.value;
  }
  return {
    y: +p.year!, mo: +p.month!, d: +p.day!,
    h: +p.hour!, mi: +p.minute!, dow: DOW[p.weekday!] ?? 0,
  };
}

function tzOffsetMs(tz: string, at: Date): number {
  const p = partsInTz(at, tz);
  const asUtc = Date.UTC(p.y, p.mo - 1, p.d, p.h, p.mi, 0);
  // arredonda ao minuto para evitar deriva por segundos
  const atMin = Math.floor(at.getTime() / 60000) * 60000;
  return asUtc - atMin;
}

/** Converte "y-mo-d hh:mi" no fuso tz para um instante UTC. */
function zonedToUtc(y: number, mo: number, d: number, h: number, mi: number, tz: string): Date {
  const guess = Date.UTC(y, mo - 1, d, h, mi);
  let res = new Date(guess - tzOffsetMs(tz, new Date(guess)));
  res = new Date(guess - tzOffsetMs(tz, res)); // 2ª passada (bordas de DST)
  return res;
}

// ─── Próxima execução ───────────────────────────────────────────────

export interface ScheduleRow {
  schedule_kind: string;
  send_at: string | Date | null;
  time_of_day: string | null;
  days_of_week: number[] | null;
  interval_minutes: number | null;
  timezone: string | null;
}

/** Calcula o próximo disparo a partir de `after` (default agora). */
export function computeNextRun(row: ScheduleRow, after = new Date()): Date | null {
  const tz = row.timezone || "America/Sao_Paulo";

  if (row.schedule_kind === "once") {
    return row.send_at ? new Date(row.send_at) : null;
  }
  if (row.schedule_kind === "interval") {
    const mins = Math.max(1, row.interval_minutes ?? 60);
    return new Date(after.getTime() + mins * 60_000);
  }
  // daily / weekly: caminha até 8 dias procurando o próximo horário válido.
  const [hh = 12, mi = 0] = String(row.time_of_day ?? "12:00").split(":").map(Number);
  for (let i = 0; i < 8; i++) {
    const probe = new Date(after.getTime() + i * 86_400_000);
    const p = partsInTz(probe, tz);
    if (row.schedule_kind === "weekly") {
      const days = row.days_of_week ?? [];
      if (days.length > 0 && !days.includes(p.dow)) continue;
    }
    const candidate = zonedToUtc(p.y, p.mo, p.d, hh, mi, tz);
    if (candidate.getTime() > after.getTime() + 1000) return candidate;
  }
  return null;
}

// ─── Alvo → tokens ──────────────────────────────────────────────────

export async function resolveTargetTokens(
  targetType: string,
  targetValue?: string | null,
): Promise<string[]> {
  let rows: { push_token: string }[];
  if (targetType === "user" && targetValue) {
    rows = await sql`
      SELECT push_token FROM devices
      WHERE user_id = ${targetValue} AND push_token IS NOT NULL`;
  } else if (targetType === "region" && targetValue) {
    rows = await sql`
      SELECT push_token FROM devices
      WHERE country = ${targetValue} AND push_token IS NOT NULL`;
  } else {
    rows = await sql`SELECT push_token FROM devices WHERE push_token IS NOT NULL`;
  }
  return rows.map((r) => r.push_token);
}

/** Sorteia uma mensagem ativa da lista (null se a lista estiver vazia). */
export async function randomPoolMessage(): Promise<{ title: string; body: string } | null> {
  const [msg] = await sql`
    SELECT title, body FROM notification_pool
    WHERE enabled ORDER BY random() LIMIT 1`;
  return msg ? { title: msg.title, body: msg.body } : null;
}

// ─── Disparo ────────────────────────────────────────────────────────

async function fire(row: any): Promise<void> {
  let title: string | null = row.title;
  let body: string | null = row.body;
  if (row.use_pool) {
    const msg = await randomPoolMessage();
    if (msg) {
      title = msg.title;
      body = msg.body;
    }
  }

  let sent = 0;
  if (title && body) {
    const tokens = await resolveTargetTokens(row.target_type, row.target_value);
    const result = await sendToTokens(tokens, {
      title, body, data: { source: "scheduled" },
    });
    sent = result.sent;
    if (result.invalidTokens.length) {
      await sql`
        UPDATE devices SET push_token = NULL
        WHERE push_token = ANY(${result.invalidTokens})`.catch(() => {});
    }
    if (result.error) {
      console.warn(`[sched] envio "${title}" com erro:`, result.error);
    }
  } else {
    console.warn("[sched] agendamento sem mensagem (lista vazia?) — pulando envio.");
  }

  await sql`
    INSERT INTO notifications (title, body, target_type, target_value, sent_count, scheduled_id, created_by)
    VALUES (${title ?? "(lista vazia)"}, ${body ?? ""}, ${row.target_type},
            ${row.target_value ?? null}, ${sent}, ${row.id}, ${row.created_by ?? null})
  `.catch(() => {});

  const isOnce = row.schedule_kind === "once";
  const next = isOnce ? null : computeNextRun(row);
  await sql`
    UPDATE scheduled_notifications SET
      last_sent_at = now(),
      next_run_at = ${next},
      enabled = ${isOnce ? false : row.enabled}
    WHERE id = ${row.id}`;
  console.log(
    `[sched] disparado "${title}" → ${row.target_type}` +
      ` (${sent} enviadas)${next ? ` · próximo: ${next.toISOString()}` : " · concluído"}`,
  );
}

async function tick(): Promise<void> {
  try {
    const due = await sql`
      SELECT id FROM scheduled_notifications
      WHERE enabled AND next_run_at IS NOT NULL AND next_run_at <= now()
      ORDER BY next_run_at LIMIT 20`;
    for (const { id } of due) {
      // Claim atômico: zera next_run_at; só quem conseguir o UPDATE dispara.
      const [claimed] = await sql`
        UPDATE scheduled_notifications SET next_run_at = NULL
        WHERE id = ${id} AND next_run_at IS NOT NULL AND next_run_at <= now()
        RETURNING *`;
      if (!claimed) continue;
      await fire(claimed).catch((e) =>
        console.warn("[sched] falha no disparo:", (e as Error).message));
    }
  } catch (e) {
    console.warn("[sched] tick falhou:", (e as Error).message);
  }
}

/** Liga o scheduler (loop de 60s) e completa next_run_at faltantes. */
export function startNotificationScheduler(): void {
  // Backfill: agendamentos ativos sem next_run_at (ex.: criados antes de um
  // deploy ou interrompidos no meio do claim) ganham nova próxima execução.
  (async () => {
    try {
      const rows = await sql`
        SELECT * FROM scheduled_notifications
        WHERE enabled AND next_run_at IS NULL AND schedule_kind <> 'once'`;
      for (const row of rows) {
        const next = computeNextRun(row);
        if (next) {
          await sql`UPDATE scheduled_notifications SET next_run_at = ${next} WHERE id = ${row.id}`;
        }
      }
    } catch (e) {
      console.warn("[sched] backfill falhou:", (e as Error).message);
    }
  })();

  setInterval(tick, 60_000);
  setTimeout(tick, 5_000); // primeira checagem logo após o boot
  console.log("[sched] scheduler de notificações ativo (checagem a cada 60s).");
}
