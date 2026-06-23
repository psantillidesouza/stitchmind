-- Traduz o conteúdo semeado (dicas + curso/aula "Crochê do Zero") para inglês.
-- Roda em instalações novas (depois dos seeds) e atualiza o banco de produção.
-- Conteúdo criado pelo admin no painel (ex.: outras aulas) NÃO é afetado.

-- ─── Dicas (Início) ─────────────────────────────────────────────────
UPDATE tips SET emoji = '🧶', title = 'Yarn tension',
  body = 'Before starting a new project, make a 10×10 cm (4×4 in) swatch to check that your stitch tension is right.'
WHERE title = 'Tensão do fio';

UPDATE tips SET emoji = '✂️', title = 'Count your stitches',
  body = 'Place a stitch marker every 10 rows — it makes it much easier to find where you went wrong.'
WHERE title = 'Conte os pontos';

UPDATE tips SET emoji = '🌈', title = 'Choosing colors',
  body = 'Analogous colors (next to each other on the color wheel) almost always go together. Start with those if you''re unsure.'
WHERE title = 'Escolha das cores';

-- ─── Curso ──────────────────────────────────────────────────────────
UPDATE courses SET title = 'Crochet from Scratch',
  description = 'Intro crochet course: from the slip knot to your first project.'
WHERE slug = 'croche-do-zero';

-- ─── Aula ───────────────────────────────────────────────────────────
UPDATE lessons SET title = 'Lesson 1 — Slip knot & chain',
  description = 'Learn from scratch: how to hold the hook and yarn, make the slip knot, and your first chain.'
WHERE slug = 'no-inicial-e-correntinha';

-- ─── Passos (mantém number + image_url, troca title + instruction) ──
UPDATE lesson_blocks b
SET content = b.content || jsonb_build_object('title', t.title, 'instruction', t.instruction)
FROM (VALUES
  (0, 'Hold the hook and yarn', 'Hold the crochet hook like a pencil in your dominant hand. Lay the yarn over the index finger of your other hand — that finger controls the yarn tension.'),
  (1, 'Slip knot', 'Make a loop with the yarn, pass the tail through it and pull to form a loose knot. Put that loop on the hook and adjust without tightening too much.'),
  (2, 'Your first chain', 'Bring the yarn over the hook (yarn over) and pull it through the loop already on the hook. Done: you made 1 chain (ch).'),
  (3, 'Repeat the chains', 'Repeat the previous step — yarn over and pull through — until you have the number of chains the pattern asks for. Keep them all the same size.'),
  (4, 'Check your foundation', 'Your chain foundation should be even: stitches the same size, not too tight or too loose. This is the foundation of your project!')
) AS t(position, title, instruction)
WHERE b.type = 'step'
  AND b.position = t.position
  AND b.lesson_id = (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha');

-- ─── Aula "Manta Listrada Arco-Íris" (modelo rico) ──────────────────
UPDATE lessons SET
  title = 'Pastel Rainbow Textured Striped Blanket',
  description = 'A crochet blanket in pastel stripes with a dense cluster texture (Suzette/Sedge family), worked flat in rows with frequent color changes.'
WHERE slug = 'manta-listrada-arco-iris-pastel';

UPDATE lesson_blocks b
SET content = b.content || jsonb_build_object('title', t.title, 'instruction', t.instruction)
FROM (VALUES
  (0, 'Make the foundation', 'Cast on the full width of the blanket with the foundation row. Simple chain — a multiple of 2 stitches plus the turning chain.'),
  (1, 'First row of clusters', 'Work the first row of textured clusters and lock in the stitch pattern. [(sc, dc) in the same stitch, skip 1 stitch] repeated to the end; turn.'),
  (2, 'Form the first stripe', 'Work several rows in the same color to form the first solid stripe. Repeat the Step 2 row for 2 rows per color band; the clusters sit offset from the previous row.'),
  (3, 'Change color', 'Change color cleanly to start the next stripe. Finish the row, change color on the last yarn-over, secure the old color and turn.'),
  (4, 'Repeat the stripe cycle', 'Repeat the stripe cycle to grow the whole body of the blanket. Repeat the color sequence (see Color Sequence) until you reach the desired length.'),
  (5, 'Finishing and borders', 'Finish the borders and weave in the ends for a neat blanket. 1 round of sc around the whole perimeter, 3 sc in each corner; optional [skip, 5-dc shell, skip, sc] finish on the bottom edge.')
) AS t(position, title, instruction)
WHERE b.type = 'step'
  AND b.position = t.position
  AND b.lesson_id = (SELECT id FROM lessons WHERE slug = 'manta-listrada-arco-iris-pastel');
