import { Controller } from '@hotwired/stimulus'

export default class extends Controller {

  connect() { this.possiblyOpenIrritateModal(); }

  possiblyOpenIrritateModal() {
    if (!(this.isBroughtOn() || Math.random() > 0.98)) return;

    setTimeout(() => {
      document.getElementById('modal_stim')
        .dispatchEvent(new CustomEvent('open-irritate-modal'));
    }, randomInteger({ floor: 1000, ceil: 3000 }));
  }
  
  isBroughtOn() {
    return new URLSearchParams(window.location.search).get('irritate') == 'bringiton'
  }
}
