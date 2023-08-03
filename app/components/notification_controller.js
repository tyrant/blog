import { Controller } from '@hotwired/stimulus';

export default class extends Controller {

  static values = {
    showtime: Number
  }

  connect() {
    this.#showForShowtimeDuration();
  }

  close() {
    this.element.remove();
  }

  #showForShowtimeDuration() {
    setTimeout(() => { this.#fadeOutSelf(); }, this.showtimeValue);
  }

  #fadeOutSelf() {
    this.element.classList.add('opacity-0');
    setTimeout(() => { this.element.remove(); }, 1000);
  }
}
