$(window).ready(function () {
  let activePage = 'garage';
  let currentMode = 'garage';

  const carSvg = "<svg viewBox='0 0 160 80' xmlns='http://www.w3.org/2000/svg'><path d='M18 50c2-12 7-19 20-22l16-14h50c12 0 22 12 31 15 11 3 17 8 18 21v9h-13a18 18 0 0 1-35 0H56a18 18 0 0 1-35 0H11v-9h7zM61 19 48 31h31V19H61zm24 0v12h34c-8-7-13-12-24-12H85z'/><circle cx='39' cy='59' r='12'/><circle cx='123' cy='59' r='12'/></svg>";
  const bikeSvg = "<svg viewBox='0 0 160 80' xmlns='http://www.w3.org/2000/svg'><path d='M45 56a18 18 0 1 1-36 0 18 18 0 0 1 36 0zm106 0a18 18 0 1 1-36 0 18 18 0 0 1 36 0zM42 50h20l16-22h17l-8 14h19l10 8h11v9h-18l-18-14H72L58 61H42v-11zm44-26 5-12h20l2 7H99l-2 5H86z'/></svg>";

  window.addEventListener("message", function (event) {
    let data = event.data;

    if (data.action === "showGaragePrompt") {
      $(".prompt-key").text(data.key || "F3");
      $(".prompt-label").text(data.label || "Garage");
      $("#garage-prompt").addClass("visible");
      return;
    }

    if (data.action === "hideGaragePrompt") {
      $("#garage-prompt").removeClass("visible");
      return;
    }

    if (data.action === "openPoliceImpoundDialog") {
      openPoliceImpoundDialog(data);
      return;
    }

    if (data.showMenu) openMenu(data);
    else if (data.hideAll) closeMenu(false);
  });

  function openMenu(data) {
    activePage = 'garage';
    currentMode = data.type || 'garage';
    $("#garage-prompt").removeClass("visible");
    $("#container").css({ display: 'flex', opacity: 0 }).animate({ opacity: 1 }, 160);

    const garageName = data.garageName || data.poundName || 'Garage';
    $("#garage-location").text(garageName);

    $("#container").data("spawnpoint", data.spawnPoint || {});
    if (data.poundCost !== undefined) $("#container").data("poundcost", data.poundCost); else $("#container").removeData("poundcost");
    if (data.poundName !== undefined) $("#container").data("poundname", data.poundName); else $("#container").removeData("poundname");

    const garageVehicles = parseList(data.vehiclesList);
    const serviceVehicles = parseList(data.serviceVehiclesList);

    const normalStored = garageVehicles.filter(v => !v.impounded).length;
    const impoundedCount = garageVehicles.filter(v => v.impounded).length;
    if (currentMode === 'impound') {
      setCount(impoundedCount, null, 'Beslaglagte Køretøjer');
    } else {
      setCount(normalStored, garageVehicles.length, 'Parked Cars');
    }

    renderPage('.content', garageVehicles, function () {
      return getVehicles(data.locales || {}, garageVehicles, data.poundCost);
    });

    // Impound er ikke længere en kategori i normal garage. Ved en impound-lokation åbner samme UI i impound-mode.
    $('.impounded_content .vehicle-list').html('');
    $('button[data-page="impounded"]').hide();

    if (currentMode === 'impound') {
      $('#garage-title').text('Impound');
      $('.garage-subtitle').text('Betal og hent beslaglagte køretøjer');
      $('button[data-page="service"]').hide();
    } else {
      $('#garage-title').text('Garage');
      $('.garage-subtitle').text('Hent køretøjer fra garagen');
    }

    if (currentMode !== 'impound' && serviceVehicles.length > 0) {
      renderPage('.service_content', serviceVehicles, function () {
        return getServiceVehicles(data.locales || {}, serviceVehicles);
      });
      $('button[data-page="service"]').show();
    } else {
      renderPage('.service_content', [], function(){ return ''; });
      $('button[data-page="service"]').hide();
    }

    const isPoliceGarage = currentMode === 'policegarage';
    $('#container').toggleClass('policegarage', isPoliceGarage);
    if (isPoliceGarage) {
      $('#garage-title').text('Politi Garage');
      $('.garage-subtitle').text('Tjenestekøretøjer & AutoShop');
      $('#police-autoshop-banner').prop('hidden', false);
    } else {
      $('#police-autoshop-banner').prop('hidden', true);
    }

    showPage('garage');
  }

  function closeMenu(sendEscape) {
    $("#container").stop(true, true).fadeOut(120, function(){ $(this).css('display','none'); });
    if (sendEscape) $.post("https://esx_garage/escape", "{}");
  }

  function parseList(raw) {
    if (raw === undefined || raw === null) return [];
    try {
      if (Array.isArray(raw)) raw = raw[0];
      if (typeof raw === 'string') return JSON.parse(raw || '[]') || [];
      if (Array.isArray(raw)) return raw;
      return [];
    } catch (e) { return []; }
  }

  function setCount(stored, total, label) {
    if (currentMode === 'impound') {
      $('#stored-count').text(String(stored || 0));
    } else {
      if (!total || total < stored) total = stored;
      $('#stored-count').text(stored + '/' + total);
    }
    $('#stored-label').text(label || (currentMode === 'impound' ? 'Beslaglagte Køretøjer' : 'Parked Cars'));
  }

  function renderPage(selector, list, htmlFactory) {
    const $page = $(selector);
    const html = htmlFactory();
    $page.find('.vehicle-list').html(html);
    if (list.length > 0) $page.find('.empty').hide();
    else $page.find('.empty').show();
  }

  $("#container").hide();
  $(".close").click(function () { closeMenu(true); });
  document.onkeyup = function (data) { if (data.which == 27) closeMenu(true); };

  $("#police-autoshop-btn").click(function () {
    $.post("https://esx_garage/openPoliceAutoshop", "{}");
  });

  function clamp(n, min, max){ return Math.max(min, Math.min(max, n)); }
  function esc(v) { return String(v === undefined || v === null ? '' : v).replace(/[&<>'"]/g, function(c){ return ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]); }); }
  function statusText(percent) { return percent >= 80 ? 'Stored' : 'Skadet'; }
  function iconFor(model) {
    const m = String(model || '').toLowerCase();
    if (m.indexOf('faggio') !== -1 || m.indexOf('bike') !== -1 || m.indexOf('bati') !== -1 || m.indexOf('sanchez') !== -1) return bikeSvg;
    return carSvg;
  }
  function fuelPercent(props) {
    const p = props || {};
    const raw = p.fuelLevel !== undefined ? p.fuelLevel : p.fuel;
    const n = Number(raw);
    return Number.isFinite(n) ? clamp(Math.round(n), 0, 100) : 0;
  }

  function damagePercent(props) {
    const p = props || {};
    const b = typeof p.bodyHealth === 'number' ? p.bodyHealth : 1000;
    const e = typeof p.engineHealth === 'number' ? p.engineHealth : 1000;
    const t = typeof p.tankHealth === 'number' ? p.tankHealth : 1000;
    return clamp(Math.round((((b/1000)*100 + (e/1000)*100 + (t/1000)*100) / 300)), 0, 100);
  }

  function vehicleCard(opts) {
    const name = esc(opts.name || opts.model || 'Vehicle');
    const plate = esc(opts.plate || 'NO PLATE');
    const model = esc(String(opts.model || '').toLowerCase());
    const pct = opts.percent !== undefined ? opts.percent : 100;
    const impounded = opts.impounded === true;
    const isLockedImpound = opts.impoundLocked === true || Number(opts.impoundLocked || 0) === 1 || opts.impoundType === 'locked' || opts.impoundType === 'permanent';
    const canRetrieveFromImpound = opts.canRetrieveFromImpound === true && !isLockedImpound;
    const extraClass = (String(opts.model || '').toLowerCase().indexOf('police') !== -1 ? ' police' : '') + (impounded ? ' impounded' : '');
    const buttonClass = (opts.red ? 'vehicle-action red' : 'vehicle-action') + (impounded && !canRetrieveFromImpound ? ' disabled' : '');
    const propsAttr = opts.props ? " data-vehprops='" + esc(JSON.stringify(opts.props)) + "'" : '';
    const modelAttr = opts.buyModel ? " data-model='" + esc(opts.buyModel) + "'" : '';
    const disabled = (impounded && !canRetrieveFromImpound) ? " disabled='disabled'" : '';
    const badgeClass = isLockedImpound ? 'impound-badge locked' : 'impound-badge';
    const badge = impounded ? "<span class='" + badgeClass + "'>" + (opts.impoundType === 'permanent' ? 'Permanent' : (isLockedImpound ? 'LÅST' : 'Beslaglagt')) + "</span>" : "";
    const reason = opts.impoundReason ? "<div class='impound-detail'><strong>Årsag:</strong> " + esc(opts.impoundReason) + "</div>" : "";
    const officer = opts.impoundOfficer ? "<div class='impound-detail'><strong>Betjent:</strong> " + esc(opts.impoundOfficer) + "</div>" : "";
    const impoundDetails = (currentMode === 'impound' && (reason || officer)) ? "<div class='impound-details'>" + reason + officer + "</div>" : "";
    const fuel = opts.fuel !== undefined ? Number(opts.fuel) : null;
    const fuelHtml = fuel !== null && Number.isFinite(fuel) ? "<span class='vehicle-fuel'>Benzin: " + clamp(Math.round(fuel), 0, 100) + "%</span>" : "";

    return "<div class='vehicle-card" + extraClass + "' data-model='" + model + "' data-plate='" + esc(String(opts.plate || '').toLowerCase()) + "'>" +
      "<div class='vehicle-thumb'><div class='vehicle-plate'>" + plate + "</div><div class='vehicle-icon'>" + iconFor(opts.model) + "</div></div>" +
      "<div class='vehicle-info'><span class='vehicle-name'>" + name + "</span>" + badge + "<span class='vehicle-status'>" + esc(opts.status || statusText(pct)) + "</span>" + fuelHtml + impoundDetails + "</div>" +
      "<div class='vehicle-meta'><span style='width:" + pct + "%'></span></div>" +
      "<button data-button='" + opts.button + "' class='" + buttonClass + "'" + propsAttr + modelAttr + disabled + ">" + esc(opts.buttonText) + "</button>" +
    "</div>";
  }

  function getVehicles(locale, vehicles, amount = null) {
    let html = "";
    for (let i = 0; i < vehicles.length; i++) {
      const v = vehicles[i];
      const p = v.props || {};
      const pct = v.impounded ? 100 : damagePercent(p);
      const isImpoundMode = currentMode === 'impound';
      const vehicleAmount = Number(v.impoundPrice || v.impound_price || amount || 0);
      html += vehicleCard({
        name: v.model,
        model: v.model,
        plate: v.plate,
        percent: pct,
        fuel: fuelPercent(p),
        props: p,
        impounded: v.impounded === true,
        canRetrieveFromImpound: isImpoundMode && v.impounded === true,
        impoundReason: v.impoundReason || v.impound_reason,
        impoundOfficer: v.impoundOfficer || v.impound_officer,
        impoundType: v.impoundType || v.impound_type || 'normal',
        impoundLocked: v.impoundLocked || v.impound_locked || 0,
        status: v.impounded ? ((v.impoundType || v.impound_type) === 'permanent' ? 'Permanent beslaglagt' : ((Number(v.impoundLocked || v.impound_locked || 0) === 1 || (v.impoundType || v.impound_type) === 'locked') ? 'Låst af politiet' : (isImpoundMode ? ('Pris: ' + vehicleAmount.toLocaleString('da-DK') + ' DKK') : 'Hent ved impound'))) : 'Stored',
        button: (v.impounded && !isImpoundMode) ? 'locked-impound' : 'spawn',
        buttonText: (v.impounded && !isImpoundMode) ? 'Hent ved impound' : ((locale.action || 'Retrieve Vehicle') + (vehicleAmount ? ' (' + vehicleAmount.toLocaleString('da-DK') + ' DKK)' : ''))
      });
    }
    return html;
  }

  function getServiceVehicles(locale, vehicles) {
    let html = "";
    for (let i = 0; i < vehicles.length; i++) {
      const v = vehicles[i];
      const price = Number(v.price || 0).toLocaleString('en-US');
      html += vehicleCard({
        name: (v.name || v.model || 'Vehicle') + ' - $' + price,
        model: v.model,
        plate: 'SERVICE',
        percent: 100,
        status: 'Til salg',
        button: 'buy-service',
        buttonText: locale.service_action || 'Køb tjenestekøretøj',
        buyModel: v.model
      });
    }
    return html;
  }

  function activeContainer() {
    if (activePage === 'service') return $('.service_content .vehicle-list');
    return $('.content .vehicle-list');
  }

  function applyFilter($container, query) {
    const q = String(query || '').trim().toLowerCase();
    const $cards = $container.find('.vehicle-card');
    if (!q) { $cards.show(); return; }
    $cards.each(function () {
      const model = String($(this).data('model') || '');
      const plate = String($(this).data('plate') || '');
      $(this).toggle(model.indexOf(q) !== -1 || plate.indexOf(q) !== -1);
    });
  }

  $(document).on('input', '#search-garage', function () { applyFilter(activeContainer(), $(this).val()); });

  function showPage(page) {
    if (page === 'service' && !$('button[data-page="service"]').is(':visible')) page = 'garage';
    if (page === 'impounded') page = 'garage';
    activePage = page;
    $('.page').removeClass('active').hide();
    if (page === 'service') $('.service_content').addClass('active').show();
    else $('.content').addClass('active').show();
    $('#tabs button').removeClass('selected');
    $('#tabs button[data-page="' + page + '"]').addClass('selected');
    applyFilter(activeContainer(), $('#search-garage').val());
  }

  $('#tabs button').click(function () { showPage($(this).data('page')); });

  $(document).on("click", "button[data-button='buy-service'].vehicle-action", function () {
    let model = $(this).data("model");
    $.post("https://esx_garage/buyServiceVehicle", JSON.stringify({ model: model }));
  });

  function ensureImpoundPayModal() {
    if ($('#impound-pay-modal').length) return;
    $('body').append(`
      <div id="impound-pay-modal" class="impound-pay-modal" style="display:none">
        <div class="impound-pay-box">
          <h3>Vælg betaling</h3>
          <p>Hvordan vil du betale for at hente køretøjet?</p>
          <div class="impound-pay-price"></div>
          <div class="impound-pay-actions">
            <button type="button" data-pay-method="bank">Kort / bank</button>
            <button type="button" data-pay-method="cash">Kontanter</button>
            <button type="button" data-pay-cancel="1">Annuller</button>
          </div>
        </div>
      </div>`);
  }

  function sendSpawnRequest(vehicleProps, spawnPoint, poundCost, paymentMethod) {
    $.post("https://esx_garage/spawnVehicle", JSON.stringify({
      vehicleProps: vehicleProps,
      spawnPoint: spawnPoint,
      exitVehicleCost: Number(poundCost || 0),
      isImpound: currentMode === 'impound',
      poundName: $('#container').data('poundname'),
      paymentMethod: paymentMethod || 'bank'
    }));
  }

  $(document).on("click", "button[data-button='spawn'].vehicle-action", function () {
    let spawnPoint = $("#container").data("spawnpoint");
    let poundCost = $("#container").data("poundcost");
    let vehicleProps = $(this).data("vehprops");
    if (poundCost === undefined) poundCost = 0;

    if (currentMode === 'impound' && Number(poundCost || 0) > 0) {
      ensureImpoundPayModal();
      $('#impound-pay-modal').data('spawnpoint', spawnPoint).data('vehprops', vehicleProps).data('poundcost', poundCost);
      $('#impound-pay-modal .impound-pay-price').text(Number(poundCost || 0).toLocaleString('da-DK') + ' DKK');
      $('#impound-pay-modal').css('display', 'grid');
      return;
    }

    sendSpawnRequest(vehicleProps, spawnPoint, poundCost, 'bank');
  });

  $(document).on('click', '#impound-pay-modal [data-pay-method]', function () {
    const modal = $('#impound-pay-modal');
    const method = $(this).data('pay-method') || 'bank';
    const spawnPoint = modal.data('spawnpoint');
    const vehicleProps = modal.data('vehprops');
    const poundCost = modal.data('poundcost') || 0;
    modal.hide();
    sendSpawnRequest(vehicleProps, spawnPoint, poundCost, method);
  });

  $(document).on('click', '#impound-pay-modal [data-pay-cancel]', function () {
    $('#impound-pay-modal').hide();
  });

  $(document).on("click", "button[data-button='locked-impound'].vehicle-action", function () {
    // Badge-only: bilen skal hentes/betales ved impound, ikke her.
  });

  function updatePoliceImpoundFields() {
    const selectedType = String($('#police-impound-type').val() || 'normal');
    const isPermanent = selectedType === 'permanent';

    $('#police-impound-price-wrap').toggle(!isPermanent);
    $('#police-impound-lock-row').toggle(!isPermanent);

    if (isPermanent) {
      $('#police-impound-locked').prop('checked', false);
      $('#police-impound-price').val(0);
    }
  }

  function openPoliceImpoundDialog(data) {
    $('#police-impound-plate').text(data.plate || 'UKENDT');
    $('#police-impound-type').val('normal');
    $('#police-impound-locked').prop('checked', false);
    $('#police-impound-price').val(data.defaultPrice || 3000);
    $('#police-impound-reason').val('');
    updatePoliceImpoundFields();
    $('#police-impound-modal').fadeIn(120).css('display', 'grid');
    setTimeout(function(){ $('#police-impound-price').trigger('focus').select(); }, 50);
  }

  function closePoliceImpoundDialog(sendCancel) {
    $('#police-impound-modal').fadeOut(100);
    if (sendCancel) $.post('https://esx_garage/closePoliceImpoundDialog', '{}');
  }

  $('.police-impound-x, .police-impound-actions .cancel').on('click', function(){
    closePoliceImpoundDialog(true);
  });

  $('#police-impound-type').on('change', updatePoliceImpoundFields);

  $('.police-impound-actions .confirm').on('click', function(){
    let impoundType = String($('#police-impound-type').val() || 'normal');
    const locked = $('#police-impound-locked').is(':checked');
    let price = Number($('#police-impound-price').val() || 0);
    const reason = String($('#police-impound-reason').val() || '').trim();

    if (impoundType === 'normal' && locked) impoundType = 'locked';
    if (impoundType === 'permanent') price = 0;

    if (!reason) {
      $('#police-impound-reason').addClass('invalid');
      setTimeout(function(){ $('#police-impound-reason').removeClass('invalid'); }, 900);
      return;
    }

    $.post('https://esx_garage/confirmPoliceImpound', JSON.stringify({
      impoundType: impoundType,
      price: Math.max(0, Math.min(1000000, price)),
      reason: reason
    }));
    $('#police-impound-modal').fadeOut(100);
  });

});
