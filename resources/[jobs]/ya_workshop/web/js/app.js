const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_workshop';

function assetUrl(path) {
  if (!path) return '';
  if (path.startsWith('http') || path.startsWith('nui://')) return path;
  const normalized = path.replace(/^\//, '');
  const full = normalized.startsWith('web/') ? normalized : `web/${normalized}`;
  return `nui://${RES}/${full}`;
}

const CATEGORY_ART = {
  customization: `<svg viewBox="0 0 140 72" fill="none">
    <path d="M18 50h104l-10-22H28l-10 22z" stroke="#2ee8d6" stroke-width="2.2"/>
    <path d="M42 28h56l8 16H34l8-16z" stroke="#eef6f5" stroke-width="1.6"/>
    <circle cx="38" cy="50" r="7" stroke="#2ee8d6" stroke-width="2"/>
    <circle cx="102" cy="50" r="7" stroke="#2ee8d6" stroke-width="2"/>
  </svg>`,
  stance: `<svg viewBox="0 0 140 72" fill="none">
    <circle cx="70" cy="36" r="26" stroke="#2ee8d6" stroke-width="2.2"/>
    <circle cx="70" cy="36" r="12" stroke="#eef6f5" stroke-width="1.6"/>
    <path d="M70 10v10M70 52v10M44 36H34M106 36h10" stroke="#2ee8d6" stroke-width="2"/>
  </svg>`,
  performance: `<svg viewBox="0 0 140 72" fill="none">
    <path d="M44 48V26h52v22" stroke="#2ee8d6" stroke-width="2.2"/>
    <path d="M52 26V16h36v10" stroke="#eef6f5" stroke-width="1.6"/>
    <path d="M36 48h68" stroke="#2ee8d6" stroke-width="2"/>
  </svg>`,
};

const ITEM_ICONS = {
  paint_primary: '<path d="M9 3h6l1 2h4v2H4V5h5l1-2z"/><rect x="4" y="9" width="16" height="10" rx="2"/>',
  paint_secondary: '<path d="M4 16h16"/><path d="M6 10h12v8H6z"/>',
  livery: '<path d="M5 17l4-10h6l4 10"/><path d="M7 17h10"/>',
  wheels: '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="3"/>',
  suspension: '<path d="M6 18h12"/><path d="M8 18V8l4-4 4 4v10"/>',
  wheel_offset: '<ellipse cx="12" cy="14" rx="8" ry="3"/><path d="M4 14v-5M20 14v-5"/>',
  engine: '<path d="M7 10h10v7H7z"/><path d="M10 8V6h4v2"/>',
  brakes: '<circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
  transmission: '<rect x="5" y="9" width="14" height="8" rx="2"/>',
  turbo: '<path d="M8 14c0-3 2-6 4-6s4 3 4 6"/><circle cx="16" cy="10" r="2"/>',
  spoiler: '<path d="M5 14h14l-3-5H8l-3 5z"/>',
  side_skirts: '<path d="M4 16h16"/><path d="M6 16V10l10-3v9"/>',
  roll_cage: '<path d="M8 6v12M16 6v12M8 6h8M8 12h8M8 18h8"/>',
  hood: '<path d="M5 14c3-7 11-7 14 0"/>',
  interior_trim: '<rect x="7" y="5" width="4" height="4" rx="1"/><rect x="13" y="9" width="4" height="4" rx="1"/>',
  dashboard: '<rect x="5" y="10" width="14" height="7" rx="2"/>',
  fuzzy_dice: '<rect x="8" y="6" width="3" height="3" rx="0.5"/><rect x="13" y="9" width="3" height="3" rx="0.5"/><path d="M9.5 9v4M14.5 12v4"/>',
  antenna: '<path d="M12 18V7"/><path d="M8 7c2-4 8-4 8 0"/>',
  window_tint: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9" y="9" width="6" height="6" fill="rgba(46,232,214,0.25)"/>',
  window_trim: '<rect x="5" y="7" width="14" height="10" rx="1"/>',
};

const DEFAULT_ICON = '<path d="M12 8l4 8H8l4-8z"/>';

const state = {
  categories: [],
  activeCategory: null,
  activeGroup: null,
  unlockedGroups: new Set(),
  cart: [],
  previewItem: null,
  vehicle: null,
  shop: null,
  cartOpen: false,
  persistedUnlocks: new Set(),
  policeMode: false,
};

const els = {
  app: document.getElementById('app'),
  shopTitle: document.getElementById('shop-title'),
  vehicleLine: document.getElementById('vehicle-line'),
  categoryRail: document.getElementById('category-rail'),
  optionsDock: document.getElementById('options-dock'),
  optionsBack: document.getElementById('options-back'),
  optionsTitle: document.getElementById('options-title'),
  optionsTrack: document.getElementById('options-track'),
  scrollLeft: document.getElementById('scroll-left'),
  scrollRight: document.getElementById('scroll-right'),
  cartPanel: document.getElementById('cart-panel'),
  cartList: document.getElementById('cart-list'),
  cartCount: document.getElementById('cart-count'),
  cartTotal: document.getElementById('cart-total'),
  cartToggle: document.getElementById('cart-toggle'),
  cartClear: document.getElementById('cart-clear'),
  submitBtn: document.getElementById('submit-btn'),
  closeBtn: document.getElementById('close-btn'),
  previewBar: document.getElementById('preview-bar'),
  previewLabel: document.getElementById('preview-label'),
  previewAddBtn: document.getElementById('preview-add-btn'),
  toast: document.getElementById('toast'),
  rgbModal: document.getElementById('rgb-modal'),
  rgbPicker: document.getElementById('rgb-picker'),
  rgbApplyBtn: document.getElementById('rgb-apply'),
  rgbCancelBtn: document.getElementById('rgb-cancel'),
  rgbTargets: () => Array.from(document.querySelectorAll('input[name="rgb-target"]')),
};

const rgbState = {
  cat: null,
  group: null,
  item: null,
};

const cameraKeys = { a: false, d: false };
let cameraTick = null;

function tunerIsOpen() {
  return !els.app.classList.contains('hidden');
}

function startCameraTick() {
  if (cameraTick) return;
  cameraTick = window.setInterval(() => {
    if (!tunerIsOpen()) {
      stopCameraTick();
      return;
    }
    if (cameraKeys.a) post('cameraRotate', { delta: -1 });
    if (cameraKeys.d) post('cameraRotate', { delta: 1 });
  }, 16);
}

function stopCameraTick() {
  if (!cameraTick) return;
  window.clearInterval(cameraTick);
  cameraTick = null;
}

function setCameraKey(key, pressed) {
  if (key === 'a') cameraKeys.a = pressed;
  if (key === 'd') cameraKeys.d = pressed;
  if (cameraKeys.a || cameraKeys.d) startCameraTick();
  else stopCameraTick();
}

let toastTimer = null;

function post(name, data = {}) {
  fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

function previewMod(payload) {
  post('previewMod', payload || {});
}

function focusCamera(payload) {
  if (!payload || !payload.itemKey) return;
  post('focusCamera', payload);
}

function hexToRgb(hex) {
  const raw = String(hex || '#2ee8d6').replace('#', '');
  const full = raw.length === 3 ? raw.split('').map((c) => c + c).join('') : raw;
  const num = parseInt(full, 16);
  return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 };
}

function rgbToHex(r, g, b) {
  const clamp = (n) => Math.max(0, Math.min(255, Number(n) || 0));
  return `#${[clamp(r), clamp(g), clamp(b)].map((v) => v.toString(16).padStart(2, '0')).join('')}`;
}

function getRgbPaintTarget() {
  const selected = els.rgbTargets().find((input) => input.checked);
  return selected?.value === 'color2' ? 'color2' : 'color1';
}

function getRgbBaseItemKey(group, prop) {
  return prop === 'color2' ? 'paint_secondary' : 'paint_primary';
}

function getRgbPrice(group, prop) {
  const baseKey = getRgbBaseItemKey(group, prop);
  const match = (group.items || []).find((entry) => entry.baseKey === baseKey || entry.key === baseKey);
  if (match) return match.price;
  return prop === 'color2' ? 3200 : 4500;
}

function openRgbModal(cat, group, item) {
  rgbState.cat = cat;
  rgbState.group = group;
  rgbState.item = item;
  els.rgbPicker.value = '#2ee8d6';
  els.rgbTargets().forEach((input) => {
    input.checked = input.value === 'color1';
  });
  els.rgbModal.hidden = false;
}

function closeRgbModal() {
  rgbState.cat = null;
  rgbState.group = null;
  rgbState.item = null;
  els.rgbModal.hidden = true;
}

function setMouseInMenu(inside) {
  post('setMouseInMenu', { inside: inside === true });
}

function formatMoney(n) {
  return Number(n || 0).toLocaleString('da-DK');
}

function formatPrice(n) {
  if (state.policeMode) return 'Gratis';
  return `${formatMoney(n)} kr`;
}

function groupKey(catKey, groupKey) {
  return `${catKey}:${groupKey}`;
}

function itemCartKey(catKey, grpKey, itemKey) {
  return `${catKey}:${grpKey}:${itemKey}`;
}

function isGroupUnlocked(catKey, grpKey) {
  const key = groupKey(catKey, grpKey);
  return state.unlockedGroups.has(key) || state.persistedUnlocks.has(key);
}

function hasUnlockInCart(catKey, grpKey) {
  return state.cart.some((line) => line.type === 'unlock' && line.categoryKey === catKey && line.groupKey === grpKey);
}

function isItemInCart(catKey, grpKey, item) {
  const itemKey = typeof item === 'string' ? item : item?.key;
  return state.cart.some((line) => line.type === 'item' && itemCartKey(line.categoryKey, line.groupKey, line.itemKey) === itemCartKey(catKey, grpKey, itemKey));
}

function isItemPreviewing(catKey, grpKey, item) {
  const itemKey = typeof item === 'string' ? item : item?.key;
  return state.previewItem
    && state.previewItem.categoryKey === catKey
    && state.previewItem.groupKey === grpKey
    && state.previewItem.itemKey === itemKey;
}

function clearPreview(resetVehicle = true) {
  state.previewItem = null;
  if (resetVehicle) post('previewItem', { reset: true });
  renderPreviewBar();
}

function renderPreviewBar() {
  const preview = state.previewItem;
  if (!preview || !state.activeGroup) {
    els.previewBar.hidden = true;
    return;
  }

  const inCart = isItemInCart(preview.categoryKey, preview.groupKey, preview.item);
  els.previewBar.hidden = false;
  els.previewLabel.textContent = `${preview.label} · ${formatPrice(preview.price)}`;
  els.previewAddBtn.textContent = inCart ? '✓' : '+';
  els.previewAddBtn.disabled = inCart;
}

function previewItemChoice(cat, group, item) {
  if (item.isRgb) {
    openRgbModal(cat, group, item);
    return;
  }

  state.previewItem = {
    categoryKey: cat.key,
    groupKey: group.key,
    itemKey: item.key,
    label: item.label,
    price: item.price,
    mod: item.mod || null,
    baseItemKey: item.baseKey || item.key,
    item,
  };

  post('previewItem', {
    categoryKey: cat.key,
    groupKey: group.key,
    itemKey: item.key,
    mod: item.mod || null,
  });

  renderOptionsView();
  renderPreviewBar();
}

function addItemToCart(cat, group, item) {
  if (isItemInCart(cat.key, group.key, item)) return;

  state.cart.push({
    type: 'item',
    categoryKey: cat.key,
    groupKey: group.key,
    itemKey: item.key,
    baseItemKey: item.baseKey || item.key,
    label: item.label,
    mod: item.mod || null,
    price: item.price,
    qty: 1,
  });

  showToast(`${item.label} i kurv`);
  renderCart();
  renderOptionsView();
  renderPreviewBar();
}

function removeItemFromCart(cat, group, item) {
  const key = itemCartKey(cat.key, group.key, item.key);
  const idx = state.cart.findIndex((line) => line.type === 'item' && itemCartKey(line.categoryKey, line.groupKey, line.itemKey) === key);
  if (idx < 0) return;
  state.cart.splice(idx, 1);
  showToast(`${item.label} fjernet`);
  renderCart();
  renderOptionsView();
  renderPreviewBar();
}

function showToast(message) {
  els.toast.textContent = message;
  els.toast.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { els.toast.hidden = true; }, 2200);
}

