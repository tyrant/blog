import { Controller } from "@hotwired/stimulus";
import ConsentIsSexyYoController from './consent_is_sexy_yo_controller';

export default class extends Controller {

  static targets = ['link', 'categories'];

  static values = { 
    nsfw: Boolean, 
    duration: Number
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

    this.#hoverable().forEach(m => {
      m.addEventListener('mouseover', () => { 
        if (this.#needToUnblurOnMouseover()) this.unblurNow();
      });
      m.addEventListener('mouseout', () => { 
        if (this.#needToBlurOnMouseout()) this.blurNow(); 
      });
    });
  }

  banishNow() {
    this.element.classList.add('opacity-0');
    setTimeout(
      () => { this.element.classList.add('hidden'); },
      this.durationValue
    );
  }

  unbanishNow() {
    this.element.classList.remove('hidden');

    // For some reason, calling .remove('opacity-0') without 
    // setTimeout() doesn't trigger Tailwind's duration. We must wrap.
    setTimeout(
      () => { this.element.classList.remove('opacity-0'); },
      0
    );

    let c = ConsentIsSexyYoController.instance();
    if (c.mouseoverValue && c.alwaysValue) this.unblurNow();
    else                                   this.blurNow();
  }

  unblurNow() {
    this.#blurrable().forEach(b => b.classList.remove('blur-sm'));
  }

  blurNow() {
    this.#blurrable().forEach(b => b.classList.add('blur-sm'));
  }

  #needToUnblurOnMouseover() {
    let c = ConsentIsSexyYoController.instance();
    return !c.banishValue && c.mouseoverValue;
  }

  #needToBlurOnMouseout() {
    let c = ConsentIsSexyYoController.instance();
    return !c.banishValue && c.mouseoverValue && !c.alwaysValue;
  }

  #hoverable() { 
    return [this.linkTarget, this.categoriesTarget];
  }

  #blurrable() { 
    return [
      this.linkTarget,
      ...this.element.getElementsByClassName('cat-blurrable')
    ];
  }
};
