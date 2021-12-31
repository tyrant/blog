// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

import Rails from "@rails/ujs"
import * as ActiveStorage from "@rails/activestorage"
import "channels"

Rails.start();
ActiveStorage.start();


document.addEventListener("DOMContentLoaded", function() {
  loadIrritateModal();
});

// 2% of the time, the Irritate modal will appear 20-30 seconds after page load -
// unless ?irritate=bringiton
var loadIrritateModal = function() {
  var urlParams = new URLSearchParams(window.location.search);
  if (urlParams.get('irritate') !== 'bringiton' || Math.random() > 0.98)
    return;

  setTimeout(function() { 
    new bootstrap.Modal(document.getElementById('irritate_modal'), {}).show(); 
  }, tenToThirtySecs());
}

var tenToThirtySecs = function() {
  return parseInt((Math.random() * 20) + 10);
}