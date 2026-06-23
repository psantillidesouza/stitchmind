-- Comunidade: social (comentários, seguir) + contador de comentários

CREATE TABLE IF NOT EXISTS post_comments (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id    uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES users(id) ON DELETE SET NULL,
  body       text NOT NULL,
  status     text NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','deleted')),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_comments_post ON post_comments(post_id, created_at);

ALTER TABLE posts ADD COLUMN IF NOT EXISTS comments_count integer NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS follows (
  follower_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);
CREATE INDEX IF NOT EXISTS idx_follows_followee ON follows(followee_id);
