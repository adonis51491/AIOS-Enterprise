import test from "node:test";
import assert from "node:assert/strict";

import {
  buildVivoWatchLatest,
  flattenVivoWatchDailyData,
  getLatestVivoWatchRecord,
} from "../src/lib/vivowatch";

test("getLatestVivoWatchRecord returns the newest record by time key", () => {
  const latest = getLatestVivoWatchRecord([
    { time: "2026-06-20 09:00:00", heartrate: 70 },
    { time: "2026-06-21 09:00:00", heartrate: 75 },
    { time: "2026-06-19 09:00:00", heartrate: 65 },
  ]);

  assert.equal(latest?.heartrate, 75);
  assert.equal(getLatestVivoWatchRecord([]), null);
});

test("flattenVivoWatchDailyData combines records across daily buckets", () => {
  const records = flattenVivoWatchDailyData(
    [
      { hb: [{ time: "2026-06-20 09:00:00", heartrate: 70 }] },
      { hb: [{ time: "2026-06-21 09:00:00", heartrate: 75 }] },
      { step: [{ time: "2026-06-21 10:00:00", steps: 200 }] },
    ],
    "hb"
  );

  assert.deepEqual(records, [
    { time: "2026-06-20 09:00:00", heartrate: 70 },
    { time: "2026-06-21 09:00:00", heartrate: 75 },
  ]);
});

test("buildVivoWatchLatest uses latest records across all days", () => {
  const latest = buildVivoWatchLatest(
    [
      {
        hb: [{ time: "2026-06-20 09:00:00", heartrate: 70 }],
        bp: [{ time: "2026-06-20 09:10:00", sys: 118, dia: 78, hr: 71 }],
        spo2: [{ time: "2026-06-20 09:15:00", spo2: 97 }],
        step: [{ time: "2026-06-20 09:20:00", steps: 1000 }],
      },
      {
        hb: [{ time: "2026-06-21 09:00:00", heartrate: 76 }],
        bp: [
          {
            time: "2026-06-21 09:10:00",
            sys: 122,
            dia: 82,
            hr: 74,
            deStressIndex: 42,
          },
        ],
        spo2: [{ time: "2026-06-21 09:15:00", spo2: 99 }],
        step: [{ time: "2026-06-21 09:20:00", steps: 2500 }],
      },
    ],
    [
      { exerciseDatetime: "2026-06-20 08:00:00", totalDistance: 1.2 },
      { exerciseDatetime: "2026-06-21 08:00:00", totalDistance: 2.8 },
    ]
  );

  assert.deepEqual(latest, {
    情緒壓力: 42,
    心率: 74,
    血氧: 99,
    血壓: { sys: 122, dia: 82 },
    步數: 2500,
    步行距離: 2.8,
  });
});

test("buildVivoWatchLatest uses bp heart rate when it is newer than hb", () => {
  const latest = buildVivoWatchLatest(
    [
      {
        hb: [{ time: "2026-06-21 09:00:00", heartrate: 76 }],
        bp: [{ time: "2026-06-21 10:00:00", sys: 122, dia: 82, hr: 81 }],
      },
    ],
    []
  );

  assert.equal(latest.心率, 81);
});
