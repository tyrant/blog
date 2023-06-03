import { Controller } from "@hotwired/stimulus";

export default class extends Controller {

  static targets = ['link', 'categories'];

  static values = { 
    nsfw: Boolean, 
    duration: Number, 
    consentIsSexyUnblur: { type: Boolean, default: true } // Non-DRY, ugh
  };

  static getNsfwStims() {
    return window.getStimsBy({ name: 'post-index' }).filter(s => s.nsfwValue);
  }

  connect() {
    // Courtesy https://leastbad.com/stimulus-power-move
    this.element.stimulusController = this;

    this.addVanillaJsMouseOverOutListeners();
  }

  // Normally we'd do this with Stim targets ... but we have a variable number
  // of category-targets, and turns out Stim-based selectors break when you 
  // can't be sure they're there. Hmph. Vanilla event listeners it is.
  addVanillaJsMouseOverOutListeners() {
    if (!this.nsfwValue) return;

    this.hoverable().forEach(m => {
      m.addEventListener('mouseover', () => { this.unblur(); });
      m.addEventListener('mouseout', () => { this.blur(); });
    });
  }

  banish(yes) {
    if (yes) {
      this.element.classList.add('opacity-0');
      setTimeout(() => { this.element.classList.add('hidden'); }, this.durationValue);

    } else { 
      this.element.classList.remove('hidden');

      // For some reason, calling this.classes().remove('opacity-0') without 
      // this setTimeout() doesn't trigger Tailwind's duration. We must wrap.
      setTimeout(() => { this.element.classList.remove('opacity-0'); }, 0);
    }
  }

  unblurAlways(yes) {
    yes ? this.unblur() : this.blur(); 
  }

  sexyStim() { return window.getStimsBy({ name: 'consent-is-sexy-yo' })[0]; }

  needToUnblurOnMouseover() {
    let c = this.sexyStim();
    return !c.banishValue && c.mouseoverValue;
  }

  unblur() {
    if (!this.needToUnblurOnMouseover()) return;
    this.blurrable().forEach(b => b.classList.remove('blur-sm'));
  }

  needToBlurOnMouseout() {
    let c = this.sexyStim();
    return !c.banishValue && c.mouseoverValue && !c.alwaysValue;
  }

  blur() {
    if (!this.needToBlurOnMouseout()) return;
    this.blurrable().forEach(b => b.classList.add('blur-sm'));
  }

  hoverable() { 
    return [this.linkTarget, this.categoriesTarget];
  }

  blurrable() { 
    return [
      this.linkTarget,
      ...this.element.getElementsByClassName('cat-blurrable')
    ];
  }
};
