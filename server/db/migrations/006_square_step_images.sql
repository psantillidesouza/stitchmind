-- Imagens dos passos passam a ser QUADRADAS (1:1). Atualiza os mocks 640x420 -> 640x640.

UPDATE lesson_blocks
SET content = jsonb_set(
      content,
      '{image_url}',
      to_jsonb(replace(content->>'image_url', '640x420', '640x640'))
    )
WHERE type = 'step'
  AND content->>'image_url' LIKE '%640x420%';
