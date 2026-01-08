import { Controller } from '@hotwired/stimulus';

declare module '@rails/ujs' {
  const Rails: {
    start(): void;
    fire(element: Element, eventName: string, data?: unknown): boolean;
  };
  export default Rails;
}

declare module 'alpinejs' {
  const Alpine: {
    start(): void;
    data(name: string, callback: () => object): void;
  };
  export default Alpine;
}

declare global {
  interface Window {
    $: JQueryStatic;
    jQuery: JQueryStatic;
    Rails: typeof import('@rails/ujs');
    Stimulus: import('@hotwired/stimulus').Application;
    getStimsBy: (opts: { name: string }) => Controller[];
    fourWeeksInSeconds: () => number;
    randomInteger: (opts: { floor: number; ceil: number }) => number;
    setCookies: (cookieData: Record<string, string | boolean | number>) => void;
  }

  interface Element {
    stimulusController?: Controller;
  }
}

export {};
