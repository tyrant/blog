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
