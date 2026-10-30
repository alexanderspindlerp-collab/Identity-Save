const repairState = {
  open: false,
  session: null,
  damage: null,
  placements: [],
  maxParts: 5,
  dragItem: null,
  ghostEl: null,
  pointerDragging: false,
};

const repairEls = {
  app: document.getElementById('repair-app'),
  title: document.getElementById('repair-title'),
  subtitle: document.getElementById('repair-subtitle'),
  invList: document.getElementById('repair-inv-list'),
  partCount: document.getElementById('repair-part-count'),
  statusGrid: document.getElementById('repair-status-grid'),
  plate: document.getElementById('repair-plate'),
  owner: document.getElementById('repair-owner'),
  hint: document.getElementById('repair-hint'),
  submit: document.getElementById('repair-submit'),
  close: document.getElementById('repair-close'),
  toast: document.getElementById('repair-toast'),
};

const zoneSlots = {
  engine: document.getElementById('slot-engine'),
  body: document.getElementById('slot-body'),
  windows: document.getElementById('slot-windows'),
  wheels: document.getElementById('slot-wheels'),
  tank: document.getElementById('slot-tank'),
  universal: document.getElementById('slot-universal'),
};

const partIcons = {
  wrench: '🔧',
  toolbox: '🧰',
  body: '🛠️',
  tank: '⛽',
  wheel: '🛞',
  part: '⚙️',
};

const statusMeta = {
  engine: { label: 'Motor', icon: '⚙️', key: 'engine' },
  body: { label: 'Karoseri', icon: '🚗', key: 'body' },
  wheels: { label: 'Hjul', icon: '🛞', key: 'wheels' },
  tank: { label: 'Tank', icon: '⛽', key: 'tank' },
};

const zoneDamageKey = {
  engine: 'engine',
  body: 'body',
  windows: 'body',
  wheels: 'wheels',
  tank: 'tank',
  universal: null,
};

function repairPost(endpoint, data) {
  return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {}),
  });
}

function healthClass(value) {
  if (value >= 75) return 'is-ok';
  if (value >= 40) return 'is-warn';
  return 'is-damaged';
}

function getZoneHealth(zone) {
  const key = zoneDamageKey[zone];
  if (!key) return 100;
  return Math.max(0, Math.min(100, Number(repairState.damage?.[key]) || 0));
}

function canPlaceOnZone(item, zone) {
  if (!item || !zone) return false;
  const zones = item.zones || [];
  if (zones.includes('universal')) return true;
  if (zone === 'universal') return zones.length > 0;
  if (zone === 'windows') return zones.includes('body') || zones.includes('universal');
  return zones.includes(zone);
}

function usedCountForItem(name) {
  return repairState.placements.filter((p) => p.name === name).length;
}

function showRepairToast(msg) {
  if (!repairEls.toast || !msg) return;
  repairEls.toast.textContent = msg;
  repairEls.toast.hidden = false;
  clearTimeout(showRepairToast._t);
  showRepairToast._t = setTimeout(() => { repairEls.toast.hidden = true; }, 2400);
}

function renderStatusGrid() {
  const damage = repairState.damage || {};
  repairEls.statusGrid.innerHTML = Object.keys(statusMeta).map((id) => {
    const meta = statusMeta[id];
    const value = Math.max(0, Math.min(100, Number(damage[meta.key]) || 0));
    const cls = healthClass(value);
    return `
      <div class="rp-health-cell ${cls}">
        <div class="rp-health-cell-icon">${meta.icon}</div>
        <span class="rp-health-cell-label">${meta.label}</span>
        <span class="rp-health-cell-pct">${value}%</span>
      </div>
    `;
  }).join('');
}

function updateZoneHealthLabels() {
  document.querySelectorAll('.rp-zone-pct[data-zone-pct]').forEach((el) => {
    const key = el.dataset.zonePct;
    const zoneEl = el.closest('.repair-zone');
    const zone = zoneEl?.dataset.zone;
    const value = getZoneHealth(zone || key);
    el.innerHTML = `Helbred: <em>${value}%</em>`;
    if (zoneEl) {
      zoneEl.classList.remove('is-ok', 'is-warn', 'is-damaged');
      zoneEl.classList.add(healthClass(value));
    }
  });
}

function updateZonePositions(zones) {
  if (!zones || typeof zones !== 'object') return;

  document.querySelectorAll('.repair-zone').forEach((zoneEl) => {
    const zone = zoneEl.dataset.zone;
    const pos = zones[zone];
    if (!pos) return;

    if (pos.visible) {
      zoneEl.style.setProperty('--zx', `${pos.x}%`);
      zoneEl.style.setProperty('--zy', `${pos.y}%`);
      zoneEl.classList.remove('is-offscreen');
    } else {
      zoneEl.classList.add('is-offscreen');
    }
  });
}

