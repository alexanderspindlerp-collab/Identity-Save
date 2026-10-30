window.GangLeafletMap = (function () {
  const CENTER_LAT = -119.43;
  const CENTER_LNG = 58.84;
  const SCALE = 1.421 / 100;
  const MAP_BOUNDS = { minLat: -192, maxLat: 0, minLng: 0, maxLng: 128 };
  const MAP_IMAGES = [
    'nui://san_mdt/nui/img/dlk-satellite-map.jpg',
    'nui://san_mdt/nui/img/dlk-master-4096x6144.png',
    'nui://san_mdt/nui/img/satellite-map.png'
  ];

  const GRID_FALLBACK_SVG = `data:image/svg+xml,${encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="960" viewBox="0 0 640 960">' +
    '<defs><pattern id="g" width="40" height="40" patternUnits="userSpaceOnUse">' +
    '<path d="M40 0H0V40" fill="none" stroke="rgba(77,255,200,0.18)" stroke-width="1"/></pattern></defs>' +
    '<rect width="100%" height="100%" fill="#0c1f2e"/>' +
    '<rect width="100%" height="100%" fill="url(#g)"/>' +
    '<line x1="115" y1="0" x2="140" y2="960" stroke="rgba(255,255,255,0.06)" stroke-width="6"/>' +
    '<line x1="320" y1="0" x2="300" y2="960" stroke="rgba(255,255,255,0.06)" stroke-width="6"/>' +
    '<line x1="0" y1="336" x2="640" y2="403" stroke="rgba(255,255,255,0.06)" stroke-width="6"/>' +
    '<line x1="0" y1="691" x2="640" y2="653" stroke="rgba(255,255,255,0.06)" stroke-width="6"/>' +
    '<text x="320" y="460" text-anchor="middle" fill="rgba(255,255,255,0.35)" font-size="22" font-family="Segoe UI,sans-serif">LOS SANTOS</text>' +
    '<text x="320" y="490" text-anchor="middle" fill="rgba(255,255,255,0.2)" font-size="13" font-family="Segoe UI,sans-serif">Gitter-kort (satellit mangler)</text>' +
    '</svg>'
  )}`;

  function gtaToLatLng(x, y) {
    return [CENTER_LAT + SCALE * Number(y), CENTER_LNG + SCALE * Number(x)];
  }

  function latLngToGta(lat, lng) {
    return {
      x: (Number(lng) - CENTER_LNG) / SCALE,
      y: (Number(lat) - CENTER_LAT) / SCALE
    };
  }

  function polygonArea(vertices) {
    if (!vertices || vertices.length < 3) return 0;
    let area = 0;
    for (let i = 0; i < vertices.length; i++) {
      const j = (i + 1) % vertices.length;
      area += vertices[i].x * vertices[j].y - vertices[j].x * vertices[i].y;
    }
    return Math.abs(area / 2);
  }

  function escapeHtml(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function mount(container, options = {}) {
    const host = typeof container === 'string' ? document.querySelector(container) : container;
    if (!host || typeof L === 'undefined') return null;

    const cfg = {
      maxArea: options.maxArea || 180,
      minArea: options.minArea || 20,
      canManage: !!options.canManage,
      myOrgId: options.myOrgId || null,
      onCreate: options.onCreate || null,
      onUpdate: options.onUpdate || null,
      onRename: options.onRename || null,
      onDelete: options.onDelete || null,
      onSelect: options.onSelect || null,
      onDrawStats: options.onDrawStats || null,
      onError: options.onError || null
    };

    host.innerHTML = `
      <div id="gang-leaflet-map"></div>
      <div class="map-overlay-stats" id="gang-map-stats">
        <div id="gang-map-stats-text">0 / ${cfg.maxArea} m²</div>
        <div class="bar"><span id="gang-map-stats-bar" style="width:0%"></span></div>
        <div style="margin-top:4px;opacity:.7;" id="gang-map-stats-pct">0%</div>
      </div>
      <div class="map-tools">
        <button type="button" id="gang-map-draw" title="Tegn territorium">✎</button>
        <button type="button" id="gang-map-cancel-draw" title="Annuller" class="hidden">✕</button>
      </div>
      <div class="draw-hint hidden" id="gang-draw-hint">Klik hjørner · Dobbeltklik for at afslutte · ESC annullerer</div>
    `;

    const mapEl = host.querySelector('#gang-leaflet-map');
    const statsText = host.querySelector('#gang-map-stats-text');
    const statsBar = host.querySelector('#gang-map-stats-bar');
    const statsPct = host.querySelector('#gang-map-stats-pct');
    const drawBtn = host.querySelector('#gang-map-draw');
    const cancelDrawBtn = host.querySelector('#gang-map-cancel-draw');
    const drawHint = host.querySelector('#gang-draw-hint');

    const leafletBounds = [
      [MAP_BOUNDS.minLat, MAP_BOUNDS.minLng],
      [MAP_BOUNDS.maxLat, MAP_BOUNDS.maxLng]
    ];

    const map = L.map(mapEl, {
      crs: L.CRS.Simple,
      minZoom: 2,
      maxZoom: 5,
      zoom: 3,
      center: [-72, 62],
      maxBounds: leafletBounds,
      maxBoundsViscosity: 1,
      attributionControl: false,
      zoomControl: false
    });

    let fallbackLayer = null;
    let satelliteLayer = null;

    const showFallback = () => {
      if (fallbackLayer) return;
      mapEl.classList.add('map-fallback');
      fallbackLayer = L.imageOverlay(GRID_FALLBACK_SVG, leafletBounds, { opacity: 1, interactive: false }).addTo(map);
      if (!host.querySelector('.map-missing-hint')) {
        const hint = document.createElement('div');
        hint.className = 'map-missing-hint';
        hint.innerHTML = 'Satellitkort mangler — læg <strong>dlk-satellite-map.jpg</strong> i <strong>san_mdt/nui/img/</strong>';
        host.appendChild(hint);
      }
    };

    const clearFallback = () => {
      if (fallbackLayer) {
        map.removeLayer(fallbackLayer);
        fallbackLayer = null;
      }
      mapEl.classList.remove('map-fallback');
      host.querySelector('.map-missing-hint')?.remove();
    };

    const trySatellite = (idx = 0) => {
      if (idx >= MAP_IMAGES.length) return;
      const url = MAP_IMAGES[idx];
      let settled = false;
      const next = (ok) => {
        if (settled) return;
        settled = true;
        if (ok) {
          clearFallback();
          if (satelliteLayer) map.removeLayer(satelliteLayer);
          satelliteLayer = L.imageOverlay(url, leafletBounds, { opacity: 0.95 }).addTo(map);
        } else {
          trySatellite(idx + 1);
        }
      };
      setTimeout(() => next(false), 1800);
      const probe = new Image();
      probe.onload = () => next(true);
      probe.onerror = () => next(false);
      probe.src = url;
    };

    showFallback();
    trySatellite(0);

    L.control.zoom({ position: 'bottomright' }).addTo(map);

    const zoneLayers = {};
    let drawMode = false;
    let drawPoints = [];
    let drawPreview = null;
    let drawMarkers = [];
    let selectedZone = null;
    let editingZoneId = null;

    function updateStats(area, maxArea) {
      const max = maxArea || cfg.maxArea;
      const pct = Math.min(100, Math.round((area / max) * 100));
      statsText.textContent = `${Math.round(area)} / ${max} m²`;
      statsBar.style.width = `${pct}%`;
      statsPct.textContent = `${pct}%`;
      if (cfg.onDrawStats) cfg.onDrawStats({ area, max, pct });
    }

    function clearDraw() {
      drawPoints = [];
      drawMarkers.forEach((m) => map.removeLayer(m));
      drawMarkers = [];
      if (drawPreview) {
        map.removeLayer(drawPreview);
        drawPreview = null;
      }
      updateStats(0, cfg.maxArea);
    }

    function finishDraw() {
      if (drawPoints.length < 3) {
        if (cfg.onError) cfg.onError('Tegn mindst 3 punkter.');
        return;
      }
      const area = polygonArea(drawPoints);
      if (area > cfg.maxArea) {
        if (cfg.onError) cfg.onError('Zonen er for stor');
        return;
      }
      if (area < cfg.minArea) {
        if (cfg.onError) cfg.onError('Zonen er for lille');
        return;
      }
      showNameModal('Zone Navn', 'Indtast zonenavn', (name) => {
        if (cfg.onCreate) cfg.onCreate({ name, vertices: drawPoints.slice(), area: Math.round(area) });
        stopDrawMode();
      });
    }

    function stopDrawMode() {
      drawMode = false;
      editingZoneId = null;
      drawBtn.classList.remove('active');
      cancelDrawBtn.classList.add('hidden');
      drawHint.classList.add('hidden');
      clearDraw();
      map.getContainer().style.cursor = '';
    }

    function startDrawMode() {
      if (!cfg.canManage) {
        if (cfg.onError) cfg.onError('Du har ikke tilladelse til at tegne zoner.');
        return;
      }
      drawMode = true;
      drawBtn.classList.add('active');
      cancelDrawBtn.classList.remove('hidden');
      drawHint.classList.remove('hidden');
      clearDraw();
      map.getContainer().style.cursor = 'crosshair';
    }

    function buildPopup(zone) {
      const isMine = cfg.myOrgId && zone.orgId === cfg.myOrgId;
      const canEdit = isMine && cfg.canManage;
      const pressure = zone.myPressure?.pressure || 0;
      const required = zone.captureRequired || 500;
      const owner = zone.isNeutral ? 'Neutralt' : (zone.orgName || 'Ejet');

      let actions = '';
      if (canEdit) {
        actions = `
          <div class="zone-popup-actions">
            <button type="button" data-act="edit">Rediger</button>
            <button type="button" data-act="rename">Omdøb</button>
            <button type="button" data-act="delete" class="danger">Slet</button>
          </div>`;
      } else if (!zone.isNeutral && !isMine) {
        actions = `<p style="margin-top:8px;">Overtagelse: ${pressure} / ${required} XP</p>`;
      }

      return `
        <div class="zone-popup-card" data-zone-id="${zone.id}">
          <h4>${escapeHtml(zone.name)}</h4>
          <p>Ejer: ${escapeHtml(owner)} · ${Math.round(zone.area || 0)} m²</p>
          <p>Points ${pressure} / ${required}</p>
          ${actions}
        </div>`;
    }

    function bindPopupActions(popup, zone) {
      const el = popup.getElement();
      if (!el) return;
      el.querySelectorAll('[data-act]').forEach((btn) => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const act = btn.dataset.act;
          if (act === 'rename') {
            showNameModal('Omdøb zone', zone.name, (name) => {
              if (cfg.onRename) cfg.onRename(zone.id, name);
            });
          } else if (act === 'delete') {
            if (cfg.onDelete) cfg.onDelete(zone.id);
          } else if (act === 'edit') {
            startEditZone(zone);
          }
          map.closePopup();
        });
      });
    }

    function startEditZone(zone) {
      if (!zone.vertices || zone.vertices.length < 3) return;
      editingZoneId = zone.id;
      stopDrawMode();
      drawMode = true;
      drawPoints = zone.vertices.map((v) => ({ x: v.x, y: v.y }));
      drawHint.textContent = 'Træk hjørner · Dobbeltklik for at gemme';
      drawHint.classList.remove('hidden');
      cancelDrawBtn.classList.remove('hidden');
      redrawPreview();
      updateStats(polygonArea(drawPoints), cfg.maxArea);
    }

    function redrawPreview() {
      if (drawPreview) map.removeLayer(drawPreview);
      if (drawPoints.length < 2) return;
      const latlngs = drawPoints.map((p) => gtaToLatLng(p.x, p.y));
      drawPreview = L.polygon(latlngs, {
        color: '#4dffc8',
        fillColor: '#4dffc8',
        fillOpacity: 0.25,
        weight: 2,
        dashArray: '6 4'
      }).addTo(map);
    }

    function renderZones(zones) {
      Object.values(zoneLayers).forEach((layer) => map.removeLayer(layer));
      Object.keys(zoneLayers).forEach((k) => delete zoneLayers[k]);

      (zones || []).forEach((zone) => {
        if (!zone.vertices || zone.vertices.length < 3) return;
        const latlngs = zone.vertices.map((v) => gtaToLatLng(v.x, v.y));
        const color = zone.isMine ? (zone.orgColor || '#4ade80') : (zone.orgColor || zone.color || '#94a3b8');
        const layer = L.polygon(latlngs, {
          color,
          fillColor: color,
          fillOpacity: zone.isNeutral ? 0.18 : 0.32,
          weight: 2
        }).addTo(map);

        layer.on('click', (e) => {
          L.DomEvent.stopPropagation(e);
          selectedZone = zone;
          const popup = L.popup({ closeButton: true, maxWidth: 260 })
            .setLatLng(e.latlng)
            .setContent(buildPopup(zone))
            .openOn(map);
          bindPopupActions(popup, zone);
          if (cfg.onSelect) cfg.onSelect(zone);
          updateStats(zone.area || polygonArea(zone.vertices), cfg.maxArea);
        });

        zoneLayers[zone.id] = layer;
      });
    }

    map.on('click', (e) => {
      if (!drawMode) return;
      const gta = latLngToGta(e.latlng.lat, e.latlng.lng);
      drawPoints.push({ x: gta.x, y: gta.y });
      const marker = L.circleMarker(e.latlng, { radius: 4, color: '#fff', fillColor: '#4dffc8', fillOpacity: 1, weight: 1 }).addTo(map);
      drawMarkers.push(marker);
      redrawPreview();
      updateStats(polygonArea(drawPoints), cfg.maxArea);
    });

    map.on('dblclick', (e) => {
      if (!drawMode) return;
      L.DomEvent.stopPropagation(e);
      if (editingZoneId) {
        const area = polygonArea(drawPoints);
        if (area > cfg.maxArea) {
          if (cfg.onError) cfg.onError('Zonen er for stor');
          return;
        }
        if (cfg.onUpdate) cfg.onUpdate(editingZoneId, drawPoints.slice(), Math.round(area));
        editingZoneId = null;
        stopDrawMode();
        return;
      }
      finishDraw();
    });

    drawBtn.addEventListener('click', () => {
      if (drawMode && !editingZoneId) stopDrawMode();
      else startDrawMode();
    });
    cancelDrawBtn.addEventListener('click', () => {
      editingZoneId = null;
      stopDrawMode();
    });

    setTimeout(() => map.invalidateSize(), 80);
    setTimeout(() => map.invalidateSize(), 300);

    return {
      map,
      setZones: renderZones,
      stopDraw: stopDrawMode,
      invalidate() { map.invalidateSize(); },
      destroy() {
        map.remove();
        host.innerHTML = '';
      }
    };
  }

  function showNameModal(title, value, onConfirm) {
    const backdrop = document.createElement('div');
    backdrop.className = 'gang-modal-backdrop';
    backdrop.innerHTML = `
      <div class="gang-modal">
        <h3>${escapeHtml(title)}</h3>
        <input type="text" id="gang-zone-name" maxlength="48" placeholder="Indtast zonenavn" value="${escapeHtml(value || '')}" />
        <div class="gang-modal-actions">
          <button type="button" data-act="cancel">Annullere</button>
          <button type="button" data-act="ok">Bekræft</button>
        </div>
      </div>
    `;
    document.body.appendChild(backdrop);
    const input = backdrop.querySelector('#gang-zone-name');
    input.focus();
    input.select();

    const close = () => backdrop.remove();
    backdrop.querySelector('[data-act="cancel"]').onclick = close;
    backdrop.querySelector('[data-act="ok"]').onclick = () => {
      const name = input.value.trim();
      if (!name) return;
      close();
      onConfirm(name);
    };
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') backdrop.querySelector('[data-act="ok"]').click();
      if (e.key === 'Escape') close();
    });
  }

  let toastTimer = null;

  function showToast(message, title = 'Fejl') {
    if (toastTimer) clearTimeout(toastTimer);
    document.querySelectorAll('.gang-toast').forEach((el) => el.remove());
    const el = document.createElement('div');
    el.className = 'gang-toast';
    el.innerHTML = `<span class="icon">🎭</span><div><div>${escapeHtml(title)}</div><div class="sub">${escapeHtml(message)}</div></div>`;
    document.body.appendChild(el);
    toastTimer = setTimeout(() => el.remove(), 3200);
  }

  return { mount, gtaToLatLng, latLngToGta, polygonArea, showNameModal, showToast };
})();
