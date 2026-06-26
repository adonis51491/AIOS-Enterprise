import test from "node:test";
import assert from "node:assert/strict";

import { isValidAppointmentStatus } from "../src/lib/appointment";
import { isValidKpiPeriodType, parseKpiIntegerInput } from "../src/lib/kpi";

test("isValidAppointmentStatus only accepts supported statuses", () => {
  assert.equal(isValidAppointmentStatus("approved"), true);
  assert.equal(isValidAppointmentStatus("pending"), true);
  assert.equal(isValidAppointmentStatus("rejected"), true);
  assert.equal(isValidAppointmentStatus("cancelled"), false);
});

test("parseKpiIntegerInput accepts integers and rejects invalid values", () => {
  assert.equal(parseKpiIntegerInput("12"), 12);
  assert.equal(parseKpiIntegerInput(0), 0);
  assert.equal(parseKpiIntegerInput(""), null);
  assert.equal(parseKpiIntegerInput("1.5"), null);
  assert.equal(parseKpiIntegerInput("abc"), null);
});

test("isValidKpiPeriodType restricts period values", () => {
  assert.equal(isValidKpiPeriodType("month"), true);
  assert.equal(isValidKpiPeriodType("quarter"), true);
  assert.equal(isValidKpiPeriodType("year"), true);
  assert.equal(isValidKpiPeriodType("week"), false);
});
