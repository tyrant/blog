import { Controller } from "@hotwired/stimulus"

export default class NavController extends Controller {
  static targets = ['booksMenu', 'booksSubmenu', 'blogMenu', 'blogSubmenu', 'mobile', 'landingDiv', 'arrow'];

  declare readonly booksMenuTarget: HTMLElement;
  declare readonly booksSubmenuTarget: HTMLElement;
  declare readonly blogMenuTarget: HTMLElement;
  declare readonly blogSubmenuTarget: HTMLElement;
  declare readonly mobileTarget: HTMLElement;
  declare readonly landingDivTarget: HTMLElement;
  declare readonly arrowTarget: HTMLElement;

  initialize(): void {
    this.landingDivShowHide();
    this.landingLinkArrowMove();
  }

  openBooksSubmenu(e: Event): void {
    e.preventDefault();
    this.booksSubmenuTarget.classList.replace('hidden', 'block');
  }

  // This event-handler function is attached on the <li> root node enclosing
  // both our 'Novels' nav-item text and its open/close submenu ... and fires
  // upon mouse-outing any of them. If we mouseout from the submenu we'd like
  // to close it ... unless we're moving the pointer to the nav-text. Then keep
  // it open. The conditional detects this and early-returns.
  closeBooksSubmenu(e: MouseEvent): void {
    e.preventDefault();
    if ((e.target as Element).closest(this.booksMenu)) return;
    this.booksSubmenuTarget.classList.replace('block', 'hidden');
  }
 
  openBlogSubmenu(e: Event): void {
    e.preventDefault();
    this.blogSubmenuTarget.classList.replace('hidden', 'block');
  }

  closeBlogSubmenu(e: MouseEvent): void {
    e.preventDefault();
    if ((e.target as Element).closest(this.blogMenu)) return;
    this.blogSubmenuTarget.classList.replace('block', 'hidden');
  }

  openContactSubmenu(): void {}
  closeContactSubmenu(): void {}

  toggleMobile(): void {
    ['hidden', 'block'].forEach(c => {
      this.mobileTarget.classList.toggle(c);
    });
  }

  // Shows/hides the landing-page link.
  // Odd bug, or unexpected behaviour: if you Cmd-R the page when scrolled
  // down, scroll events don't start firing until actual scrolling happens ...
  // but if you click the Refresh button, a single scroll event happens on page
  // load, meaning that the landing-page link renders and immediately
  // disappears. Odd. This `firstEvent` flag-hack sidesteps it.
  landingDivShowHide(): void {
    let firstEvent = true;
    document.addEventListener('scroll', () => {
      const landingDivHeight = this.landingDivTarget.offsetHeight
      if (window.scrollY < landingDivHeight) {
        this.landingDivTarget.style.marginTop = '0';
      } else {
        if (!firstEvent)
          this.landingDivTarget.style.marginTop = `-${landingDivHeight}px`;
        firstEvent = false;
      }
    });
  }

  landingLinkArrowMove(): void {
    this.landingDivTarget.addEventListener('mouseover', () => {
      this.arrowTarget.classList.add('translate-x-2');
    });
    this.landingDivTarget.addEventListener('mouseout', () => {
      this.arrowTarget.classList.remove('translate-x-2');
    });
  }
}
