const sellApp = document.getElementById('sell-app');
const adminApp = document.getElementById('admin-app');
const worldPrompt = document.getElementById('world-prompt');
const worldPromptText = document.getElementById('world-prompt-text');
const worldPromptKey = document.getElementById('world-prompt-key');

let sellState = {
    target: null,
    offers: [],
    selectedOfferIndex: 0,
    sliderValue: 50,
    npcBagCount: 1,
    maxNpcBuy: 8,
};

let adminState = {
    state: null,
    drugs: {},
    oxItems: [],
    position: null,
    dealerModels: [],
    defaults: {},
};

let adminActionBusy = false;
let sellSubmitting = false;

function isEnabledFlag(value) {
    return value == 1 || value === true || value === '1';
}

function escapeHtml(text) {
    return String(text ?? '')
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function itemLabelFor(name) {
    const found = adminState.oxItems.find((i) => i.name === name);
    return found ? `${found.label} (${found.name})` : name;
}

function buildItemOptions(selected, query) {
    const q = (query || '').toLowerCase();
    const items = adminState.oxItems.filter((i) =>
        !q || i.label.toLowerCase().includes(q) || i.name.toLowerCase().includes(q)
    );

    if (!items.length) {
        return '<option value="">Ingen items fundet i ox_inventory</option>';
    }

    return items.map((i) =>
        `<option value="${escapeHtml(i.name)}" ${i.name === selected ? 'selected' : ''}>${escapeHtml(i.label)} (${escapeHtml(i.name)})</option>`
    ).join('');
}

function itemFieldHtml(prefix, selected, labelText) {
    return `
        <label class="item-field">${labelText}
            <input type="search" id="${prefix}-search" class="item-search" placeholder="Søg item..." autocomplete="off">
            <select id="${prefix}-select" class="item-select">${buildItemOptions(selected || '', '')}</select>
        </label>
    `;
}

function bindItemField(prefix, onChange) {
    const search = document.getElementById(`${prefix}-search`);
    const select = document.getElementById(`${prefix}-select`);
    if (!select) return;

    const refresh = () => {
        const selected = select.value;
        select.innerHTML = buildItemOptions(selected, search?.value || '');
        if (selected) select.value = selected;
    };

    search?.addEventListener('input', refresh);
    select.addEventListener('change', () => onChange?.(select.value));
}

function getItemFieldValue(prefix) {
    return document.getElementById(`${prefix}-select`)?.value || '';
}

function setItemFieldValue(prefix, value) {
    const select = document.getElementById(`${prefix}-select`);
    const search = document.getElementById(`${prefix}-search`);
    if (!select) return;
    if (search) search.value = '';
    select.innerHTML = buildItemOptions(value, '');
    select.value = value;
}

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

async function runAdminAction(action) {
    if (adminActionBusy) return;
    adminActionBusy = true;
    try {
        await action();
    } finally {
        adminActionBusy = false;
    }
}

function closeAll() {
    sellApp.classList.add('hidden');
    adminApp.classList.add('hidden');
    worldPrompt.classList.add('hidden');
    post('close');
}

function updateWorldPrompt(data) {
    if (!data?.show) {
        worldPrompt.classList.add('hidden');
        return;
    }

    worldPromptText.textContent = data.text || 'Sælg Stoffer';
    worldPrompt.style.left = `${data.x || 50}%`;
    worldPrompt.style.top = `${data.y || 50}%`;

    if (worldPromptKey) {
        worldPromptKey.classList.toggle('hidden', data.showKey === false);
    }

    worldPrompt.classList.remove('hidden');
}

function calcAcceptChance(base, offer, bonusPct = 0) {
    let chance;
    if (offer <= base) chance = 92;
    else {
        const over = (offer - base) / base;
        if (over <= 0.30) {
            chance = Math.max(55, Math.floor(92 - over * 120));
        } else {
            const extraOver = over - 0.30;
            chance = Math.max(4, Math.floor(14 - extraOver * 30));
        }
    }
    return Math.min(98, chance + (Number(bonusPct) || 0));
}

function flattenSellOffers(items) {
    const offers = [];
    (items || []).forEach((item) => {
        (item.bags || []).forEach((bag) => {
            offers.push({
                drugKey: item.key,
                drugLabel: item.label,
                grams: bag.grams,
                count: bag.count,
                minPrice: bag.minPrice,
                basePrice: bag.basePrice,
                maxPrice: bag.maxPrice,
                color: item.color,
            });
        });
    });
    return offers.sort((a, b) => a.drugLabel.localeCompare(b.drugLabel, 'da') || a.grams - b.grams);
}

function getSelectedOffer() {
    return sellState.offers[sellState.selectedOfferIndex] || null;
}

function priceFromSlider(priceCfg, sliderVal) {
    const min = priceCfg.minPrice;
    const max = priceCfg.maxPrice;
    const t = sliderVal / 100;
    return Math.floor(min + (max - min) * t);
}

function renderOfferTabs() {
    const wrap = document.getElementById('sell-offer-tabs');
    if (!wrap) return;

    const offers = sellState.offers;
    if (offers.length <= 1) {
        wrap.innerHTML = '';
        wrap.classList.add('hidden');
        return;
    }

    wrap.classList.remove('hidden');
    wrap.innerHTML = offers.map((offer, index) => `
        <button type="button"
            class="sell-offer-tab ${index === sellState.selectedOfferIndex ? 'active' : ''}"
            data-index="${index}"
            style="${offer.color ? `--tab-color:${offer.color}` : ''}">
            ${offer.drugLabel}${offer.count > 1 ? ` · ${offer.count}x` : ''}
        </button>
    `).join('');

    wrap.querySelectorAll('.sell-offer-tab').forEach((btn) => {
        btn.addEventListener('click', () => {
            sellState.selectedOfferIndex = Number(btn.dataset.index);
            sellState.sliderValue = 50;
            document.getElementById('price-slider').value = 50;
            renderSell();
        });
    });
}

function renderSell() {
    const offer = getSelectedOffer();
    if (!offer) return;

    renderOfferTabs();

    const qty = sellState.npcBagCount || 1;
    const unit = priceFromSlider(offer, sellState.sliderValue);
    const total = unit * qty;
    const accept = calcAcceptChance(offer.basePrice, unit, sellState.skillAcceptPct);
    const fillPct = sellState.sliderValue;
    const canFulfill = offer.count >= qty;
    const skillBits = [];
    if (sellState.skillAcceptPct > 0) skillBits.push(`+${sellState.skillAcceptPct}% accept`);
    if (sellState.skillPricePct > 0) skillBits.push(`+${sellState.skillPricePct}% indkomst`);
    if (sellState.skillPoliceReducePct > 0) skillBits.push(`-${sellState.skillPoliceReducePct}% politi`);
    const skillHint = skillBits.length ? ` · Skill: ${skillBits.join(', ')}` : '';

    document.getElementById('sell-offer-title').textContent = `${qty}x ${offer.drugLabel}`;
    document.getElementById('sell-unit-price').textContent = `${unit.toLocaleString('da-DK')} kr`;
    document.getElementById('sell-base-hint').textContent = canFulfill
        ? `Køber vil have ${qty}x ${offer.drugLabel} · Normal: ${offer.basePrice.toLocaleString('da-DK')} kr/stk${skillHint}`
        : `Køber vil have ${qty}x ${offer.drugLabel} — du har kun ${offer.count}x${skillHint}`;
    document.getElementById('sell-total-hint').textContent = `Total: ${total.toLocaleString('da-DK')} kr (${qty}x ${offer.drugLabel})`;
    document.getElementById('sell-total-hint').style.color = canFulfill ? '' : 'var(--danger)';
    document.getElementById('sell-min-label').textContent = `${offer.minPrice.toLocaleString('da-DK')} kr`;
    document.getElementById('sell-max-label').textContent = `${offer.maxPrice.toLocaleString('da-DK')} kr`;
    document.getElementById('accept-fill').style.width = `${accept}%`;
    document.getElementById('accept-text').textContent = `${accept}%`;

    const fill = document.getElementById('price-slider-fill');
    if (fill) fill.style.width = `${fillPct}%`;
    updateSellConfirmButton();
}

function openSell(data) {
    const offers = flattenSellOffers(data.items || []);
    if (!offers.length) return;

    sellState = {
        target: data.target || null,
        offers,
        selectedOfferIndex: 0,
        sliderValue: 50,
        npcBagCount: Math.max(1, Number(data.npcBagCount) || 1),
        maxNpcBuy: Math.max(1, Number(data.maxNpcBuy) || 5),
        skillAcceptPct: Number(data.skillBonuses?.acceptPct) || 0,
        skillPricePct: Number(data.skillBonuses?.pricePct) || 0,
        skillPoliceReducePct: Number(data.skillBonuses?.policeReducePct) || 0,
    };

    document.getElementById('price-slider').value = 50;
    sellApp.classList.remove('hidden');
    adminApp.classList.add('hidden');
    renderSell();
}

function submitSellOffer() {
    if (sellSubmitting) return;

    const offer = getSelectedOffer();
    if (!offer) return;

    const qty = sellState.npcBagCount || 1;
    if (offer.count < qty) {
        post('sellNotify', {
            message: `Du har kun ${offer.count}x — køber vil have ${qty}x`,
            type: 'error',
        });
        return;
    }

    const offerPrice = priceFromSlider(offer, sellState.sliderValue);
    sellSubmitting = true;
    post('sellDrug', {
        target: sellState.target,
        drugKey: offer.drugKey,
        bagGrams: offer.grams,
        bagCount: qty,
        offerPrice,
    }).finally(() => {
        sellSubmitting = false;
    });
}

function updateSellConfirmButton() {
    const btn = document.getElementById('sell-confirm-btn');
    if (!btn) return;
    const offer = getSelectedOffer();
    const qty = sellState.npcBagCount || 1;
    const canFulfill = offer && offer.count >= qty;
    btn.disabled = !canFulfill;
}

function drugOptions(selected) {
    return Object.entries(adminState.drugs).map(([key, drug]) => `
        <option value="${key}" ${key === selected ? 'selected' : ''}>${drug.label}</option>
    `).join('');
}

function modelOptions(selected) {
    return adminState.dealerModels.map((m) => `
        <option value="${m}" ${m === selected ? 'selected' : ''}>${m}</option>
    `).join('');
}

function renderList(kind, rows, renderMeta, renderEdit) {
    if (!rows || rows.length === 0) {
        return '<p style="color: rgba(238,242,246,0.55); font-size: 13px;">Ingen punkter endnu.</p>';
    }

    const showMarkerToggle = kind === 'farm' || kind === 'process';

    return `<div class="admin-list">${rows.map((row) => `
        <div class="list-item-wrap" data-wrap-kind="${kind}" data-wrap-id="${row.id}">
            <div class="list-item" data-kind="${kind}" data-id="${row.id}">
                <div class="list-item__meta">
                    <strong>${escapeHtml(row.label || kind)}</strong>
                    ${renderMeta(row)}
                    <span class="badge ${isEnabledFlag(row.enabled) ? 'badge--on' : 'badge--off'}">${isEnabledFlag(row.enabled) ? 'Åben' : 'Lukket'}</span>
                    ${showMarkerToggle ? `<span class="badge ${isEnabledFlag(row.show_marker) ? 'badge--marker-on' : 'badge--marker-off'}">${isEnabledFlag(row.show_marker) ? 'Marker synlig' : 'Marker skjult'}</span>` : ''}
                </div>
                <div class="list-item__actions">
                    ${renderEdit ? `<button type="button" class="btn btn-sm btn-ghost" data-action="edit">Items</button>` : ''}
                    ${showMarkerToggle ? `<button type="button" class="btn btn-sm btn-ghost ${isEnabledFlag(row.show_marker) ? 'btn-marker-on' : ''}" data-action="marker">${isEnabledFlag(row.show_marker) ? 'Skjul marker' : 'Vis marker'}</button>` : ''}
                    <button type="button" class="btn btn-sm btn-ghost" data-action="toggle">${isEnabledFlag(row.enabled) ? 'Luk' : 'Åbn'}</button>
                    <button type="button" class="btn btn-sm btn-danger" data-action="delete">Slet</button>
                </div>
            </div>
            ${renderEdit ? `<div class="list-item-edit hidden" id="edit-${kind}-${row.id}">${renderEdit(row)}</div>` : ''}
        </div>
    `).join('')}</div>`;
}

function bindItemEditActions(kind) {
    document.querySelectorAll(`.list-item-wrap[data-wrap-kind="${kind}"]`).forEach((wrap) => {
        const id = Number(wrap.dataset.wrapId);
        const row = (adminState.state?.[kind === 'farm' ? 'farms' : kind === 'process' ? 'process' : 'dealers'] || [])
            .find((r) => r.id === id);
        if (!row) return;

        wrap.querySelector('[data-action="edit"]')?.addEventListener('click', () => {
            const panel = document.getElementById(`edit-${kind}-${id}`);
            panel?.classList.toggle('hidden');
        });

        if (kind === 'farm') {
            bindItemField(`edit-farm-item-${id}`);
            wrap.querySelector(`[data-save-farm="${id}"]`)?.addEventListener('click', () => {
                post('adminUpdateFarm', {
                    id,
                    label: row.label,
                    amountMin: row.amount_min,
                    amountMax: row.amount_max,
                    cooldown: row.cooldown,
                    giveItem: getItemFieldValue(`edit-farm-item-${id}`),
                    drugKey: row.drug_key,
                }).then(() => post('adminRefresh'));
            });
        }

        if (kind === 'process') {
            bindItemField(`edit-process-in-${id}`);
            bindItemField(`edit-process-out-${id}`);
            wrap.querySelector(`[data-save-process="${id}"]`)?.addEventListener('click', () => {
                post('adminUpdateProcess', {
                    id,
                    label: row.label,
                    inputAmount: row.input_amount,
                    outputAmount: row.output_amount,
                    duration: row.duration,
                    inputItem: getItemFieldValue(`edit-process-in-${id}`),
                    outputItem: getItemFieldValue(`edit-process-out-${id}`),
                    drugKey: row.drug_key,
                }).then(() => post('adminRefresh'));
            });
        }
    });
}

function itemPreview(itemName) {
    if (!itemName) return '';
    return `<small class="item-preview">Valgt item: <strong>${escapeHtml(itemLabelFor(itemName))}</strong></small>`;
}

function processPreview(inputItem, outputAmount, outputItem, inputAmount) {
    if (!inputItem || !outputItem) return '';
    return `<small class="item-preview">${inputAmount}x <strong>${escapeHtml(itemLabelFor(inputItem))}</strong> → ${outputAmount}x <strong>${escapeHtml(itemLabelFor(outputItem))}</strong></small>`;
}

function defaultDrugItem(drugKey, raw) {
    const drug = adminState.drugs[drugKey];
    if (!drug) return '';
    return raw ? drug.rawItem : drug.sellItem;
}

function renderFarmsTab() {
    const farms = adminState.state?.farms || [];
    const d = adminState.defaults.farm || {};
    const defaultDrug = 'hash';
    const defaultGive = defaultDrugItem(defaultDrug, true);

    document.getElementById('tab-farms').innerHTML = `
        <div class="admin-card">
            <h3>Opret farm på din position</h3>
            <div class="admin-grid">
                <label>Navn<input id="farm-label" value="Farm"></label>
                <label>Stoftype<select id="farm-drug">${drugOptions(defaultDrug)}</select></label>
                <label>Min mængde<input id="farm-min" type="number" min="1" value="${d.amountMin || 1}"></label>
                <label>Max mængde<input id="farm-max" type="number" min="1" value="${d.amountMax || 3}"></label>
                <label>Cooldown (sek)<input id="farm-cooldown" type="number" min="5" value="${d.cooldown || 45}"></label>
            </div>
            ${itemFieldHtml('farm-give', defaultGive, 'Item fra ox_inventory (spilleren får)')}
            <div class="item-presets">
                <span class="item-presets__label">Hurtig valg:</span>
                <button type="button" class="btn btn-sm btn-ghost" id="farm-preset-raw">Råvare</button>
                <button type="button" class="btn btn-sm btn-ghost" id="farm-preset-sell">Færdig 1g</button>
            </div>
            <div id="farm-preview">${itemPreview(defaultGive)}</div>
            <div class="admin-create">
                <button type="button" class="btn btn-primary" id="create-farm"><i class="fa-solid fa-plus"></i> Opret farm her</button>
            </div>
        </div>
        ${renderList('farm', farms, (row) => `
            <small>${adminState.drugs[row.drug_key]?.label || row.drug_key} · ${row.amount_min}-${row.amount_max} stk · ${row.cooldown}s</small>
            <small>Giver: ${escapeHtml(row.reward_label || itemLabelFor(row.give_item))}</small>
        `, (row) => `
            <div class="edit-items-grid edit-items-grid--single">
                ${itemFieldHtml(`edit-farm-item-${row.id}`, row.give_item, 'Reward item')}
                <button type="button" class="btn btn-sm btn-primary" data-save-farm="${row.id}">Gem item</button>
            </div>
        `)}
    `;

    bindItemField('farm-give', (value) => {
        document.getElementById('farm-preview').innerHTML = itemPreview(value);
    });

    const updateFarmItemFromDrug = (raw) => {
        const drugKey = document.getElementById('farm-drug').value;
        setItemFieldValue('farm-give', defaultDrugItem(drugKey, raw));
        document.getElementById('farm-preview').innerHTML = itemPreview(getItemFieldValue('farm-give'));
    };

    document.getElementById('farm-drug').addEventListener('change', () => updateFarmItemFromDrug(true));
    document.getElementById('farm-preset-raw').addEventListener('click', () => updateFarmItemFromDrug(true));
    document.getElementById('farm-preset-sell').addEventListener('click', () => updateFarmItemFromDrug(false));

    document.getElementById('create-farm').addEventListener('click', () => {
        post('adminCreateFarm', {
            label: document.getElementById('farm-label').value,
            drugKey: document.getElementById('farm-drug').value,
            amountMin: Number(document.getElementById('farm-min').value),
            amountMax: Number(document.getElementById('farm-max').value),
            cooldown: Number(document.getElementById('farm-cooldown').value),
            giveItem: getItemFieldValue('farm-give'),
            ...adminState.position,
        }).then(() => post('adminRefresh'));
    });

    bindItemEditActions('farm');
}

function renderProcessTab() {
    const rows = adminState.state?.process || [];
    const d = adminState.defaults.process || {};
    const defaultDrug = 'hash';
    const defaultIn = defaultDrugItem(defaultDrug, true);
    const defaultOut = defaultDrugItem(defaultDrug, false);

    document.getElementById('tab-process').innerHTML = `
        <div class="admin-card">
            <h3>Opret omdan på din position</h3>
            <div class="admin-grid">
                <label>Navn<input id="process-label" value="Omdan"></label>
                <label>Stoftype<select id="process-drug">${drugOptions(defaultDrug)}</select></label>
                <label>Rå mængde ind<input id="process-in" type="number" min="1" value="${d.inputAmount || 5}"></label>
                <label>1g mængde ud<input id="process-out" type="number" min="1" value="${d.outputAmount || 1}"></label>
                <label>Varighed (ms)<input id="process-duration" type="number" min="1000" value="${d.duration || 9000}"></label>
            </div>
            <div class="admin-grid admin-grid--items">
                ${itemFieldHtml('process-input', defaultIn, 'Input item (ox_inventory)')}
                ${itemFieldHtml('process-output', defaultOut, 'Output item (ox_inventory)')}
            </div>
            <div class="item-presets">
                <span class="item-presets__label">Hurtig valg:</span>
                <button type="button" class="btn btn-sm btn-ghost" id="process-preset-default">Standard for stoftype</button>
            </div>
            <div id="process-preview">${processPreview(defaultIn, d.outputAmount || 1, defaultOut, d.inputAmount || 5)}</div>
            <div class="admin-create">
                <button type="button" class="btn btn-primary" id="create-process"><i class="fa-solid fa-plus"></i> Opret omdan her</button>
            </div>
        </div>
        ${renderList('process', rows, (row) => `
            <small>${adminState.drugs[row.drug_key]?.label || row.drug_key} · ${row.input_amount} → ${row.output_amount} · ${row.duration}ms</small>
            <small>${escapeHtml(row.input_label || itemLabelFor(row.input_item))} → ${escapeHtml(row.output_label || itemLabelFor(row.output_item))}</small>
        `, (row) => `
            <div class="edit-items-grid">
                ${itemFieldHtml(`edit-process-in-${row.id}`, row.input_item, 'Input item')}
                ${itemFieldHtml(`edit-process-out-${row.id}`, row.output_item, 'Output item')}
                <button type="button" class="btn btn-sm btn-primary" data-save-process="${row.id}">Gem items</button>
            </div>
        `)}
    `;

    const updateProcessPreview = () => {
        const inputAmount = Number(document.getElementById('process-in').value) || 1;
        const outputAmount = Number(document.getElementById('process-out').value) || 1;
        document.getElementById('process-preview').innerHTML = processPreview(
            getItemFieldValue('process-input'),
            outputAmount,
            getItemFieldValue('process-output'),
            inputAmount
        );
    };

    const applyProcessDrugDefaults = () => {
        const drugKey = document.getElementById('process-drug').value;
        setItemFieldValue('process-input', defaultDrugItem(drugKey, true));
        setItemFieldValue('process-output', defaultDrugItem(drugKey, false));
        updateProcessPreview();
    };

    bindItemField('process-input', updateProcessPreview);
    bindItemField('process-output', updateProcessPreview);

    document.getElementById('process-drug').addEventListener('change', applyProcessDrugDefaults);
    document.getElementById('process-preset-default').addEventListener('click', applyProcessDrugDefaults);
    ['process-in', 'process-out'].forEach((id) => {
        document.getElementById(id).addEventListener('input', updateProcessPreview);
    });

    document.getElementById('create-process').addEventListener('click', () => {
        post('adminCreateProcess', {
            label: document.getElementById('process-label').value,
            drugKey: document.getElementById('process-drug').value,
            inputAmount: Number(document.getElementById('process-in').value),
            outputAmount: Number(document.getElementById('process-out').value),
            duration: Number(document.getElementById('process-duration').value),
            inputItem: getItemFieldValue('process-input'),
            outputItem: getItemFieldValue('process-output'),
            ...adminState.position,
        }).then(() => post('adminRefresh'));
    });

    bindItemEditActions('process');
}

function renderDealersTab() {
    const rows = adminState.state?.dealers || [];
    const defModel = adminState.defaults.dealer?.model || 'a_m_y_stwhi_02';

    document.getElementById('tab-dealers').innerHTML = `
        <div class="admin-card">
            <h3>Salgs-NPC'er (valgfrit)</h3>
            <p class="admin-help">Spillere kan sælge til alle NPC'er i verden med [E] Sælg Stoffer. Admin-dealere her er kun til reference/markører hvis SellToAllNpcs er slået fra.</p>
            <div class="admin-grid">
                <label>Navn<input id="dealer-label" value="Dealer"></label>
                <label>Model<select id="dealer-model">${modelOptions(defModel)}</select></label>
            </div>
            <div class="admin-create">
                <button type="button" class="btn btn-primary" id="create-dealer"><i class="fa-solid fa-plus"></i> Spawn dealer her</button>
            </div>
        </div>
        ${renderList('dealer', rows, (row) => `
            <small>${row.model} · heading ${Math.round(row.heading || 0)}°</small>
        `)}
    `;

    document.getElementById('create-dealer').addEventListener('click', () => {
        post('adminCreateDealer', {
            label: document.getElementById('dealer-label').value,
            model: document.getElementById('dealer-model').value,
            x: adminState.position.x,
            y: adminState.position.y,
            z: adminState.position.z,
            heading: adminState.position.heading,
        }).then(() => post('adminRefresh'));
    });
}

function renderPricesTab() {
    const bagPrices = adminState.state?.bagPrices || {};
    const gramsList = [1];
    const maxNpcBuy = adminState.state?.settings?.maxNpcBuy || 8;

    document.getElementById('tab-prices').innerHTML = `
        <div class="admin-card">
            <h3>NPC køb</h3>
            <p class="admin-help">Hvor mange enheder en NPC max kan købe ad gangen. Ved hvert salg ønsker NPC'en et tilfældigt antal mellem 1 og dette tal (fx 8x Kokain).</p>
            <label class="admin-inline-field">Max antal per NPC-salg
                <input id="max-npc-buy" type="number" min="1" max="50" value="${maxNpcBuy}">
            </label>
        </div>
        <div class="admin-card">
            <h3>Salgspriser</h3>
            <p class="admin-help">Sæt min, normal og max pris per stk (fx 1x Kokain). Spilleren forhandler prisen per stk.</p>
            <div class="price-admin-list">
                ${Object.entries(adminState.drugs).map(([key, drug]) => {
                    const sizes = bagPrices[key] || {};
                    return `
                        <div class="price-admin-row">
                            <h4>${escapeHtml(drug.label)}</h4>
                            <div class="bag-price-table">
                                <div class="bag-price-head">
                                    <span>Stof</span>
                                    <span>Min</span>
                                    <span>Normal</span>
                                    <span>Max</span>
                                </div>
                                ${gramsList.map((grams) => {
                                    const p = sizes[grams] || sizes[String(grams)] || { minPrice: 300, basePrice: 500, maxPrice: 650 };
                                    return `
                                        <div class="bag-price-row">
                                            <strong>${drug.label}</strong>
                                            <input id="bag-price-min-${key}-${grams}" type="number" min="1" value="${p.minPrice}">
                                            <input id="bag-price-base-${key}-${grams}" type="number" min="1" value="${p.basePrice}">
                                            <input id="bag-price-max-${key}-${grams}" type="number" min="1" value="${p.maxPrice}">
                                        </div>
                                    `;
                                }).join('')}
                            </div>
                        </div>
                    `;
                }).join('')}
            </div>
            <div class="admin-create">
                <button type="button" class="btn btn-primary" id="save-prices"><i class="fa-solid fa-floppy-disk"></i> Gem priser</button>
            </div>
        </div>
    `;

    document.getElementById('save-prices').addEventListener('click', () => {
        const payload = {};
        Object.keys(adminState.drugs).forEach((key) => {
            payload[key] = {};
            gramsList.forEach((grams) => {
                payload[key][grams] = {
                    minPrice: Number(document.getElementById(`bag-price-min-${key}-${grams}`).value),
                    basePrice: Number(document.getElementById(`bag-price-base-${key}-${grams}`).value),
                    maxPrice: Number(document.getElementById(`bag-price-max-${key}-${grams}`).value),
                };
            });
        });
        post('adminUpdatePrices', {
            bagPrices: payload,
            maxNpcBuy: Number(document.getElementById('max-npc-buy').value),
        });
    });
}

function bindAdminListActions() {
    document.querySelectorAll('.list-item').forEach((el) => {
        el.querySelector('[data-action="marker"]')?.addEventListener('click', () => {
            const kind = el.dataset.kind;
            const id = Number(el.dataset.id);
            runAdminAction(async () => {
                await post('adminToggleMarker', { kind, id });
                await post('adminRefresh');
            });
        });

        el.querySelector('[data-action="toggle"]')?.addEventListener('click', () => {
            const kind = el.dataset.kind;
            const id = Number(el.dataset.id);
            const enabled = !isEnabledFlag(
                (adminState.state?.[kind === 'farm' ? 'farms' : kind === 'process' ? 'process' : 'dealers'] || [])
                    .find((row) => row.id === id)?.enabled
            );
            runAdminAction(async () => {
                await post('adminToggle', { kind, id, enabled });
                await post('adminRefresh');
            });
        });

        el.querySelector('[data-action="delete"]')?.addEventListener('click', () => {
            const kind = el.dataset.kind;
            const id = Number(el.dataset.id);
            runAdminAction(async () => {
                await post('adminDelete', { kind, id });
                await post('adminRefresh');
            });
        });
    });
}

function renderAdminTab(tab) {
    document.querySelectorAll('.admin-tab').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.admin-section').forEach((sec) => sec.classList.add('hidden'));
    document.getElementById(`tab-${tab}`).classList.remove('hidden');

    if (tab === 'farms') renderFarmsTab();
    if (tab === 'process') renderProcessTab();
    if (tab === 'dealers') renderDealersTab();
    if (tab === 'prices') renderPricesTab();
    bindAdminListActions();
}

function openAdmin(data) {
    adminState = {
        state: data.state,
        drugs: data.drugs || {},
        oxItems: data.oxItems || [],
        position: data.position,
        dealerModels: data.dealerModels || [],
        defaults: data.defaults || {},
    };

    adminApp.classList.remove('hidden');
    sellApp.classList.add('hidden');
    renderAdminTab('farms');
}

document.getElementById('admin-close').addEventListener('click', closeAll);

document.getElementById('price-slider').addEventListener('input', (e) => {
    sellState.sliderValue = Number(e.target.value);
    renderSell();
});

document.getElementById('sell-confirm-btn')?.addEventListener('click', submitSellOffer);

document.querySelectorAll('.admin-tab').forEach((btn) => {
    btn.addEventListener('click', () => renderAdminTab(btn.dataset.tab));
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data?.action) return;

    if (data.action === 'openSell') openSell(data);
    if (data.action === 'openAdmin') openAdmin(data);
    if (data.action === 'worldPrompt') updateWorldPrompt(data);
    if (data.action === 'confirmSell') submitSellOffer();
    if (data.action === 'stateUpdate') {
        adminState.state = data.state;
        const active = document.querySelector('.admin-tab.active')?.dataset.tab || 'farms';
        renderAdminTab(active);
    }
    if (data.action === 'close') {
        sellApp.classList.add('hidden');
        adminApp.classList.add('hidden');
    }
});

document.addEventListener('keydown', (e) => {
    if (sellApp.classList.contains('hidden')) {
        if (e.key === 'Escape') closeAll();
        return;
    }

    if (e.key === 'Escape') {
        closeAll();
        return;
    }

    if (e.key === 'Enter' || e.code === 'NumpadEnter') {
        e.preventDefault();
        submitSellOffer();
    }
});
