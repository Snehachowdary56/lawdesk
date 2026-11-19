import { billableMinutes, formatClock, hours } from "../src/billing";

test("rounds up to 6-minute billing units", () => {
  expect(billableMinutes(0)).toBe(0);
  expect(billableMinutes(1_000)).toBe(6);            // 1 second still bills 0.1 h
  expect(billableMinutes(6 * 60_000)).toBe(6);
  expect(billableMinutes(6 * 60_000 + 1)).toBe(12);
  expect(billableMinutes(47 * 60_000)).toBe(48);
});

test("formats the running clock and hours", () => {
  expect(formatClock(3_725_000)).toBe("01:02:05");
  expect(hours(48)).toBe("0.8");
});