function clearZoneHighlights() {
  document.querySelectorAll('.repair-zone.is-over').forEach((el) => el.classList.remove('is-over'));
}

function highlightZoneAtPoint(clientX, clientY) {
  clearZoneHighlights();
  if (!repairState.pointerDragging || !repairState.dragItem) return;

  const hit = document.elementFromPoint(clientX, clientY);
  const zoneEl = hit?.closest('.repair-zone');
  if (!zoneEl || zoneEl.classList.contains('is-offscreen')) return;

  const zone = zoneEl.dataset.zone;
  if (canPlaceOnZone(repairState.dragItem, zone)) {
    zoneEl.classList.add('is-over');
  }
}

function renderInventory() {
  const inventory = repairState.session?.inventory || [];
  repairEls.invList.innerHTML = inventory.length
    ? inventory.map((item) => {
        const used = usedCountForItem(item.name);
        const available = Math.max(0, (item.count || 0) - used);
        const disabled = available <= 0 || repairState.placements.length >= repairState.maxParts;
        const iconKey = item.icon || 'part';
        return `
          <div class="repair-part repair-part--${iconKey}${disabled ? ' is-used' : ''}"
               data-item="${item.name}"
               data-draggable="${disabled ? 'false' : 'true'}">
            <div class="repair-part-icon">${partIcons[iconKey] || partIcons.part}</div>
            <div class="repair-part-body">
              <h4>${item.label || item.name}</h4>
              <p>${item.desc || ''}</p>
            </div>
            <div class="repair-part-qty">×${available}</div>
          </div>
        `;
      }).join('')
    : '<p class="rp-parts-empty">Ingen reparationsdele i inventory.</p>';
}

function findPlacementForZone(zone) {
  return repairState.placements.find((p) => (p.displayZone || p.zone) === zone);
}

function renderZoneSlots() {
  Object.keys(zoneSlots).forEach((zone) => {
    const slot = zoneSlots[zone];
    const zoneEl = slot?.closest('.repair-zone');
    const placement = findPlacementForZone(zone);

    if (zoneEl) {
      zoneEl.classList.toggle('has-part', !!placement);
      if (zone !== 'universal') {
        const value = getZoneHealth(zone);
        zoneEl.classList.remove('is-ok', 'is-warn', 'is-damaged');
        zoneEl.classList.add(healthClass(value));
      }
    }

    if (!slot) return;
    if (!placement) {
      slot.innerHTML = '';
      return;
    }

    const icon = partIcons[findInventoryItem(placement.name)?.icon] || '🔧';
    slot.innerHTML = `
      <div class="repair-zone-filled">
        <span class="rp-filled-icon">${icon}</span>
        <strong>${placement.label}</strong>
        <button type="button" data-remove-zone="${zone}" title="Fjern">×</button>
      </div>
    `;
    slot.querySelector('[data-remove-zone]')?.addEventListener('click', (e) => {
      e.stopPropagation();
      removePlacement(zone);
    });
  });

  updateZoneHealthLabels();
}

function updateRepairUI() {
  const count = repairState.placements.length;
  repairEls.partCount.textContent = `${count} / ${repairState.maxParts}`;
  repairEls.submit.disabled = count === 0;
  repairEls.hint.textContent = count > 0
    ? `${count} del${count > 1 ? 'e' : ''} monteret — klar til reparation`
    : 'Træk dele til ikonerne på bilen';
  renderInventory();
  renderZoneSlots();
}

function findInventoryItem(name) {
  return (repairState.session?.inventory || []).find((item) => item.name === name);
}

function endPointerDrag(clientX, clientY) {
  const item = repairState.dragItem;
  repairState.pointerDragging = false;
  repairState.dragItem = null;

  document.querySelectorAll('.repair-part.is-dragging').forEach((el) => el.classList.remove('is-dragging'));

  if (repairState.ghostEl) {
    repairState.ghostEl.remove();
    repairState.ghostEl = null;
  }

  clearZoneHighlights();

  if (!item) return;

  const hit = document.elementFromPoint(clientX, clientY);
  const zoneEl = hit?.closest('.repair-zone');
  if (zoneEl && !zoneEl.classList.contains('is-offscreen')) {
    addPlacement(zoneEl.dataset.zone, item);
  }
}

