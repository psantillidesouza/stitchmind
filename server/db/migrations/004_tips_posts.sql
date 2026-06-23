-- Dicas (Início) + publicações da comunidade (usuários postam seus crochês)

CREATE TABLE IF NOT EXISTS tips (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  emoji       text DEFAULT '🧶',
  title       text NOT NULL,
  body        text NOT NULL DEFAULT '',
  published   boolean NOT NULL DEFAULT true,
  order_index integer NOT NULL DEFAULT 0,
  created_by  uuid REFERENCES users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posts (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users(id) ON DELETE SET NULL,
  caption     text DEFAULT '',
  image_asset_id uuid REFERENCES assets(id) ON DELETE SET NULL,
  status      text NOT NULL DEFAULT 'approved'
              CHECK (status IN ('pending','approved','hidden')),
  likes_count integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status, created_at DESC);

CREATE TABLE IF NOT EXISTS post_likes (
  post_id uuid REFERENCES posts(id) ON DELETE CASCADE,
  user_id uuid REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

-- Seed de dicas
INSERT INTO tips (emoji, title, body, order_index) VALUES
  ('🧶', 'Tensão do fio', 'Antes de iniciar um projeto novo, faça uma amostra de 10×10 cm para conferir se a tensão do seu ponto está correta.', 0),
  ('✂️', 'Conte os pontos', 'Marque a cada 10 carreiras com um marcador de ponto — fica muito mais fácil achar onde errou.', 1),
  ('🌈', 'Escolha das cores', 'Cores análogas (vizinhas no círculo cromático) combinam quase sempre. Comece por elas se estiver insegura.', 2)
ON CONFLICT DO NOTHING;
