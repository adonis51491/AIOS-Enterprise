import { hash } from "bcryptjs";
import pg from "pg";

import { loadLocalEnv } from "./load-env.mjs";

loadLocalEnv();

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

function parseArgs(argv) {
  const parsed = {};

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith("--")) continue;

    const key = token.slice(2);
    const value = argv[i + 1];
    if (!value || value.startsWith("--")) {
      parsed[key] = "true";
      continue;
    }

    parsed[key] = value;
    i += 1;
  }

  return parsed;
}

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  console.error("DATABASE_URL is required");
  process.exit(1);
}

const args = parseArgs(process.argv.slice(2));
const email = typeof args.email === "string" ? normalizeEmail(args.email) : "";
const password = typeof args.password === "string" ? args.password : "";
const name = typeof args.name === "string" ? args.name.trim() : "Admin";

if (!email || !password) {
  console.error(
    "Usage: npm run db:create-admin -- --email admin@example.com --password your-password [--name \"Admin\"]"
  );
  process.exit(1);
}

if (password.length < 8) {
  console.error("Password must be at least 8 characters.");
  process.exit(1);
}

const { Client } = pg;
const client = new Client({ connectionString });

try {
  await client.connect();

  const existing = await client.query(
    'select id, email, role from "User" where lower(email) = lower($1) limit 1',
    [email]
  );

  if (existing.rows.length > 0) {
    const user = existing.rows[0];
    console.error(
      `A user with email ${user.email} already exists (id=${user.id}, role=${user.role}).`
    );
    process.exit(1);
  }

  const hashedPassword = await hash(password, 12);

  const inserted = await client.query(
    `
      insert into "User" (email, password, role, name, "createdAt", "updatedAt")
      values ($1, $2, $3::"Role", $4, now(), now())
      returning id, email, role, name
    `,
    [email, hashedPassword, "ADMIN", name]
  );

  const user = inserted.rows[0];
  console.log(
    `Created admin user id=${user.id} email=${user.email} role=${user.role} name=${user.name ?? ""}`.trim()
  );
} finally {
  await client.end();
}
