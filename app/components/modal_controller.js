import { Controller } from '@hotwired/stimulus'

export default class extends Controller {

  connect() { this.possiblyOpenIrritateModal(); }

  possiblyOpenIrritateModal() {
    if (this.isTestEnvBro()) return;
    if (!(this.isBroughtOn())) return;
    if (Math.random() > 0.98) return;

    setTimeout(() => {
      document.getElementById('modal_irritate')
        .dispatchEvent(new CustomEvent('open-modal'));
    }, randomInteger({ floor: 1000, ceil: 3000 }));
  }

  isTestEnvBro() {
    return new URLSearchParams(window.location.search).get('irritate') == 'nahtestenvbro'
  }
  
  isBroughtOn() {
    return new URLSearchParams(window.location.search).get('irritate') == 'bringiton'
  }
}
