import { Controller } from "@hotwired/stimulus";
import { Calendar, EventApi } from "@fullcalendar/core";
import dayGridPlugin from "@fullcalendar/daygrid";
import {
  forecastOccurrences,
  evenlySpreadOccurrences,
  spreadWithinIntervals,
  countByDay,
  intervalIndexForDate,
  intervalColor,
  groupsDigest,
  truncateTitle,
  formatTimestamp,
  formatTime,
  formatDay,
  dayKey,
  toScheduleRefs,
  scheduleSignature,
  hydrateSchedule,
  ForecastEvent,
  ForecastGroup,
  ScheduleRef,
} from "./blizzard_forecast";

const EDIT_ICON_SVG =
  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" width="15" height="15" style="display:block">' +
  '<path d="M2.695 14.763l-1.262 3.154a.5.5 0 00.65.65l3.155-1.262a4 4 0 001.343-.885L17.5 5.5a2.121 2.121 0 00-3-3L3.58 13.42a4 4 0 00-.885 1.343z"/></svg>';

interface SavedSchedule {
  days?: number;
  even?: boolean;
  events?: ScheduleRef[];
  groupsDigest?: string;
}

export default class BlizzardForecastController extends Controller {
  static targets = ["days", "even", "status", "calendar"];
  static values = { groups: Array, saved: Object, saveUrl: String };

