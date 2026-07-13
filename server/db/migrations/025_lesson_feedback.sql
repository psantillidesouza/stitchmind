-- Feedback das aulas (sheet "⋯" no app): like e sugestão/comentário curto.
-- UNIQUE garante no máximo 1 like e 1 comentário por usuário por aula
-- (comentário novo substitui o anterior via upsert).
CREATE TABLE IF NOT EXISTS lesson_feedback (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id   uuid NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind        text NOT NULL CHECK (kind IN ('like','comment')),
  comment     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, user_id, kind)
);
CREATE INDEX IF NOT EXISTS idx_lesson_feedback_lesson ON lesson_feedback(lesson_id, kind);
