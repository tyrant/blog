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
    // Hack hackity hack :O Turns out we need to swap in/out cursor-* classes
    // for three separate HTML elements.
    let classLists = {
      input: this.mouseoverTarget.classList,
      label: this.mouseoverTarget.parentNode.classList,
      li: this.mouseoverTarget.parentNode.parentNode.classList
    };

    if (this.isMouseoverDisabled()) {
      classLists.label.add('opacity-40');
      Object.values(classLists).forEach(el => {
        el.remove('cursor-pointer');
        el.add('cursor-not-allowed');
      });

    } else {
      classLists.label.remove('opacity-40');
      Object.values(classLists).forEach(el => {
        el.remove('cursor-not-allowed');
        el.add('cursor-pointer');
      });
    }
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
    let classLists = {
      input: this.alwaysTarget.classList,
      label: this.alwaysTarget.parentNode.classList,
      li: this.alwaysTarget.parentNode.parentNode.classList
    };

    if (this.isAlwaysDisabled()) {
      classLists.label.add('opacity-40');
      Object.values(classLists).forEach(el => {
        el.remove('cursor-pointer');
        el.add('cursor-not-allowed');
      });

    } else {
      classLists.label.remove('opacity-40');
      Object.values(classLists).forEach(el => {
        el.remove('cursor-not-allowed');
        el.add('cursor-pointer');
      });
    }
  }
}