function startPointerDrag(card, e) {
  const name = card.dataset.item;
  const item = findInventoryItem(name);
  if (!item) return;
  if (repairState.placements.length >= repairState.maxParts) return;
  if (usedCountForItem(name) >= (item.count || 0)) return;

  repairState.dragItem = item;
  repairState.pointerDragging = true;
  card.classList.add('is-dragging');

  repairState.ghostEl = document.createElement('div');
  repairState.ghostEl.className = 'repair-ghost';
  repairState.ghostEl.textContent = item.label || item.name;
  repairState.ghostEl.style.left = `${e.clientX}px`;
  repairState.ghostEl.style.top = `${e.clientY}px`;
  document.body.appendChild(repairState.ghostEl);

  const onMove = (ev) => {
    if (!repairState.pointerDragging) return;
    if (repairState.ghostEl) {
      repairState.ghostEl.style.left = `${ev.clientX}px`;
      repairState.ghostEl.style.top = `${ev.clientY}px`;
    }
    highlightZoneAtPoint(ev.clientX, ev.clientY);
  };

  const onUp = (ev) => {
    document.removeEventListener('mousemove', onMove);
    endPointerDrag(ev.clientX, ev.clientY);
  };

  document.addEventListener('mousemove', onMove);
  document.addEventListener('mouseup', onUp, { once: true });
}

function bindPartPointerDrag() {
  repairEls.invList.addEventListener('mousedown', (e) => {
    if (!repairState.open || repairState.pointerDragging) return;
    const card = e.target.closest('.repair-part[data-draggable="true"]');
    if (!card) return;
    e.preventDefault();
    startPointerDrag(card, e);
  });
}

function removePlacement(zone) {
  repairState.placements = repairState.placements.filter((p) => (p.displayZone || p.zone) !== zone);
  updateRepairUI();
}

function addPlacement(zone, item) {
  if (!item || !canPlaceOnZone(item, zone)) {
    showRepairToast('Denne del passer ikke her.');
    return false;
  }
  if (repairState.placements.length >= repairState.maxParts) {
    showRepairToast('Maks 5 dele ad gangen.');
    return false;
  }
  if (usedCountForItem(item.name) >= (item.count || 0)) return false;

  repairState.placements = repairState.placements.filter((p) => (p.displayZone || p.zone) !== zone);

  repairState.placements.push({
    name: item.name,
    label: item.label || item.name,
    zone: zone === 'windows' ? 'body' : zone,
    displayZone: zone,
    power: item.power || 0,
  });
  updateRepairUI();
  showRepairToast(`${item.label || item.name} monteret`);
  return true;
}

function openRepairUI(payload) {
  repairState.open = true;
  repairState.session = payload.session || {};
  repairState.damage = payload.damage || {};
  repairState.placements = [];
  repairState.maxParts = Number(repairState.session.maxParts) || 5;

  const company = String(repairState.session.companyName || 'Værksted').trim();
  repairEls.title.textContent = company;
  repairEls.subtitle.textContent = 'Find skader og reparer køretøjet';
  repairEls.plate.textContent = repairState.session.plate || repairState.damage.plate || '—';
  repairEls.owner.textContent = repairState.session.ownerName
    ? `Ejer: ${repairState.session.ownerName}`
    : 'Ukendt ejer';

  renderStatusGrid();
  updateRepairUI();
  repairEls.app.classList.remove('hidden');
}

function closeRepairUI() {
  repairState.open = false;
  repairState.session = null;
  repairState.damage = null;
  repairState.placements = [];
  repairState.pointerDragging = false;
  repairState.dragItem = null;
  if (repairState.ghostEl) {
    repairState.ghostEl.remove();
    repairState.ghostEl = null;
  }
  clearZoneHighlights();
  repairEls.app.classList.add('hidden');
  if (repairEls.toast) repairEls.toast.hidden = true;
}

repairEls.close.addEventListener('click', () => repairPost('repairClose'));

repairEls.submit.addEventListener('click', () => {
  if (repairState.placements.length === 0) return;
  repairPost('repairSubmit', {
    placements: repairState.placements.map((p) => ({
      name: p.name,
      label: p.label,
      zone: p.zone,
      power: p.power,
    })),
    damage: repairState.damage,
  });
});

document.addEventListener('keydown', (e) => {
  if (!repairState.open) return;
  if (e.key === 'Escape') repairPost('repairClose');
});

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'openRepair') openRepairUI(msg);
  if (msg.action === 'closeRepair') closeRepairUI();
  if (msg.action === 'updateZonePositions') updateZonePositions(msg.zones);
});

bindPartPointerDrag();
