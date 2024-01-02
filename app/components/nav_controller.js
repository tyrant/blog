import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['sexyverseSubmenu', 'allpostsSubmenu', 'mobile'];

  closeShite(e) {
    if (e.target.closest('#sexyverseIcon') == null) {
      this.sexyverseSubmenuTarget.classList.add('hidden');
      this.sexyverseSubmenuTarget.classList.remove('block');
    }
    if (e.target.closest('#allpostsIcon') == null) {
      this.allpostsSubmenuTarget.classList.add('hidden');
      this.allpostsSubmenuTarget.classList.remove('block');
    }
  }

  toggleSexyverseSubmenu(e) {
    e.preventDefault();
    ['hidden', 'block'].forEach(c => {
      this.sexyverseSubmenuTarget.classList.toggle(c);
    });
  }

  toggleAllpostsSubmenu(e) {
    e.preventDefault();
    ['hidden', 'block'].forEach(c => {
      this.allpostsSubmenuTarget.classList.toggle(c);
    });
  }

  toggleMobile() {
    ['hidden', 'block'].forEach(c => {
      this.mobileTarget.classList.toggle(c);
    });
  }
}
