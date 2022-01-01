import { getCookie } from "./cookie";

export function setNsfwSlidersChangeEvents() {

  document.querySelector('.unblur-nsfw-on-mouseover').addEventListener('change', function() {
    var checked = this.checked;

    document.querySelectorAll('.card.nsfw').forEach(function(card) {
      if (checked) card.classList.add('unblurred-on-mouseover');
      else         card.classList.remove('unblurred-on-mouseover');
    });
    document.cookie = `unblur_nsfw_on_mouseover=${checked}; max-age=${_fourWeeksInSeconds()};`;
    console.log('unblur_nsfw_on_mouseover', getCookie('unblur_nsfw_on_mouseover'))
  });

  document.querySelector('.unblur-nsfw-always').addEventListener('change', function() {
    var checked = this.checked;

    document.querySelectorAll('.card.nsfw').forEach(function(card) {
      if (checked) card.classList.remove('blurred');
      else         card.classList.add('blurred');
    });
    document.cookie = `unblur_nsfw_always=${checked}; max-age=${_fourWeeksInSeconds()};`;
    console.log('unblur_nsfw_always', getCookie('unblur_nsfw_always'))
  });
}

var _fourWeeksInSeconds = function() {
  return 60*60*24*28;
}