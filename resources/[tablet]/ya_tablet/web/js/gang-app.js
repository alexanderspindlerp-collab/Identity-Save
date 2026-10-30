window.GangApp = (function () {
  var NAV = [
    { id: 'forside', label: 'Forside', icon: '<path d="M12 3 3 11h2v9h6v-5h2v5h6v-9h2L12 3Z"/>' },
    { id: 'territorier', label: 'Territorier', icon: '<path d="M4 6h16v12H4V6Zm2 2v8h12V8H6Zm2 2h8v4H8v-4Z"/>' },
    { id: 'medlemmer', label: 'Medlemmer', icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>' },
    { id: 'beskeder', label: 'Beskeder', icon: '<path d="M4 5h16v10H7l-3 3V5Z"/>' }
  ];

  var state = { tab: 'forside', map: null };

  function post(name, data) {
    var RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_tablet';
    fetch('https://' + RES + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || {})
    }).catch(function () {});
  }

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function xpProgress(org, cfg) {
    var per = (cfg && cfg.xpPerLevel) || 500;
    var xp = (org && org.xp) || 0;
    var into = xp % per;
    return {
      xp: xp,
      level: (org && org.level) || 1,
      pct: Math.min(100, Math.round((into / per) * 100)),
      into: into,
      per: per
    };
  }

  function navHtml(data) {
    var unread = (data && data.unreadMessages) || 0;
    return '<nav class="bande-nav">' +
      NAV.map(function (n) {
        return '<button type="button" class="bande-nav-btn' + (state.tab === n.id ? ' active' : '') + '" data-gang-tab="' + n.id + '" style="position:relative;">' +
          '<svg viewBox="0 0 24 24">' + n.icon + '</svg>' +
          n.label +
          (n.id === 'beskeder' && unread ? '<span class="nav-badge">' + unread + '</span>' : '') +
        '</button>';
      }).join('') +
    '</nav>';
  }

  function renderForside(org, cfg) {
    var p = xpProgress(org, cfg);
    var members = (org.members || []).slice(0, 6);
    return '<div class="bande-forside">' +
      '<div class="bande-forside-grid">' +
        '<div class="hero-card"><div class="label">Bande XP</div><div class="value">' + p.xp + '</div>' +
        '<div class="sub">Niveau ' + p.level + '</div><div class="xp-bar"><span style="width:' + p.pct + '%"></span></div></div>' +
        '<div class="hero-card"><div class="label">Medlemmer</div><div class="value">' + (org.memberCount || 0) + '</div>' +
        '<div class="member-preview" style="margin-top:10px;">' +
          (members.map(function (m) {
            return '<div class="member-chip"><div class="avatar">' + esc((m.name || '?').slice(0, 1)) + '</div>' +
              '<div><div class="name">' + esc(m.name) + '</div><div class="role">' + esc(m.roleName) + '</div></div></div>';
          }).join('') || '<div class="sub">Ingen medlemmer</div>') +
        '</div></div>' +
      '</div>' +
      '<div class="hero-card"><div class="label">Territorier</div>' +
      '<div class="sub">Gå til <strong>Territorier</strong> for at tegne zoner på kortet.</div></div>' +
    '</div>';
  }

  function renderMedlemmer(org) {
    var perms = org.myPermissions || {};
    var canInvite = perms.invite;
    var canKick = perms.kick;
    var canRoles = perms.manage_roles;
    return '<div class="bande-forside">' +
      (canInvite ? '<div class="invite-row"><input type="number" class="field" id="invite-id" placeholder="Spiller server-ID" min="1" />' +
        '<button type="button" class="btn" id="invite-btn">Tilføj</button></div>' : '') +
      '<div class="member-list">' +
        (org.members || []).map(function (m) {
          return '<div class="member-row">' +
            '<div class="info"><div class="name">' + esc(m.name) + '</div><div class="meta">' + esc(m.roleName) + '</div></div>' +
            (canRoles && m.roleKey !== 'leader' ?
              '<select class="role-select" data-member-role="' + m.id + '">' +
                (org.roles || []).filter(function (r) { return r.key !== 'leader'; }).map(function (r) {
                  return '<option value="' + r.id + '"' + (r.id === m.roleId ? ' selected' : '') + '>' + esc(r.name) + '</option>';
                }).join('') +
              '</select>' : '<span class="badge">' + esc(m.roleName) + '</span>') +
            (canKick && m.roleKey !== 'leader' ? '<button type="button" class="btn danger" data-kick="' + m.id + '">Smid ud</button>' : '') +
          '</div>';
        }).join('') +
      '</div></div>';
  }

  function renderBeskeder(data) {
    var msgs = data.messages || [];
    return '<div class="bande-forside"><div class="message-list">' +
      (msgs.length ? msgs.map(function (m) {
        return '<div class="message-card"><h4>' + esc(m.title) + '</h4><p>' + esc(m.body || '') + '</p>' +
          '<div class="time">' + esc(m.createdAt || '') + '</div></div>';
      }).join('') : '<div class="empty-state">Ingen beskeder. I får besked ved rival-salg i jeres turf.</div>') +
    '</div></div>';
  }

  function renderTerritorier() {
    return '<div class="bande-panel"><div class="bande-map-wrap" id="gang-map-host"></div></div>';
  }

  function renderCreate(cfg) {
    cfg = cfg || {};
    return '<div class="bande-shell">' +
      '<div class="bande-top" style="padding:16px 18px;display:flex;gap:12px;align-items:center;">' +
        '<button type="button" class="back-btn" data-nav="home">‹</button>' +
        '<div><h2 style="font-size:18px;">Bande</h2><p style="font-size:12px;opacity:.6;">Opret organisation</p></div>' +
      '</div>' +
      '<div class="create-box"><h3>Opret bande</h3><p>Tegn territorier på kortet efter oprettelse.</p>' +
        '<input type="text" class="field" id="org-name-input" maxlength="' + (cfg.maxNameLength || 32) + '" placeholder="Bande navn" />' +
        '<button type="button" class="btn" id="create-org-btn" style="width:100%;">Opret bande</button>' +
      '</div></div>';
  }

  function destroyMap() {
    if (state.map) {
      state.map.destroy();
      state.map = null;
    }
  }

  function initMap(data) {
    destroyMap();
    var host = document.getElementById('gang-map-host');
    if (!host || typeof GangLeafletMap === 'undefined') return;

    var org = data.org;
    var tcfg = data.territoryConfig || {};
    var orgPerms = (org && org.myPermissions) || {};
    state.map = GangLeafletMap.mount(host, {
      maxArea: tcfg.MaxZoneArea || 180,
      minArea: tcfg.MinZoneArea || 20,
      canManage: !!orgPerms.manage_zones,
      myOrgId: org && org.id,
      onCreate: function (payload) { post('createZone', payload); },
      onUpdate: function (zoneId, vertices) { post('updateZone', { zoneId: zoneId, vertices: vertices }); },
      onRename: function (zoneId, name) { post('renameZone', { zoneId: zoneId, name: name }); },
      onDelete: function (zoneId) { post('deleteZone', { zoneId: zoneId }); },
      onError: function (msg) {
        if (typeof GangLeafletMap !== 'undefined' && GangLeafletMap.showToast) {
          GangLeafletMap.showToast(msg);
        } else {
          post('gangNotify', { message: msg });
        }
      }
    });
    if (state.map) {
      state.map.setZones(data.territories || []);
      setTimeout(function () { if (state.map) state.map.invalidate(); }, 100);
    }
  }

  function render(data, tab, hooks) {
    state.tab = tab || state.tab;
    var org = data && data.org;
    if (!org) return { html: renderCreate(data && data.orgConfig), after: null };

    var body = '';
    if (state.tab === 'forside') body = renderForside(org, data.orgConfig);
    else if (state.tab === 'medlemmer') body = renderMedlemmer(org);
    else if (state.tab === 'beskeder') body = renderBeskeder(data);
    else body = renderTerritorier();

    var roleName = (org.myRole && org.myRole.name) || 'Medlem';
    var html = '<div class="bande-shell">' +
      '<div class="bande-top" style="padding:12px 18px 0;display:flex;gap:12px;align-items:center;">' +
        '<button type="button" class="back-btn" data-nav="home">‹</button>' +
        '<div><h2 style="font-size:17px;font-weight:800;">' + esc(org.name) + '</h2>' +
        '<p style="font-size:11px;opacity:.6;">' + esc(roleName) + ' · Niveau ' + (org.level || 1) + '</p></div>' +
      '</div>' + navHtml(data) + body + '</div>';

    return {
      html: html,
      after: function () {
        document.querySelectorAll('[data-gang-tab]').forEach(function (btn) {
          btn.onclick = function () {
            var id = btn.dataset.gangTab;
            if (id === 'beskeder') post('markMessagesRead');
            hooks.onTab(id);
          };
        });
        if (state.tab === 'territorier') {
          requestAnimationFrame(function () {
            requestAnimationFrame(function () { initMap(data); });
          });
        } else {
          destroyMap();
        }
        hooks.bindMembers();
      }
    };
  }

  return {
    render: render,
    destroyMap: destroyMap,
    getTab: function () { return state.tab; },
    setTab: function (t) { state.tab = t; }
  };
})();
