import { Controller } from '@hotwired/stimulus';

export default class extends Controller {

  static values = { 
    containsNsfw: Boolean, 
    duration: Number,
    prevIsNsfw: Boolean,
    nekIsNsfw: Boolean
  }

  static targets = ['prev', 'nek'];

  static getNsfwContainingStims() {
    return window.getStimsBy({ name: 'prev-nek' })
                 .filter(s => s.containsNsfwValue);
  }

  // Courtesy https://leastbad.com/stimulus-power-move
  connect() {
    this.element.stimulusController = this;
  }

  banish(yes) {
    console.log('yes', yes)
    console.log('this.nsfwTargets()', this.nsfwTargets())

    if (yes) {
      this.nsfwTargets().forEach(el => {

      });
      this.prevNsfwTarget.classLis
    } else {

    }
  }

  unblurOnMouseover(yes) {
    if (yes) this.nsfwEls().add('hover:blur-none');
    else     this.classes().remove('hover:blur-none');
  }

  unblurAlways(yes) {
    if (yes) this.classes().remove('blur-sm');
    else     this.classes().add('blur-sm');
  }

  nsfwTargets() {

    ['prev', 'nek'].map(pn => {
      console.log('pn', pn)
      console.log('`${pn}IsNsfwValue`', `${pn}IsNsfwValue`)
      console.log('this[`${pn}IsNsfwValue`]', this[`${pn}IsNsfwValue`])
      console.log('this[`${pn}Target`]', this[`${pn}Target`])
      if (this[`${pn}IsNsfwValue`]) return this[`${pn}Target`];
    });
  }


}
