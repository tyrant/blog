import { Controller } from '@hotwired/stimulus';
import PostIndexController from './post_index_controller';
import PrevNekController from './prev_nek_controller';

export default class extends Controller {

  static targets = ['banish', 'mouseover', 'always'];

  handleClickBanishNsfwCompletely() {
    this.mouseoverTarget.disabled = this.isMouseoverDisabled();
    this.updateUnblurOnHoverCss();
    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updateNsfwPostIndexStimsBanish();
    this.updateNsfwPrevNekStimsBanish();
    window.setCookies({ banish_nsfw_completely: this.banishTarget.checked });
  }

  updateNsfwPostIndexStimsBanish() {
    PostIndexController.getNsfwStims().forEach(stim => {
      stim.banish(this.banishTarget.checked);
    });
  }

  updateNsfwPrevNekStimsBanish() {
    PrevNekController.getNsfwContainingStims().forEach(stim => {
      stim.banish(this.banishTarget.checked);
    });
  }

  handleClickUnblurNsfwOnMouseover() {
    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    this.updateUnblurAlwaysCss();
    this.updateNsfwPostIndexStimsUnblurOnMouseover();
    this.updatePrevNekStimsUnblurOnMouseover();
    window.setCookies({ unblur_nsfw_on_mouseover: this.mouseoverTarget.checked });
  }

  updateNsfwPostIndexStimsUnblurOnMouseover() {
    PostIndexController.getNsfwStims().forEach(stim => {
      stim.unblurOnMouseover(this.mouseoverTarget.checked);
    });
  }

  updatePrevNekStimsUnblurOnMouseover() {
    PrevNekController.getNsfwContainingStims().forEach(stim => {
      stim.unblurOnMouseover(this.mouseoverTarget.checked);
    });
  }

  isMouseoverDisabled() {
    return this.banishTarget.checked;
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
    this.updateNsfwPostIndexStimsUnblurAlways();
    this.updatePrevNekStimsUnblurAlways();
    window.setCookies({ unblur_nsfw_always: this.alwaysTarget.checked });
  }

  updateNsfwPostIndexStimsUnblurAlways() {
    PostIndexController.getNsfwStims().forEach(stim => {
      stim.unblurAlways(this.alwaysTarget.checked);
    });
  }

  updatePrevNekStimsUnblurAlways() {
    PrevNekController.getNsfwContainingStims().forEach(stim => {
      stim.unblurAlways(this.alwaysTarget.checked);
    });
  }

  isAlwaysDisabled() {
    return this.banishTarget.checked || !this.mouseoverTarget.checked;
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
