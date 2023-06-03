// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

import Rails from "@rails/ujs";
import * as ActiveStorage from "@rails/activestorage";
import Alpine from 'alpinejs';
import "channels";
import "@hotwired/turbo-rails";
import "../controllers";
import "../components";

Rails.start();
ActiveStorage.start();
Alpine.start();

// `name` must be dasherised: to, e.g., yoink all PostIndexController instances, 
// call getStimsBy({ name: 'post-index' }).
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
