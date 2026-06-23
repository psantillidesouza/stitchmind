-- Troca as imagens mockadas (placehold.co) pelas ilustrações da marca,
-- servidas pelo backend em /lessons/crochet-zero/*.png.

UPDATE lessons SET
  cover_url = 'https://stitchmindapp.com/lessons/crochet-zero/cover.png'
WHERE slug = 'no-inicial-e-correntinha';

-- Cada passo (position 0..4) -> step-1..step-5.png
UPDATE lesson_blocks b SET content = jsonb_set(
  b.content,
  '{image_url}',
  to_jsonb('https://stitchmindapp.com/lessons/crochet-zero/step-' || (b.position + 1) || '.png')
)
WHERE b.type = 'step'
  AND b.lesson_id = (SELECT id FROM lessons WHERE slug = 'no-inicial-e-correntinha');
