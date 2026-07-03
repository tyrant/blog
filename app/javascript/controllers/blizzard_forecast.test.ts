import { describe, it, expect } from "vitest";
import { forecastOccurrences, evenlySpreadOccurrences, shuffleWithinDays, countByDay, dayKey, intervalIndexForDate, intervalColor, ForecastGroup, ForecastEvent } from "./blizzard_forecast";

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

describe("evenlySpreadOccurrences", () => {
  const seven: ForecastGroup[] = Array.from({ length: 7 }, (_, i) => ({
    anchor: null,
    title: `T${i}`,
    content: "C",
    url: null,
  }));

  function firstStartFor(events: ForecastEvent[], title: string): number {
    return Math.min(...events.filter((e) => e.title === title).map((e) => new Date(e.start).getTime()));
  }

  it("returns nothing when the interval is below 1", () => {
    expect(evenlySpreadOccurrences(seven, 0, now)).toEqual([]);
  });

  it("returns nothing when there are no groups", () => {
    expect(evenlySpreadOccurrences([], 7, now)).toEqual([]);
  });

  it("spreads each group's first repost evenly across the interval", () => {
    const events = evenlySpreadOccurrences(seven, 7, now);
    // 7 groups over a 7-day interval → one day apart, first at now.
    seven.forEach((_, i) => {
      expect(firstStartFor(events, `T${i}`)).toBe(now.getTime() + i * DAY);
    });
  });

  it("recurs each group every interval", () => {
    const events = evenlySpreadOccurrences(seven, 7, now).filter((e) => e.title === "T0");
    const times = events.map((e) => new Date(e.start).getTime());
    expect(times[1] - times[0]).toBe(7 * DAY);
  });
});

describe("intervalIndexForDate", () => {
  const addD = (n: number) => new Date(now.getTime() + n * DAY);

  it("puts today in interval 0", () => {
    expect(intervalIndexForDate(now, now, 7)).toBe(0);
  });

  it("keeps the last day of the first block in interval 0", () => {
    expect(intervalIndexForDate(addD(6), now, 7)).toBe(0);
  });

  it("rolls to interval 1 at the start of the next block", () => {
    expect(intervalIndexForDate(addD(7), now, 7)).toBe(1);
  });

  it("puts a date two blocks out in interval 2", () => {
    expect(intervalIndexForDate(addD(14), now, 7)).toBe(2);
  });

  it("returns a negative index for dates before today", () => {
    expect(intervalIndexForDate(addD(-1), now, 7)).toBeLessThan(0);
  });
});

describe("intervalColor", () => {
  it("returns a light pastel hsl string", () => {
    expect(intervalColor(0)).toMatch(/^hsl\(\d+, 70%, 90%\)$/);
  });

  it("gives adjacent intervals different hues", () => {
    expect(intervalColor(0)).not.toBe(intervalColor(1));
  });
});

describe("shuffleWithinDays", () => {
  function ev(title: string, start: Date): ForecastEvent {
    return { title, start: start.toISOString(), extendedProps: { content: title } };
  }
  const d1 = new Date(2026, 3, 1, 9, 0, 0);
  const d1b = new Date(2026, 3, 1, 15, 0, 0);
  const d2 = new Date(2026, 3, 2, 9, 0, 0);

  it("preserves the total number of reposts", () => {
    const out = shuffleWithinDays([ev("A", d1), ev("B", d1b), ev("C", d2)]);
    expect(out.length).toBe(3);
  });

  it("keeps each day's set of time-slots unchanged", () => {
    const out = shuffleWithinDays([ev("A", d1), ev("B", d1b)]);
    const starts = out.map((e) => e.start).sort();
    expect(starts).toEqual([d1.toISOString(), d1b.toISOString()].sort());
  });

  it("reassigns slots within a day (random reversal moves A off its slot)", () => {
    const out = shuffleWithinDays([ev("A", d1), ev("B", d1b)], () => 0);
    expect(out.find((e) => e.title === "A")!.start).toBe(d1b.toISOString());
  });

  it("leaves a single repost on its day untouched", () => {
    const out = shuffleWithinDays([ev("A", d1), ev("C", d2)]);
    expect(out.find((e) => e.title === "C")!.start).toBe(d2.toISOString());
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
