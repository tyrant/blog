import { Controller } from '@hotwired/stimulus'

export default class ModalController extends Controller {
  connect(): void {
    this.possiblyOpenIrritateModal();
  }

  possiblyOpenIrritateModal(): void {
    if (this.isTestEnvBro()) return;
    if (!(this.isBroughtOn())) return;
    if (Math.random() > 0.98) return;

    setTimeout(() => {
      document.getElementById('modal_irritate')
        ?.dispatchEvent(new CustomEvent('open-modal'));
    }, window.randomInteger({ floor: 1000, ceil: 3000 }));
  }

  isTestEnvBro(): boolean {
    return new URLSearchParams(window.location.search).get('irritate') == 'nahtestenvbro'
  }
  
  isBroughtOn(): boolean {
    return new URLSearchParams(window.location.search).get('irritate') == 'bringiton'
  }
}