function categoryArt(cat) {
  if (cat && cat.image) {
    return `<img src="${assetUrl(cat.image)}" alt="" />`;
  }
  const key = typeof cat === 'string' ? cat : cat?.key;
  return CATEGORY_ART[key] || CATEGORY_ART.customization;
}

function optionIcon(entry) {
  if (entry && entry.isColor && entry.color) {
    return `<div class="color-swatch" style="background:${entry.color}"></div>`;
  }
  if (entry && entry.image) {
    return `<img src="${assetUrl(entry.image)}" alt="" />`;
  }
  const key = entry?.icon || entry?.key;
  return itemIconSvg(key);
}

function itemIconSvg(key) {
  return `<svg viewBox="0 0 24 24">${ITEM_ICONS[key] || DEFAULT_ICON}</svg>`;
}

function getActiveCategory() {
  return state.categories.find((c) => c.key === state.activeCategory) || null;
}

function getActiveGroup() {
  const cat = getActiveCategory();
  if (!cat || !state.activeGroup) return null;
  return (cat.groups || []).find((g) => g.key === state.activeGroup) || null;
}

function scrollActiveCategoryIntoView() {
  const active = els.categoryRail.querySelector('.cat-card.is-active');
  if (active) active.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

function renderCategoryRail() {
  const visible = (state.categories || []).filter((cat) => cat.hasVehicleItems !== false);
  els.categoryRail.innerHTML = visible.length
    ? visible.map((cat) => `
    <button type="button" class="cat-card${state.activeCategory === cat.key ? ' is-active' : ''}" data-cat="${cat.key}">
      <div class="cat-hero cat-hero--${cat.key}">
        <div class="cat-hero-glow" aria-hidden="true"></div>
        <div class="cat-hero-art">${categoryArt(cat)}</div>
      </div>
      <div class="cat-foot">
        <h3>${cat.label}</h3>
        <p>${cat.desc || ''}</p>
        <span class="cat-cta">Åbn valg</span>
      </div>
    </button>
  `).join('')
    : '<p class="cart-empty" style="padding:16px;">Ingen tuning tilgængelig for denne bil.</p>';

  els.categoryRail.querySelectorAll('[data-cat]').forEach((btn) => {
    btn.addEventListener('click', () => openCategory(btn.dataset.cat));
  });

  scrollActiveCategoryIntoView();
}

function openCategory(key) {
  if (!key) return;
  state.activeCategory = key;
  state.activeGroup = null;
  clearPreview(true);

  els.optionsDock.hidden = false;
  els.app.classList.add('has-options');
  els.optionsDock.classList.remove('is-detail');

  renderCategoryRail();
  renderOptionsView();
  els.optionsTrack.scrollLeft = 0;
}

function closeCategory() {
  state.activeCategory = null;
  state.activeGroup = null;
  els.optionsDock.hidden = true;
  els.app.classList.remove('has-options');
  els.optionsDock.classList.remove('is-detail');
  renderCategoryRail();
}

function backOptions() {
  if (state.activeGroup) {
    state.activeGroup = null;
    els.optionsDock.classList.remove('is-detail');
    clearPreview(true);
    renderOptionsView();
    els.optionsTrack.scrollLeft = 0;
    return;
  }
  closeCategory();
}

function unlockGroup(cat, group) {
  const key = groupKey(cat.key, group.key);
  if (state.policeMode) {
    state.unlockedGroups.add(key);
    openGroupItems(cat, group);
    return;
  }
  if (!state.unlockedGroups.has(key)) {
    state.unlockedGroups.add(key);
    const alreadyPaid = state.persistedUnlocks.has(key);
    if ((group.openPrice || 0) > 0 && !hasUnlockInCart(cat.key, group.key) && !alreadyPaid) {
      state.cart.push({
        type: 'unlock',
        categoryKey: cat.key,
        groupKey: group.key,
        itemKey: '_open',
        label: `${group.label} — åbning`,
        price: group.openPrice,
        qty: 1,
      });
      showToast(`${group.label} · ${formatPrice(group.openPrice)}`);
    } else {
      showToast(alreadyPaid ? `${group.label} (allerede betalt)` : group.label);
    }
    renderCart();
  }
  state.activeGroup = group.key;
  els.optionsDock.classList.add('is-detail');
  clearPreview(true);
  renderOptionsView();
  els.optionsTrack.scrollLeft = 0;
}

function renderOptionsView() {
  const cat = getActiveCategory();
  if (!cat) return;

  const group = getActiveGroup();

  if (group) {
    els.optionsTitle.textContent = group.label;
    renderItemTrack(cat, group);
    return;
  }

  els.previewBar.hidden = true;
  els.optionsTitle.textContent = cat.label;
  renderGroupTrack(cat);
}

function renderGroupTrack(cat) {
  const groups = (cat.groups || []).filter((group) => group.hasVehicleItems === true);
  const hint = cat.key === 'ekstra'
    ? 'Ekstra er til lygtebar/bullbar. Bagklap og motorhjelm findes under <b>Tilpasning</b>.'
    : 'Prøv en anden kategori — fx <b>Farve</b> eller <b>Bagklap</b> under Tilpasning.';
  els.optionsTrack.innerHTML = groups.length
    ? groups.map((group) => {
        const unlocked = isGroupUnlocked(cat.key, group.key);
        return `
          <article class="option-card option-card--group${unlocked ? ' is-unlocked' : ''}" data-group="${group.key}">
            <div class="option-icon">${optionIcon(group)}</div>
            <div class="option-body">
              <h4>${group.label}</h4>
            </div>
            <div class="option-foot">
              <span class="price">${formatPrice(group.openPrice)}</span>
            </div>
          </article>
        `;
      }).join('')
    : `<p class="cart-empty" style="padding:16px;">Ingen valg i ${cat.label || 'denne kategori'}. ${hint}</p>`;

  els.optionsTrack.querySelectorAll('[data-group]').forEach((card) => {
    card.addEventListener('click', () => {
      const grp = groups.find((g) => g.key === card.dataset.group);
      if (!grp) return;
      if (isGroupUnlocked(cat.key, grp.key)) {
        state.activeGroup = grp.key;
        els.optionsDock.classList.add('is-detail');
        clearPreview(true);
        renderOptionsView();
        els.optionsTrack.scrollLeft = 0;
        return;
      }
      unlockGroup(cat, grp);
    });
  });
}

function renderItemTrack(cat, group) {
  const items = group.items || [];
  els.optionsTrack.innerHTML = items.length
    ? items.map((item) => {
        const inCart = isItemInCart(cat.key, group.key, item);
        const previewing = isItemPreviewing(cat.key, group.key, item);
        const extraClass = item.isColor ? ' option-card--color' : (item.isRgb ? ' option-card--rgb' : '');
        return `
          <article class="option-card option-card--item${extraClass}${previewing ? ' is-previewing' : ''}${inCart ? ' is-in-cart' : ''}" data-item="${item.key}">
            <div class="option-icon">${optionIcon(item)}</div>
            <div class="option-body">
              <h4>${item.label}</h4>
            </div>
            <div class="option-foot">
              <span class="price">${formatPrice(item.price)}</span>
            </div>
          </article>
        `;
      }).join('')
    : group.key === 'trunk' || group.emptyForVehicle
      ? '<p class="cart-empty" style="padding:16px;">Denne bil har ingen bagklap-dele i GTA. Prøv fx <b>Slamvan Custom</b>, <b>Buccaneer Custom</b> eller <b>Gauntlet Classic Custom</b> hos Benny\'s.</p>'
      : '<p class="cart-empty" style="padding:16px;">Ingen dele tilgængelige for denne bil her. Prøv <b>Farve</b>, <b>Ruder</b> eller <b>Ekstra</b>.</p>';

  els.optionsTrack.querySelectorAll('[data-item]').forEach((card) => {
    card.addEventListener('click', () => {
      const item = items.find((i) => i.key === card.dataset.item);
      if (!item) return;
      previewItemChoice(cat, group, item);
    });
  });

  renderPreviewBar();
}

function scrollOptionsTrack(direction) {
  els.optionsTrack.scrollBy({ left: direction * 360, behavior: 'smooth' });
}

function shortCartLabel(line) {
  let label = String(line.label || '');
  label = label.replace(/\s*[—–-]\s*åbning$/i, '');
  if (label.length > 24) label = `${label.slice(0, 22)}…`;
  return label;
}

function renderCart() {
  const count = state.cart.length;
  const total = state.cart.reduce((sum, line) => sum + line.price * (line.qty || 1), 0);

  els.cartCount.textContent = String(count);
  els.cartCount.classList.toggle('is-empty', count === 0);
  els.cartTotal.textContent = formatPrice(total);
  els.submitBtn.disabled = count === 0;

  els.cartList.innerHTML = state.cart.length
    ? state.cart.map((line, index) => `
      <div class="cart-line">
        <span title="${line.label}">${shortCartLabel(line)}</span>
        <span>${formatPrice(line.price)}</span>
        <button type="button" data-remove="${index}">✕</button>
      </div>
    `).join('')
    : '<div class="cart-empty">Tom</div>';

  els.cartList.querySelectorAll('[data-remove]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const line = state.cart[Number(btn.dataset.remove)];
      state.cart.splice(Number(btn.dataset.remove), 1);
      if (line && line.type === 'unlock') {
        state.unlockedGroups.delete(groupKey(line.categoryKey, line.groupKey));
        if (state.activeGroup === line.groupKey) {
          state.activeGroup = null;
          els.optionsDock.classList.remove('is-detail');
        }
      }
      renderCart();
      renderOptionsView();
    });
  });

  if (count === 0) {
    state.cartOpen = false;
    els.cartPanel.hidden = true;
  }
}

