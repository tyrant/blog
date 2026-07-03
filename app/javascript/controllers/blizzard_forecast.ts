// Pure recurrence math for the Blizzard repost-forecast calendar. Kept free of
// FullCalendar/DOM imports so it can be unit-tested under vitest in node.

export interface ForecastGroup {
  anchor: string | null; // ISO8601 of the most recent note, or null if never posted
  title: string;
  content: string; // the intended Note text, shown in the hover tooltip
  url: string | null;
}

export interface ForecastEvent {
  title: string;
  start: string; // ISO8601
  url?: string;
  extendedProps: { content: string };
}

// Local YYYY-MM-DD, matching FullCalendar's per-day `data-date` attribute.
export function dayKey(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

// Which days-length forecast block a date falls in, counting from today
// (interval 0 = [today, today+intervalDays)). Negative for dates before today.
export function intervalIndexForDate(date: Date, now: Date, intervalDays: number): number {
  const step = Math.floor(intervalDays);
  if (!Number.isFinite(step) || step < 1) return -1;
  const dayNumber = Math.round((midnight(date).getTime() - midnight(now).getTime()) / (24 * 60 * 60 * 1000));
  return Math.floor(dayNumber / step);
}

// A light pastel per interval, cycling hues so adjacent blocks stay distinct.
export function intervalColor(index: number): string {
  return `hsl(${(index * 47) % 360}, 70%, 90%)`;
}

// Number of forecast occurrences falling on each local day.
export function countByDay(events: ForecastEvent[]): Map<string, number> {
  const counts = new Map<string, number>();
  for (const event of events) {
    const key = dayKey(new Date(event.start));
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  return counts;
}

function addDays(date: Date, days: number): Date {
  const d = new Date(date.getTime());
  d.setDate(d.getDate() + days);
  return d;
}

function midnight(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

// Today's date carrying the time-of-day of `timeSource`.
function todayAt(now: Date, timeSource: Date): Date {
  return new Date(
    now.getFullYear(), now.getMonth(), now.getDate(),
    timeSource.getHours(), timeSource.getMinutes(), timeSource.getSeconds(),
  );
}

// For each group, emit its forecast repost occurrences within [today, today+horizonDays].
// A group that is overdue (its next anchor+interval is already past) or has never
// been posted collapses onto today, then recurs every `intervalDays`.
export function forecastOccurrences(
  groups: ForecastGroup[],
  intervalDays: number,
  now: Date = new Date(),
  horizonDays = 90,
): ForecastEvent[] {
  const step = Math.floor(intervalDays);
  if (!Number.isFinite(step) || step < 1) return [];

  const horizonEnd = addDays(midnight(now), horizonDays);
  const events: ForecastEvent[] = [];

  for (const group of groups) {
    const anchor = group.anchor ? new Date(group.anchor) : null;

    let first: Date;
    if (anchor === null) {
      first = todayAt(now, now);
    } else {
      const next = addDays(anchor, step);
      first = next.getTime() <= now.getTime() ? todayAt(now, anchor) : next;
    }

    for (let t = first; t.getTime() <= horizonEnd.getTime(); t = addDays(t, step)) {
      events.push({
        title: group.title,
        start: t.toISOString(),
        url: group.url ?? undefined,
        extendedProps: { content: group.content },
      });
    }
  }

  return events;
}

// One-off recalculation: ignore each group's anchor and instead spread every
// group's first repost evenly across [now, now + intervalDays], then recur every
// intervalDays. This evens out the first interval and, since all groups share the
// same period, every subsequent interval too.
export function evenlySpreadOccurrences(
  groups: ForecastGroup[],
  intervalDays: number,
  now: Date = new Date(),
  horizonDays = 90,
): ForecastEvent[] {
  const step = Math.floor(intervalDays);
  if (!Number.isFinite(step) || step < 1 || groups.length === 0) return [];

  const stepMs = step * 24 * 60 * 60 * 1000;
  const horizonEnd = addDays(midnight(now), horizonDays).getTime();
  const events: ForecastEvent[] = [];

  groups.forEach((group, i) => {
    const first = now.getTime() + Math.round((i / groups.length) * stepMs);
    for (let t = first; t <= horizonEnd; t += stepMs) {
      events.push({
        title: group.title,
        start: new Date(t).toISOString(),
        url: group.url ?? undefined,
        extendedProps: { content: group.content },
      });
    }
  });

  return events;
}
