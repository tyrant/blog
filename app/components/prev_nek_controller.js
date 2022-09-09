import { Controller } from '@hotwired/stimulus';

export default class extends Controller {

  static values = { 
    duration: Number,
    prevIsNsfw: Boolean,
    nekIsNsfw: Boolean
  }

  static targets = ['prev', 'nek'];

  static getNsfwContainingStims() {
    return window.getStimsBy({ name: 'prev-nek' })
                 .filter(s => { return s.prevIsNsfwValue || s.nekIsNsfwValue });
  }

  // Courtesy https://leastbad.com/stimulus-power-move
  connect() {
    this.element.stimulusController = this;
  }

  banish(yes) {
    this.nsfwTargets().forEach(el => {
      if (yes) el.classList.add('opacity-50');
      else     el.classList.remove('opacity-50');
    });
  }

  unblurOnMouseover(yes) {
    this.nsfwTargets().forEach(el => {
      if (yes) el.classList.add('hover:blur-none');
      else     el.classList.remove('hover:blur-none');
    });
  }

  unblurAlways(yes) {
    this.nsfwTargets().forEach(el => {
      if (yes) el.classList.remove('blur-sm');
      else     el.classList.add('blur-sm');
    });
  }

  nsfwTargets() {
    return ['prev', 'nek'].map(pn => {
      if (this[`${pn}IsNsfwValue`]) return this[`${pn}Target`];
    }).filter(Boolean);
  }


}
