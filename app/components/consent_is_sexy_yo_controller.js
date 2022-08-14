import { Controller } from '@hotwired/stimulus';
import PostIndexController from './post_index_controller';
import PrevNekController from './prev_nek_controller';

export default class extends Controller {

  static targets = ['banish', 'mouseover', 'always'];

  handleClickBanishNsfwCompletely() {
    this.updateUnblurOnHoverCss();
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
      stim.unblurOnMouseover(this.banishTarget.checked);
    });
  }

  isMouseoverDisabled() {
    return this.banishTarget.checked;
  }

  updateUnblurOnHoverCss() {
    this.mouseoverTarget.disabled = this.isMouseoverDisabled();
    let classes = this.mouseoverTarget.parentNode.classList;
    if (this.isMouseoverDisabled()) classes.add('opacity-40');
    else                            classes.remove('opacity-40');
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
      stim.unblurAlways(this.banishTarget.checked);
    });
  }

  isAlwaysDisabled() {
    return this.banishTarget.checked || !this.mouseoverTarget.checked;
  }

  updateUnblurAlwaysCss() {
    this.alwaysTarget.disabled = this.isAlwaysDisabled();
    let classes = this.alwaysTarget.parentNode.classList;
    if (this.isAlwaysDisabled()) classes.add('opacity-40');
    else                         classes.remove('opacity-40');
  }
}
