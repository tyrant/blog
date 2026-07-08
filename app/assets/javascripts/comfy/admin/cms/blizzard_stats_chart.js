import Chart from 'chart.js/auto';

// Renders the Substack Blizzard "Totals over time" line chart inside its modal.
// It renders on first open (not page load) so the canvas has real dimensions —
// Chart.js sizes to 0 in a hidden (display:none) modal. No-ops off the Blizzard
// page. The series (labels + posts/entries/notes arrays) comes from data-series.
const render = (canvas) => {
  let series;
  try {
    series = JSON.parse(canvas.dataset.series || '{}');
  } catch (e) {
    return;
  }
  if (!Array.isArray(series.labels) || series.labels.length === 0) return;

  const line = (label, data, color) => ({
    label, data, borderColor: color, backgroundColor: color, tension: 0.2, pointRadius: 2,
  });

  new Chart(canvas, {
    type: 'line',
    data: {
      labels: series.labels,
      datasets: [
        line('Posts', series.posts, '#4e79a7'),
        line('Blizzard entries', series.entries, '#59a14f'),
        line('Notes', series.notes, '#e15759'),
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      scales: {
        x: { ticks: { autoSkip: true, maxTicksLimit: 12 } },
        y: { beginAtZero: true },
      },
    },
  });
};

const init = () => {
  const modal = document.getElementById('blizzard-graph-modal');
  const canvas = document.getElementById('blizzard-stats-chart');
  if (!modal || !canvas) return;

  const $ = window.jQuery;
  if ($) {
    let rendered = false;
    $(modal).on('shown.bs.modal', () => {
      if (rendered) return;
      rendered = true;
      render(canvas);
    });
  } else {
    render(canvas); // no jQuery — render eagerly as a fallback
  }
};

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
