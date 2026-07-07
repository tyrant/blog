// Pure recurrence math for the Blizzard repost-forecast calendar. Kept free of
// FullCalendar/DOM imports so it can be unit-tested under vitest in node.

export interface ForecastGroup {
  categorizationId: number;
  uid: string; // stable per-entry id (survives reordering/deletion, unlike an array index)
  anchor: string | null; // ISO8601 of the most recent note, or null if never posted
  title: string;
  content: string; // the intended Note text, shown in the hover tooltip
  url: string | null;
  editUrl: string | null; // ComfyAdmin Post#edit, linked from the tooltip title
}

export interface ForecastEvent {
  categorizationId: number;
  uid: string;
  title: string;
  start: string; // ISO8601
  url?: string;
  extendedProps: { content: string; editUrl: string | null };
}

// Post title for the tooltip link — capped at `max` chars.
export function truncateTitle(title: string, max = 50): string {
  return title.length > max ? `${title.slice(0, max - 1).trimEnd()}…` : title;
}

const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

// Local time-of-day, e.g. "7:05pm".
export function formatTime(iso: string): string {
  const d = new Date(iso);
  const minutes = String(d.getMinutes()).padStart(2, "0");
  const meridiem = d.getHours() < 12 ? "am" : "pm";
  const hour12 = d.getHours() % 12 || 12;
  return `${hour12}:${minutes}${meridiem}`;
}

// Human-readable local timestamp, e.g. "4 Jul 2026, 7:05pm".
export function formatTimestamp(iso: string): string {
  const d = new Date(iso);
  return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}, ${formatTime(iso)}`;
}

// Compact saved-schedule reference: categorization id, entry index, timestamp.
export interface ScheduleRef {
  c: number;
  u: string;
  t: string;
}

export function toScheduleRefs(events: ForecastEvent[]): ScheduleRef[] {
  return events.map((e) => ({ c: e.categorizationId, u: e.uid, t: e.start }));
}

// Order-independent fingerprint of a schedule: two arrangements are the same iff
// they hold the same set of (group, timestamp) pairs.
export function scheduleSignature(refs: ScheduleRef[]): string {
  return refs.map((r) => `${r.c}:${r.u}:${r.t}`).sort().join("|");
}

// Rebuilds events from saved refs, pulling title/content/url from the current
// groups. Refs whose group no longer exists are dropped.
export function hydrateSchedule(refs: ScheduleRef[], groups: ForecastGroup[]): ForecastEvent[] {
  const lookup = new Map(groups.map((g) => [g.uid, g]));
  return refs.flatMap((ref) => {
    const group = lookup.get(ref.u);
    if (!group) return [];
    return [{
      categorizationId: ref.c,
      uid: ref.u,
      title: group.title,
      start: ref.t,
      url: group.url ?? undefined,
      extendedProps: { content: group.content, editUrl: group.editUrl },
    }];
  });
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

// A compact fingerprint of the group set + anchors. Saved alongside a schedule so
// the admin can detect (on load) that a backfill has changed the underlying
// groups since the schedule was saved, and prompt a re-save.
export function groupsDigest(groups: ForecastGroup[]): string {
  const canonical = groups
    .map((g) => `${g.categorizationId}:${g.uid}:${g.anchor ?? ""}`)
    .sort()
    .join("|");
  let hash = 5381;
  for (let i = 0; i < canonical.length; i += 1) {
    hash = ((hash << 5) + hash + canonical.charCodeAt(i)) | 0;
  }
  return (hash >>> 0).toString(36);
}

function fisherYates<T>(arr: T[], random: () => number): T[] {
  const a = [...arr];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

// Orders one day's reposts so each Post's reposts sit at evenly-spaced fractional
// positions (its k reposts at ~1/k apart), each Post randomly rotated — so Posts
// interleave and same-Post reposts are maximally separated.
function spreadOrder(dayEvents: ForecastEvent[], random: () => number): ForecastEvent[] {
  const byPost = new Map<number, ForecastEvent[]>();
  for (const event of dayEvents) {
    const bucket = byPost.get(event.categorizationId);
    if (bucket) bucket.push(event);
    else byPost.set(event.categorizationId, [event]);
  }

  const keyed: { key: number; event: ForecastEvent }[] = [];
  for (const items of byPost.values()) {
    const phase = random();
    fisherYates(items, random).forEach((event, j) => keyed.push({ key: (j + phase) / items.length, event }));
  }
  keyed.sort((a, b) => a.key - b.key);
  return keyed.map((entry) => entry.event);
}

// Reassigns each interval's time-slots so each Post's reposts are spread as widely
// as possible across the whole interval (no adjacent same-Post neighbours when a
// Post is at most half the interval's reposts), rather than a plain random shuffle
// — so reposts of the same Post aren't posted close together.
export function spreadWithinIntervals(
  events: ForecastEvent[],
  intervalDays: number,
  now: Date = new Date(),
  random: () => number = Math.random,
): ForecastEvent[] {
  const byInterval = new Map<number, ForecastEvent[]>();
  for (const event of events) {
    const key = intervalIndexForDate(new Date(event.start), now, intervalDays);
    const bucket = byInterval.get(key);
    if (bucket) bucket.push(event);
    else byInterval.set(key, [event]);
  }

  const result: ForecastEvent[] = [];
  for (const intervalEvents of byInterval.values()) {
    const slots = intervalEvents.map((event) => event.start).sort();
    spreadOrder(intervalEvents, random).forEach((event, i) => result.push({ ...event, start: slots[i] }));
  }
  return result;
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
        categorizationId: group.categorizationId,
        uid: group.uid,
        title: group.title,
        start: t.toISOString(),
        url: group.url ?? undefined,
        extendedProps: { content: group.content, editUrl: group.editUrl },
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
        categorizationId: group.categorizationId,
        uid: group.uid,
        title: group.title,
        start: new Date(t).toISOString(),
        url: group.url ?? undefined,
        extendedProps: { content: group.content, editUrl: group.editUrl },
      });
    }
  });

  return events;
}
