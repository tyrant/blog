import { Controller } from '@hotwired/stimulus';

export default class FlashController extends Controller {
  static targets = ['banner'];

  declare readonly bannerTarget: HTMLElement;

  close(): void {
    this.bannerTarget.remove();
  }
}
