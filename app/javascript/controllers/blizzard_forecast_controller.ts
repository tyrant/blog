import { Controller } from "@hotwired/stimulus";
import { Calendar } from "@fullcalendar/core";
import dayGridPlugin from "@fullcalendar/daygrid";
import { forecastOccurrences, countByDay, ForecastEvent, ForecastGroup } from "./blizzard_forecast";

export default class BlizzardForecastController extends Controller {
  static targets = ["days", "calendar"];
  static values = { groups: Array };

  declare readonly daysTarget: HTMLInputElement;
  declare readonly calendarTarget: HTMLElement;
  declare groupsValue: ForecastGroup[];

  private static readonly HORIZON_DAYS = 90;
  private calendar!: Calendar;
  private debounceTimer?: number;
  private tooltip?: HTMLElement;
  private currentEvents: ForecastEvent[] = [];

  connect(): void {
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin],
      initialView: "dayGridMonth",
      height: "auto",
      dayMaxEvents: false, // show every entry; each day's list is capped + scrolled via CSS
      headerToolbar: { left: "prev,next today", center: "title", right: "" },
      validRange: this.validRange(),
      events: this.computeEvents(),
      eventDidMount: (info) => this.attachTooltip(info.el, info.event.extendedProps.content as string),
      datesSet: () => this.updateDayCounts(),
    });
    this.calendar.render();
    this.updateDayCounts();
  }

  disconnect(): void {
    this.calendar?.destroy();
    this.hideTooltip();
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);
  }

  recompute(): void {
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);
    this.debounceTimer = window.setTimeout(() => {
      this.hideTooltip();
      this.calendar.removeAllEvents();
      this.calendar.addEventSource(this.computeEvents());
      this.updateDayCounts();
    }, 200);
  }

  // FullCalendar doesn't expose per-day event counts to its day-cell hooks, so
  // derive them from our own event list and inject a label beside each day number.
  private updateDayCounts(): void {
    const counts = countByDay(this.currentEvents);
    this.calendarTarget.querySelectorAll<HTMLElement>(".fc-daygrid-day").forEach((cell) => {
      const date = cell.getAttribute("data-date");
      const top = cell.querySelector<HTMLElement>(".fc-daygrid-day-top");
      if (!date || !top) return;

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

  private attachTooltip(el: HTMLElement, content: string): void {
    if (!content) return;
    el.addEventListener("mouseenter", (e) => this.showTooltip(content, e));
    el.addEventListener("mousemove", (e) => this.moveTooltip(e));
    el.addEventListener("mouseleave", () => this.hideTooltip());
  }

  private showTooltip(content: string, event: MouseEvent): void {
    this.hideTooltip();
    const tip = document.createElement("div");
    tip.textContent = content;
    Object.assign(tip.style, {
      position: "fixed",
      zIndex: "1080",
      maxWidth: "22rem",
      padding: "0.4rem 0.6rem",
      background: "rgba(17, 24, 39, 0.97)",
      color: "#fff",
      fontSize: "0.8rem",
      lineHeight: "1.35",
      borderRadius: "0.25rem",
      whiteSpace: "pre-wrap",
      boxShadow: "0 2px 10px rgba(0, 0, 0, 0.35)",
      pointerEvents: "none",
    } as Partial<CSSStyleDeclaration>);
    document.body.appendChild(tip);
    this.tooltip = tip;
    this.moveTooltip(event);
  }

  private moveTooltip(event: MouseEvent): void {
    if (!this.tooltip) return;
    const offset = 14;
    const rect = this.tooltip.getBoundingClientRect();
    let left = event.clientX + offset;
    let top = event.clientY + offset;
    if (left + rect.width > window.innerWidth) left = event.clientX - rect.width - offset;
    if (top + rect.height > window.innerHeight) top = event.clientY - rect.height - offset;
    this.tooltip.style.left = `${Math.max(0, left)}px`;
    this.tooltip.style.top = `${Math.max(0, top)}px`;
  }

  private hideTooltip(): void {
    this.tooltip?.remove();
    this.tooltip = undefined;
  }

  private computeEvents(): ForecastEvent[] {
    this.currentEvents = forecastOccurrences(
      this.groupsValue,
      parseInt(this.daysTarget.value, 10),
      new Date(),
      BlizzardForecastController.HORIZON_DAYS,
    );
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
