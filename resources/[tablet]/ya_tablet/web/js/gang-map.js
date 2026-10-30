window.GangLeafletMap = (function () {
  var CENTER_LAT = -119.43;
  var CENTER_LNG = 58.84;
  var SCALE = 1.421 / 100;
  var MAP_BOUNDS = { minLat: -192, maxLat: 0, minLng: 0, maxLng: 128 };
  // Startvisning: Los Santos fylder skærmen (som reference-screenshot).
  var MAP_COVER_INSET = 0.22;
  var MAP_COVER_ZOOM_BOOST = 0.55;
  // Lidt ud fra start, meget ind på gader/niveau.
  var MAP_ZOOM_OUT_LEVELS = 1.25;
  var MAP_MAX_ZOOM = 16;

  function getLeafletBounds(bounds) {
    bounds = bounds || MAP_BOUNDS;
    return [
      [bounds.minLat, bounds.minLng],
      [bounds.maxLat, bounds.maxLng]
    ];
  }

  function getCoverBounds() {
    var h = MAP_BOUNDS.maxLat - MAP_BOUNDS.minLat;
    var w = MAP_BOUNDS.maxLng - MAP_BOUNDS.minLng;
    var insetLat = h * MAP_COVER_INSET;
    var insetLng = w * MAP_COVER_INSET;
    return [
      [MAP_BOUNDS.minLat + insetLat, MAP_BOUNDS.minLng + insetLng],
      [MAP_BOUNDS.maxLat - insetLat, MAP_BOUNDS.maxLng - insetLng]
    ];
  }
  var ZONE_THEME = {
    mine: {
      stroke: '#00f8b9',
      fill: '#00f8b9',
      fillOpacity: 0.24,
      weight: 2.5,
      glow: true,
      className: 'gang-zone-mine'
    },
    rival: {
      stroke: '#ff3b5c',
      fill: '#ef4444',
      fillOpacity: 0.3,
      weight: 2.5,
      glow: true,
      className: 'gang-zone-rival'
    },
    neutral: {
      stroke: '#8b9cb3',
      fill: '#64748b',
      fillOpacity: 0.16,
      weight: 2,
      glow: false,
      className: 'gang-zone-neutral'
    },
    draw: {
      stroke: '#00f8b9',
      fill: '#00f8b9',
      fillOpacity: 0.22,
      weight: 2.5,
      glow: false,
      className: 'gang-zone-draw'
    }
  };

  function zoneThemeFor(zone) {
    if (!zone) return ZONE_THEME.neutral;
    if (zone.isMine === true) return ZONE_THEME.mine;
    if (zone.isNeutral === true) return ZONE_THEME.neutral;
    return ZONE_THEME.rival;
  }

  function pointInPolygon(point, vertices) {
    if (!point || !vertices || vertices.length < 3) return false;
    var inside = false;
    var x = Number(point.x);
    var y = Number(point.y);
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      var xi = Number(vertices[i].x);
      var yi = Number(vertices[i].y);
      var xj = Number(vertices[j].x);
      var yj = Number(vertices[j].y);
      var intersect = ((yi > y) !== (yj > y)) &&
        (x < ((xj - xi) * (y - yi)) / ((yj - yi) || 1e-9) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  function addThemedPolygon(map, latlngs, theme, interactive) {
    var layers = [];
    if (theme.glow) {
      layers.push(L.polygon(latlngs, {
        color: theme.stroke,
        fillColor: theme.fill,
        fillOpacity: 0.1,
        weight: 9,
        opacity: 0.5,
        interactive: false,
        className: theme.className + ' gang-zone-glow'
      }).addTo(map));
    }
    layers.push(L.polygon(latlngs, {
      color: theme.stroke,
      fillColor: theme.fill,
      fillOpacity: theme.fillOpacity,
      weight: theme.weight,
      interactive: interactive !== false,
      className: theme.className
    }).addTo(map));
    if (interactive !== false) {
      layers.push(L.polygon(latlngs, {
        color: 'transparent',
        fillColor: 'transparent',
        fillOpacity: 0.01,
        weight: 0,
        opacity: 0,
        interactive: true,
        bubblingMouseEvents: true,
        className: (theme.className || 'gang-zone') + ' gang-zone-hit'
      }).addTo(map));
    }
    return {
      main: layers[theme.glow ? 1 : 0],
      hit: interactive !== false ? layers[layers.length - 1] : null,
      glow: theme.glow ? layers[0] : null,
      all: layers
    };
  }

  function removeZoneEntry(entry) {
    if (!entry) return;
    if (entry.all) {
      entry.all.forEach(function (layer) { layer.remove(); });
      return;
    }
    if (entry.remove) entry.remove();
  }

  var DEFAULT_MAP_FILES = [
    'nui/img/dlk-satellite-map.jpg',
    'nui/img/dlk-master-4096x6144.png',
    'nui/img/satellite-map.png'
  ];

  function buildDefaultMapUrls() {
    var urls = [];
    var resource = 'san_mdt';
    for (var i = 0; i < DEFAULT_MAP_FILES.length; i++) {
      var file = DEFAULT_MAP_FILES[i];
      urls.push('https://cfx-nui-' + resource + '/' + file);
      urls.push('nui://' + resource + '/' + file);
    }
    return urls;
  }

  function normalizeMapSources(sources) {
    var out = [];
    var seen = {};
    var list = sources && sources.length ? sources : buildDefaultMapUrls();
    for (var i = 0; i < list.length; i++) {
      var url = String(list[i] || '').trim();
      if (!url || seen[url]) continue;
      seen[url] = true;
      out.push(url);
      if (url.indexOf('https://cfx-nui-') !== 0 && url.indexOf('nui://') === 0) {
        var cfx = url.replace(/^nui:\/\//, 'https://cfx-nui-');
        if (!seen[cfx]) {
          seen[cfx] = true;
          out.push(cfx);
        }
      }
    }
    return out.length ? out : buildDefaultMapUrls();
  }

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
    var area = 0;
    for (var i = 0; i < vertices.length; i++) {
      var j = (i + 1) % vertices.length;
      area += vertices[i].x * vertices[j].y - vertices[j].x * vertices[i].y;
    }
    return Math.abs(area / 2);
  }

  function gameAreaToM2(rawArea, divisor) {
    var div = Number(divisor) || 100;
    if (div <= 0) div = 100;
    return (Number(rawArea) || 0) / div;
  }

  function roundM2(area) {
    return Math.round(Number(area) || 0);
  }

  function formatM2(area) {
    var n = roundM2(area);
    return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
  }

  function escapeHtml(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function loadMapOverlay(map, baseEl, hintEl, sources, bounds) {
    if (!map || !baseEl) return null;
    var satelliteLayer = null;
    var mapImages = normalizeMapSources(sources);
    baseEl.classList.add('map-base-fallback');
    var idx = 0;

    function tryNext() {
      if (idx >= mapImages.length) {
        if (hintEl) hintEl.classList.remove('hidden');
        return;
      }
      var url = mapImages[idx++];
      var probe = new Image();
      probe.onload = function () {
        if (satelliteLayer) map.removeLayer(satelliteLayer);
        satelliteLayer = L.imageOverlay(url, bounds, { opacity: 0.95, interactive: false }).addTo(map);
        baseEl.style.display = 'none';
        if (hintEl) hintEl.classList.add('hidden');
        map.invalidateSize();
        if (!map._gangInitialFitDone && map._gangApplyInitial) map._gangApplyInitial();
        if (map._gangBringZonesFront) map._gangBringZonesFront();
      };
      probe.onerror = tryNext;
      probe.src = url;
    }

    tryNext();
    return function () {
      if (satelliteLayer) map.removeLayer(satelliteLayer);
    };
  }

  function bindMapWheel(map, target) {
    if (!map || !target) return;
    target.addEventListener('wheel', function (e) {
      e.preventDefault();
      e.stopPropagation();
      var snap = map.options.zoomSnap || 0.25;
      var delta = e.deltaY > 0 ? -snap : snap;
      var next = map.getZoom() + delta;
      if (next < map.getMinZoom()) next = map.getMinZoom();
      if (next > map.getMaxZoom()) next = map.getMaxZoom();
      var container = map.getContainer();
      var rect = container.getBoundingClientRect();
      var point = L.point(e.clientX - rect.left, e.clientY - rect.top);
      map.setZoomAround(map.containerPointToLatLng(point), next);
    }, { passive: false });
  }

  function snapCoverZoom(map, coverBounds) {
    if (!map || !coverBounds) return null;
    map.invalidateSize(false);
    var size = map.getSize();
    if (!size.x || !size.y) return null;

    var latLngBounds = L.latLngBounds(coverBounds);
    var boundsW = latLngBounds.getEast() - latLngBounds.getWest();
    var boundsH = latLngBounds.getNorth() - latLngBounds.getSouth();
    if (boundsW <= 0 || boundsH <= 0) return null;

    var prevMin = map.getMinZoom();
    var prevMax = map.getMaxZoom();
    map.setMinZoom(0);
    map.setMaxZoom(MAP_MAX_ZOOM);

    map.fitBounds(coverBounds, { animate: false, padding: [0, 0] });
    var containZoom = map.getZoom();
    var containerAspect = size.x / size.y;
    var boundsAspect = boundsW / boundsH;
    var coverZoom = containZoom;

    if (containerAspect > boundsAspect) {
      coverZoom = containZoom + Math.log2(containerAspect / boundsAspect);
    } else if (containerAspect < boundsAspect) {
      coverZoom = containZoom + Math.log2(boundsAspect / containerAspect);
    }

    coverZoom += MAP_COVER_ZOOM_BOOST;

    var snap = map.options.zoomSnap || 0.25;
    coverZoom = Math.ceil(coverZoom / snap) * snap;
    coverZoom = Math.max(0, Math.min(MAP_MAX_ZOOM, coverZoom));

    map.setMinZoom(prevMin);
    map.setMaxZoom(prevMax);
    return coverZoom;
  }

  function applyMapZoomLimits(map, defaultZoom) {
    if (!map || defaultZoom == null) return;
    var snap = map.options.zoomSnap || 0.25;
    var minZoom = Math.max(0, defaultZoom - MAP_ZOOM_OUT_LEVELS);
    minZoom = Math.floor(minZoom / snap) * snap;
    map._gangDefaultZoom = defaultZoom;
    map._gangMinZoom = minZoom;
    map.setMinZoom(minZoom);
    map.setMaxZoom(MAP_MAX_ZOOM);
  }

  function withMapGuard(map, fn) {
    if (!map || map._gangClamping) return;
    map._gangClamping = true;
    try {
      fn();
    } finally {
      map._gangClamping = false;
    }
  }

  function applyInitialView(map, coverBounds) {
    if (!map || !coverBounds || map._gangInitialFitDone || map._gangClamping) return null;
    var result = null;
    withMapGuard(map, function () {
      var latLngBounds = L.latLngBounds(coverBounds);
      var coverZoom = snapCoverZoom(map, coverBounds);
      if (coverZoom == null) return;
      applyMapZoomLimits(map, coverZoom);
      map.setView(latLngBounds.getCenter(), coverZoom, { animate: false });
      map._gangInitialFitDone = true;
      result = coverZoom;
    });
    return result;
  }

  function resizeMap(map, coverBounds) {
    if (!map) return;
    var center = map.getCenter();
    var zoom = map.getZoom();
    map.invalidateSize({ animate: false });
    if (map._gangInitialFitDone) {
      var minZ = map._gangMinZoom;
      if (minZ != null && zoom < minZ) zoom = minZ;
      withMapGuard(map, function () {
        map.setView(center, zoom, { animate: false });
      });
      enforceMinZoom(map);
      return;
    }
    applyInitialView(map, coverBounds);
  }

  function scheduleInitialFit(map, coverBounds) {
    if (!map) return;
    map._gangCoverBounds = coverBounds;
    var attempt = 0;
    function tryFit() {
      if (map._gangInitialFitDone) return;
      attempt += 1;
      var size = map.getSize();
      if (!size.x || !size.y) {
        if (attempt < 8) setTimeout(tryFit, 80);
        return;
      }
      applyInitialView(map, coverBounds);
    }
    tryFit();
    requestAnimationFrame(tryFit);
  }

  function enforceMinZoom(map) {
    if (!map || map._gangClamping) return;
    var minZ = map._gangMinZoom;
    if (minZ == null || map.getZoom() >= minZ - 0.01) return;
    withMapGuard(map, function () {
      map.setZoom(minZ, { animate: false });
    });
  }

  function mount(container, options) {
    options = options || {};
    var host = typeof container === 'string' ? document.querySelector(container) : container;
    if (!host) return null;

    var cfg = {
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
      onError: options.onError || null,
      onRequest: options.onRequest || null,
      onTransfer: options.onTransfer || null,
      mapSources: options.mapSources || null,
      areaDivisor: options.areaDivisor || 100,
      territoryConfig: options.territoryConfig || {},
      otherOrgs: options.otherOrgs || []
    };

    host.innerHTML =
      '<div class="map-base-layer" id="gang-map-base"></div>' +
      '<div id="gang-leaflet-map"></div>' +
      '<div class="map-overlay-stats" id="gang-map-stats">' +
        '<div id="gang-map-stats-text">0 / ' + cfg.maxArea + ' m²</div>' +
        '<div class="bar"><span id="gang-map-stats-bar" style="width:0%"></span></div>' +
        '<div class="map-stats-pct" id="gang-map-stats-pct">0%</div>' +
      '</div>' +
      '<div class="map-tools">' +
        '<button type="button" id="gang-map-draw" title="Tegn territorium">✎</button>' +
        '<button type="button" id="gang-map-cancel-draw" title="Annuller" class="hidden">✕</button>' +
        '<button type="button" id="gang-map-confirm-draw" title="Placer zone" class="hidden gang-confirm-btn">✓</button>' +
      '</div>' +
      '<div class="map-missing-hint hidden" id="gang-map-missing-hint">Satellitkort kunne ikke indlæses fra <strong>san_mdt</strong></div>' +
      '<div class="draw-hint hidden" id="gang-draw-hint">Klik hjørner · Træk i prikker · ✓ for at placere</div>' +
      '<div class="map-nav-hint" id="gang-map-nav-hint">Træk med venstre museknap · Scroll for zoom</div>' +
      '<div class="zone-detail-panel hidden" id="gang-zone-panel">' +
        '<button type="button" class="zone-detail-close" id="gang-zone-panel-close" aria-label="Luk">×</button>' +
        '<div id="gang-zone-panel-body"></div>' +
      '</div>';

    var mapEl = host.querySelector('#gang-leaflet-map');
    var zonePanel = host.querySelector('#gang-zone-panel');
    var zonePanelBody = host.querySelector('#gang-zone-panel-body');
    var zonePanelClose = host.querySelector('#gang-zone-panel-close');
    var baseEl = host.querySelector('#gang-map-base');
    var hintEl = host.querySelector('#gang-map-missing-hint');
    var statsText = host.querySelector('#gang-map-stats-text');
    var statsBar = host.querySelector('#gang-map-stats-bar');
    var statsPct = host.querySelector('#gang-map-stats-pct');
    var drawBtn = host.querySelector('#gang-map-draw');
    var cancelDrawBtn = host.querySelector('#gang-map-cancel-draw');
    var confirmDrawBtn = host.querySelector('#gang-map-confirm-draw');
    var drawHint = host.querySelector('#gang-draw-hint');

    if (typeof L === 'undefined') {
      if (hintEl) {
        hintEl.classList.remove('hidden');
        hintEl.innerHTML = 'Leaflet kunne ikke indlæses — genstart <strong>ya_tablet</strong>';
      }
      return { map: null, setZones: function () {}, stopDraw: function () {}, invalidate: function () {}, destroy: function () { host.innerHTML = ''; } };
    }

    var leafletBounds = getLeafletBounds();
    var coverBounds = getCoverBounds();
    var viewBounds = L.latLngBounds(leafletBounds).pad(0.03);

    var map = L.map(mapEl, {
      crs: L.CRS.Simple,
      minZoom: 0,
      maxZoom: MAP_MAX_ZOOM,
      zoom: 3,
      center: [-96, 64],
      maxBounds: viewBounds,
      maxBoundsViscosity: 1,
      attributionControl: false,
      zoomControl: false,
      preferCanvas: false,
      dragging: true,
      scrollWheelZoom: true,
      doubleClickZoom: false,
      boxZoom: false,
      keyboard: false,
      zoomSnap: 0.25,
      zoomDelta: 0.5,
      wheelPxPerZoomLevel: 45
    });

    map._gangApplyInitial = function () { applyInitialView(map, coverBounds); };

    map.dragging.enable();
    map.scrollWheelZoom.disable();
    var vertexIcon = L.divIcon({
      className: 'gang-vertex-handle',
      iconSize: [14, 14],
      iconAnchor: [7, 7]
    });
    L.control.zoom({ position: 'bottomright' }).addTo(map);
    loadMapOverlay(map, baseEl, hintEl, cfg.mapSources, leafletBounds);
    bindMapWheel(map, host);
    bindMapWheel(map, map.getContainer());
    map.on('zoomend', function () { enforceMinZoom(map); });

    var zoneLayers = {};
    var currentZones = [];
    var drawMode = false;
    map.getContainer().style.cursor = 'grab';
    var drawPoints = [];
    var drawPreview = null;
    var drawMarkers = [];
    var selectedZone = null;
    var editingZoneId = null;

    function zoneAreaM2(vertices) {
      return roundM2(gameAreaToM2(polygonArea(vertices), cfg.areaDivisor));
    }

    function updateStats(area, maxArea) {
      var max = maxArea || cfg.maxArea;
      var m2 = roundM2(area);
      var pct = Math.min(100, Math.round((m2 / max) * 100));
      statsText.textContent = formatM2(m2) + ' / ' + formatM2(max) + ' m²';
      statsBar.style.width = pct + '%';
      statsPct.textContent = pct + '%';
      if (cfg.onDrawStats) cfg.onDrawStats({ area: m2, max: max, pct: pct });
    }

    function clearDraw() {
      drawPoints = [];
      drawMarkers.forEach(function (m) { map.removeLayer(m); });
      drawMarkers = [];
      if (drawPreview) {
        map.removeLayer(drawPreview);
        drawPreview = null;
      }
      updateStats(0, cfg.maxArea);
      updateConfirmButton();
    }

    function updateConfirmButton() {
      if (!confirmDrawBtn) return;
      var canPlace = drawMode && drawPoints.length >= 3;
      confirmDrawBtn.classList.toggle('hidden', !drawMode);
      confirmDrawBtn.disabled = !canPlace;
    }

    function onVertexMoved(index) {
      return function () {
        var ll = drawMarkers[index].getLatLng();
        var gta = latLngToGta(ll.lat, ll.lng);
        drawPoints[index] = { x: gta.x, y: gta.y };
        redrawPreview();
        updateStats(zoneAreaM2(drawPoints), cfg.maxArea);
      };
    }

    function addDrawVertex(latlng, gta) {
      drawPoints.push({ x: gta.x, y: gta.y });
      var marker = L.marker(latlng, { draggable: true, icon: vertexIcon }).addTo(map);
      var index = drawMarkers.length;
      marker.on('drag', onVertexMoved(index));
      marker.on('dragstart', function () { map.dragging.disable(); });
      drawMarkers.push(marker);
      redrawPreview();
      updateStats(zoneAreaM2(drawPoints), cfg.maxArea);
      updateConfirmButton();
    }

    function rebuildDrawMarkers() {
      drawMarkers.forEach(function (m) { map.removeLayer(m); });
      drawMarkers = [];
      for (var i = 0; i < drawPoints.length; i++) {
        var latlng = gtaToLatLng(drawPoints[i].x, drawPoints[i].y);
        var marker = L.marker(latlng, { draggable: true, icon: vertexIcon }).addTo(map);
        marker.on('drag', onVertexMoved(i));
        marker.on('dragstart', function () { map.dragging.disable(); });
        drawMarkers.push(marker);
      }
      redrawPreview();
      updateStats(zoneAreaM2(drawPoints), cfg.maxArea);
      updateConfirmButton();
    }

    function finishDraw() {
      if (drawPoints.length < 3) {
        if (cfg.onError) cfg.onError('Tegn mindst 3 punkter.');
        return;
      }
      var area = zoneAreaM2(drawPoints);
      if (area > cfg.maxArea) {
        if (cfg.onError) cfg.onError('Zonen er for stor');
        return;
      }
      if (area < cfg.minArea) {
        if (cfg.onError) cfg.onError('Zonen er for lille');
        return;
      }
      showNameModal('Zone Navn', 'Indtast zonenavn', function (name) {
        if (cfg.onCreate) cfg.onCreate({ name: name, vertices: drawPoints.slice(), area: area });
        stopDrawMode();
      });
    }

    function stopDrawMode() {
      drawMode = false;
      editingZoneId = null;
      drawBtn.classList.remove('active');
      cancelDrawBtn.classList.add('hidden');
      if (confirmDrawBtn) confirmDrawBtn.classList.add('hidden');
      drawHint.classList.add('hidden');
      host.classList.remove('draw-active');
      clearDraw();
      map.getContainer().style.cursor = 'grab';
      map.dragging.enable();
    }

    function startDrawMode() {
      if (!cfg.canManage) {
        if (cfg.onError) cfg.onError('Du har ikke tilladelse til at tegne zoner.');
        return;
      }
      closeZonePanel();
      editingZoneId = null;
      drawMode = true;
      drawBtn.classList.add('active');
      cancelDrawBtn.classList.remove('hidden');
      drawHint.textContent = 'Klik hjørner · Træk i prikker · ✓ for at placere';
      drawHint.classList.remove('hidden');
      host.classList.add('draw-active');
      clearDraw();
      map.getContainer().style.cursor = 'crosshair';
      map.dragging.disable();
      updateConfirmButton();
    }

    function confirmDraw() {
      if (!drawMode || drawPoints.length < 3) {
        if (cfg.onError) cfg.onError('Tegn mindst 3 punkter.');
        return;
      }
      if (editingZoneId) {
        var editArea = zoneAreaM2(drawPoints);
        if (editArea > cfg.maxArea) {
          if (cfg.onError) cfg.onError('Zonen er for stor');
          return;
        }
        if (editArea < cfg.minArea) {
          if (cfg.onError) cfg.onError('Zonen er for lille');
          return;
        }
        if (cfg.onUpdate) cfg.onUpdate(editingZoneId, drawPoints.slice(), editArea);
        editingZoneId = null;
        stopDrawMode();
        return;
      }
      finishDraw();
    }

    function formatCooldown(seconds) {
      var s = Math.max(0, Math.ceil(Number(seconds) || 0));
      if (s < 60) return s + ' sek';
      var m = Math.ceil(s / 60);
      return m + ' min';
    }

    function formatExpireHours(seconds) {
      var s = Math.max(0, Math.ceil(Number(seconds) || 0));
      if (s < 3600) return Math.max(1, Math.ceil(s / 60)) + ' min';
      return Math.ceil(s / 3600) + ' timer';
    }

    function captureProgressPct(pressure, required) {
      if (!required) return 0;
      return Math.min(100, Math.round((pressure / required) * 100));
    }

    function buildCaptureBlock(zone) {
      var tcfg = cfg.territoryConfig || {};
      var pressure = (zone.myPressure && zone.myPressure.pressure) || 0;
      var required = zone.captureRequired || tcfg.DefaultCaptureRequired || 500;
      var saleXp = tcfg.SalePressureXp || 25;
      var remaining = Math.max(0, required - pressure);
      var salesLeft = saleXp > 0 ? Math.ceil(remaining / saleXp) : 0;
      var pct = captureProgressPct(pressure, required);
      return (
        '<div class="zone-capture-block">' +
          '<div class="zone-capture-head"><span>Overtagelse</span><span>' + pressure + ' / ' + required + ' (' + pct + '%)</span></div>' +
          '<div class="zone-capture-bar"><span style="width:' + pct + '%"></span></div>' +
          '<p class="zone-capture-hint">Ca. ' + salesLeft + ' salg i zonen tilbage</p>' +
          '<p class="zone-capture-note">' + (zone.saleExpiresIn
            ? ('Progress udløber om ' + formatExpireHours(zone.saleExpiresIn) + ' — vend tilbage til zonen')
            : 'I har 24 timer til at vende tilbage efter I forlader zonen') + '</p>' +
        '</div>'
      );
    }

    function buildPopup(zone) {
      var myId = cfg.myOrgId != null ? Number(cfg.myOrgId) : null;
      var zoneOrg = zone.orgId != null ? Number(zone.orgId) : null;
      var isMine = myId != null && zoneOrg != null && zoneOrg === myId;
      var isNeutral = zone.isNeutral === true;
      var isRival = zone.isRival === true || (!isMine && !isNeutral && zoneOrg != null);
      var canEdit = isMine && cfg.canManage;
      var owner = isNeutral ? 'Neutralt' : (zone.orgName || 'Ejet');
      var html = '<div class="zone-popup-card" data-zone-id="' + zone.id + '">';
      html += '<h4>' + escapeHtml(zone.name) + '</h4>';
      html += '<p class="zone-meta">Ejer: ' + escapeHtml(owner) + ' · ' + formatM2(zone.area || zoneAreaM2(zone.vertices || [])) + ' m²</p>';

      if (isRival || isNeutral) {
        html += buildCaptureBlock(zone);
        var requestCd = zone.requestCooldownRemaining || 0;
        html += '<div class="zone-popup-actions zone-popup-actions--rival">';
        html += '<button type="button" data-act="request"' + (requestCd > 0 ? ' disabled' : '') + '>Anmod om zone</button>';
        html += '</div>';
        if (requestCd > 0) html += '<p class="zone-cooldown">Anmodning klar om ' + formatCooldown(requestCd) + '</p>';
      }

      if (canEdit) {
        var threats = (zone.pressures || []).filter(function (p) { return (p.pressure || 0) > 0; });
        if (threats.length) {
          html += '<div class="zone-threats"><p class="zone-threats-title">Trusler mod zonen</p>';
          for (var i = 0; i < threats.length; i++) {
            var th = threats[i];
            html += '<p class="zone-threat-row">' + escapeHtml(th.orgName || 'Rival') + ': ' + (th.pressure || 0) + '/' + (th.required || zone.captureRequired || 500) + '</p>';
          }
          html += '</div>';
        }
        html += '<div class="zone-popup-actions">';
        html += '<button type="button" data-act="edit">Rediger</button>';
        html += '<button type="button" data-act="rename">Omdøb</button>';
        if ((cfg.otherOrgs || []).length) html += '<button type="button" data-act="transfer">Overdrag</button>';
        html += '<button type="button" data-act="delete" class="danger">Slet</button>';
        html += '</div>';
      }

      html += '</div>';
      return html;
    }

    function closeZonePanel() {
      if (zonePanel) zonePanel.classList.add('hidden');
      if (map) map.closePopup();
    }

    function bindZonePanelActions(zone) {
      if (!zonePanelBody) return;
      var buttons = zonePanelBody.querySelectorAll('[data-act]');
      for (var i = 0; i < buttons.length; i++) {
        buttons[i].addEventListener('click', function (e) {
          e.preventDefault();
          e.stopPropagation();
          if (this.disabled) return;
          var act = this.getAttribute('data-act');
          if (act === 'rename') {
            closeZonePanel();
            showNameModal('Omdøb zone', zone.name, function (name) {
              if (cfg.onRename) cfg.onRename(zone.id, name);
            });
          } else if (act === 'delete') {
            closeZonePanel();
            if (cfg.onDelete) cfg.onDelete(zone.id);
          } else if (act === 'edit') {
            closeZonePanel();
            startEditZone(zone);
          } else if (act === 'request') {
            closeZonePanel();
            if (cfg.onRequest) cfg.onRequest(zone.id);
          } else if (act === 'transfer') {
            closeZonePanel();
            showOrgPickerModal('Overdrag territorium', cfg.otherOrgs || [], function (orgId) {
              if (cfg.onTransfer) cfg.onTransfer(zone.id, orgId);
            });
          }
        });
      }
    }

    if (zonePanelClose) {
      zonePanelClose.addEventListener('click', function (e) {
        e.stopPropagation();
        closeZonePanel();
      });
    }
    if (zonePanel) {
      zonePanel.addEventListener('mousedown', function (e) { e.stopPropagation(); });
      zonePanel.addEventListener('click', function (e) { e.stopPropagation(); });
    }

    function startEditZone(zone) {
      if (!zone.vertices || zone.vertices.length < 3) return;
      if (zoneLayers[zone.id]) {
        removeZoneEntry(zoneLayers[zone.id]);
        delete zoneLayers[zone.id];
      }
      if (drawPreview) {
        map.removeLayer(drawPreview);
        drawPreview = null;
      }
      drawMarkers.forEach(function (m) { map.removeLayer(m); });
      drawMarkers = [];
      editingZoneId = zone.id;
      drawMode = true;
      drawBtn.classList.add('active');
      drawPoints = zone.vertices.map(function (v) { return { x: v.x, y: v.y }; });
      drawHint.textContent = 'Træk i prikker · ✓ for at gemme';
      drawHint.classList.remove('hidden');
      cancelDrawBtn.classList.remove('hidden');
      host.classList.add('draw-active');
      map.getContainer().style.cursor = 'crosshair';
      map.dragging.disable();
      rebuildDrawMarkers();
    }

    function redrawPreview() {
      if (drawPreview) {
        if (drawPreview._glowLayer) map.removeLayer(drawPreview._glowLayer);
        map.removeLayer(drawPreview);
        drawPreview = null;
      }
      if (drawPoints.length < 2) return;
      var latlngs = drawPoints.map(function (p) { return gtaToLatLng(p.x, p.y); });
      var drawEntry = addThemedPolygon(map, latlngs, ZONE_THEME.draw, true);
      drawPreview = drawEntry.main;
      drawPreview.setStyle({ dashArray: '6 4' });
      if (drawEntry.glow) {
        drawPreview._glowLayer = drawEntry.glow;
        drawEntry.glow.setStyle({ dashArray: '6 4' });
      }
    }

    function bringZonesToFront() {
      Object.keys(zoneLayers).forEach(function (key) {
        var entry = zoneLayers[key];
        if (!entry || !entry.all) return;
        entry.all.forEach(function (layer) {
          if (layer && layer.bringToFront) layer.bringToFront();
        });
      });
    }

    function openZonePanel(zone) {
      if (!zone || !zonePanel || !zonePanelBody) return;
      selectedZone = zone;
      zonePanelBody.innerHTML = buildPopup(zone);
      zonePanel.classList.remove('hidden');
      bindZonePanelActions(zone);
      if (cfg.onSelect) cfg.onSelect(zone);
      updateStats(zone.area || zoneAreaM2(zone.vertices), cfg.maxArea);
    }

    function findZoneAtLatLng(latlng) {
      var gta = latLngToGta(latlng.lat, latlng.lng);
      for (var i = currentZones.length - 1; i >= 0; i--) {
        var zone = currentZones[i];
        if (zone.vertices && pointInPolygon(gta, zone.vertices)) return zone;
      }
      return null;
    }

    function bindZoneClick(zone, layer) {
      if (!layer) return;
      layer.on('click', function (e) {
        L.DomEvent.stopPropagation(e);
        openZonePanel(zone);
      });
    }

    function tryOpenZoneAt(latlng) {
      var hitZone = findZoneAtLatLng(latlng);
      if (hitZone) {
        openZonePanel(hitZone);
        return true;
      }
      return false;
    }

    function renderZones(zones) {
      currentZones = zones || [];
      Object.keys(zoneLayers).forEach(function (key) {
        removeZoneEntry(zoneLayers[key]);
        delete zoneLayers[key];
      });

      currentZones.forEach(function (zone) {
        if (!zone.vertices || zone.vertices.length < 3) return;
        var latlngs = zone.vertices.map(function (v) { return gtaToLatLng(v.x, v.y); });
        var theme = zoneThemeFor(zone);
        var entry = addThemedPolygon(map, latlngs, theme, true);
        bindZoneClick(zone, entry.main);
        bindZoneClick(zone, entry.hit);
        zoneLayers[zone.id] = entry;
      });
      bringZonesToFront();
    }

    map._gangBringZonesFront = bringZonesToFront;

    var mapPress = null;
    map.on('mousedown', function (e) {
      if (drawMode && editingZoneId) return;
      mapPress = {
        x: e.containerPoint.x,
        y: e.containerPoint.y,
        latlng: e.latlng
      };
    });

    map.on('mouseup', function (e) {
      if (!mapPress) return;
      var dx = e.containerPoint.x - mapPress.x;
      var dy = e.containerPoint.y - mapPress.y;
      var latlng = mapPress.latlng;
      mapPress = null;
      if ((dx * dx) + (dy * dy) > 36) return;

      if (drawMode && !editingZoneId) {
        var gta = latLngToGta(latlng.lat, latlng.lng);
        addDrawVertex(latlng, gta);
        return;
      }
      if (drawMode || editingZoneId) return;
      tryOpenZoneAt(latlng);
    });

    map.on('click', function (e) {
      if (drawMode || editingZoneId) return;
      if (!tryOpenZoneAt(e.latlng)) closeZonePanel();
    });

    map.on('dblclick', function (e) {
      if (!drawMode) return;
      L.DomEvent.stopPropagation(e);
    });

    drawBtn.addEventListener('click', function () {
      if (drawMode && !editingZoneId) stopDrawMode();
      else startDrawMode();
    });
    cancelDrawBtn.addEventListener('click', function () {
      editingZoneId = null;
      stopDrawMode();
    });
    if (confirmDrawBtn) {
      confirmDrawBtn.addEventListener('click', function () {
        confirmDraw();
      });
    }

    scheduleInitialFit(map, coverBounds);

    return {
      map: map,
      setZones: renderZones,
      stopDraw: stopDrawMode,
      invalidate: function () { resizeMap(map, coverBounds); },
      resetView: function () {
        map._gangInitialFitDone = false;
        applyInitialView(map, coverBounds);
      },
      destroy: function () {
        map.remove();
        host.innerHTML = '';
      }
    };
  }

  function showOrgPickerModal(title, orgs, onConfirm) {
    if (!orgs || !orgs.length) return;
    var backdrop = document.createElement('div');
    backdrop.className = 'gang-modal-backdrop';
    var optionsHtml = '';
    for (var i = 0; i < orgs.length; i++) {
      optionsHtml += '<option value="' + escapeHtml(String(orgs[i].id)) + '">' + escapeHtml(orgs[i].name || ('Bande #' + orgs[i].id)) + '</option>';
    }
    backdrop.innerHTML =
      '<div class="gang-modal">' +
        '<h3>' + escapeHtml(title) + '</h3>' +
        '<label class="gang-modal-label">Vælg bande</label>' +
        '<select id="gang-zone-org">' + optionsHtml + '</select>' +
        '<div class="gang-modal-actions">' +
          '<button type="button" data-act="cancel">Annuller</button>' +
          '<button type="button" data-act="ok">Overdrag</button>' +
        '</div>' +
      '</div>';
    var host = (typeof window.getTabletOverlayHost === 'function') ? window.getTabletOverlayHost() : document.body;
    host.appendChild(backdrop);
    var select = backdrop.querySelector('#gang-zone-org');
    var close = function () { backdrop.remove(); };
    backdrop.querySelector('[data-act="cancel"]').onclick = close;
    backdrop.querySelector('[data-act="ok"]').onclick = function () {
      var orgId = Number(select.value);
      if (!orgId) return;
      close();
      onConfirm(orgId);
    };
  }

  function showNameModal(title, value, onConfirm) {
    var backdrop = document.createElement('div');
    backdrop.className = 'gang-modal-backdrop';
    backdrop.innerHTML =
      '<div class="gang-modal">' +
        '<h3>' + escapeHtml(title) + '</h3>' +
        '<input type="text" id="gang-zone-name" maxlength="48" placeholder="Indtast zonenavn" value="' + escapeHtml(value || '') + '" />' +
        '<div class="gang-modal-actions">' +
          '<button type="button" data-act="cancel">Annullere</button>' +
          '<button type="button" data-act="ok">Bekræft</button>' +
        '</div>' +
      '</div>';
    var host = (typeof window.getTabletOverlayHost === 'function') ? window.getTabletOverlayHost() : document.body;
    host.appendChild(backdrop);
    var input = backdrop.querySelector('#gang-zone-name');
    input.focus();
    input.select();

    var close = function () { backdrop.remove(); };
    backdrop.querySelector('[data-act="cancel"]').onclick = close;
    backdrop.querySelector('[data-act="ok"]').onclick = function () {
      var name = input.value.trim();
      if (!name) return;
      close();
      onConfirm(name);
    };
    input.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') backdrop.querySelector('[data-act="ok"]').click();
      if (e.key === 'Escape') close();
    });
  }

  var toastTimer = null;

  function showToast(message, title) {
    if (typeof window.showTabletToast === 'function') {
      window.showTabletToast(message, title === 'Fejl' ? 'error' : 'info');
      return;
    }
    if (toastTimer) clearTimeout(toastTimer);
    var old = document.querySelectorAll('.gang-toast');
    for (var i = 0; i < old.length; i++) old[i].remove();
    var el = document.createElement('div');
    el.className = 'gang-toast';
    el.innerHTML = '<span class="icon">!</span><div><div>' + escapeHtml(title || 'Info') + '</div><div class="sub">' + escapeHtml(message) + '</div></div>';
    document.body.appendChild(el);
    toastTimer = setTimeout(function () { el.remove(); }, 3200);
  }

  return { mount: mount, gtaToLatLng: gtaToLatLng, latLngToGta: latLngToGta, polygonArea: polygonArea, showNameModal: showNameModal, showOrgPickerModal: showOrgPickerModal, showToast: showToast };
})();
