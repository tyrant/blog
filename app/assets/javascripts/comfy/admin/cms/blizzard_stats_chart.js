import Chart from 'chart.js/auto';

// Renders the Substack Blizzard "Totals over time" line chart. No-ops unless the
// canvas is on the page, so it's safe to ship in the shared admin bundle. The
// series (labels + posts/entries/notes arrays) is passed via data-series.
const init = () => {
  const canvas = document.getElementById('blizzard-stats-chart');
  if (!canvas) return;

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

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', init);
} else {
  init();
}
