-- Voto por passo do guia (like/dislike no card do passo, no app).
-- UNIQUE (block_id, user_id): 1 voto por usuário por passo; votar de novo
-- troca o voto (upsert).
CREATE TABLE IF NOT EXISTS lesson_step_feedback (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  block_id    uuid NOT NULL REFERENCES lesson_blocks(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  vote        text NOT NULL CHECK (vote IN ('like','dislike')),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (block_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_step_feedback_block ON lesson_step_feedback(block_id);
