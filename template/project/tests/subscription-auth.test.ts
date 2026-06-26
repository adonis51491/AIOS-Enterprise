import test from "node:test";
import assert from "node:assert/strict";

import {
  hasValidSessionUserPayload,
  shouldClearAuthStateForMeResponse,
} from "../src/lib/auth-session";
import {
  createEcpayCheckMacValue,
  verifyEcpayCheckMacValue,
} from "../src/lib/ecpay";
import { checkRateLimit } from "../src/lib/rate-limit";
import {
  buildPayuniSuccessSubscriptionUpdate,
  buildSubscriptionCheckoutWindow,
  createSubscriptionWindow,
} from "../src/lib/subscription";

test("createSubscriptionWindow returns a 30-day range", () => {
  const now = new Date("2026-06-21T00:00:00.000Z");
  const { startDate, expireDate } = createSubscriptionWindow(now);

  assert.equal(startDate.toISOString(), now.toISOString());
  assert.equal(
    expireDate.toISOString(),
    "2026-07-21T00:00:00.000Z"
  );
});

test("shouldClearAuthStateForMeResponse only clears on 401", () => {
  assert.equal(shouldClearAuthStateForMeResponse(401), true);
  assert.equal(shouldClearAuthStateForMeResponse(503), false);
  assert.equal(shouldClearAuthStateForMeResponse(500), false);
});

test("hasValidSessionUserPayload validates minimum session payload", () => {
  assert.equal(
    hasValidSessionUserPayload({ id: 1, role: "ADMIN", email: "a@example.com" }),
    true
  );
  assert.equal(hasValidSessionUserPayload({ id: 1 }), false);
  assert.equal(hasValidSessionUserPayload(null), false);
});

test("buildPayuniSuccessSubscriptionUpdate extends active subscriptions from current expiry", () => {
  const now = new Date("2026-06-21T00:00:00.000Z");
  const update = buildPayuniSuccessSubscriptionUpdate(
    {
      status: "active",
      startDate: new Date("2026-05-21T00:00:00.000Z"),
      expireDate: new Date("2026-07-01T00:00:00.000Z"),
      payuniPeriodNo: null,
      invoiceNumber: null,
    },
    { PeriodNo: "P2", InvoiceNo: "INV2" },
    now
  );

  assert.equal(update.startDate?.toISOString(), "2026-07-01T00:00:00.000Z");
  assert.equal(update.expireDate?.toISOString(), "2026-07-31T00:00:00.000Z");
});

test("buildSubscriptionCheckoutWindow preserves an active subscription window during checkout", () => {
  const now = new Date("2026-06-21T00:00:00.000Z");
  const window = buildSubscriptionCheckoutWindow(
    {
      status: "active",
      startDate: new Date("2026-06-01T00:00:00.000Z"),
      expireDate: new Date("2026-07-01T00:00:00.000Z"),
    },
    now
  );

  assert.equal(window.status, "pending");
  assert.equal(window.startDate.toISOString(), "2026-06-01T00:00:00.000Z");
  assert.equal(window.expireDate.toISOString(), "2026-07-01T00:00:00.000Z");
});

test("buildPayuniSuccessSubscriptionUpdate extends pending renewals from current expiry", () => {
  const now = new Date("2026-06-21T00:00:00.000Z");
  const update = buildPayuniSuccessSubscriptionUpdate(
    {
      status: "pending",
      startDate: new Date("2026-06-01T00:00:00.000Z"),
      expireDate: new Date("2026-07-01T00:00:00.000Z"),
      payuniTradeNo: "SUB123",
      payuniPeriodNo: null,
      invoiceNumber: null,
    },
    { MerTradeNo: "SUB123", PeriodNo: "P2", InvoiceNo: "INV2" },
    now
  );

  assert.equal(update.startDate?.toISOString(), "2026-07-01T00:00:00.000Z");
  assert.equal(update.expireDate?.toISOString(), "2026-07-31T00:00:00.000Z");
});

test("buildPayuniSuccessSubscriptionUpdate is idempotent for duplicate callbacks", () => {
  const now = new Date("2026-06-21T00:00:00.000Z");
  const update = buildPayuniSuccessSubscriptionUpdate(
    {
      status: "active",
      startDate: new Date("2026-06-01T00:00:00.000Z"),
      expireDate: new Date("2026-07-31T00:00:00.000Z"),
      payuniTradeNo: "SUB123",
      payuniPeriodNo: null,
      invoiceNumber: null,
    },
    { MerTradeNo: "SUB123" },
    now
  );

  assert.equal("startDate" in update, false);
  assert.equal("expireDate" in update, false);
});

test("verifyEcpayCheckMacValue accepts a matching callback signature", () => {
  process.env.ECPAY_HASH_KEY = "HashKey123";
  process.env.ECPAY_HASH_IV = "HashIV456";

  const params = {
    MerchantTradeNo: "ORD123",
    RtnCode: "1",
    TradeAmt: "1000",
  };
  const CheckMacValue = createEcpayCheckMacValue(params);

  assert.equal(verifyEcpayCheckMacValue({ ...params, CheckMacValue }), true);
  assert.equal(
    verifyEcpayCheckMacValue({ ...params, CheckMacValue: "INVALID" }),
    false
  );
});

test("checkRateLimit blocks after the configured limit and resets after the window", () => {
  const key = `test:${Date.now()}:rate-limit`;
  assert.deepEqual(
    checkRateLimit({ key, limit: 2, windowMs: 1000 }, 1000),
    { allowed: true }
  );
  assert.deepEqual(
    checkRateLimit({ key, limit: 2, windowMs: 1000 }, 1100),
    { allowed: true }
  );

  const blocked = checkRateLimit({ key, limit: 2, windowMs: 1000 }, 1200);
  assert.equal(blocked.allowed, false);
  if (!blocked.allowed) {
    assert.equal(blocked.retryAfterSeconds, 1);
  }

  assert.deepEqual(
    checkRateLimit({ key, limit: 2, windowMs: 1000 }, 2100),
    { allowed: true }
  );
});

test("checkRateLimit cleans expired buckets before accepting new attempts", () => {
  const key = `test:${Date.now()}:cleanup`;
  assert.deepEqual(
    checkRateLimit({ key, limit: 1, windowMs: 100 }, 1000),
    { allowed: true }
  );

  const blocked = checkRateLimit({ key, limit: 1, windowMs: 100 }, 1050);
  assert.equal(blocked.allowed, false);

  assert.deepEqual(
    checkRateLimit({ key, limit: 1, windowMs: 100 }, 1200),
    { allowed: true }
  );
});
