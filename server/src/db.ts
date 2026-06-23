import postgres from "postgres";
import { readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { env } from "./env.ts";

export const sql = postgres(env.databaseUrl, {
  max: env.databasePoolSize,
  idle_timeout: 20,
  onnotice: () => {}, // silencia NOTICE do postgres
});

const MIGRATIONS_DIR = join(
  dirname(fileURLToPath(import.meta.url)),
  "..",
  "db",
  "migrations",
);

/** Roda todas as migrations .sql em ordem, registrando as já aplicadas. */
export async function runMigrations(): Promise<void> {
  await sql`
    CREATE TABLE IF NOT EXISTS _migrations (
      name text PRIMARY KEY,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `;

  let files: string[];
  try {
    files = (await readdir(MIGRATIONS_DIR))
      .filter((f) => f.endsWith(".sql"))
      .sort();
  } catch {
    console.warn("[db] pasta de migrations não encontrada:", MIGRATIONS_DIR);
    return;
  }

  for (const file of files) {
    const already = await sql`SELECT 1 FROM _migrations WHERE name = ${file}`;
    if (already.length > 0) continue;

    const content = await readFile(join(MIGRATIONS_DIR, file), "utf-8");
    console.log(`[db] aplicando migration ${file}…`);
    await sql.unsafe(content);
    await sql`INSERT INTO _migrations (name) VALUES (${file})`;
  }
  console.log("[db] migrations em dia.");
}

/** Espera o Postgres aceitar conexões (boot do docker). */
export async function waitForDb(retries = 30): Promise<void> {
  for (let i = 0; i < retries; i++) {
    try {
      await sql`SELECT 1`;
      return;
    } catch (err) {
      if (i === retries - 1) throw err;
      console.log(`[db] aguardando Postgres… (${i + 1}/${retries})`);
      await new Promise((r) => setTimeout(r, 1000));
    }
  }
}
