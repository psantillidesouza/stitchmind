-- Vídeos: poster (thumbnail). A duração já existe em assets.duration_s.
-- O poster é guardado como um asset de imagem separado, referenciado aqui.
ALTER TABLE assets
  ADD COLUMN IF NOT EXISTS poster_asset_id uuid REFERENCES assets(id) ON DELETE SET NULL;