function toggleCart() {
  if (state.cart.length === 0) return;
  state.cartOpen = !state.cartOpen;
  els.cartPanel.hidden = !state.cartOpen;
}

function closeCartPanel() {
  state.cartOpen = false;
  els.cartPanel.hidden = true;
}

function openUI(payload) {
  state.policeMode = payload.policeMode === true;
  state.shop = payload.shop || {};
  state.vehicle = payload.vehicle || {};
  state.categories = payload.categories || [];
  state.cart = [];
  state.previewItem = null;
  state.cartOpen = false;
  state.unlockedGroups = new Set();
  state.persistedUnlocks = new Set();
  state.activeGroup = null;

  (payload.unlockedGroups || []).forEach((entry) => {
    if (!entry || !entry.categoryKey || !entry.groupKey) return;
    const key = groupKey(entry.categoryKey, entry.groupKey);
    state.persistedUnlocks.add(key);
    state.unlockedGroups.add(key);
  });

  if (state.policeMode) {
    (state.categories || []).forEach((cat) => {
      (cat.groups || []).forEach((group) => {
        state.unlockedGroups.add(groupKey(cat.key, group.key));
      });
    });
  }

  els.shopTitle.textContent = state.policeMode
    ? (state.shop.brandingLabel || 'Politi AutoShop')
    : (state.shop.brandingLabel || state.shop.label || "Benny's");
  els.vehicleLine.textContent = state.vehicle.plate || state.vehicle.label || '—';
  if (els.submitBtn) {
    els.submitBtn.textContent = state.policeMode ? 'Gem ændringer' : 'Bestil';
  }

  els.optionsDock.hidden = true;
  els.cartPanel.hidden = true;
  els.app.classList.remove('has-options');
  els.optionsDock.classList.remove('is-detail');
  els.app.classList.remove('hidden');

  renderCategoryRail();
  renderCart();

  const firstCat = (state.categories || []).find((cat) => cat.hasVehicleItems !== false);
  if (firstCat) {
    openCategory(firstCat.key);
  }
}

