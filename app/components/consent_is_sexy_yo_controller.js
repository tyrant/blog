import { Controller } from '@hotwired/stimulus';
import PostIndexController from './post_index_controller';
import PrevNekController from './prev_nek_controller';

export default class extends Controller {

  static targets = ['banish', 'mouseover', 'always'];
  static values = {
    banish: Boolean,
    mouseover: Boolean,
    always: Boolean
  }

  static instance() {
    return window.getStimsBy({ name: 'consent-is-sexy-yo' })[0];
  }

  connect() {
    // Courtesy https://leastbad.com/stimulus-power-move
    this.element.stimulusController = this;
  }

  handleClickBanishNsfwCompletely() {
    this.banishValue = this.banishTarget.checked;

    window.setCookies({ banish_nsfw_completely: this.banishValue });
    this.mouseoverTarget.disabled = this.isMouseoverDisabled();
    this.updateUnblurOnHoverCss();
    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updateNsfwPostIndexStimsBanish();
    this.updateNsfwPrevNekStimsBanish();
    this.updatePaginationControllerCeil();
  }

  updateNsfwPostIndexStimsBanish() {
    PostIndexController.getNsfwStims().forEach(stim => {
      this.banishValue ? stim.banishNow() : stim.unbanishNow();
    });
  }

  updateNsfwPrevNekStimsBanish() {
    let prevNekTurbo = document.getElementById('prev_nek');
    if (prevNekTurbo) prevNekTurbo.reload();
  }

  updatePaginationControllerCeil() {
    window.getStimsBy({ name: 'pagination' }).forEach(stim => {
      stim.updateCeil({ nsfwBanished: this.banishValue });
    });
  }

  handleClickUnblurNsfwOnMouseover() {
    this.mouseoverValue = this.mouseoverTarget.checked;

    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updatePostIndexStimsPossiblyBlur();
    this.updatePrevNekStimsPossiblyBlurOnMouseover();

    window.setCookies({ unblur_nsfw_on_mouseover: this.mouseoverValue });
  }

  updatePostIndexStimsPossiblyBlur() {
    if (!this.alwaysValue) return;

    PostIndexController.getNsfwStims().forEach(stim => {
      this.mouseoverValue ? stim.unblurNow() : stim.blurNow();
    });
  }

  updatePrevNekStimsPossiblyBlurOnMouseover() {
    PrevNekController.getNsfwContainingStims().forEach(stim => {
      stim.unblurOnFutureMouseover(this.mouseoverValue);
    });
  }

  isMouseoverDisabled() {
    return this.banishValue;
  }

  updateUnblurOnHoverCss() {
    let cursors = ['cursor-pointer', 'cursor-not-allowed'];
    let classLists = [
      this.mouseoverTarget,
      this.mouseoverTarget.closest('label'),
      this.mouseoverTarget.closest('li')
    ].map(c => c.classList);

    // The Mouseover checkbox/form-el CSS only ever changes upon checking the 
    // Banish checkbox. It's a straightforward toggle/switch, every time, so we
    // can safely call .toggle(). See updateUnblurAlwaysCss() for more.
    classLists[1].toggle('opacity-40');
    if (!this.isMouseoverDisabled()) cursors.reverse();
    classLists.forEach(el => el.replace(...cursors));
  }
  
  handleClickUnblurNsfwAlways() {
    this.alwaysValue = this.alwaysTarget.checked;

    this.updateNsfwPostIndexStimsUnblurAlways();
    this.updatePrevNekStimsUnblurAlways();
    window.setCookies({ unblur_nsfw_always: this.alwaysValue });
  }

  updateNsfwPostIndexStimsUnblurAlways() {
    PostIndexController.getNsfwStims().forEach(stim => {
      this.alwaysValue ? stim.unblurNow() : stim.blurNow();
    });
  }

  updatePrevNekStimsUnblurAlways() {
    PrevNekController.getNsfwContainingStims().forEach(stim => {
      this.alwaysValue ? stim.unblurNow() : stim.blurNow();
    });
  }

  isAlwaysDisabled() {
    return this.banishValue || !this.mouseoverValue;
  }

  updateUnblurAlwaysCss() {
    let cursors = ['cursor-pointer', 'cursor-not-allowed'];
    let classLists = [
      this.alwaysTarget,
      this.alwaysTarget.closest('label'),
      this.alwaysTarget.closest('li')
    ].map(c => c.classList);

    // Bit more complex here. Unlike updateUnblurOnHoverCss(), the Always
    // checkbox/form-el CSS can be updated by either Banish or Mouseover
    // check actions. .isAlwaysDisabled() sometimes doesn't change, so these
    // classes sometimes don't toggle. You have to query .isAlwaysDisabled() 
    // manually each time.
    if (this.isAlwaysDisabled()) {
      classLists[1].add('opacity-40');
    } else {
      classLists[1].remove('opacity-40');
      cursors.reverse();
    }

    classLists.forEach(el => el.replace(...cursors));
  }
}
