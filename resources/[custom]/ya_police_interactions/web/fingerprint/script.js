const fpApp = document.getElementById('fingerprintApp');
const fpPads = document.getElementById('fpPads');
const fpProgress = document.getElementById('fpProgress');
const fpStatus = document.getElementById('fpStatus');

let holdMs = 10000;
let totalPads = 3;
let currentPad = 0;
let holding = false;
let holdTimer = null;
let holdStart = 0;
let rafId = null;

function resetScanner() {
  currentPad = 0;
  holding = false;
  fpProgress.style.width = '0%';
  fpStatus.textContent = 'Tryk og hold fingeren på scanneren';
  fpPads.innerHTML = '';
}

function buildPads() {
  fpPads.innerHTML = '';
  for (let i = 0; i < totalPads; i += 1) {
    const pad = document.createElement('button');
    pad.type = 'button';
    pad.className = 'fp-pad';
    pad.dataset.index = String(i);
    pad.innerHTML = `<strong>🖐</strong><span>Finger ${i + 1}</span>`;
    pad.addEventListener('mousedown', () => startHold(i, pad));
    pad.addEventListener('mouseup', stopHold);
    pad.addEventListener('mouseleave', stopHold);
    pad.addEventListener('touchstart', (e) => { e.preventDefault(); startHold(i, pad); });
    pad.addEventListener('touchend', stopHold);
    fpPads.appendChild(pad);
  }
}

function updateProgress() {
  if (!holding) return;
  const elapsed = Date.now() - holdStart;
  const pct = Math.min(100, (elapsed / holdMs) * 100);
  fpProgress.style.width = `${pct}%`;

  if (elapsed >= holdMs) {
    completePad();
    return;
  }

  rafId = requestAnimationFrame(updateProgress);
}

function startHold(index, padEl) {
  if (index !== currentPad) {
    fpStatus.textContent = `Scan finger ${currentPad + 1} først`;
    return;
  }

  holding = true;
  holdStart = Date.now();
  padEl.classList.add('active');
  fpStatus.textContent = `Scanner finger ${index + 1}... hold stille`;
  updateProgress();
}

function stopHold() {
  if (!holding) return;
  holding = false;
  if (rafId) cancelAnimationFrame(rafId);
  fpProgress.style.width = '0%';

  const active = fpPads.querySelector('.fp-pad.active');
  if (active) active.classList.remove('active');

  if (currentPad < totalPads) {
    fpStatus.textContent = 'Hold fingeren nede i hele scanningen';
  }
}

function completePad() {
  holding = false;
  if (rafId) cancelAnimationFrame(rafId);

  const pad = fpPads.querySelector(`[data-index="${currentPad}"]`);
  if (pad) {
    pad.classList.remove('active');
    pad.classList.add('done');
    pad.innerHTML = `<strong>✓</strong><span>OK</span>`;
  }

  currentPad += 1;
  fpProgress.style.width = '0%';

  if (currentPad >= totalPads) {
    fpStatus.textContent = 'Scanning fuldført — gemmer i database...';
    fetch(`https://${GetParentResourceName()}/fingerprintComplete`, { method: 'POST', body: '{}' });
    setTimeout(() => fpApp.classList.add('hidden'), 600);
    return;
  }

  fpStatus.textContent = `Fortsæt med finger ${currentPad + 1}`;
}

window.addEventListener('message', (event) => {
  const msg = event.data || {};

  if (msg.action === 'openFingerprint') {
    holdMs = msg.holdMs || 10000;
    totalPads = msg.pads || 3;
    resetScanner();
    buildPads();
    fpApp.classList.remove('hidden');
  }

  if (msg.action === 'closeFingerprint') {
    fpApp.classList.add('hidden');
    stopHold();
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !fpApp.classList.contains('hidden')) {
    fetch(`https://${GetParentResourceName()}/fingerprintCancel`, { method: 'POST', body: '{}' });
    fpApp.classList.add('hidden');
  }
});
