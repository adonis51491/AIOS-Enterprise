import { readFile } from "node:fs/promises";

import { loadLocalEnv } from "./load-env.mjs";
import pg from "pg";

loadLocalEnv();

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const { Client } = pg;
const client = new Client({ connectionString });

try {
  await client.connect();

  const sql = await readFile(
    new URL("../prisma/sql/enforce_case_insensitive_email_uniqueness.sql", import.meta.url),
    "utf8"
  );

  await client.query(sql);
  console.log("Applied case-insensitive email uniqueness guard.");
} finally {
  await client.end();
}
