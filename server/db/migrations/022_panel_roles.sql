-- Papel do usuário DENTRO do painel (admin = tudo; editor = só conteúdo).
-- Usuários do painel continuam sendo role='admin' (gateia o login do painel);
-- panel_role refina o que cada um pode acessar.
ALTER TABLE users ADD COLUMN IF NOT EXISTS panel_role text
  CHECK (panel_role IN ('admin','editor'));

-- Admins existentes viram 'admin' completo.
UPDATE users SET panel_role = 'admin' WHERE role = 'admin' AND panel_role IS NULL;
