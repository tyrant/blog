
// 2% of the time, the Irritate modal will appear 20-30 seconds after page load -
// unless ?irritate=bringiton
export function loadIrritateModal() {
  var urlParams = new URLSearchParams(window.location.search);
  if (!(urlParams.get('irritate') == 'bringiton' || Math.random() > 0.98))
    return;

  setTimeout(function() { 
    new bootstrap.Modal(document.getElementById('irritate_modal'), {}).show(); 
  }, _between10And30SecondsInMilliseconds());
}

var _between10And30SecondsInMilliseconds = function() {
  return parseInt((Math.random() * 20) + 10);
}