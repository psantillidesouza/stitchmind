-- Notificações agendadas/recorrentes + lista de mensagens para sorteio.
--  • notification_pool: banco de mensagens; envios com use_pool=true sorteiam
--    uma mensagem ativa daqui (ORDER BY random()).
--  • scheduled_notifications: agendamentos. Tipos:
--      once     → envia 1x em send_at e desativa;
--      daily    → todo dia em time_of_day (no fuso `timezone`);
--      weekly   → nos days_of_week (0=domingo…6=sábado) em time_of_day;
--      interval → a cada interval_minutes.
--    next_run_at é pré-calculado pelo scheduler (claim atômico no disparo).

CREATE TABLE IF NOT EXISTS notification_pool (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text NOT NULL,
  body        text NOT NULL,
  enabled     boolean NOT NULL DEFAULT true,
  created_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS scheduled_notifications (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title            text,
  body             text,
  use_pool         boolean NOT NULL DEFAULT false,
  target_type      text NOT NULL DEFAULT 'all',   -- all | region | user
  target_value     text,
  schedule_kind    text NOT NULL,                 -- once | daily | weekly | interval
  send_at          timestamptz,                   -- once
  time_of_day      text,                          -- "HH:MM" (daily/weekly)
  days_of_week     int[],                         -- weekly (0=dom…6=sáb)
  interval_minutes integer,                       -- interval
  timezone         text NOT NULL DEFAULT 'America/Sao_Paulo',
  enabled          boolean NOT NULL DEFAULT true,
  next_run_at      timestamptz,
  last_sent_at     timestamptz,
  created_by       uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sched_notif_due
  ON scheduled_notifications(next_run_at) WHERE enabled;

-- Liga o histórico ao agendamento que disparou (null = envio manual).
ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS scheduled_id uuid
  REFERENCES scheduled_notifications(id) ON DELETE SET NULL;
