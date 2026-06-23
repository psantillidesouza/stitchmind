// Cria/atualiza o admin do painel.
// Uso: bun run src/seed-admin.ts <email> <senha>
import { sql } from "./db.ts";

const email = process.argv[2] ?? Bun.env.ADMIN_EMAIL;
const password = process.argv[3] ?? Bun.env.ADMIN_PASSWORD;

if (!email || !password) {
  console.error("uso: bun run src/seed-admin.ts <email> <senha>");
  process.exit(1);
}

const hash = await Bun.password.hash(password); // argon2id

const [u] = await sql`
  INSERT INTO users (firebase_uid, email, name, role, status, email_verified, password_hash)
  VALUES (${"admin-" + email}, ${email}, 'Admin', 'admin', 'active', true, ${hash})
  ON CONFLICT (email) DO UPDATE SET
    role = 'admin', password_hash = ${hash}, updated_at = now()
  RETURNING id, email, role
`;

console.log("✓ admin pronto:", u.email, "(role:", u.role + ")");
await sql.end();
