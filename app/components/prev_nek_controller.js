import { Controller } from '@hotwired/stimulus';

export default class extends Controller {

  static values = { 
    duration: Number,
    prevIsNsfw: Boolean,
    nekIsNsfw: Boolean
  }

  static targets = ['prev', 'prevArrow', 'nek', 'nekArrow'];

  static getNsfwContainingStims() {
    return window.getStimsBy({ name: 'prev-nek' })
                 .filter(s => { return s.prevIsNsfwValue || s.nekIsNsfwValue });
  }

  // Courtesy https://leastbad.com/stimulus-power-move
  connect() { this.element.stimulusController = this; }

  initialize() {
    this.prevArrowMove();
    this.nekArrowMove();
  }

  unblurOnFutureMouseover(yes) {
    this.#nsfwTargets().forEach(el => {
      if (yes) el.classList.add('hover:blur-none');
      else     el.classList.remove('hover:blur-none');
    });
  }

  blurNow() {
    this.#nsfwTargets().forEach(el => el.classList.add('blur-sm'));
  }

  unblurNow() {
    this.#nsfwTargets().forEach(el => el.classList.remove('blur-sm'));
  }

  prevArrowMove() {
    this.prevTarget.addEventListener('mouseover', () => {
      this.prevArrowTarget.classList.add('-translate-x-4');
    });
    this.prevTarget.addEventListener('mouseout', () => {
      this.prevArrowTarget.classList.remove('-translate-x-4');
    });
  }

  nekArrowMove() {
    this.nekTarget.addEventListener('mouseover', () => {
      this.nekArrowTarget.classList.add('translate-x-4');
    });
    this.nekTarget.addEventListener('mouseout', () => {
      this.nekArrowTarget.classList.remove('translate-x-4');
    });
  }

  #nsfwTargets() {
    return ['prev', 'nek'].map(pn => {
      if (this[`${pn}IsNsfwValue`]) return this[`${pn}Target`];
    }).filter(Boolean);
  }
}
