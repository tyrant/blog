import { Controller } from "@hotwired/stimulus";

export default class extends Controller {

  static targets = ['card'];

  static values = { nsfw: Boolean, duration: Number };

  static getNsfwStims() {
    return window.getStimsBy({ name: 'post-index' })
                 .filter(s => s.nsfwValue);
  }

  // Courtesy https://leastbad.com/stimulus-power-move
  connect() {
    this.element.stimulusController = this;
  }

  banish(yes) {
    if (yes) {
      this.classes().add('opacity-0');
      setTimeout(() => {
        this.classes().add('hidden');
      }, this.durationValue);

    } else { 
      this.classes().remove('hidden');

      // For some reason, calling this.classes().remove('opacity-0') without 
      // this setTimeout() doesn't trigger Tailwind's duration. We must wrap.
      setTimeout(() => {
        this.classes().remove('opacity-0');
      }, 0);
    }
  }

  unblurOnMouseover(yes) {
    if (yes) this.classes().add('hover:blur-none');
    else     this.classes().remove('hover:blur-none');
  }

  unblurAlways(yes) {
    if (yes) this.classes().remove('blur-sm');
    else     this.classes().add('blur-sm');
  }

  classes() {
    return this.cardTarget.classList;
  }
};