function closeUI(keepVehicle = false) {
  stopCameraTick();
  cameraKeys.a = false;
  state.policeMode = false;
  if (els.submitBtn) els.submitBtn.textContent = 'Bestil';
  cameraKeys.d = false;
  clearPreview(!keepVehicle);
  els.app.classList.add('hidden');
  closeCategory();
  state.cartOpen = false;
  state.unlockedGroups = new Set();
  state.persistedUnlocks = new Set();
  els.cartPanel.hidden = true;
}

els.closeBtn.addEventListener('click', () => post('close'));
els.optionsBack.addEventListener('click', backOptions);
els.scrollLeft.addEventListener('click', () => scrollOptionsTrack(-1));
els.scrollRight.addEventListener('click', () => scrollOptionsTrack(1));
els.cartToggle.addEventListener('click', (e) => {
  e.stopPropagation();
  toggleCart();
});

document.addEventListener('click', (e) => {
  if (!state.cartOpen) return;
  if (e.target.closest('.topbar-cart')) return;
  closeCartPanel();
});
els.cartClear.addEventListener('click', () => {
  state.cart = [];
  state.unlockedGroups = new Set(state.persistedUnlocks);
  state.activeGroup = null;
  clearPreview(true);
  els.optionsDock.classList.remove('is-detail');
  renderCart();
  renderOptionsView();
});

