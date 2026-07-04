import { Controller } from "@hotwired/stimulus";
import { Calendar, EventApi } from "@fullcalendar/core";
import dayGridPlugin from "@fullcalendar/daygrid";
import {
  forecastOccurrences,
  evenlySpreadOccurrences,
  shuffleWithinDays,
  countByDay,
  intervalIndexForDate,
  intervalColor,
  groupsDigest,
  truncateTitle,
  formatTimestamp,
  toScheduleRefs,
  scheduleSignature,
  hydrateSchedule,
  ForecastEvent,
  ForecastGroup,
  ScheduleRef,
} from "./blizzard_forecast";

interface SavedSchedule {
  days?: number;
  even?: boolean;
  shuffle?: boolean;
  events?: ScheduleRef[];
  groupsDigest?: string;
}

export default class BlizzardForecastController extends Controller {
  static targets = ["days", "even", "shuffle", "status", "calendar"];
  static values = { groups: Array, saved: Object, saveUrl: String };

  declare readonly daysTarget: HTMLInputElement;
  declare readonly evenTarget: HTMLInputElement;
  declare readonly shuffleTarget: HTMLInputElement;
  declare readonly statusTarget: HTMLElement;
  declare readonly calendarTarget: HTMLElement;
  declare groupsValue: ForecastGroup[];
  declare savedValue: SavedSchedule;
  declare saveUrlValue: string;

  private static readonly HORIZON_DAYS = 90;
  private calendar!: Calendar;
  private debounceTimer?: number;
  private tooltip?: HTMLElement;
  private hideTimer?: number;
  private currentEvents: ForecastEvent[] = [];
  private savedSignature: string | null = null;
  private currentDigest = "";
  private savedDigest: string | null = null;

