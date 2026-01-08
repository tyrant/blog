import jQuery from 'jquery';
window.$ = jQuery;
window.jQuery = jQuery;

import Rails from '@rails/ujs';
window.Rails = Rails;
Rails.start();

// Entry point for the build script in your package.json:
import '@hotwired/turbo-rails'

import Alpine from 'alpinejs';
import "./controllers";

Alpine.start();

// `name` must be dasherised: to, e.g., yoink all PostController instances, 
// call getStimsBy({ name: 'post' }).
// Don't forget to add the correct connect() calls! With .stimulusController.
window.getStimsBy = ({ name }: { name: string }) => {
  return [...document.querySelectorAll(`[data-controller="${name}"]`)].map(el => {
    return (el as Element).stimulusController!;
  }).filter(Boolean);
};

window.fourWeeksInSeconds = () => {
  return 60*60*24*28;
}

window.randomInteger = ({ floor, ceil }: { floor: number; ceil: number }) => {
  return parseInt(String((Math.random() * (ceil - floor)) + floor));
}

// Receives cookie key-value pairs: { cookieName: cookieValue, ... }
window.setCookies = (cookieData: Record<string, string | boolean | number>) => {
  Object.keys(cookieData).forEach(name => {
    document.cookie = `${name}=${cookieData[name]}; max-age=${window.fourWeeksInSeconds()}; path=/`;
  });
}
