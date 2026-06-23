-- Comunidade: metadados de post (estilo Ravelry) + salvos (favoritos)

ALTER TABLE posts ADD COLUMN IF NOT EXISTS post_type text NOT NULL DEFAULT 'finished'
  CHECK (post_type IN ('finished','wip','help'));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS category text
  CHECK (category IN ('amigurumi','garment','blanket','accessory','granny','home_decor','other'));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS difficulty text
  CHECK (difficulty IN ('beginner','intermediate','advanced'));
ALTER TABLE posts ADD COLUMN IF NOT EXISTS yarn text;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS hook text;

CREATE INDEX IF NOT EXISTS idx_posts_category ON posts(category);

-- Posts salvos (favoritos) por usuário
CREATE TABLE IF NOT EXISTS post_saves (
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  post_id    uuid NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, post_id)
);
CREATE INDEX IF NOT EXISTS idx_post_saves_user ON post_saves(user_id, created_at DESC);
