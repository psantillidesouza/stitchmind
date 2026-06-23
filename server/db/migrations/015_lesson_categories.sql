-- Categorias de aulas: tabela gerenciada pelo painel admin e ligada às aulas.
-- Cada aula pode pertencer a no máximo uma categoria (category_id). O app usa
-- a categoria para filtrar a home (chips). order_index controla a ordenação.

CREATE TABLE IF NOT EXISTS categories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,
  slug        text UNIQUE NOT NULL,
  order_index int  NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE lessons
  ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES categories(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_lessons_category_id ON lessons(category_id);

-- Categorias iniciais de crochê/tricô.
INSERT INTO categories (name, slug, order_index) VALUES
  ('Amigurumi',      'amigurumi',      0),
  ('Clothing',       'clothing',       1),
  ('Accessories',    'accessories',    2),
  ('Home Decor',     'home-decor',     3),
  ('Basic Stitches', 'basic-stitches', 4)
ON CONFLICT (slug) DO NOTHING;
