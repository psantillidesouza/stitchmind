-- Login admin próprio (email + senha com hash) para o painel.
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash text;
CREATE INDEX IF NOT EXISTS idx_users_email_admin ON users(email) WHERE role = 'admin';
