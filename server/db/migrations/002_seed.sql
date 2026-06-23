-- Seed de desenvolvimento: usuário admin + curso/aula de exemplo.
-- Idempotente (ON CONFLICT). Em produção, troque o admin pelo seu Firebase UID.

INSERT INTO users (firebase_uid, email, name, role, email_verified)
VALUES ('dev-admin', 'admin@stitchmind.local', 'Admin Dev', 'admin', true)
ON CONFLICT (email) DO UPDATE SET role = 'admin';

-- Curso de exemplo
INSERT INTO courses (title, slug, description, technique, level, published, order_index, created_by)
SELECT 'Crochê do Zero', 'croche-do-zero',
       'Curso introdutório de crochê: do nó inicial ao primeiro projeto.',
       'crochet', 'beginner', true, 0, u.id
FROM users u WHERE u.email = 'admin@stitchmind.local'
ON CONFLICT (slug) DO NOTHING;

-- Aula de exemplo (publicada) com blocos mistos
WITH c AS (SELECT id FROM courses WHERE slug = 'croche-do-zero'),
     a AS (SELECT id FROM users WHERE email = 'admin@stitchmind.local')
INSERT INTO lessons (course_id, title, slug, description, technique, difficulty,
                     duration_min, status, order_index, published_at, created_by)
SELECT c.id, 'Aula 1 — Nó inicial e correntinha', 'no-inicial-e-correntinha',
       'Aprenda a segurar o fio, fazer o nó inicial e a base de correntinhas.',
       'crochet', 'beginner', 8, 'published', 0, now(), a.id
FROM c, a
ON CONFLICT (slug) DO NOTHING;

WITH l AS (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha')
INSERT INTO lesson_blocks (lesson_id, position, type, content)
SELECT l.id, 0, 'text',
       jsonb_build_object('text',
         'Bem-vinda! Nesta aula você vai dar os primeiros pontos. Separe um fio médio e uma agulha 4mm.')
FROM l
WHERE NOT EXISTS (SELECT 1 FROM lesson_blocks b WHERE b.lesson_id = l.id);

WITH l AS (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha')
INSERT INTO lesson_blocks (lesson_id, position, type, content)
SELECT l.id, 1, 'text',
       jsonb_build_object('text',
         'Passo a passo da correntinha: laçada, puxe o fio pela alça, repita mantendo a tensão uniforme.')
FROM l
WHERE (SELECT count(*) FROM lesson_blocks b WHERE b.lesson_id = l.id) = 1;
