import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['booksMenu', 'booksSubmenu', 'blogMenu', 'blogSubmenu', 'mobile'];

  openBooksSubmenu(e) {
    e.preventDefault();
    this.booksSubmenuTarget.classList.replace('hidden', 'block');
  }

  // This event-handler function is attached on the <li> root node enclosing
  // both our 'Novels' nav-item text and its open/close submenu ... and fires
  // upon mouse-outing any of them. If we mouseout from the submenu we'd like
  // to close it ... unless we're moving the pointer to the nav-text. Then keep
  // it open. The conditional detects this and early-returns.
  closeBooksSubmenu(e) {
    e.preventDefault();
    if (e.target.closest(this.booksMenu)) return;
    this.booksSubmenuTarget.classList.replace('block', 'hidden');
  }
 
  openBlogSubmenu(e) {
    e.preventDefault();
    this.blogSubmenuTarget.classList.replace('hidden', 'block');
  }

  closeBlogSubmenu(e) {
    e.preventDefault();
    if (e.target.closest(this.blogMenu)) return;
    this.blogSubmenuTarget.classList.replace('block', 'hidden');
  }

  openAboutSubmenu() {}
  closeAboutSubmenu() {}

  toggleMobile() {
    ['hidden', 'block'].forEach(c => {
      this.mobileTarget.classList.toggle(c);
    });
  }
}
