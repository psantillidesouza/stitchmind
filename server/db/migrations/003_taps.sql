-- Heatmaps + sinais de frustração (rage/dead tap)

CREATE TABLE IF NOT EXISTS taps (
  id          bigserial PRIMARY KEY,
  session_id  uuid REFERENCES app_sessions(id) ON DELETE SET NULL,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  screen      text,
  x           real NOT NULL,   -- normalizado 0..1
  y           real NOT NULL,   -- normalizado 0..1
  label       text,
  is_rage     boolean NOT NULL DEFAULT false,
  is_dead     boolean NOT NULL DEFAULT false,
  app_version text,
  platform    text,
  ts          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_taps_screen ON taps(screen);
CREATE INDEX IF NOT EXISTS idx_taps_session ON taps(session_id);
CREATE INDEX IF NOT EXISTS idx_taps_ts ON taps(ts);
CREATE INDEX IF NOT EXISTS idx_taps_rage ON taps(is_rage) WHERE is_rage = true;
