-- Aulas em PASSO A PASSO: cada passo tem foto (mock) + instrução (agulha/fio).

-- 1) Capa mockada nas aulas + bloco do tipo "step"
ALTER TABLE lessons ADD COLUMN IF NOT EXISTS cover_url text;

ALTER TABLE lesson_blocks DROP CONSTRAINT IF EXISTS lesson_blocks_type_check;
ALTER TABLE lesson_blocks ADD CONSTRAINT lesson_blocks_type_check
  CHECK (type IN ('text','image','video','material','step'));

-- 2) Aula 1 — capa + metadados
UPDATE lessons SET
  cover_url = 'https://placehold.co/800x520/F2604E/FFFFFF/png?text=Croch%C3%AA+do+Zero',
  duration_min = 8,
  difficulty = 'beginner',
  description = 'Aprenda do zero: como segurar a agulha e o fio, fazer o nó inicial e a sua primeira base de correntinhas.'
WHERE slug = 'no-inicial-e-correntinha';

-- 3) Substitui os blocos antigos por PASSOS
DELETE FROM lesson_blocks
WHERE lesson_id = (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha');

WITH l AS (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha')
INSERT INTO lesson_blocks (lesson_id, position, type, content)
SELECT l.id, s.position, 'step', s.content::jsonb
FROM l, (VALUES
  (0, '{"number":1,"title":"Segure a agulha e o fio","instruction":"Segure a agulha de crochê como se fosse um lápis, na mão dominante. Passe o fio por cima do dedo indicador da outra mão — é ele que controla a tensão do fio.","image_url":"https://placehold.co/640x420/EADBCD/2E2620/png?text=1.+Agulha+%2B+fio"}'),
  (1, '{"number":2,"title":"Nó inicial (laçada)","instruction":"Faça uma alça com o fio, passe a ponta solta por dentro dela e puxe para formar um nó frouxo. Coloque essa alça na agulha e ajuste sem apertar demais.","image_url":"https://placehold.co/640x420/F2D9C6/2E2620/png?text=2.+N%C3%B3+inicial"}'),
  (2, '{"number":3,"title":"Sua primeira correntinha","instruction":"Leve o fio por cima da agulha (laçada) e puxe esse fio por dentro da alça que já está na agulha. Pronto: você fez 1 correntinha (corr).","image_url":"https://placehold.co/640x420/F2604E/FFFFFF/png?text=3.+1+correntinha"}'),
  (3, '{"number":4,"title":"Repita as correntinhas","instruction":"Repita o passo anterior — laçada e puxa — até ter a quantidade de correntinhas que a receita pedir. Mantenha todas do mesmo tamanho.","image_url":"https://placehold.co/640x420/EADBCD/2E2620/png?text=4.+Repita"}'),
  (4, '{"number":5,"title":"Confira a sua base","instruction":"Sua base de correntinhas deve ficar uniforme: pontos do mesmo tamanho, sem apertar nem afrouxar. Essa é a fundação do seu projeto!","image_url":"https://placehold.co/640x420/7C9A6A/FFFFFF/png?text=5.+Base+pronta"}')
) AS s(position, content);
