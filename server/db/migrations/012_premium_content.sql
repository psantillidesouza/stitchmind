-- Conteúdo premium: aulas (e cursos) marcadas como premium só liberam o
-- conteúdo para assinantes. No app aparecem com selo "Premium" + cadeado e, ao
-- tocar, abrem a paywall. O flag é exposto na API para o app decidir o gate.

ALTER TABLE lessons ADD COLUMN IF NOT EXISTS is_premium boolean NOT NULL DEFAULT false;
ALTER TABLE courses ADD COLUMN IF NOT EXISTS is_premium boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_lessons_is_premium ON lessons(is_premium);
