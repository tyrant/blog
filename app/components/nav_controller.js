import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ['open', 'closed', 'mobileMenu'];

  // Toggle block/hidden classes on our nav menu icons, and mobile nav menu.
  // Their initial state is: 
  // show the Closed icon; hide the Open icon; hide the mobile menu.
  toggleMobileMenu() {
    this.openTarget.classList.toggle('hidden');
    this.openTarget.classList.toggle('block');

    this.closedTarget.classList.toggle('block');
    this.closedTarget.classList.toggle('hidden');

    this.mobileMenuTarget.classList.toggle('hidden');
    this.mobileMenuTarget.classList.toggle('block');
  }
}
