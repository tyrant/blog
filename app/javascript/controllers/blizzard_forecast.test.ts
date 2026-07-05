import { describe, it, expect } from "vitest";
import {
  forecastOccurrences,
  evenlySpreadOccurrences,
  spreadWithinIntervals,
  countByDay,
  dayKey,
  intervalIndexForDate,
  intervalColor,
  groupsDigest,
  truncateTitle,
  formatTimestamp,
  formatTime,
  formatDay,
  toScheduleRefs,
  scheduleSignature,
  hydrateSchedule,
  ForecastGroup,
  ForecastEvent,
  ScheduleRef,
} from "./blizzard_forecast";

const now = new Date(2026, 0, 15, 12, 0, 0); // 15 Jan 2026, 12:00 local
const DAY = 24 * 60 * 60 * 1000;

function group(anchor: string | null): ForecastGroup {
  return { categorizationId: 1, entryIndex: 0, anchor, title: "T", content: "C", url: "u", editUrl: "/e" };
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
    categorizationId: i,
    entryIndex: 0,
    anchor: null,
    title: `T${i}`,
    content: "C",
    url: null,
    editUrl: null,
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

describe("spreadWithinIntervals", () => {
  const spreadNow = new Date(2026, 3, 1, 0, 0, 0); // 1 Apr 2026, local midnight
  const INTERVAL = 7;
  // A repost of Post `post`, `dayOffset` days into the forecast.
  function ev(post: number, dayOffset: number): ForecastEvent {
    const start = new Date(2026, 3, 1 + dayOffset, 9, 0, 0).toISOString();
    return { categorizationId: post, entryIndex: dayOffset, title: `P${post}`, start, extendedProps: { content: "c", editUrl: null } };
  }
  // Deterministic random: cycles the given values.
  function seq(values: number[]): () => number {
    let i = 0;
    return () => values[i++ % values.length];
  }

  it("preserves the total number of reposts", () => {
    const out = spreadWithinIntervals([ev(1, 0), ev(1, 1), ev(2, 2), ev(2, 3)], INTERVAL, spreadNow);
    expect(out.length).toBe(4);
  });

  it("keeps each interval's set of time-slots unchanged", () => {
    const input = [ev(1, 0), ev(1, 1), ev(2, 2), ev(2, 3)];
    const out = spreadWithinIntervals(input, INTERVAL, spreadNow);
    expect(out.map((e) => e.start).sort()).toEqual(input.map((e) => e.start).sort());
  });

  it("spreads same-Post reposts across the interval so none are adjacent (when feasible)", () => {
    // 3 of Post 1, 3 of Post 2 over days 0–5 (all interval 0) → alternating.
    const input = [ev(1, 0), ev(1, 1), ev(1, 2), ev(2, 3), ev(2, 4), ev(2, 5)];
    const out = spreadWithinIntervals(input, INTERVAL, spreadNow, seq([0.1, 0.5, 0.5, 0.6, 0.5, 0.5]));
    const ordered = [...out].sort((a, b) => a.start.localeCompare(b.start));
    for (let i = 1; i < ordered.length; i += 1) {
      expect(ordered[i].categorizationId).not.toBe(ordered[i - 1].categorizationId);
    }
  });

  it("keeps each repost within its own interval", () => {
    // Post 1 in interval 0 (days 0,1); Post 2 in interval 1 (days 7,8).
    const input = [ev(1, 0), ev(1, 1), ev(2, 7), ev(2, 8)];
    const out = spreadWithinIntervals(input, INTERVAL, spreadNow);
    const post2 = out.filter((e) => e.categorizationId === 2);
    expect(post2.every((e) => new Date(e.start) >= new Date(2026, 3, 8))).toBe(true);
  });
});

describe("schedule refs / signature / hydrate", () => {
  const groups: ForecastGroup[] = [
    { categorizationId: 10, entryIndex: 0, anchor: null, title: "P1a", content: "c1", url: "u1", editUrl: "/e10-0" },
    { categorizationId: 10, entryIndex: 1, anchor: null, title: "P1b", content: "c2", url: null, editUrl: null },
  ];
  const refs: ScheduleRef[] = [
    { c: 10, i: 0, t: "2026-07-05T09:00:00.000Z" },
    { c: 10, i: 1, t: "2026-07-06T09:00:00.000Z" },
  ];

  it("maps events to compact {c,i,t} refs", () => {
    const hydrated = hydrateSchedule(refs, groups);
    expect(toScheduleRefs(hydrated)).toEqual(refs);
  });

  it("signature is order-independent", () => {
    expect(scheduleSignature(refs)).toBe(scheduleSignature([...refs].reverse()));
  });

  it("signature differs when a timestamp changes", () => {
    const changed: ScheduleRef[] = [{ ...refs[0], t: "2026-07-09T09:00:00.000Z" }, refs[1]];
    expect(scheduleSignature(refs)).not.toBe(scheduleSignature(changed));
  });

  it("hydrates refs into events using the groups lookup", () => {
    const hydrated = hydrateSchedule(refs, groups);
    expect(hydrated).toEqual([
      { categorizationId: 10, entryIndex: 0, title: "P1a", start: "2026-07-05T09:00:00.000Z", url: "u1", extendedProps: { content: "c1", editUrl: "/e10-0" } },
      { categorizationId: 10, entryIndex: 1, title: "P1b", start: "2026-07-06T09:00:00.000Z", url: undefined, extendedProps: { content: "c2", editUrl: null } },
    ]);
  });

  it("drops refs whose group no longer exists", () => {
    const orphan: ScheduleRef[] = [{ c: 999, i: 0, t: "2026-07-05T09:00:00.000Z" }];
    expect(hydrateSchedule(orphan, groups)).toEqual([]);
  });
});

describe("truncateTitle", () => {
  it("leaves a short title untouched", () => {
    expect(truncateTitle("Short title")).toBe("Short title");
  });

  it("truncates past the max with an ellipsis", () => {
    const long = "x".repeat(60);
    const out = truncateTitle(long, 50);
    expect(out.length).toBe(50);
    expect(out.endsWith("…")).toBe(true);
  });
});

describe("formatTimestamp", () => {
  it("renders a human-readable local time", () => {
    const iso = new Date(2026, 6, 4, 19, 5).toISOString(); // 4 Jul 2026, 7:05pm local
    expect(formatTimestamp(iso)).toBe("4 Jul 2026, 7:05pm");
  });

  it("renders midnight as 12:00am", () => {
    const iso = new Date(2026, 0, 1, 0, 0).toISOString();
    expect(formatTimestamp(iso)).toBe("1 Jan 2026, 12:00am");
  });
});

describe("formatTime", () => {
  it("renders just the time-of-day", () => {
    expect(formatTime(new Date(2026, 6, 4, 19, 5).toISOString())).toBe("7:05pm");
  });
});

describe("formatDay", () => {
  it("renders a YYYY-MM-DD key as a human date", () => {
    expect(formatDay("2026-07-04")).toBe("4 Jul 2026");
  });
});

describe("groupsDigest", () => {
  const g = (categorizationId: number, entryIndex: number, anchor: string | null): ForecastGroup => ({
    categorizationId, entryIndex, anchor, title: "T", content: "C", url: null, editUrl: null,
  });

  it("is stable regardless of group order", () => {
    const a = [g(1, 0, "2026-01-01T00:00:00Z"), g(2, 0, null)];
    expect(groupsDigest(a)).toBe(groupsDigest([...a].reverse()));
  });

  it("changes when a new group is added", () => {
    const base = [g(1, 0, null)];
    expect(groupsDigest(base)).not.toBe(groupsDigest([...base, g(1, 1, null)]));
  });

  it("changes when an anchor moves (a note was added)", () => {
    expect(groupsDigest([g(1, 0, "2026-01-01T00:00:00Z")])).not.toBe(groupsDigest([g(1, 0, "2026-02-01T00:00:00Z")]));
  });
});

describe("countByDay", () => {
  function event(start: Date): ForecastEvent {
    return { categorizationId: 0, entryIndex: 0, title: "T", start: start.toISOString(), extendedProps: { content: "C", editUrl: null } };
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