  declare readonly daysTarget: HTMLInputElement;
  declare readonly evenTarget: HTMLInputElement;
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
  private popover?: HTMLElement;
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
      datesSet: () => {
        this.closePopover();
        this.decorateDayCells();
      },
    });
    this.calendar.render();
    this.decorateDayCells();
    this.updateStatus();

    this.calendarTarget.addEventListener("click", this.onDayNumberClick);
    document.addEventListener("click", this.onOutsideClick);
    document.addEventListener("keydown", this.onKeydown);
  }

  disconnect(): void {
    this.calendar?.destroy();
    this.clearHide();
    this.tooltip?.remove();
    this.tooltip = undefined;
    this.popover?.remove();
    this.popover = undefined;
    document.removeEventListener("click", this.onOutsideClick);
    document.removeEventListener("keydown", this.onKeydown);
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);
  }

  // Client-side recompute on any control change (days/even/shuffle). No network.
  recompute(): void {
    this.closePopover();
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

  // Clicking a day number opens a popover listing that day's reposts.
  private onDayNumberClick = (e: Event): void => {
    const numberEl = (e.target as HTMLElement).closest<HTMLElement>(".fc-daygrid-day-number");
    if (!numberEl) return;
    const date = numberEl.closest<HTMLElement>(".fc-daygrid-day")?.getAttribute("data-date");
    if (!date) return;
    e.preventDefault();
    this.openPopover(numberEl, date);
  };

  private onOutsideClick = (e: MouseEvent): void => {
    if (!this.popover || this.popover.style.display === "none") return;
    const target = e.target as HTMLElement;
    if (this.popover.contains(target) || target.closest(".fc-daygrid-day-number")) return;
    this.closePopover();
  };

  private onKeydown = (e: KeyboardEvent): void => {
    if (e.key === "Escape") this.closePopover();
  };

  private openPopover(anchor: HTMLElement, date: string): void {
    const events = this.currentEvents
      .filter((event) => dayKey(new Date(event.start)) === date)
      .sort((a, b) => a.start.localeCompare(b.start));

    const pop = this.popoverElement();
    pop.querySelector<HTMLElement>(".bz-pop-title")!.textContent = formatDay(date);

    const body = pop.querySelector<HTMLElement>(".bz-pop-body")!;
    if (events.length === 0) {
      const empty = document.createElement("div");
      empty.textContent = "No reposts this day.";
      Object.assign(empty.style, { padding: "0.4rem 0.6rem", opacity: "0.6" } as Partial<CSSStyleDeclaration>);
      body.replaceChildren(empty);
    } else {
      body.replaceChildren(...events.map((event) => this.popoverRow(event)));
    }

    pop.style.display = "block";
    this.positionPopover(anchor, pop);
  }

  private popoverRow(event: ForecastEvent): HTMLElement {
    const row = document.createElement("div");
    Object.assign(row.style, { display: "flex", gap: "0.5rem", alignItems: "flex-start", padding: "0.2rem 0.6rem" } as Partial<CSSStyleDeclaration>);

    const time = document.createElement("span");
    time.textContent = formatTime(event.start);
    Object.assign(time.style, { flex: "0 0 auto", opacity: "0.6", fontSize: "0.72rem", fontVariantNumeric: "tabular-nums" } as Partial<CSSStyleDeclaration>);

    // Title → public post URL (as in the calendar day list), plus an edit glyph → Post#edit.
    const link = document.createElement("a");
    link.textContent = truncateTitle(event.title);
    link.href = event.url || "#";
    link.target = "_blank";
    link.rel = "noopener";
    Object.assign(link.style, { flex: "1 1 auto", color: "#0d6efd" } as Partial<CSSStyleDeclaration>);

    const edit = document.createElement("a");
    edit.innerHTML = EDIT_ICON_SVG;
    edit.href = (event.extendedProps.editUrl as string) || "#";
    edit.target = "_blank";
    edit.rel = "noopener";
    edit.title = "Edit post";
    edit.setAttribute("aria-label", "Edit post");
    Object.assign(edit.style, {
      flex: "0 0 auto",
      color: "#0d6efd",
      lineHeight: "0",
      padding: "2px",
      border: "1px solid #0d6efd",
      borderRadius: "4px",
    } as Partial<CSSStyleDeclaration>);
    edit.style.display = event.extendedProps.editUrl ? "inline-flex" : "none";

    row.append(time, link, edit);
    return row;
  }

  private popoverElement(): HTMLElement {
    if (this.popover) return this.popover;

    const pop = document.createElement("div");
    Object.assign(pop.style, {
      position: "fixed",
      zIndex: "1090",
      width: "18rem",
      maxWidth: "90vw",
      background: "#fff",
      color: "#212529",
      border: "1px solid rgba(0, 0, 0, 0.15)",
      borderRadius: "0.3rem",
      boxShadow: "0 4px 16px rgba(0, 0, 0, 0.25)",
      fontSize: "0.8rem",
      display: "none",
    } as Partial<CSSStyleDeclaration>);

    const head = document.createElement("div");
    Object.assign(head.style, {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      padding: "0.4rem 0.6rem",
      borderBottom: "1px solid rgba(0, 0, 0, 0.1)",
      fontWeight: "600",
    } as Partial<CSSStyleDeclaration>);

    const title = document.createElement("span");
    title.className = "bz-pop-title";

    const close = document.createElement("button");
    close.type = "button";
    close.textContent = "×";
    Object.assign(close.style, { border: "0", background: "transparent", fontSize: "1.1rem", lineHeight: "1", cursor: "pointer", color: "#6c757d" } as Partial<CSSStyleDeclaration>);
    close.addEventListener("click", () => this.closePopover());

    head.append(title, close);

    const bodyEl = document.createElement("div");
    bodyEl.className = "bz-pop-body";
    Object.assign(bodyEl.style, { maxHeight: "16rem", overflowY: "auto", padding: "0.25rem 0" } as Partial<CSSStyleDeclaration>);

    pop.append(head, bodyEl);
    document.body.appendChild(pop);
    this.popover = pop;
    return pop;
  }

  private positionPopover(anchor: HTMLElement, pop: HTMLElement): void {
    const rect = anchor.getBoundingClientRect();
    const pr = pop.getBoundingClientRect();
    let top = rect.bottom + 4;
    if (top + pr.height > window.innerHeight) top = window.innerHeight - pr.height - 4;
    let left = rect.left;
    if (left + pr.width > window.innerWidth) left = window.innerWidth - pr.width - 8;
    pop.style.top = `${Math.max(4, top)}px`;
    pop.style.left = `${Math.max(4, left)}px`;
  }

  private closePopover(): void {
    if (this.popover) this.popover.style.display = "none";
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

    const editUrl = (event.extendedProps.editUrl as string) || "";
    const link = tip.querySelector<HTMLAnchorElement>(".bz-tip-title")!;
    link.textContent = truncateTitle(event.title);
    link.href = editUrl || "#";

    const edit = tip.querySelector<HTMLAnchorElement>(".bz-tip-edit")!;
    edit.href = editUrl || "#";
    edit.style.display = editUrl ? "inline-flex" : "none";

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

    const head = document.createElement("div");
    Object.assign(head.style, { display: "flex", alignItems: "center", gap: "0.5rem", marginBottom: "0.35rem" } as Partial<CSSStyleDeclaration>);

    const link = document.createElement("a");
    link.className = "bz-tip-title";
    link.target = "_blank";
    link.rel = "noopener";
    Object.assign(link.style, {
      flex: "1 1 auto",
      color: "#8ec5ff",
      fontWeight: "600",
      textDecoration: "underline",
    } as Partial<CSSStyleDeclaration>);

    const edit = document.createElement("a");
    edit.className = "bz-tip-edit";
    edit.target = "_blank";
    edit.rel = "noopener";
    edit.title = "Edit post";
    edit.setAttribute("aria-label", "Edit post");
    edit.innerHTML = EDIT_ICON_SVG;
    Object.assign(edit.style, {
      flex: "0 0 auto",
      color: "#8ec5ff",
      lineHeight: "0",
      padding: "2px",
      border: "1px solid #8ec5ff",
      borderRadius: "4px",
    } as Partial<CSSStyleDeclaration>);

    head.append(link, edit);

    const note = document.createElement("div");
    note.className = "bz-tip-note";
    note.style.whiteSpace = "pre-wrap";

    const time = document.createElement("div");
    time.className = "bz-tip-time";
    Object.assign(time.style, { marginTop: "0.4rem", fontSize: "0.72rem", opacity: "0.7" } as Partial<CSSStyleDeclaration>);

    tip.append(head, note, time);
    tip.addEventListener("mouseenter", () => this.clearHide());
    tip.addEventListener("mouseleave", () => this.scheduleHide());
    document.body.appendChild(tip);
    this.tooltip = tip;
    return tip;
  }

  private positionTooltip(anchor: HTMLElement, tip: HTMLElement): void {
    const rect = anchor.getBoundingClientRect();
    const tipRect = tip.getBoundingClientRect();
    // Prefer to the right of the item, flipping to the left if it would overflow.
    // Overlap the item by 1px so there is no dead-zone (not even a sub-pixel gap)
    // for the pointer to cross when moving into the tooltip.
    let left = rect.right - 1;
    if (left + tipRect.width > window.innerWidth) left = rect.left - tipRect.width + 1;
    let top = rect.top;
    if (top + tipRect.height > window.innerHeight) top = window.innerHeight - tipRect.height - 4;
    tip.style.left = `${Math.max(4, left)}px`;
    tip.style.top = `${Math.max(4, top)}px`;
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
    const now = new Date();
    // One toggle: evenly spread across each interval AND separate same-post reposts.
    const spread = this.evenTarget.checked;
    const compute = spread ? evenlySpreadOccurrences : forecastOccurrences;
    let events = compute(this.groupsValue, interval, now, BlizzardForecastController.HORIZON_DAYS);
    if (spread) events = spreadWithinIntervals(events, interval, now);
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
