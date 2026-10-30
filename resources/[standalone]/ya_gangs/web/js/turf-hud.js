(function () {
  var RING_LEN = 2 * Math.PI * 18;
  var els = {
    root: document.getElementById('turf-hud'),
    zoneName: document.getElementById('turf-zone-name'),
    pct: document.getElementById('turf-pct'),
    ringFill: document.getElementById('turf-ring-fill'),
    barFill: document.getElementById('turf-bar-fill'),
    points: document.getElementById('turf-points')
  };

  function formatPoints(n) {
    return String(Math.round(Number(n) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  function updateHud(data) {
    if (!els.root) return;
    var pct = Math.max(0, Math.min(100, Math.round(Number(data.pct) || 0)));
    var pressure = Number(data.pressure) || 0;
    var required = Number(data.required) || 500;

    els.zoneName.textContent = data.zoneName || 'Territorium';
    els.pct.textContent = pct + '%';
    els.points.textContent = formatPoints(pressure) + ' / ' + formatPoints(required);
    els.barFill.style.width = pct + '%';

    if (els.ringFill) {
      var offset = RING_LEN * (1 - pct / 100);
      els.ringFill.style.strokeDashoffset = String(offset);
    }

    els.root.classList.remove('hidden');
  }

  function hideHud() {
    if (!els.root) return;
    els.root.classList.add('hidden');
  }

  window.addEventListener('message', function (event) {
    var msg = event.data || {};
    if (msg.action === 'turfHudShow') updateHud(msg);
    if (msg.action === 'turfHudHide') hideHud();
  });
})();
