-- Modelo rico de aula (vindo da análise da foto): metadados estruturados em
-- coluna jsonb (nome do produto, materiais, sequência de cores, método de
-- construção, pontos usados, análise do padrão) + passos com campos detalhados
-- (objetivo, descrição visual, pontos usados, padrão usado, resultado esperado)
-- guardados no content jsonb dos blocos do tipo 'step'.

ALTER TABLE lessons ADD COLUMN IF NOT EXISTS meta jsonb NOT NULL DEFAULT '{}'::jsonb;
