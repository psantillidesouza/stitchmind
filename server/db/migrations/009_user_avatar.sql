-- Avatar do usuário: foto enviada pelo próprio app (convertida em WebP).
-- A imagem vive no bucket público do MinIO; a URL estável fica em users.photo_url
-- e referenciamos o asset para limpeza/escala.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS photo_asset_id uuid REFERENCES assets(id) ON DELETE SET NULL;
