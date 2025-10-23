// Entry point for the build script in your package.json:
import '@hotwired/turbo-rails'

import Alpine from 'alpinejs';
import "./controllers";

Alpine.start();

// `name` must be dasherised: to, e.g., yoink all PostController instances, 
// call getStimsBy({ name: 'post' }).
// Don't forget to add the correct connect() calls! With .stimulusController.
window.getStimsBy = ({ name }) => {
  return [...document.querySelectorAll(`[data-controller="${name}"]`)].map(el => {
    return el.stimulusController;
  });
};

window.fourWeeksInSeconds = () => {
  return 60*60*24*28;
}

window.randomInteger = ({ floor, ceil }) => {
  return parseInt((Math.random() * (ceil - floor)) + floor);
}

// Receives cookie key-value pairs: { cookieName: cookieValue, ... }
window.setCookies = cookieData => {
  Object.keys(cookieData).forEach(name => {
    document.cookie = `${name}=${cookieData[name]}; max-age=${fourWeeksInSeconds()}; path=/`;
  });
}
