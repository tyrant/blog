import { Controller } from '@hotwired/stimulus';

export default class extends Controller {

  static targets = ['ceil'];

  static values = {
    pageNo: Number,
    pageSize: Number
  };

  connect() {
    // Courtesy https://leastbad.com/stimulus-power-move
    this.element.stimulusController = this;
  }

  updateCeil({ nsfwBanished }) {
    let ceilCount = window.getStimsBy({ name: 'post-index' }).filter(stim => {
      return !stim.nsfwValue || !nsfwBanished;
    }).length;

    this.ceilTarget.innerHTML = ceilCount + ((this.pageNoValue-1) * this.pageSizeValue);
  }  
}
