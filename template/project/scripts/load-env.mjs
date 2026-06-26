import { existsSync, readFileSync } from "node:fs";
import path from "node:path";

function parseEnvFile(content) {
  const entries = {};

  for (const rawLine of content.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;

    const separatorIndex = line.indexOf("=");
    if (separatorIndex === -1) continue;

    const key = line.slice(0, separatorIndex).trim();
    let value = line.slice(separatorIndex + 1).trim();

    if (
      (value.startsWith("\"") && value.endsWith("\"")) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }

    entries[key] = value;
  }

  return entries;
}

export function loadLocalEnv() {
  const envPaths = [".env.local", ".env"];

  for (const relativePath of envPaths) {
    const filePath = path.resolve(process.cwd(), relativePath);
    if (!existsSync(filePath)) continue;

    const envEntries = parseEnvFile(readFileSync(filePath, "utf8"));
    for (const [key, value] of Object.entries(envEntries)) {
      if (process.env[key] === undefined) {
        process.env[key] = value;
      }
    }
  }
}
