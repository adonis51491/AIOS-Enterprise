import test from "node:test";
import assert from "node:assert/strict";

import {
  findCaseInsensitiveEmailDuplicates,
  normalizeEmail,
} from "../src/lib/email";

test("normalizeEmail trims and lowercases input", () => {
  assert.equal(normalizeEmail("  User@Example.COM "), "user@example.com");
});

test("findCaseInsensitiveEmailDuplicates groups mixed-case duplicates", () => {
  const duplicates = findCaseInsensitiveEmailDuplicates([
    { id: 2, email: "user@example.com" },
    { id: 1, email: "User@example.com" },
    { id: 3, email: "other@example.com" },
  ]);

  assert.deepEqual(duplicates, [
    {
      normalizedEmail: "user@example.com",
      users: [
        { id: 1, email: "User@example.com" },
        { id: 2, email: "user@example.com" },
      ],
    },
  ]);
});
