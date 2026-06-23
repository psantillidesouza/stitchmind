-- StitchMind — schema inicial
-- Plataforma: usuários (Firebase), aulas (misto), telemetria, crashes, IA.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ─── Identidade & sessões ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS users (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  firebase_uid  text UNIQUE,                     -- null até o 1º login
  email         text UNIQUE,
  name          text,
  photo_url     text,
  role          text NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','blocked')),
  email_verified boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz
);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS devices (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid REFERENCES users(id) ON DELETE SET NULL,
  platform      text CHECK (platform IN ('ios','android','web')),
  model         text,
  os_version    text,
  app_version   text,
  push_token    text,
  first_seen_at timestamptz NOT NULL DEFAULT now(),
  last_seen_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_devices_user ON devices(user_id);

CREATE TABLE IF NOT EXISTS app_sessions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  started_at  timestamptz NOT NULL DEFAULT now(),
  ended_at    timestamptz,
  duration_s  integer,
  app_version text,
  platform    text
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON app_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_started ON app_sessions(started_at);

-- ─── Storage de mídia (objetos no MinIO) ────────────────────────────

CREATE TABLE IF NOT EXISTS assets (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind        text NOT NULL CHECK (kind IN ('video','image','pdf')),
  filename    text NOT NULL,
  mime        text NOT NULL,
  size_bytes  bigint NOT NULL DEFAULT 0,
  bucket      text NOT NULL,
  storage_key text NOT NULL,
  width       integer,
  height      integer,
  duration_s  integer,
  uploaded_by uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- ─── Aulas (conteúdo misto) ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS courses (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title         text NOT NULL,
  slug          text UNIQUE NOT NULL,
  description   text DEFAULT '',
  cover_asset_id uuid REFERENCES assets(id) ON DELETE SET NULL,
  technique     text CHECK (technique IN ('crochet','knit')),
  level         text DEFAULT 'beginner' CHECK (level IN ('beginner','intermediate','advanced')),
  published     boolean NOT NULL DEFAULT false,
  order_index   integer NOT NULL DEFAULT 0,
  created_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS lessons (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id     uuid REFERENCES courses(id) ON DELETE SET NULL,
  title         text NOT NULL,
  slug          text UNIQUE NOT NULL,
  description   text DEFAULT '',
  technique     text CHECK (technique IN ('crochet','knit')),
  difficulty    text DEFAULT 'beginner' CHECK (difficulty IN ('beginner','intermediate','advanced')),
  duration_min  integer,
  cover_asset_id uuid REFERENCES assets(id) ON DELETE SET NULL,
  status        text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  order_index   integer NOT NULL DEFAULT 0,
  published_at  timestamptz,
  created_by    uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_lessons_status ON lessons(status);
CREATE INDEX IF NOT EXISTS idx_lessons_course ON lessons(course_id);

-- Blocos = conteúdo misto na ordem: texto / imagem / vídeo / material
CREATE TABLE IF NOT EXISTS lesson_blocks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  position    integer NOT NULL DEFAULT 0,
  type        text NOT NULL CHECK (type IN ('text','image','video','material')),
  content     jsonb NOT NULL DEFAULT '{}'::jsonb,   -- {text} | {caption} etc.
  asset_id    uuid REFERENCES assets(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_blocks_lesson ON lesson_blocks(lesson_id, position);

-- ─── Progresso & engajamento ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS lesson_progress (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  lesson_id     uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  status        text NOT NULL DEFAULT 'not_started'
                CHECK (status IN ('not_started','in_progress','completed')),
  progress_pct  integer NOT NULL DEFAULT 0,
  last_position_s integer NOT NULL DEFAULT 0,
  completed_at  timestamptz,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, lesson_id)
);

CREATE TABLE IF NOT EXISTS lesson_views (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  lesson_id   uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  started_at  timestamptz NOT NULL DEFAULT now(),
  watched_s   integer NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_views_lesson ON lesson_views(lesson_id);

-- ─── Telemetria ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS events (
  id          bigserial PRIMARY KEY,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  session_id  uuid REFERENCES app_sessions(id) ON DELETE SET NULL,
  name        text NOT NULL,
  screen      text,
  props       jsonb NOT NULL DEFAULT '{}'::jsonb,
  app_version text,
  platform    text,
  ts          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_events_name ON events(name);
CREATE INDEX IF NOT EXISTS idx_events_screen ON events(screen);
CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
CREATE INDEX IF NOT EXISTS idx_events_user ON events(user_id);

CREATE TABLE IF NOT EXISTS crashes (
  id          bigserial PRIMARY KEY,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  device_id   uuid REFERENCES devices(id) ON DELETE SET NULL,
  app_version text,
  platform    text,
  os_version  text,
  error_type  text,
  message     text,
  stack_trace text,
  is_fatal    boolean NOT NULL DEFAULT false,
  breadcrumbs jsonb NOT NULL DEFAULT '[]'::jsonb,
  fingerprint text,                                -- agrupa crashes iguais
  ts          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_crashes_fingerprint ON crashes(fingerprint);
CREATE INDEX IF NOT EXISTS idx_crashes_ts ON crashes(ts);

-- ─── IA (migra do .jsonl) ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS analyses (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  provider    text,
  model       text,
  latency_ms  integer,
  image_key   text,
  result      jsonb,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS feedback (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  analysis_id uuid REFERENCES analyses(id) ON DELETE CASCADE,
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  section     text NOT NULL,
  rating      text NOT NULL CHECK (rating IN ('correct','partial','wrong')),
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now()
);
