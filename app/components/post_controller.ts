import { Controller } from "@hotwired/stimulus";
import ConsentIsSexyYoController from './consent_is_sexy_yo_controller';

export default class PostController extends Controller {
  static targets = ['datebg', 'date', 'body', 'categories', 'scale'];

  static values = { 
    nsfw: Boolean, 
    duration: Number
  };

  declare readonly datebgTarget: HTMLElement;
  declare readonly dateTarget: HTMLElement;
  declare readonly bodyTarget: HTMLElement;
  declare readonly categoriesTarget: HTMLElement;
  declare readonly scaleTarget: HTMLElement;
  declare nsfwValue: boolean;
  declare durationValue: number;

  static getNsfwStims(): PostController[] {
    return window.getStimsBy({ name: 'post' }).filter(s => (s as PostController).nsfwValue) as PostController[];
  }

  connect(): void {
    // Courtesy https://leastbad.com/stimulus-power-move
    (this.element as Element).stimulusController = this;

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
  setVanillaJsMouseoverMouseoutListeners(): void {
    this.hoverables().forEach(m => {
      m.addEventListener('mouseover', () => {
        this.scaleScalablesNow();
        if (this.needToUnblurOnMouseover()) this.unblurBlurrablesNow();
      });
      m.addEventListener('mouseout', () => {
        this.unscaleScalablesNow();
        if (this.needToBlurOnMouseout()) this.blurBlurrablesNow();
      });
    });
  }

  banishNow(): void {
    this.element.classList.add('opacity-0');
    setTimeout(
      () => { this.element.classList.add('hidden'); },
      this.durationValue
    );
  }

  unbanishNow(): void {
    this.element.classList.remove('hidden');

    // For some reason, calling .remove('opacity-0') without 
    // setTimeout() doesn't trigger Tailwind's duration. We must wrap.
    setTimeout(
      () => { this.element.classList.remove('opacity-0'); },
      0
    );

    const c = ConsentIsSexyYoController.instance();
    if (c.mouseoverValue && c.alwaysValue) this.unblurBlurrablesNow();
    else                                   this.blurBlurrablesNow();
  }

  unblurBlurrablesNow(): void {
    this.blurrables().forEach(b => b.classList.remove('blur-sm'));
  }

  blurBlurrablesNow(): void {
    this.blurrables().forEach(b => b.classList.add('blur-sm'));
  }

  // Private methods (converted from # syntax for better TS compatibility)

  private scaleScalablesNow(): void {
    this.scalables().forEach(s => s.classList.add('scale-[1.015]'));
  }

  private unscaleScalablesNow(): void {
    this.scalables().forEach(s => s.classList.remove('scale-[1.015]'));
  }

  private needToUnblurOnMouseover(): boolean {
    const c = ConsentIsSexyYoController.instance();
    return this.nsfwValue && !c.banishValue && c.mouseoverValue;
  }

  private needToBlurOnMouseout(): boolean {
    const c = ConsentIsSexyYoController.instance();
    return this.nsfwValue && !c.banishValue && c.mouseoverValue && !c.alwaysValue;
  }

  private scalables(): HTMLElement[] {
    return [
      this.datebgTarget,
      this.scaleTarget
    ];
  }

  private hoverables(): HTMLElement[] { 
    return [
      this.datebgTarget,
      this.dateTarget, 
      this.bodyTarget, 
      this.categoriesTarget
    ];
  }

  private blurrables(): HTMLElement[] { 
    return [
      this.datebgTarget,
      this.bodyTarget,
      ...Array.from(this.element.getElementsByClassName('cat-blurrable')) as HTMLElement[]
    ];
  }
}
