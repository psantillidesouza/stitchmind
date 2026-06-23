// Runner standalone de migrations: `bun run src/migrate.ts`
import { runMigrations, waitForDb, sql } from "./db.ts";

await waitForDb();
await runMigrations();
await sql.end();
console.log("✓ migrations concluídas");