els.previewAddBtn.addEventListener('click', () => {
  const cat = getActiveCategory();
  const group = getActiveGroup();
  const preview = state.previewItem;
  if (!cat || !group || !preview) return;
  addItemToCart(cat, group, preview.item || {
    key: preview.itemKey,
    baseKey: preview.baseItemKey,
    label: preview.label,
    price: preview.price,
    mod: preview.mod,
  });
});

els.submitBtn.addEventListener('click', () => {
  const cart = state.cart.map((line) => ({
    type: line.type,
    categoryKey: line.categoryKey,
    groupKey: line.groupKey,
    itemKey: line.type === 'item' ? (line.baseItemKey || line.itemKey) : line.itemKey,
    variantKey: line.type === 'item' ? line.itemKey : undefined,
    label: line.label,
    mod: line.mod,
  }));
  post('submitOrder', { cart });
});

function handleEscape() {
  if (state.activeGroup) {
    backOptions();
    return;
  }
  if (state.activeCategory) {
    closeCategory();
    return;
  }
  post('close');
}

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'open') openUI(msg);
  if (msg.action === 'close') closeUI(msg.keepVehicle === true);
  if (msg.action === 'escape') handleEscape();
});

document.addEventListener('keydown', (e) => {
  if (!tunerIsOpen()) return;

  if (e.key === 'a' || e.key === 'A') {
    e.preventDefault();
    setCameraKey('a', true);
    return;
  }
  if (e.key === 'd' || e.key === 'D') {
    e.preventDefault();
    setCameraKey('d', true);
    return;
  }

  if (e.key === 'Escape') {
    handleEscape();
  }
});

