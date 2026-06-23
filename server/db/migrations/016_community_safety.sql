-- Comunidade: segurança/moderação (denúncia, bloqueio, soft-delete) + likes_count

-- Denúncias de post (1 por usuário por post)
CREATE TABLE IF NOT EXISTS post_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  reporter_id uuid REFERENCES users(id) ON DELETE SET NULL,
  reason      text NOT NULL CHECK (reason IN ('spam','offensive','nudity','harassment','other')),
  note        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, reporter_id)
);
CREATE INDEX IF NOT EXISTS idx_post_reports_post ON post_reports(post_id);

-- Bloqueio entre usuários
CREATE TABLE IF NOT EXISTS user_blocks (
  blocker_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id)
);
CREATE INDEX IF NOT EXISTS idx_user_blocks_blocker ON user_blocks(blocker_id);

-- Soft-delete do post (estende o CHECK existente de 004)
ALTER TABLE posts DROP CONSTRAINT IF EXISTS posts_status_check;
ALTER TABLE posts ADD CONSTRAINT posts_status_check
  CHECK (status IN ('pending','approved','hidden','deleted'));

-- likes_count deixa de ser denormalizado-manual: trigger mantém em sincronia
CREATE OR REPLACE FUNCTION sync_likes_count() RETURNS trigger AS $$
BEGIN
  UPDATE posts
     SET likes_count = (SELECT count(*) FROM post_likes
                        WHERE post_id = COALESCE(NEW.post_id, OLD.post_id))
   WHERE id = COALESCE(NEW.post_id, OLD.post_id);
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_likes_count ON post_likes;
CREATE TRIGGER trg_likes_count
  AFTER INSERT OR DELETE ON post_likes
  FOR EACH ROW EXECUTE FUNCTION sync_likes_count();

-- Recalcula uma vez para corrigir qualquer drift acumulado
UPDATE posts p SET likes_count =
  (SELECT count(*) FROM post_likes pl WHERE pl.post_id = p.id);
