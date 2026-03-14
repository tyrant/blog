import { Controller } from '@hotwired/stimulus';

export default class PrevNekController extends Controller {
  static values = { 
    duration: Number,
    prevIsNsfw: Boolean,
    nekIsNsfw: Boolean
  }

  static targets = ['prev', 'prevArrow', 'nek', 'nekArrow'];

  declare readonly prevTarget: HTMLElement;
  declare readonly prevArrowTarget: HTMLElement;
  declare readonly nekTarget: HTMLElement;
  declare readonly nekArrowTarget: HTMLElement;
  declare durationValue: number;
  declare prevIsNsfwValue: boolean;
  declare nekIsNsfwValue: boolean;

  static getNsfwContainingStims(): PrevNekController[] {
    return window.getStimsBy({ name: 'prev-nek' })
                 .filter(s => { 
                   const ctrl = s as PrevNekController;
                   return ctrl.prevIsNsfwValue || ctrl.nekIsNsfwValue;
                 }) as PrevNekController[];
  }

  // Courtesy https://leastbad.com/stimulus-power-move
  connect(): void {
    (this.element as Element).stimulusController = this;
  }

  initialize(): void {
    this.prevNekArrowsMove();
  }

  unblurOnFutureMouseover(yes: boolean): void {
    this.nsfwClasslists().forEach(c => {
      if (yes) c.add('hover:blur-none');
      else     c.remove('hover:blur-none');
    });
  }

  blurNow(): void {
    this.nsfwClasslists().forEach(c => c.add('blur-xs'));
  }

  unblurNow(): void {
    this.nsfwClasslists().forEach(c => c.remove('blur-xs'));
  }

  prevNekArrowsMove(): void {
    [this.prevTarget, this.prevArrowTarget].forEach(t => {
      const pc = this.prevArrowTarget.classList;
      t.addEventListener('mouseover', () => pc.add('-translate-x-4'));
      t.addEventListener('mouseout',  () => pc.remove('-translate-x-4'));
    });

    [this.nekTarget, this.nekArrowTarget].forEach(t => {
      const nc = this.nekArrowTarget.classList;
      t.addEventListener('mouseover', () => nc.add('translate-x-4'));
      t.addEventListener('mouseout',  () => nc.remove('translate-x-4'));
    });
  }

  private nsfwClasslists(): DOMTokenList[] {
    return (['prev', 'nek'] as const).map(pn => {
      if (this[`${pn}IsNsfwValue` as keyof this]) return this[`${pn}Target` as keyof this] as HTMLElement;
      return null;
    }).filter(Boolean).map(n => n!.classList);
  }
}
