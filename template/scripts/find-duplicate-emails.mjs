import { loadLocalEnv } from "./load-env.mjs";
import pg from "pg";

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

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

  const { rows: users } = await client.query(`
    select id, email, role, "createdAt"
    from "User"
    order by id asc
  `);

  const groups = new Map();

  for (const user of users) {
    const normalized = normalizeEmail(user.email);
    const existing = groups.get(normalized) || [];
    existing.push(user);
    groups.set(normalized, existing);
  }

  const duplicates = Array.from(groups.entries()).filter(([, group]) => group.length > 1);

  if (duplicates.length === 0) {
    console.log("No case-insensitive duplicate emails found.");
    process.exit(0);
  }

  console.log(`Found ${duplicates.length} duplicate email group(s):`);
  for (const [normalizedEmail, group] of duplicates) {
    console.log(`\n${normalizedEmail}`);
    for (const user of group) {
      console.log(
        `  id=${user.id} role=${user.role} email=${user.email} createdAt=${user.createdAt.toISOString()}`
      );
    }
  }

  process.exit(1);
} finally {
  await client.end();
}