  connect(): void {
    this.loadInitialEvents();
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin],
      initialView: "dayGridMonth",
      height: "auto",
      dayMaxEvents: false, // show every entry; each day's list is capped + scrolled via CSS
      // Reposts are instantaneous: no implied 1h duration, so none spill past
      // midnight and render as day-straddling blocks. Force the compact dot style.
      defaultTimedEventDuration: "00:00:00",
      eventDisplay: "list-item",
      headerToolbar: { left: "prev,next today", center: "title", right: "" },
      validRange: this.validRange(),
      events: this.currentEvents,
      eventDidMount: (info) => this.attachTooltip(info.el, info.event),
      datesSet: () => this.decorateDayCells(),
    });
    this.calendar.render();
    this.decorateDayCells();
    this.updateStatus();
  }

  disconnect(): void {
    this.calendar?.destroy();
    this.clearHide();
    this.tooltip?.remove();
    this.tooltip = undefined;
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);
  }

  // Client-side recompute on any control change (days/even/shuffle). No network.
  recompute(): void {
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);
    this.debounceTimer = window.setTimeout(() => {
      this.hideTooltip();
      this.calendar.removeAllEvents();
      this.calendar.addEventSource(this.computeEvents());
      this.decorateDayCells();
      this.updateStatus();
    }, 200);
  }

  // Persists the current arrangement so every reload/device renders it identically.
  save(): void {
    const refs = toScheduleRefs(this.currentEvents);
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") ?? "";
    fetch(this.saveUrlValue, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": token },
      body: JSON.stringify({
        days: parseInt(this.daysTarget.value, 10),
        even: this.evenTarget.checked,
        shuffle: this.shuffleTarget.checked,
        events: refs,
        groupsDigest: this.currentDigest,
      }),
    })
      .then((response) => response.json())
      .then((result) => {
        if (result.ok) {
          this.savedSignature = scheduleSignature(refs);
          this.savedDigest = this.currentDigest;
          this.updateStatus();
        }
      })
      .catch(() => undefined);
  }

  private loadInitialEvents(): void {
    this.currentDigest = groupsDigest(this.groupsValue);
    const refs = Array.isArray(this.savedValue.events) ? this.savedValue.events : [];
    const hydrated = refs.length > 0 ? hydrateSchedule(refs, this.groupsValue) : [];
    if (hydrated.length > 0) {
      if (typeof this.savedValue.days === "number") this.daysTarget.value = String(this.savedValue.days);
      this.evenTarget.checked = !!this.savedValue.even;
      this.shuffleTarget.checked = !!this.savedValue.shuffle;
      this.currentEvents = hydrated;
      this.savedSignature = scheduleSignature(toScheduleRefs(hydrated));
      this.savedDigest = typeof this.savedValue.groupsDigest === "string" ? this.savedValue.groupsDigest : null;
    } else {
      // No saved schedule, or it no longer maps to any current group — show a
      // live computation and mark it unsaved rather than rendering nothing.
      this.currentEvents = this.computeEvents();
      this.savedSignature = null;
      this.savedDigest = null;
    }
  }

  private updateStatus(): void {
    const currentSignature = scheduleSignature(toScheduleRefs(this.currentEvents));
    const saved = this.savedSignature !== null && currentSignature === this.savedSignature;
    const stale = this.savedDigest !== null && this.savedDigest !== this.currentDigest;

    let text: string;
    let color: string;
    if (saved && stale) {
      text = "Forecast out of date — posts/notes changed. Re-save.";
      color = "#b8860b";
    } else if (saved) {
      text = "Forecasts saved";
      color = "#6c757d";
    } else {
      text = "Unsaved forecasts";
      color = "#b02a37";
    }
    this.statusTarget.textContent = text;
    this.statusTarget.style.color = color;
    this.statusTarget.style.fontWeight = saved && !stale ? "normal" : "600";
  }

  // FullCalendar doesn't expose per-day data to its day-cell hooks, so in one pass
  // we tint each cell by its forecast interval and inject the per-day entry count.
  private decorateDayCells(): void {
    const counts = countByDay(this.currentEvents);
    const now = new Date();
    const interval = parseInt(this.daysTarget.value, 10);

    this.calendarTarget.querySelectorAll<HTMLElement>(".fc-daygrid-day").forEach((cell) => {
      const date = cell.getAttribute("data-date");
      const top = cell.querySelector<HTMLElement>(".fc-daygrid-day-top");
      if (!date || !top) return;

      const [y, m, d] = date.split("-").map(Number);
      const index = intervalIndexForDate(new Date(y, m - 1, d), now, interval);
      cell.style.backgroundColor = index >= 0 ? intervalColor(index) : "";

      const count = counts.get(date) ?? 0;
      let label = top.querySelector<HTMLElement>(".blizzard-entry-count");
      if (count === 0) {
        label?.remove();
        return;
      }
      if (!label) {
        label = document.createElement("span");
        label.className = "blizzard-entry-count";
        Object.assign(label.style, {
          marginRight: "auto", // day-top is row-reverse: pushes the label left, day number stays right
          alignSelf: "center",
          paddingLeft: "0.25rem",
          fontSize: "0.7rem",
          fontWeight: "600",
          opacity: "0.75",
        } as Partial<CSSStyleDeclaration>);
        top.appendChild(label);
      }
      label.textContent = count === 1 ? "1 entry" : `${count} entries`;
    });
  }

  // A persistent, hoverable tooltip locked to the repost element: post-title link
  // (opens Post#edit in a new tab), the Note text, and the human-readable time.
  private attachTooltip(el: HTMLElement, event: EventApi): void {
    el.addEventListener("mouseenter", () => this.showTooltip(el, event));
    el.addEventListener("mouseleave", () => this.scheduleHide());
  }

  private showTooltip(anchor: HTMLElement, event: EventApi): void {
    this.clearHide();
    const tip = this.tooltipElement();

    const link = tip.querySelector<HTMLAnchorElement>(".bz-tip-title")!;
    link.textContent = truncateTitle(event.title);
    link.href = (event.extendedProps.editUrl as string) || "#";

    tip.querySelector<HTMLElement>(".bz-tip-note")!.textContent = (event.extendedProps.content as string) || "";
    tip.querySelector<HTMLElement>(".bz-tip-time")!.textContent = event.start ? formatTimestamp(event.start.toISOString()) : "";

    tip.style.display = "block";
    this.positionTooltip(anchor, tip);
  }

  private tooltipElement(): HTMLElement {
    if (this.tooltip) return this.tooltip;

    const tip = document.createElement("div");
    Object.assign(tip.style, {
      position: "fixed",
      zIndex: "1080",
      maxWidth: "24rem",
      padding: "0.5rem 0.6rem",
      background: "rgba(17, 24, 39, 0.98)",
      color: "#fff",
      fontSize: "0.8rem",
      lineHeight: "1.35",
      borderRadius: "0.3rem",
      boxShadow: "0 2px 12px rgba(0, 0, 0, 0.4)",
      display: "none",
    } as Partial<CSSStyleDeclaration>);

    const link = document.createElement("a");
    link.className = "bz-tip-title";
    link.target = "_blank";
    link.rel = "noopener";
    Object.assign(link.style, {
      display: "block",
      marginBottom: "0.35rem",
      color: "#8ec5ff",
      fontWeight: "600",
      textDecoration: "underline",
    } as Partial<CSSStyleDeclaration>);

    const note = document.createElement("div");
    note.className = "bz-tip-note";
    note.style.whiteSpace = "pre-wrap";

    const time = document.createElement("div");
    time.className = "bz-tip-time";
    Object.assign(time.style, { marginTop: "0.4rem", fontSize: "0.72rem", opacity: "0.7" } as Partial<CSSStyleDeclaration>);

    tip.append(link, note, time);
    tip.addEventListener("mouseenter", () => this.clearHide());
    tip.addEventListener("mouseleave", () => this.scheduleHide());
    document.body.appendChild(tip);
    this.tooltip = tip;
    return tip;
  }

  private positionTooltip(anchor: HTMLElement, tip: HTMLElement): void {
    const rect = anchor.getBoundingClientRect();
    const tipRect = tip.getBoundingClientRect();
    // Minimal gap so the pointer can bridge from the event into the tooltip
    // without crossing a dead-zone that would trigger the hide timer.
    let top = rect.bottom + 2;
    if (top + tipRect.height > window.innerHeight) top = rect.top - tipRect.height - 2;
    let left = rect.left;
    if (left + tipRect.width > window.innerWidth) left = window.innerWidth - tipRect.width - 8;
    tip.style.top = `${Math.max(4, top)}px`;
    tip.style.left = `${Math.max(4, left)}px`;
  }

  private scheduleHide(): void {
    this.clearHide();
    this.hideTimer = window.setTimeout(() => this.hideTooltip(), 300);
  }

  private clearHide(): void {
    if (this.hideTimer) window.clearTimeout(this.hideTimer);
    this.hideTimer = undefined;
  }

  private hideTooltip(): void {
    this.clearHide();
    if (this.tooltip) this.tooltip.style.display = "none";
  }

  private computeEvents(): ForecastEvent[] {
    const interval = parseInt(this.daysTarget.value, 10);
    const compute = this.evenTarget.checked ? evenlySpreadOccurrences : forecastOccurrences;
    let events = compute(this.groupsValue, interval, new Date(), BlizzardForecastController.HORIZON_DAYS);
    if (this.shuffleTarget.checked) events = shuffleWithinDays(events);
    this.currentEvents = events;
    return this.currentEvents;
  }

  private validRange(): { start: Date; end: Date } {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start);
    end.setDate(end.getDate() + BlizzardForecastController.HORIZON_DAYS + 1);
    return { start, end };
  }
}
