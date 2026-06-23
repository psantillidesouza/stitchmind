-- Status de assinatura (premium) por usuário.
-- Atualizado pelo app (sync) e/ou pelo webhook do RevenueCat (autoritativo).

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS is_premium boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS premium_product text,
  ADD COLUMN IF NOT EXISTS premium_updated_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_users_is_premium ON users(is_premium);
