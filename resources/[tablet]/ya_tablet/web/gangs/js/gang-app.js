window.GangApp = (function () {
  const NAV = [
    { id: 'forside', label: 'Forside', icon: '<path d="M12 3 3 11h2v9h6v-5h2v5h6v-9h2L12 3Z"/>' },
    { id: 'territorier', label: 'Territorier', icon: '<path d="M4 6h16v12H4V6Zm2 2v8h12V8H6Zm2 2h8v4H8v-4Z"/>' },
    { id: 'medlemmer', label: 'Medlemmer', icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>' },
    { id: 'beskeder', label: 'Beskeder', icon: '<path d="M4 5h16v10H7l-3 3V5Z"/>' }
  ];

  let state = { tab: 'forside', map: null };

  function post(name, data) {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_tablet';
    fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || {})
    }).catch(() => {});
  }

  function esc(s) {
    return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function xpProgress(org, cfg) {
    const per = cfg?.xpPerLevel || 500;
    const xp = org?.xp || 0;
    const into = xp % per;
    return { xp, level: org?.level || 1, pct: Math.min(100, Math.round((into / per) * 100)), into, per };
  }

  function navHtml(data) {
    const unread = data?.unreadMessages || 0;
    return `<nav class="bande-nav">
      ${NAV.map((n) => `
        <button type="button" class="bande-nav-btn${state.tab === n.id ? ' active' : ''}" data-gang-tab="${n.id}" style="position:relative;">
          <svg viewBox="0 0 24 24">${n.icon}</svg>
          ${n.label}
          ${n.id === 'beskeder' && unread ? `<span class="nav-badge">${unread}</span>` : ''}
        </button>
      `).join('')}
    </nav>`;
  }

  function renderForside(org, cfg) {
    const p = xpProgress(org, cfg);
    const members = (org.members || []).slice(0, 6);
    return `<div class="bande-forside">
      <div class="bande-forside-grid">
        <div class="hero-card">
          <div class="label">Bande XP</div>
          <div class="value">${p.xp}</div>
          <div class="sub">Niveau ${p.level}</div>
          <div class="xp-bar"><span style="width:${p.pct}%"></span></div>
        </div>
        <div class="hero-card">
          <div class="label">Medlemmer</div>
          <div class="value">${org.memberCount || 0}</div>
          <div class="member-preview" style="margin-top:10px;">
            ${members.map((m) => `
              <div class="member-chip">
                <div class="avatar">${esc((m.name || '?').slice(0, 1))}</div>
                <div><div class="name">${esc(m.name)}</div><div class="role">${esc(m.roleName)}</div></div>
              </div>
            `).join('') || '<div class="sub">Ingen medlemmer</div>'}
          </div>
        </div>
      </div>
      <div class="hero-card">
        <div class="label">Territorier</div>
        <div class="sub">Gå til <strong>Territorier</strong> for at tegne zoner på kortet.</div>
      </div>
    </div>`;
  }

  function renderMedlemmer(org) {
    const canInvite = org.myPermissions?.invite;
    const canKick = org.myPermissions?.kick;
    const canRoles = org.myPermissions?.manage_roles;
    return `<div class="bande-forside">
      ${canInvite ? `
        <div class="invite-row">
          <input type="number" class="field" id="invite-id" placeholder="Spiller server-ID" min="1" />
          <button type="button" class="btn" id="invite-btn">Tilføj</button>
        </div>
      ` : ''}
      <div class="member-list">
        ${(org.members || []).map((m) => `
          <div class="member-row">
            <div class="info"><div class="name">${esc(m.name)}</div><div class="meta">${esc(m.roleName)}</div></div>
            ${canRoles && m.roleKey !== 'leader' ? `
              <select class="role-select" data-member-role="${m.id}">
                ${(org.roles || []).filter((r) => r.key !== 'leader').map((r) => `
                  <option value="${r.id}" ${r.id === m.roleId ? 'selected' : ''}>${esc(r.name)}</option>
                `).join('')}
              </select>
            ` : `<span class="badge">${esc(m.roleName)}</span>`}
            ${canKick && m.roleKey !== 'leader' ? `<button type="button" class="btn danger" data-kick="${m.id}">Smid ud</button>` : ''}
          </div>
        `).join('')}
      </div>
    </div>`;
  }

  function renderBeskeder(data) {
    const msgs = data.messages || [];
    return `<div class="bande-forside">
      <div class="message-list">
        ${msgs.length ? msgs.map((m) => `
          <div class="message-card">
            <h4>${esc(m.title)}</h4>
            <p>${esc(m.body || '')}</p>
            <div class="time">${esc(m.createdAt || '')}</div>
          </div>
        `).join('') : '<div class="empty-state">Ingen beskeder. I får besked ved rival-salg i jeres turf.</div>'}
      </div>
    </div>`;
  }

  function renderTerritorier() {
    return `<div class="bande-panel">
      <div class="bande-map-wrap" id="gang-map-host"></div>
    </div>`;
  }

  function renderCreate(cfg) {
    return `<div class="bande-shell">
      <div class="bande-top" style="padding:16px 18px;display:flex;gap:12px;align-items:center;">
        <button type="button" class="back-btn" data-nav="home">‹</button>
        <div><h2 style="font-size:18px;">Bande</h2><p style="font-size:12px;opacity:.6;">Opret organisation</p></div>
      </div>
      <div class="create-box">
        <h3>Opret bande</h3>
        <p>Tegn territorier på kortet efter oprettelse.</p>
        <input type="text" class="field" id="org-name-input" maxlength="${cfg.maxNameLength || 32}" placeholder="Bande navn" />
        <button type="button" class="btn" id="create-org-btn" style="width:100%;">Opret bande</button>
      </div>
    </div>`;
  }

  function destroyMap() {
    if (state.map) {
      state.map.destroy();
      state.map = null;
    }
  }

  function initMap(data) {
    destroyMap();
    const host = document.getElementById('gang-map-host');
    if (!host || typeof GangLeafletMap === 'undefined') return;

    const org = data.org;
    const tcfg = data.territoryConfig || {};
    state.map = GangLeafletMap.mount(host, {
      maxArea: tcfg.MaxZoneArea || 180,
      minArea: tcfg.MinZoneArea || 20,
      canManage: !!org?.myPermissions?.manage_zones,
      myOrgId: org?.id,
      onCreate: (payload) => post('createZone', payload),
      onUpdate: (zoneId, vertices, area) => post('updateZone', { zoneId, vertices, area }),
      onRename: (zoneId, name) => post('renameZone', { zoneId, name }),
      onDelete: (zoneId) => post('deleteZone', { zoneId }),
      onError: (msg) => {
        if (typeof GangLeafletMap !== 'undefined' && GangLeafletMap.showToast) {
          GangLeafletMap.showToast(msg);
        } else {
          post('gangNotify', { message: msg });
        }
      }
    });
    state.map.setZones(data.territories || []);
    setTimeout(() => state.map?.invalidate(), 100);
  }

  function render(data, tab, hooks) {
    state.tab = tab || state.tab;
    const org = data?.org;
    if (!org) return { html: renderCreate(data?.orgConfig || {}), after: null };

    let body = '';
    if (state.tab === 'forside') body = renderForside(org, data.orgConfig);
    else if (state.tab === 'medlemmer') body = renderMedlemmer(org);
    else if (state.tab === 'beskeder') body = renderBeskeder(data);
    else body = renderTerritorier();

    const html = `<div class="bande-shell">
      <div class="bande-top" style="padding:12px 18px 0;display:flex;gap:12px;align-items:center;">
        <button type="button" class="back-btn" data-nav="home">‹</button>
        <div>
          <h2 style="font-size:17px;font-weight:800;">${esc(org.name)}</h2>
          <p style="font-size:11px;opacity:.6;">${esc(org.myRole?.name)} · Niveau ${org.level || 1}</p>
        </div>
      </div>
      ${navHtml(data)}
      ${body}
    </div>`;

    return {
      html,
      after: () => {
        document.querySelectorAll('[data-gang-tab]').forEach((btn) => {
          btn.onclick = () => {
            const id = btn.dataset.gangTab;
            if (id === 'beskeder') post('markMessagesRead');
            hooks.onTab(id);
          };
        });
        if (state.tab === 'territorier') {
          requestAnimationFrame(() => requestAnimationFrame(() => initMap(data)));
        } else {
          destroyMap();
        }
        hooks.bindMembers();
      }
    };
  }

  return { render, destroyMap, getTab: () => state.tab, setTab: (t) => { state.tab = t; } };
})();
