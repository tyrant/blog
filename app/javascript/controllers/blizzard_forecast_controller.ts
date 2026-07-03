import { Controller } from "@hotwired/stimulus";
import { Calendar } from "@fullcalendar/core";
import dayGridPlugin from "@fullcalendar/daygrid";
import { forecastOccurrences, ForecastGroup } from "./blizzard_forecast";

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

  connect(): void {
    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [dayGridPlugin],
      initialView: "dayGridMonth",
      height: "auto",
      dayMaxEvents: true,
      headerToolbar: { left: "prev,next today", center: "title", right: "" },
      validRange: this.validRange(),
      events: this.computeEvents(),
      eventDidMount: (info) => this.attachTooltip(info.el, info.event.extendedProps.content as string),
    });
    this.calendar.render();
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
    }, 200);
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

  private computeEvents() {
    return forecastOccurrences(
      this.groupsValue,
      parseInt(this.daysTarget.value, 10),
      new Date(),
      BlizzardForecastController.HORIZON_DAYS,
    );
  }

  private validRange(): { start: Date; end: Date } {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const end = new Date(start);
    end.setDate(end.getDate() + BlizzardForecastController.HORIZON_DAYS + 1);
    return { start, end };
  }
}
