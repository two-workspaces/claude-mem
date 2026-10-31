// First-boot key setup. claude-mem only mints random keys from its CLI and has
// no dashboard for the first one, so this mints one with the CLI, then swaps
// its hash for CLAUDE_MEM_API_KEY's. The server accepts unsalted SHA-256 hashes
// and re-hashes them with scrypt on first use. Runs on every boot; a no-op once
// the key exists.
import { SQL } from "bun";
import { createHash } from "node:crypto";

const key = (process.env.CLAUDE_MEM_API_KEY ?? "").trim();
if (!key) {
  console.log("[railway-setup] CLAUDE_MEM_API_KEY is empty, skipping key setup");
  process.exit(0);
}
if (key.length < 32) throw new Error("CLAUDE_MEM_API_KEY must be at least 32 characters");

const sql = new SQL(process.env.CLAUDE_MEM_SERVER_DATABASE_URL);
const prefix = key.slice(0, 10); // apiKeyPrefix() in src/server/auth/api-key-hash.ts
const sha = createHash("sha256").update(key).digest("hex");

const [{ t }] = await sql`SELECT to_regclass('api_keys') IS NOT NULL AS t`;
let [row] = t ? await sql`SELECT id, project_id FROM api_keys WHERE key_prefix = ${prefix} AND revoked_at IS NULL` : [];

if (!row) {
  const cli = Bun.spawnSync(
    ["bun", "/opt/claude-mem/scripts/server-service.cjs", "server", "api-key", "create",
     "--name", "railway", "--scope", "memories:read,memories:write"],
    { stdout: "pipe", stderr: "inherit", env: process.env },
  );
  const out = cli.stdout.toString();
  if (cli.exitCode !== 0) throw new Error(`api-key create failed (${cli.exitCode})`);
  const created = JSON.parse(out.slice(out.indexOf("{"), out.lastIndexOf("}") + 1));
  await sql`UPDATE api_keys SET key_hash = ${sha}, key_prefix = ${prefix} WHERE id = ${created.id}`;
  row = { id: created.id, project_id: created.projectId };
  console.log("[railway-setup] API key from CLAUDE_MEM_API_KEY is ready");
}
console.log(`[railway-setup] project id: ${row.project_id}`);
await sql.close();