document.addEventListener('keyup', (e) => {
  if (!tunerIsOpen()) return;
  if (e.key === 'a' || e.key === 'A') setCameraKey('a', false);
  if (e.key === 'd' || e.key === 'D') setCameraKey('d', false);
});

document.addEventListener('wheel', (e) => {
  if (!tunerIsOpen()) return;
  if (els.optionsTrack.contains(e.target)) return;
  e.preventDefault();
  post('cameraZoom', { delta: e.deltaY > 0 ? 1 : -1 });
}, { passive: false });

els.optionsTrack.addEventListener('wheel', (e) => {
  if (Math.abs(e.deltaY) > Math.abs(e.deltaX)) {
    e.preventDefault();
    els.optionsTrack.scrollLeft += e.deltaY * 1.2;
  }
}, { passive: false });

els.rgbCancelBtn.addEventListener('click', closeRgbModal);
els.rgbApplyBtn.addEventListener('click', () => {
  const cat = rgbState.cat;
  const group = rgbState.group;
  const item = rgbState.item;
  if (!cat || !group || !item) return;

  const prop = getRgbPaintTarget();
  const baseItemKey = getRgbBaseItemKey(group, prop);
  const price = getRgbPrice(group, prop);
  const paintLabel = prop === 'color2' ? 'Sekundær RGB' : 'Primær RGB';
  const rgb = hexToRgb(els.rgbPicker.value);
  const mod = {
    kind: 'customColor',
    prop,
    r: rgb.r,
    g: rgb.g,
    b: rgb.b,
  };
  const label = `${paintLabel} (${els.rgbPicker.value.toUpperCase()})`;

  state.previewItem = {
    categoryKey: cat.key,
    groupKey: group.key,
    itemKey: item.key,
    label,
    price,
    mod,
    baseItemKey,
    item: { ...item, mod, label, price, baseKey: baseItemKey },
  };

  post('applyRgbColor', {
    categoryKey: cat.key,
    groupKey: group.key,
    itemKey: item.key,
    prop: mod.prop,
    r: rgb.r,
    g: rgb.g,
    b: rgb.b,
  });

  closeRgbModal();
  renderOptionsView();
  renderPreviewBar();
  showToast('RGB anvendt');
});
