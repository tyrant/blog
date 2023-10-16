import { Controller } from "@hotwired/stimulus";
import ConsentIsSexyYoController from './consent_is_sexy_yo_controller';

export default class extends Controller {

  static targets = ['link', 'categories', 'scale'];

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

    this.setVanillaJsMouseoverMouseoutListeners();
  }

  // Normally we'd do this with regular ol' Stim targets ... but things are a 
  // tad fiddlier here: 
  // (1) #blurrables() includes a post's categories, which have different 
  //     counts per post. Turns out Stim-based selectors break when you can't be
  //     sure they're there. Hmph. Vanilla event listeners it is.
  // (2) With #scalables(), I don't think there's a Tailwind-y way of applying
  //     or removing classes to sibling elements on hover. Is there? Vanilla
  //     again.
  setVanillaJsMouseoverMouseoutListeners() {
    this.#hoverables().forEach(m => {
      m.addEventListener('mouseover', () => {
        this.#scaleScalablesNow();
        if (this.#needToUnblurOnMouseover()) this.unblurBlurrablesNow();
      });
      m.addEventListener('mouseout', () => {
        this.#unscaleScalablesNow();
        if (this.#needToBlurOnMouseout()) this.blurBlurrablesNow();
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
    if (c.mouseoverValue && c.alwaysValue) this.unblurBlurrablesNow();
    else                                   this.blurBlurrablesNow();
  }

  unblurBlurrablesNow() {
    this.#blurrables().forEach(b => b.classList.remove('blur-sm'));
  }

  blurBlurrablesNow() {
    this.#blurrables().forEach(b => b.classList.add('blur-sm'));
  }

  // Private :O

  #scaleScalablesNow() {
    this.#scalables().forEach(s => s.classList.add('scale-[1.015]'));
  }

  #unscaleScalablesNow() {
    this.#scalables().forEach(s => s.classList.remove('scale-[1.015]'));
  }

  #needToUnblurOnMouseover() {
    let c = ConsentIsSexyYoController.instance();
    return this.nsfwValue && !c.banishValue && c.mouseoverValue;
  }

  #needToBlurOnMouseout() {
    let c = ConsentIsSexyYoController.instance();
    return this.nsfwValue && !c.banishValue && c.mouseoverValue && !c.alwaysValue;
  }

  #scalables() {
    return [this.scaleTarget];
  }

  #hoverables() { 
    return [this.linkTarget, this.categoriesTarget];
  }

  #blurrables() { 
    return [
      this.linkTarget,
      ...this.element.getElementsByClassName('cat-blurrable')
    ];
  }
};
