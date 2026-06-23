-- Push notifications enviadas pelo painel admin.
--  • devices.country: país/região do aparelho (ex.: "BR", "US") para segmentar
--    envios por região. Preenchido pelo app no /devices/register (locale).
--  • notifications: log do que foi enviado (alvo + contagem).

ALTER TABLE devices ADD COLUMN IF NOT EXISTS country text;
CREATE INDEX IF NOT EXISTS idx_devices_country ON devices(country);
CREATE INDEX IF NOT EXISTS idx_devices_push_token ON devices(push_token)
  WHERE push_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS notifications (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL,
  body         text NOT NULL,
  target_type  text NOT NULL DEFAULT 'all',  -- all | region | user
  target_value text,                          -- país (region) ou user_id (user)
  sent_count   integer NOT NULL DEFAULT 0,
  created_by   uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
