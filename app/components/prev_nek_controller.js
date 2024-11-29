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

  initialize() { this.prevNekArrowsMove(); }

  unblurOnFutureMouseover(yes) {
    this.#nsfwClasslists().forEach(c => {
      if (yes) c.add('hover:blur-none');
      else     c.remove('hover:blur-none');
    });
  }

  blurNow() {
    this.#nsfwClasslists().forEach(c => c.add('blur-sm'));
  }

  unblurNow() {
    this.#nsfwClasslists().forEach(c => c.remove('blur-sm'));
  }

  prevNekArrowsMove() {
    [this.prevTarget, this.prevArrowTarget].forEach(t => {
      const pc = this.prevArrowTarget.classList;
      t.addEventListener('mouseover', () => pc.add('-translate-x-4'));
      t.addEventListener('mouseout',  () => pc.remove('-translate-x-4'));
    });

    [this.nekTarget, this.nekArrowTarget].forEach(t => {
      const nc = this.nekArrowTarget.classList;
      t.addEventListener('mouseover', () => nc.add('translate-x-4'));
      t.addEventListener('mouseout',  () => nc.remove('translate-x-4'));
    });
  }

  #nsfwClasslists() {
    return ['prev', 'nek'].map(pn => {
      if (this[`${pn}IsNsfwValue`]) return this[`${pn}Target`];
    }).filter(Boolean).map(n => n.classList);
  }
}
