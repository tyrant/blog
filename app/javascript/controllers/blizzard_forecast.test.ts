import { describe, it, expect } from "vitest";
import { forecastOccurrences, countByDay, dayKey, ForecastGroup, ForecastEvent } from "./blizzard_forecast";

const now = new Date(2026, 0, 15, 12, 0, 0); // 15 Jan 2026, 12:00 local
const DAY = 24 * 60 * 60 * 1000;

function group(anchor: string | null): ForecastGroup {
  return { anchor, title: "T", content: "C", url: "u" };
}

function starts(events: ReturnType<typeof forecastOccurrences>): Date[] {
  return events.map((e) => new Date(e.start));
}

describe("forecastOccurrences", () => {
  it("returns nothing when the interval is below 1", () => {
    expect(forecastOccurrences([group(null)], 0, now)).toEqual([]);
  });

  it("floors fractional intervals below 1 to nothing", () => {
    expect(forecastOccurrences([group(null)], 0.5, now)).toEqual([]);
  });

  describe("a never-posted group", () => {
    const events = forecastOccurrences([group(null)], 14, now);

    it("starts its first occurrence today", () => {
      expect(starts(events)[0].getTime()).toBe(now.getTime());
    });

    it("spaces occurrences by the interval", () => {
      const [a, b] = starts(events);
      expect(b.getTime() - a.getTime()).toBe(14 * DAY);
    });

    it("keeps every occurrence within the horizon", () => {
      const horizonEnd = new Date(2026, 0, 15).getTime() + 90 * DAY;
      expect(starts(events).every((d) => d.getTime() <= horizonEnd)).toBe(true);
    });
  });

  describe("an overdue group", () => {
    const anchor = new Date(now.getTime() - 40 * DAY).toISOString(); // next = -26d, already past
    const events = forecastOccurrences([group(anchor)], 14, now);

    it("collapses its first occurrence onto today", () => {
      expect(starts(events)[0].getTime()).toBe(now.getTime());
    });
  });

  describe("a group that is not yet due", () => {
    const anchor = new Date(now.getTime() - 5 * DAY).toISOString(); // next = +9d, future
    const events = forecastOccurrences([group(anchor)], 14, now);

    it("schedules its first occurrence at anchor + interval, not today", () => {
      expect(starts(events)[0].getTime()).toBe(now.getTime() + 9 * DAY);
    });
  });

  it("emits nothing for a group whose next occurrence is beyond the horizon", () => {
    const anchor = new Date(now.getTime() - 1 * DAY).toISOString();
    expect(forecastOccurrences([group(anchor)], 200, now)).toEqual([]);
  });
});

describe("countByDay", () => {
  function event(start: Date): ForecastEvent {
    return { title: "T", start: start.toISOString(), extendedProps: { content: "C" } };
  }

  it("tallies occurrences that share a local day", () => {
    const day = new Date(2026, 2, 3, 9, 0, 0);
    const sameDayLater = new Date(2026, 2, 3, 18, 30, 0);
    const counts = countByDay([event(day), event(sameDayLater)]);
    expect(counts.get(dayKey(day))).toBe(2);
  });

  it("keeps distinct days separate", () => {
    const a = new Date(2026, 2, 3, 9, 0, 0);
    const b = new Date(2026, 2, 4, 9, 0, 0);
    const counts = countByDay([event(a), event(b)]);
    expect(counts.get(dayKey(a))).toBe(1);
  });

  it("returns an empty map for no events", () => {
    expect(countByDay([]).size).toBe(0);
  });
});
