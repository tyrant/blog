import { Controller } from '@hotwired/stimulus';
import PostController from './post_controller';
import PrevNekController from './prev_nek_controller';

export default class ConsentIsSexyYoController extends Controller {
  static targets = ['banish', 'mouseover', 'always'];
  static values = {
    banish:    Boolean,
    mouseover: Boolean,
    always:    Boolean
  };

  declare readonly banishTarget: HTMLInputElement;
  declare readonly mouseoverTarget: HTMLInputElement;
  declare readonly alwaysTarget: HTMLInputElement;
  declare banishValue: boolean;
  declare mouseoverValue: boolean;
  declare alwaysValue: boolean;

  static instance(): ConsentIsSexyYoController {
    return window.getStimsBy({ name: 'consent-is-sexy-yo' })[0] as ConsentIsSexyYoController;
  }

  connect(): void {
    // Courtesy https://leastbad.com/stimulus-power-move
    (this.element as Element).stimulusController = this;
  }

  handleClickBanishNsfwCompletely(): void {
    this.banishValue = this.banishTarget.checked;

    window.setCookies({ banish_nsfw_completely: this.banishValue });
    this.mouseoverTarget.disabled = this.isMouseoverDisabled();
    this.updateUnblurOnHoverCss();
    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updateNsfwPostStimsBanish();
    this.updateNsfwPrevNekStimsBanish();
  }

  updateNsfwPostStimsBanish(): void {
    PostController.getNsfwStims().forEach((stim: PostController) => {
      this.banishValue ? stim.banishNow() : stim.unbanishNow();
    });
  }

  updateNsfwPrevNekStimsBanish(): void {
    const prevNekTurbo = document.getElementById('prev_nek') as HTMLElement & { reload?: () => void };
    if (prevNekTurbo?.reload) prevNekTurbo.reload();
  }

  handleClickUnblurNsfwOnMouseover(): void {
    this.mouseoverValue = this.mouseoverTarget.checked;

    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updatePostStimsPossiblyBlur();
    this.updatePrevNekStimsPossiblyBlurOnMouseover();

    window.setCookies({ unblur_nsfw_on_mouseover: this.mouseoverValue });
  }

  updatePostStimsPossiblyBlur(): void {
    if (!this.alwaysValue) return;

    PostController.getNsfwStims().forEach((stim: PostController) => {
      this.mouseoverValue ? stim.unblurBlurrablesNow() : stim.blurBlurrablesNow();
    });
  }

  updatePrevNekStimsPossiblyBlurOnMouseover(): void {
    PrevNekController.getNsfwContainingStims().forEach((stim: PrevNekController) => {
      stim.unblurOnFutureMouseover(this.mouseoverValue);
    });
  }

  isMouseoverDisabled(): boolean {
    return this.banishValue;
  }

  updateUnblurOnHoverCss(): void {
    const cursors: [string, string] = ['cursor-pointer', 'cursor-not-allowed'];
    const classLists = [
      this.mouseoverTarget,
      this.mouseoverTarget.closest('label'),
      this.mouseoverTarget.closest('li')
    ].filter(Boolean).map(c => c!.classList);

    // The Mouseover checkbox/form-el CSS only ever changes upon checking the 
    // Banish checkbox. It's a straightforward toggle/switch, every time, so we
    // can safely call .toggle(). See updateUnblurAlwaysCss() for more.
    classLists[1]?.toggle('opacity-40');
    if (!this.isMouseoverDisabled()) cursors.reverse();
    classLists.forEach(el => el.replace(...cursors));
  }
  
  handleClickUnblurNsfwAlways(): void {
    this.alwaysValue = this.alwaysTarget.checked;

    this.updateNsfwPostStimsUnblurAlways();
    this.updatePrevNekStimsUnblurAlways();
    window.setCookies({ unblur_nsfw_always: this.alwaysValue });
  }

  updateNsfwPostStimsUnblurAlways(): void {
    PostController.getNsfwStims().forEach((stim: PostController) => {
      this.alwaysValue ? stim.unblurBlurrablesNow() : stim.blurBlurrablesNow();
    });
  }

  updatePrevNekStimsUnblurAlways(): void {
    PrevNekController.getNsfwContainingStims().forEach((stim: PrevNekController) => {
      this.alwaysValue ? stim.unblurNow() : stim.blurNow();
    });
  }

  isAlwaysDisabled(): boolean {
    return this.banishValue || !this.mouseoverValue;
  }

  updateUnblurAlwaysCss(): void {
    const cursors: [string, string] = ['cursor-pointer', 'cursor-not-allowed'];
    const classLists = [
      this.alwaysTarget,
      this.alwaysTarget.closest('label'),
      this.alwaysTarget.closest('li')
    ].filter(Boolean).map(c => c!.classList);

    // Bit more complex here. Unlike updateUnblurOnHoverCss(), the Always
    // checkbox/form-el CSS can be updated by either Banish or Mouseover
    // check actions. .isAlwaysDisabled() sometimes doesn't change, so these
    // classes sometimes don't toggle. You have to query .isAlwaysDisabled() 
    // manually each time.
    if (this.isAlwaysDisabled()) {
      classLists[1]?.add('opacity-40');
    } else {
      classLists[1]?.remove('opacity-40');
      cursors.reverse();
    }

    classLists.forEach(el => el.replace(...cursors));
  }
}
