window.GangApp = (function () {
  var NAV = [
    { id: 'forside', label: 'Forside', icon: '<path d="M12 3 3 11h2v9h6v-5h2v5h6v-9h2L12 3Z"/>' },
    { id: 'territorier', label: 'Territorier', icon: '<path d="M4 6h16v12H4V6Zm2 2v8h12V8H6Zm2 2h8v4H8v-4Z"/>' },
    { id: 'operationer', label: 'Operationer', icon: '<path d="M12 2 3 7v6c0 5.2 3.8 10 9 11 5.2-1 9-5.8 9-11V7l-9-5Zm0 4.2 7 3.9v3.9c0 3.8-2.6 7.4-7 8.4-4.4-1-7-4.6-7-8.4V10.1l7-3.9ZM11 10v4.2l3.5 2-1 1.7-4.5-2.6V10h2Z"/>' },
    { id: 'medlemmer', label: 'Medlemmer', icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>' },
    { id: 'roller', label: 'Roller', icon: '<path d="M12 2 4 6v6c0 5 3.5 9.7 8 11 4.5-1.3 8-6 8-11V6l-8-4Zm0 3.2 6 3v4.8c0 3.7-2.4 7.1-6 8.3-3.6-1.2-6-4.6-6-8.3V8.2l6-3Zm-1 4.8v3.4l2.5 1.4 1-1.7-1.5-.9V10H11Z"/>' },
    { id: 'beskeder', label: 'Beskeder', icon: '<path d="M4 5h16v10H7l-3 3V5Z"/>' }
  ];
  var gangState = { tab: 'forside', map: null, lastData: null, showInviteList: false };
  function gangPost(name, data) {
    var res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_tablet';
    fetch('https://' + res + '/' + name, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data || {})
    }).catch(function () {});
  }
  function gangEsc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
  function gangXpProgress(org, cfg) {
    var per = (cfg && cfg.xpPerLevel) || 500;
    var xp = (org && org.xp) || 0;
    var into = xp % per;
    return { xp: xp, level: (org && org.level) || 1, pct: Math.min(100, Math.round((into / per) * 100)), into: into, per: per };
  }
  function gangTopActionsHtml() {
    return '<div class="bande-top-actions">' +
      '<button type="button" class="bande-skilltree-btn" id="gang-open-skilltree" title="Bande Skill Board">' +
        '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2 3 7v6c0 5.2 3.8 10 9 11 5.2-1 9-5.8 9-11V7l-9-5Zm0 4.2 7 3.9v3.9c0 3.8-2.6 7.4-7 8.4-4.4-1-7-4.6-7-8.4V10.1l7-3.9ZM11 10v4.2l3.5 2-1 1.7-4.5-2.6V10h2Z"/></svg>' +
        '<span>Skills</span>' +
      '</button>' +
      '<button type="button" class="bande-settings-btn" data-gang-settings title="Bande-indstillinger">' +
        '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8Zm8.2 4.3.83-.67a.65.65 0 0 0 .16-.82l-.78-1.35a.65.65 0 0 0-.76-.31l-.99.3a6.2 6.2 0 0 0-.98-.57l-.14-1.03a.65.65 0 0 0-.64-.55h-1.56c-.32 0-.6.22-.64.55l-.14 1.03c-.35.16-.68.35-.98.57l-.99-.3a.65.65 0 0 0-.76.31l-.78 1.35a.65.65 0 0 0 .16.82l.83.67a6.5 6.5 0 0 0 0 1.4l-.83.67a.65.65 0 0 0-.16.82l.78 1.35a.65.65 0 0 0 .76.31l.99-.3c.3.22.63.41.98.57l.14 1.03c.04.33.32.55.64.55h1.56c.32 0 .6-.22.64-.55l.14-1.03c.35-.16.68-.35.98-.57l.99.3a.65.65 0 0 0 .76-.31l.78-1.35a.65.65 0 0 0-.16-.82l-.83-.67a6.5 6.5 0 0 0 0-1.4Z"/></svg>' +
      '</button>' +
    '</div>';
  }
  function gangBindSkillTreeBtn() {
    var skillBtn = document.getElementById('gang-open-skilltree');
    if (!skillBtn) return;
    skillBtn.onclick = function () {
      if (!window.GangSkillTree) {
        gangPost('gangNotify', { message: 'Skill Board kunne ikke indlæses. Genstart ya_tablet.', type: 'error' });
        return;
      }
      GangSkillTree.open(gangState.lastData, gangPost);
    };
  }
  function gangNavHtml(data, activeTab, org) {
    var unread = (data && data.unreadMessages) || 0;
    var canViewRoller = org && gangCanViewPerms(org.myPermissions || {});
    return '<nav class="bande-nav">' + NAV.filter(function (n) {
      return n.id !== 'roller' || canViewRoller;
    }).map(function (n) {
      return '<button type="button" class="bande-nav-btn' + (activeTab === n.id ? ' active' : '') + '" data-gang-tab="' + n.id + '" style="position:relative;"><svg viewBox="0 0 24 24">' + n.icon + '</svg>' + n.label + (n.id === 'beskeder' && unread ? '<span class="nav-badge">' + unread + '</span>' : '') + '</button>';
    }).join('') + '</nav>';
  }
  var GANG_ZONE_STATUS = {
    secure: 'Sikker',
    under_attack: 'Under angreb',
    critical: 'Kritisk',
    lost: 'Tabt',
    transferred_out: 'Overdraget',
    transferred_in: 'Modtaget',
    captured: 'Overtaget'
  };
  function gangZoneStatusTone(status) {
    if (status === 'secure' || status === 'transferred_in' || status === 'captured') return 'ok';
    if (status === 'under_attack') return 'warn';
    return 'danger';
  }
  function gangCanManageZones(org) {
    return !!(org && org.myPermissions && org.myPermissions.manage_zones);
  }
  function gangCanManageOrg(org) {
    return !!(org && org.myPermissions && (org.myPermissions.manage_org || org.myPermissions.manage_zones));
  }
  function gangRenderForside(data) {
    var org = data && data.org;
    var cfg = data && data.orgConfig;
    var overview = (data && data.territoryOverview) || [];
    var skillBoard = (data && data.skillBoard) || {};
    var p = gangXpProgress(org, cfg);
    var members = (org.members || []).slice(0, 6);
    var canManageZones = gangCanManageZones(org);
    var zoneLevelCost = skillBoard.zoneLevelXpCost || 100;
    var zoneCards = overview.length ? overview.map(function (z) {
      var tone = gangZoneStatusTone(z.status);
      var statusLabel = GANG_ZONE_STATUS[z.status] || z.status;
      var meta = z.kind === 'owned'
        ? (z.threatPct > 0 ? ('Pres: ' + z.threatPct + '%') : 'Ingen aktiv trussel')
        : (z.relatedOrgName ? gangEsc(z.relatedOrgName) : '');
      var upgradeBtn = (z.kind === 'owned' && canManageZones)
        ? '<button type="button" class="zone-upgrade-btn" data-upgrade-zone="' + z.id + '">+1 niveau · ' + zoneLevelCost + ' XP</button>'
        : '';
      var threatBar = (z.kind === 'owned' && z.threatPct > 0)
        ? '<div class="zone-threat-bar"><span style="width:' + Math.min(100, z.threatPct) + '%"></span></div>'
        : '';
      return '<div class="zone-status-card tone-' + tone + (z.isHistorical ? ' is-history' : '') + '">' +
        '<div class="zone-status-top"><div><h4>' + gangEsc(z.name) + '</h4><span class="zone-status-pill">' + gangEsc(statusLabel) + '</span></div>' +
        (z.level ? '<span class="zone-lvl-badge">Lvl ' + z.level + '</span>' : '') +
        '</div>' +
        '<p class="zone-status-meta">' + meta + '</p>' +
        threatBar +
        '<div class="zone-status-foot">' + upgradeBtn + '</div>' +
      '</div>';
    }).join('') : '<div class="empty-state">Ingen zoner endnu. Lås op under Skill Board og tegn på <strong>Territorier</strong>.</div>';
    var slotInfo = (skillBoard.zoneCount || 0) + ' / ' + (skillBoard.maxZoneSlots || 1) + ' territorier';
    return '<div class="bande-forside">' +
      '<div class="bande-forside-grid">' +
        '<div class="hero-card"><div class="label">Bande XP</div><div class="value">' + p.xp + '</div><div class="sub">Niveau ' + p.level + '</div><div class="xp-bar"><span style="width:' + p.pct + '%"></span></div></div>' +
        '<div class="hero-card"><div class="label">Medlemmer</div><div class="value">' + (org.memberCount || 0) + '</div><div class="member-preview" style="margin-top:10px;">' + (members.map(function (m) {
          return '<div class="member-chip"><div class="avatar">' + gangEsc((m.name || '?').slice(0, 1)) + '</div><div><div class="name">' + gangEsc(m.name) + '</div><div class="role">' + gangEsc(m.roleName) + '</div></div></div>';
        }).join('') || '<div class="sub">Ingen medlemmer</div>') + '</div></div>' +
      '</div>' +
      '<div class="forside-section"><div class="section-head"><h3>Territorier</h3><span class="count">' + slotInfo + '</span></div>' +
        '<div class="zone-status-grid">' + zoneCards + '</div>' +
      '</div>' +
    '</div>';
  }
  function gangBindForsideActions() {
    document.querySelectorAll('[data-upgrade-zone]').forEach(function (btn) {
      btn.onclick = function () {
        var zoneId = btn.getAttribute('data-upgrade-zone');
        if (zoneId) gangPost('upgradeZoneLevel', { zoneId: Number(zoneId) });
      };
    });
  }
  function gangCanViewPerms(perms) {
    return !!(perms.view_permissions || perms.manage_permissions || perms.manage_roles);
  }
  function gangCanEditPerms(perms) {
    return !!(perms.manage_permissions || perms.manage_roles);
  }
  function gangCanManageRoles(perms) {
    return !!perms.manage_roles;
  }
  function gangCountRoleMembers(org, roleId) {
    return (org.members || []).filter(function (m) { return m.roleId === roleId; }).length;
  }
  function gangCountEnabledPerms(role, catalogList) {
    if (role.isTopRank || role.key === 'leader') return catalogList.length;
    var n = 0;
    var p = role.permissions || {};
    catalogList.forEach(function (item) { if (p[item.key]) n++; });
    return n;
  }
  function gangIsTopRankMember(org, member) {
    var top = org.topSortOrder;
    if (top == null) return member.roleKey === 'leader';
    return Number(member.sortOrder) === Number(top);
  }
  function gangCanActOnMember(org, member) {
    if (!member || member.identifier === org.myIdentifier) return false;
    var mySort = Number(org.mySortOrder != null ? org.mySortOrder : 999);
    var theirSort = Number(member.sortOrder != null ? member.sortOrder : 999);
    return mySort <= theirSort;
  }
  function gangGetAssignableRoles(org) {
    var ids = org.myAssignableRoleIds || [];
    return (org.roles || []).filter(function (r) {
      return ids.indexOf(r.id) >= 0 || ids.indexOf(Number(r.id)) >= 0;
    });
  }
  function gangRenderRoller(org, data) {
    var perms = org.myPermissions || {};
    var canEditPerms = gangCanEditPerms(perms);
    var canManageRoles = gangCanManageRoles(perms);
    var catalogList = (data && data.permissionsCatalog) || [];
    var roles = org.roles || [];
    var roleCount = roles.length;
    var leaderIdx = -1;
    for (var li = 0; li < roles.length; li++) {
      if (roles[li].key === 'leader') { leaderIdx = li; break; }
    }
    var rolesHtml = roles.map(function (role, index) {
      var isLeader = role.key === 'leader';
      var memberCount = gangCountRoleMembers(org, role.id);
      var enabledCount = gangCountEnabledPerms(role, catalogList);
      var permSummary = isLeader
        ? 'Alle tilladelser aktivt'
        : (enabledCount + ' af ' + catalogList.length + ' tilladelser');
      var canRename = canManageRoles;
      var canMoveUp = canManageRoles && !isLeader && index > (leaderIdx < 0 ? 0 : leaderIdx + 1);
      var canMoveDown = canManageRoles && !isLeader && index < roles.length - 1;
      var orderBtns = canManageRoles && !isLeader
        ? '<div class="role-order-btns">' +
            '<button type="button" class="role-order-btn" data-move-role-up="' + role.id + '"' + (canMoveUp ? '' : ' disabled') + ' title="Flyt op">▲</button>' +
            '<button type="button" class="role-order-btn" data-move-role-down="' + role.id + '"' + (canMoveDown ? '' : ' disabled') + ' title="Flyt ned">▼</button>' +
          '</div>'
        : '';
      var actions = '';
      if (canRename) {
        actions += '<button type="button" class="btn sm" data-save-role-name="' + role.id + '">Gem navn</button>';
      }
      if (canEditPerms && !isLeader) {
        actions += '<button type="button" class="btn secondary sm" data-edit-role-perms="' + role.id + '">Rediger Permissions</button>';
      }
      if (canManageRoles && !isLeader && !role.isDefault) {
        actions += '<button type="button" class="btn danger sm" data-delete-role="' + role.id + '">Slet rolle</button>';
      }
      return '<div class="gang-role-card' + (isLeader ? ' is-leader' : '') + '" data-role-card="' + role.id + '">' +
        '<div class="gang-role-card-layout">' +
          '<div class="gang-role-card-main">' +
            '<div class="gang-role-card-top">' +
              '<div class="gang-role-card-title">' +
                (canRename
                  ? '<input type="text" class="field role-name-input" data-role-name="' + role.id + '" value="' + gangEsc(role.name) + '" maxlength="32" />'
                  : '<h4>' + gangEsc(role.name) + '</h4>') +
                (isLeader ? '<span class="badge leader-badge">Leder</span>' : (role.isDefault ? '<span class="badge">Standard</span>' : '')) +
              '</div>' +
              '<span class="role-member-count">' + memberCount + ' medlem' + (memberCount === 1 ? '' : 'mer') + '</span>' +
            '</div>' +
            '<div class="role-perm-summary">' + gangEsc(permSummary) + '</div>' +
            (actions ? '<div class="gang-role-card-actions">' + actions + '</div>' : '<p class="role-locked-note">Kun visning — du kan ikke redigere roller.</p>') +
          '</div>' +
          orderBtns +
        '</div>' +
      '</div>';
    }).join('');
    return '<div class="bande-roller">' +
      '<div class="section-head"><h3>Roller & Permissions</h3><span class="count">' + roleCount + ' roller</span></div>' +
      '<p class="section-sub">Opret roller og vælg hvad hver rolle må i banden.</p>' +
      (canManageRoles ? '<div class="roller-toolbar"><button type="button" class="btn" id="gang-create-role-btn">+ Opret ny rolle</button></div>' : '') +
      '<div class="gang-role-list">' + (rolesHtml || '<div class="empty-state">Ingen roller fundet.</div>') + '</div>' +
    '</div>';
  }
  function gangRenderMedlemmer(org) {
    var perms = org.myPermissions || {};
    var canInvite = !!perms.invite;
    var canKick = !!perms.kick;
    var canAssignRole = !!perms.manage_roles;
    var assignableRoles = gangGetAssignableRoles(org);
    var memberCardsHtml = (org.members || []).map(function (m) {
      var isTopRank = gangIsTopRankMember(org, m);
      var canAct = gangCanActOnMember(org, m);
      var roleOptions = assignableRoles.map(function (r) {
        return '<option value="' + r.id + '"' + (r.id === m.roleId ? ' selected' : '') + '>' + gangEsc(r.name) + '</option>';
      }).join('');
      return '<div class="member-card' + (isTopRank ? ' is-leader' : '') + '">' +
        '<div class="member-card-top">' +
          '<div class="member-card-avatar">' + gangEsc((m.name || '?').slice(0, 1)) + '</div>' +
          '<div class="member-card-info">' +
            '<div class="member-card-name">' + gangEsc(m.name) + '</div>' +
            '<span class="member-role-badge' + (isTopRank ? ' leader' : '') + '">' + gangEsc(m.roleName) + '</span>' +
          '</div>' +
        '</div>' +
        (canAssignRole && canAct && roleOptions ? '<div class="member-rank-row"><span class="member-rank-label">Rang</span><select class="role-select" data-member-role="' + m.id + '">' + roleOptions + '</select></div>' : '') +
        (canKick && canAct ? '<div class="member-card-footer"><button type="button" class="btn danger sm full" data-kick="' + m.id + '">Fjern fra bande</button></div>' : '') +
      '</div>';
    }).join('');
    if (!memberCardsHtml) memberCardsHtml = '<div class="empty-state">Ingen medlemmer endnu.</div>';
    return '<div class="bande-medlemmer">' +
      '<div class="section-head"><h3>Medlemmer</h3><span class="count">' + (org.memberCount || 0) + ' / ' + (org.maxMembers || 50) + '</span></div>' +
      '<p class="section-sub">Administrer hvem der er i banden og deres rang.</p>' +
      (canInvite ? '<div class="invite-card"><div class="invite-card-label">Send invitation</div><div class="invite-row"><input type="number" class="field" id="invite-id" placeholder="Spiller server-ID" min="1" /><button type="button" class="btn" id="invite-btn">Inviter</button></div><p class="invite-card-hint">Invitationen varer 7 dage. Spilleren skal acceptere i Bande-appen.</p></div>' : '') +
      '<div class="member-card-grid">' + memberCardsHtml + '</div>' +
    '</div>';
  }
  function gangRenderBeskeder(data) {
    var msgs = data.messages || [];
    return '<div class="bande-forside"><div class="message-list">' + (msgs.length ? msgs.map(function (m) {
      return '<div class="message-card"><h4>' + gangEsc(m.title) + '</h4><p>' + gangEsc(m.body || '') + '</p><div class="time">' + gangEsc(m.createdAt || '') + '</div></div>';
    }).join('') : '<div class="empty-state">Ingen beskeder. I får besked ved rival-salg i jeres turf.</div>') + '</div></div>';
  }
  function gangRenderOperationer(data) {
    var categories = (data && data.operationsCatalog) || [
      { id: 'robberies', label: 'Røverier', desc: 'Butiks-, bank- og gade-røverier.', soon: true },
      { id: 'heists', label: 'Heists', desc: 'Større koordinerede kup og missioner.', soon: true },
      { id: 'contracts', label: 'Kontrakter', desc: 'Tidsbegrænsede bande-opgaver.', soon: true },
      { id: 'smuggling', label: 'Smugleri', desc: 'Leveringer, drops og sorte markeder.', soon: true }
    ];
    return '<div class="bande-operationer">' +
      '<div class="section-head"><h3>Operationer</h3><span class="count">Kommer snart</span></div>' +
      '<p class="section-sub">Kategoriserede missioner, røverier og heists lander her — planlæg og start bande-operationer fra tabletten.</p>' +
      '<div class="ops-category-grid">' + categories.map(function (cat) {
        return '<div class="ops-category-card' + (cat.soon ? ' is-soon' : '') + '">' +
          '<div class="ops-category-top">' +
            '<h4>' + gangEsc(cat.label) + '</h4>' +
            (cat.soon ? '<span class="ops-soon-badge">Snart</span>' : '') +
          '</div>' +
          '<p>' + gangEsc(cat.desc || '') + '</p>' +
        '</div>';
      }).join('') +
      '</div>' +
      '<div class="ops-footnote">Sælg i rival-zoner for at optjene bande XP og overtage territorier under <strong>Territorier</strong>.</div>' +
    '</div>';
  }
  function gangDestroyMap() {
    if (gangState.map) { gangState.map.destroy(); gangState.map = null; }
  }
  function gangInitMap(data, attempt) {
    attempt = attempt || 0;
    gangDestroyMap();
    var host = document.getElementById('gang-map-host');
    if (!host) {
      if (attempt < 10) setTimeout(function () { gangInitMap(data, attempt + 1); }, 60);
      return;
    }
    if (typeof GangLeafletMap === 'undefined') {
      host.innerHTML = '<div class="map-error-state">Kort kunne ikke indlæses — genstart ya_tablet</div>';
      return;
    }
    var org = data.org;
    var tcfg = data.territoryConfig || {};
    var orgPerms = (org && org.myPermissions) || {};
    var mapCfg = data.mapConfig || {};
    var mapSources = mapCfg.ImageSources || mapCfg.imageSources || null;
    gangState.map = GangLeafletMap.mount(host, {
      maxArea: tcfg.MaxZoneArea || 180,
      minArea: tcfg.MinZoneArea || 20,
      areaDivisor: tcfg.AreaDivisor || 100,
      canManage: !!orgPerms.manage_zones,
      myOrgId: org && org.id,
      mapSources: mapSources,
      territoryConfig: tcfg,
      otherOrgs: data.otherOrgs || [],
      onCreate: function (payload) { gangPost('createZone', payload); },
      onUpdate: function (zoneId, vertices) { gangPost('updateZone', { zoneId: zoneId, vertices: vertices }); },
      onRename: function (zoneId, name) { gangPost('renameZone', { zoneId: zoneId, name: name }); },
      onDelete: function (zoneId) { gangPost('deleteZone', { zoneId: zoneId }); },
      onRequest: function (zoneId) { gangPost('requestZone', { zoneId: zoneId }); },
      onTransfer: function (zoneId, targetOrgId) { gangPost('transferZone', { zoneId: zoneId, targetOrgId: targetOrgId }); },
      onError: function (msg) {
        if (typeof GangLeafletMap !== 'undefined' && GangLeafletMap.showToast) GangLeafletMap.showToast(msg);
        else gangPost('gangNotify', { message: msg });
      }
    });
    if (gangState.map) {
      gangState.map.setZones(data.territories || []);
      setTimeout(function () { if (gangState.map) gangState.map.invalidate(); }, 150);
    }
  }
  function gangInviteSummary(invites) {
    if (!invites || !invites.length) return '';
    var names = invites.map(function (inv) { return gangEsc(inv.orgName); });
    if (names.length <= 3) return names.join(', ');
    return names.slice(0, 2).join(', ') + ' +' + (names.length - 2) + ' flere';
  }
  function gangRenderInviteCard(inv) {
    return '<div class="gang-invite-card">' +
      '<div class="gang-invite-card-accent" style="background:' + gangEsc(inv.orgColor || '#143d2b') + '"></div>' +
      '<div class="gang-invite-card-main">' +
        '<div class="gang-invite-org-name">' + gangEsc(inv.orgName) + '</div>' +
        '<div class="gang-invite-meta">Inviteret af ' + gangEsc(inv.invitedBy || 'Ukendt') + ' · Niveau ' + (inv.orgLevel || 1) + '</div>' +
        '<div class="gang-invite-expire">Udløber om ' + (inv.daysLeft || 1) + ' dag' + ((inv.daysLeft || 1) === 1 ? '' : 'e') + '</div>' +
      '</div>' +
      '<div class="gang-invite-actions">' +
        '<button type="button" class="btn sm" data-accept-invite="' + inv.id + '">Acceptér</button>' +
        '<button type="button" class="btn secondary sm" data-decline-invite="' + inv.id + '">Afvis</button>' +
      '</div>' +
    '</div>';
  }
  function gangRenderJoinScreen(data) {
    var invites = (data && data.gangInvites) || [];
    var showList = gangState.showInviteList;
    var maxLen = (data && data.orgConfig && data.orgConfig.maxNameLength) || 32;
    var inviteBlock = '';
    if (invites.length) {
      inviteBlock =
        '<button type="button" class="gang-invite-banner" data-gang-invite-toggle>' +
          '<div class="gang-invite-banner-icon" aria-hidden="true">' +
            '<svg viewBox="0 0 24 24"><path d="M4 6h16v12H4V6Zm2 2v8h12V8H6Zm2 2h8v1.5H8V10Zm0 3h5v1.5H8V13Z"/></svg>' +
          '</div>' +
          '<div class="gang-invite-banner-text">' +
            '<strong>Du er blevet inviteret til ' + gangInviteSummary(invites) + '</strong>' +
            '<span>' + (showList ? 'Skjul invitationer' : 'Tryk her for at se liste') + '</span>' +
          '</div>' +
          '<span class="gang-invite-banner-chevron" aria-hidden="true">' + (showList ? '▲' : '›') + '</span>' +
        '</button>' +
        (showList ? '<div class="gang-invite-list">' + invites.map(gangRenderInviteCard).join('') + '</div>' : '');
    }
    return '<div class="bande-shell bande-shell--join">' +
      '<div class="bande-top">' +
        '<button type="button" class="back-btn" data-nav="home">‹</button>' +
        '<div class="bande-top-info"><h2>Bande</h2><p>Opret eller tilslut en organisation</p></div>' +
      '</div>' +
      '<div class="gang-join-screen">' +
        inviteBlock +
        '<div class="gang-join-hero">' +
          '<div class="gang-join-hero-icon" aria-hidden="true">' +
            '<svg viewBox="0 0 24 24"><path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/></svg>' +
          '</div>' +
          '<h3>' + (invites.length ? 'Vælg en bande' : 'Ingen bande endnu') + '</h3>' +
          '<p>' + (invites.length ? 'Acceptér en invitation ovenfor — eller opret din egen bande nedenfor.' : 'Opret din egen bande og tegn territorier på kortet bagefter.') + '</p>' +
        '</div>' +
        '<div class="gang-create-card">' +
          '<div class="gang-create-card-head"><h4>Opret ny bande</h4><span>Start fra bunden</span></div>' +
          '<label class="gang-field-label" for="org-name-input">Bandenavn</label>' +
          '<input type="text" class="field" id="org-name-input" maxlength="' + maxLen + '" placeholder="Fx. Grove Street" />' +
          '<button type="button" class="btn gang-create-btn" id="create-org-btn">Opret bande</button>' +
        '</div>' +
      '</div>' +
    '</div>';
  }
  function gangBindJoinScreen(hooks) {
    document.querySelectorAll('[data-gang-invite-toggle]').forEach(function (btn) {
      btn.onclick = function () {
        gangState.showInviteList = !gangState.showInviteList;
        if (hooks && hooks.onRefresh) hooks.onRefresh();
      };
    });
    document.querySelectorAll('[data-accept-invite]').forEach(function (btn) {
      btn.onclick = function () {
        var inviteId = Number(btn.getAttribute('data-accept-invite'));
        if (inviteId) gangPost('acceptInvite', { inviteId: inviteId });
      };
    });
    document.querySelectorAll('[data-decline-invite]').forEach(function (btn) {
      btn.onclick = function () {
        var inviteId = Number(btn.getAttribute('data-decline-invite'));
        if (inviteId) gangPost('declineInvite', { inviteId: inviteId });
      };
    });
  }
  function gangRenderLockedScreen(data) {
    var name = (data && data.orgLockedName) || 'Din bande';
    return '<div class="bande-shell bande-shell--locked">' +
      '<div class="bande-top">' +
        '<button type="button" class="back-btn" data-nav="home">‹</button>' +
        '<div class="bande-top-info"><h2>' + gangEsc(name) + '</h2><p>Bande-app</p></div>' +
      '</div>' +
      '<div class="bande-locked-screen">' +
        '<div class="bande-locked-icon" aria-hidden="true">' +
          '<svg viewBox="0 0 24 24"><path d="M12 2a5 5 0 0 0-5 5v3H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-1V7a5 5 0 0 0-5-5Zm-3 8V7a3 3 0 0 1 6 0v3H9Z"/></svg>' +
        '</div>' +
        '<h3>UDE AF DRIFT</h3>' +
        '<p>Din bande er midlertidigt lukket af administrationen.</p>' +
        '<p class="bande-locked-sub">Bande-appen er ikke tilgængelig, før banden er låst op igen.</p>' +
      '</div>' +
    '</div>';
  }
  return {
    render: function (data, tab, hooks) {
      gangState.lastData = data || null;
      var activeTab = tab || gangState.tab || 'forside';
      gangState.tab = activeTab;
      var org = data && data.org;
      var isLocked = isGangLocked(data);
      if (isLocked) {
        return { html: gangRenderLockedScreen(data), after: function () { gangDestroyMap(); } };
      }
      if (!org) {
        return {
          html: gangRenderJoinScreen(data),
          after: function () { gangBindJoinScreen(hooks); }
        };
      }
      if (activeTab === 'roller' && !gangCanViewPerms(org.myPermissions || {})) activeTab = 'medlemmer';
      gangState.tab = activeTab;
      var isMapTab = activeTab === 'territorier';
      var body = activeTab === 'forside' ? gangRenderForside(data)
        : activeTab === 'medlemmer' ? gangRenderMedlemmer(org)
        : activeTab === 'roller' ? gangRenderRoller(org, data)
        : activeTab === 'beskeder' ? gangRenderBeskeder(data)
        : activeTab === 'operationer' ? gangRenderOperationer(data)
        : '<div class="bande-map-screen"><div class="bande-map-wrap" id="gang-map-host"></div></div>';
      var roleName = (org.myRole && org.myRole.name) || 'Medlem';
      var shellClass = 'bande-shell' + (isMapTab ? ' bande-shell--map' : '');
      var html = '<div class="' + shellClass + '"><div class="bande-top"><button type="button" class="back-btn" data-nav="home">‹</button><div class="bande-top-info"><h2>' + gangEsc(org.name) + '</h2><p>' + gangEsc(roleName) + ' · Niveau ' + (org.level || 1) + '</p></div>' + gangTopActionsHtml() + '</div>' + gangNavHtml(data, activeTab, org) + '<div class="bande-content' + (isMapTab ? ' bande-content--map' : '') + '">' + body + '</div></div>';
      return {
        html: html,
        after: function () {
          document.querySelectorAll('[data-gang-tab]').forEach(function (btn) {
            btn.onclick = function () {
              var id = btn.getAttribute('data-gang-tab');
              if (!id) return;
              if (id === 'beskeder') gangPost('markMessagesRead');
              hooks.onTab(id);
            };
          });
          if (activeTab === 'territorier') {
            setTimeout(function () { gangInitMap(data); }, 0);
          } else gangDestroyMap();
          if (activeTab === 'forside') gangBindForsideActions();
          gangBindSkillTreeBtn();
          hooks.bindMembers();
        }
      };
    },
    destroyMap: gangDestroyMap,
    getTab: function () { return gangState.tab; },
    setTab: function (t) { gangState.tab = t; }
  };
})();

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_tablet';

const els = {
  wrap: document.getElementById('tablet-wrap'),
  root: document.getElementById('screen-root'),
  homeIndicator: document.getElementById('home-indicator'),
  clock: document.getElementById('clock')
};

const state = {
  data: null,
  view: 'home',
  bandeTab: 'forside',
  adminRows: [],
  adminOrgId: null,
  adminOrgDetail: null,
  adminTab: 'oversigt',
  adminSection: 'hub',
  adminDealerRows: [],
  adminDealerId: null,
  adminDealerDetail: null,
  adminDealerTab: 'oversigt',
  adminShowCatalog: false,
  adminCatalogRows: [],
  cardealerData: null,
  cardealerTab: 'oversigt',
  workshopData: null,
  workshopTab: 'oversigt',
  workshopSearch: '',
  workshopOrderFilter: 'alle',
  workshopOrderDetail: null,
  workshopOrderConfirm: null,
  workshopInvoiceDetail: null,
  workshopInvoiceForm: {
    customerName: '',
    customerIdentifier: '',
    description: '',
    amount: '',
    orderId: null,
  },
  workshopInvoiceSearchResults: [],
  adminWorkshopRows: [],
  adminWorkshopShopCatalog: [],
  adminBlipCatalog: [],
  adminBlipColors: [],
  adminBlipPicker: null,
  adminWorkshopId: null,
  adminWorkshopDetail: null,
  adminWorkshopTab: 'oversigt',
  garageData: null,
  adminDealerVehicles: [],
  salesInvoiceDetail: null,
  ledgerDetail: null
};

const ADMIN_SECTIONS = [
  {
    id: 'gangs',
    title: 'Bande Administrationer',
    desc: 'Administrer bander — lås, rediger, medlemmer og territorier.',
    icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>'
  },
  {
    id: 'cardealers',
    title: 'Bilforhandlere',
    desc: 'Opret forhandlere, tildel ejere, medarbejdere og katalog.',
    icon: '<path d="M5 11h14l-1.5-4.5H6.5L5 11Zm1.5 2.5a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5Zm11 0a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5ZM4 18.5V20h16v-1.5H4Z"/>'
  },
  {
    id: 'workshops',
    title: 'Værksteder & firmaer',
    desc: 'Opret og administrer Benny\'s, LS Customs og mekaniker-firmaer.',
    icon: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z"/>'
  }
];

const ADMIN_TABS = [
  { id: 'oversigt', label: 'Oversigt' },
  { id: 'medlemmer', label: 'Medlemmer' },
  { id: 'roller', label: 'Roller' },
  { id: 'territorier', label: 'Territorier' }
];

const DEALER_ADMIN_TABS = [
  { id: 'oversigt', label: 'Oversigt' },
  { id: 'medlemmer', label: 'Medlemmer' },
  { id: 'roller', label: 'Roller' },
  { id: 'koretojer', label: 'Køretøjer' }
];

const CARDEALER_TABS = [
  { id: 'oversigt', label: 'Oversigt', icon: '<path d="M12 3 4 9v12h16V9l-8-6Zm0 2.2 6 4.5V19H6v-9.3l6-4.5Z"/>' },
  { id: 'lager', label: 'Lager', icon: '<path d="M4 6h16v2H4V6Zm0 5h16v2H4v-2Zm0 5h16v2H4v-2Z"/>' },
  { id: 'importere', label: 'Importér', icon: '<path d="M5 11h14l-1.5-4.5H6.5L5 11Zm1.5 2.5a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5Zm11 0a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5ZM4 18.5V20h16v-1.5H4Z"/>' },
  { id: 'faktura', label: 'Faktura', icon: '<path d="M7 4h10v16H7V4Zm2 2v2h6V6H9Zm0 4v2h6v-2H9Zm0 4v2h4v-2H9Z"/>' }
];

const WORKSHOP_NAV = [
  {
    label: 'Forside',
    items: [
      { id: 'oversigt', label: 'Oversigt', icon: '<path d="M12 3 4 9v12h16V9l-8-6Zm0 2.2 6 4.5V19H6v-9.3l6-4.5Z"/>' }
    ]
  },
  {
    label: 'Ordre (bestillinger)',
    items: [
      { id: 'bestillinger', label: 'Bestillinger', icon: '<path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2"/>' },
      { id: 'faktura', label: 'Faktura', icon: '<path d="M7 4h10v16H7V4Zm2 2v2h6V6H9Zm0 4v2h6v-2H9Zm0 4v2h4v-2H9Z"/>' },
      { id: 'faerdige_ordre', label: 'Færdige ordre', icon: '<path d="M9 12l2 2 4-4m6 2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>' }
    ]
  },
  {
    label: 'Arbejde',
    items: [
      { id: 'opkald', label: 'Opkald', icon: '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.81.3 1.6.57 2.34a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.74-1.74a2 2 0 0 1 2.11-.45c.74.27 1.53.45 2.34.57A2 2 0 0 1 22 16.92Z"/>' }
    ]
  },
  {
    label: 'Administration',
    items: [
      { id: 'prisliste', label: 'Prisliste', icon: '<path d="M7 4h10v16H7V4Zm2 2v2h6V6H9Zm0 4v2h6v-2H9Zm0 4v2h4v-2H9Z"/>' },
      { id: 'ansatte', label: 'Ansatte', icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>' }
    ]
  }
];

const WORKSHOP_TABS = [
  { id: 'oversigt', label: 'Oversigt', icon: '<path d="M12 3 4 9v12h16V9l-8-6Zm0 2.2 6 4.5V19H6v-9.3l6-4.5Z"/>' },
  { id: 'bestillinger', label: 'Bestillinger', icon: '<path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2"/>' },
  { id: 'faktura', label: 'Faktura', icon: '<path d="M7 4h10v16H7V4Zm2 2v2h6V6H9Zm0 4v2h6v-2H9Zm0 4v2h4v-2H9Z"/>' },
  { id: 'faerdige_ordre', label: 'Færdige ordre', icon: '<path d="M9 12l2 2 4-4m6 2a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z"/>' },
  { id: 'opkald', label: 'Opkald', icon: '<path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.12.81.3 1.6.57 2.34a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.74-1.74a2 2 0 0 1 2.11-.45c.74.27 1.53.45 2.34.57A2 2 0 0 1 22 16.92Z"/>' },
  { id: 'prisliste', label: 'Prisliste', icon: '<path d="M7 4h10v16H7V4Zm2 2v2h6V6H9Zm0 4v2h6v-2H9Zm0 4v2h4v-2H9Z"/>' },
  { id: 'ansatte', label: 'Ansatte', icon: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>' }
];

const WORKSHOP_ADMIN_TABS = [
  { id: 'oversigt', label: 'Oversigt' },
  { id: 'medlemmer', label: 'Medlemmer' },
  { id: 'roller', label: 'Roller' }
];

function formatMoney(amount) {
  const n = Number(amount) || 0;
  return n.toLocaleString('da-DK', { minimumFractionDigits: 0, maximumFractionDigits: 0 }) + ' DKK';
}

function formatMoneyDec(amount) {
  const n = Number(amount) || 0;
  return n.toLocaleString('da-DK', { minimumFractionDigits: 2, maximumFractionDigits: 2 }) + ' DKK';
}

function post(name, data = {}) {
  fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function isGangLocked(data) {
  if (!data) return false;
  if (data.orgLocked === true || data.orgLocked === 1) return true;
  return !!(data.org && (data.org.locked === true || data.org.locked === 1));
}

function refreshTabletData() {
  return fetch(`https://${RES}/refreshTablet`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
  })
    .then((res) => res.json())
    .then((data) => {
      if (data && data.homeApps) syncTablet(data);
      return data;
    })
    .catch(() => null);
}

let tabletToastTimer = null;

function inferToastType(message) {
  const msg = String(message || '').toLowerCase();
  if (/fejl|ikke |ugyldig|ingen adgang|kan ikke|for stor|for lille/.test(msg)) return 'error';
  if (/oprettet|tilføjet|opdateret|omdøbt|slettet|installeret|gemt|placeret/.test(msg)) return 'success';
  return 'info';
}

function showTabletToast(message, type) {
  const host = document.getElementById('tablet-toast-host');
  if (!host || !message) return;
  const toastType = type || inferToastType(message);
  const icon = toastType === 'success' ? '✓' : toastType === 'error' ? '!' : 'i';
  if (tabletToastTimer) clearTimeout(tabletToastTimer);
  host.innerHTML =
    '<div class="tablet-toast ' + toastType + '">' +
      '<span class="toast-icon">' + icon + '</span>' +
      '<span class="toast-text">' + escapeHtml(message) + '</span>' +
    '</div>';
  tabletToastTimer = setTimeout(() => { host.innerHTML = ''; }, 3200);
}

window.showTabletToast = showTabletToast;

function escapeHtml(str) {
  return String(str == null ? '' : str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatDanishDateShort(now) {
  const days = ['søn.', 'man.', 'tirs.', 'ons.', 'tors.', 'fre.', 'lør.'];
  const months = ['jan.', 'feb.', 'mar.', 'apr.', 'maj', 'jun.', 'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.'];
  return `${days[now.getDay()]} ${now.getDate()}. ${months[now.getMonth()]}`;
}

function formatDanishDateLong(now) {
  const days = ['Søndag', 'Mandag', 'Tirsdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lørdag'];
  const months = ['jan.', 'feb.', 'mar.', 'apr.', 'maj', 'jun.', 'jul.', 'aug.', 'sep.', 'okt.', 'nov.', 'dec.'];
  return `${days[now.getDay()]} ${now.getDate()}. ${months[now.getMonth()]}`;
}

function getGreeting(now) {
  const hour = now.getHours();
  if (hour >= 5 && hour < 11) return 'Godmorgen';
  if (hour >= 11 && hour < 17) return 'Goddag';
  if (hour >= 17 && hour < 22) return 'Godaften';
  return 'Godnat';
}

function getFirstName(fullName) {
  const name = String(fullName || 'Spiller').trim();
  return name.split(/\s+/)[0] || 'Spiller';
}

function updateClock() {
  const now = new Date();
  const h = String(now.getHours()).padStart(2, '0');
  const m = String(now.getMinutes()).padStart(2, '0');
  if (els.clock) {
    els.clock.textContent = `${h}:${m}`;
  }
}
setInterval(updateClock, 10000);
updateClock();

function setView(view) {
  state.view = view;
  if (!isAdminAppView(view)) {
    state.adminOrgId = null;
    state.adminOrgDetail = null;
    state.adminTab = 'oversigt';
    state.adminSection = 'hub';
  }
  if (els.root) {
    els.root.classList.toggle('home-bg', view === 'home' || view === 'app:apps');
    els.root.classList.toggle('gang-screen', view === 'app:gangs' || view === 'app:orga' || view === 'app:cardealer' || view === 'app:workshop' || view === 'app:garage' || isAdminAppView(view));
  }
  const tabletScreen = document.querySelector('.tablet-screen');
  if (tabletScreen) {
    tabletScreen.classList.toggle('theme-ipad', view === 'home' || view === 'app:apps');
  }
  updateClock();
  if (els.homeIndicator) {
    els.homeIndicator.classList.toggle('is-home', view === 'home');
    els.homeIndicator.classList.toggle('is-away', view !== 'home');
  }
  if (view !== 'app:gangs' && view !== 'app:orga' && window.GangApp) GangApp.destroyMap();
  if (window.GangSkillTree && GangSkillTree.isOpen()) GangSkillTree.close();
  render();
}

const APP_ICON_SVGS = {
  apps: '<path d="M5 5h5v5H5V5Zm9 0h5v5h-5V5ZM5 14h5v5H5v-5Zm9 0h5v5h-5v-5Z"/>',
  gangs: '<path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4Zm-8 8a8 8 0 0 1 16 0H4Z"/>',
  admin: '<path d="M12 2 4 6v6c0 5 3.5 9.7 8 11 4.5-1.3 8-6 8-11V6l-8-4Zm-1 7 5 2v2.2l-3.5 2-1-1.7 2.5-1.4V11H11Z"/>',
  gangs_admin: '<path d="M12 2 4 6v6c0 5 3.5 9.7 8 11 4.5-1.3 8-6 8-11V6l-8-4Zm0 3.2 6 3v4.8c0 3.7-2.4 7.1-6 8.3-3.6-1.2-6-4.6-6-8.3V8.2l6-3Zm-1 4.8v3.4l2.5 1.4 1-1.7-1.5-.9V10H11Z"/>',
  cardealer: '<path d="M5 11h14l-1.5-4.5H6.5L5 11Zm1.5 2.5a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5Zm11 0a1.5 1.5 0 1 0 1.5 1.5 1.5 1.5 0 0 0-1.5-1.5ZM4 18.5V20h16v-1.5H4Z"/>',
  workshop: '<path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z"/>',
  garage: '<path d="M4 10.5 12 4l8 6.5V20a1 1 0 0 1-1 1h-5v-6H10v6H5a1 1 0 0 1-1-1v-9.5Zm8-4.2 5.5 4.5H6.5l5.5-4.5Z"/>'
};

const APP_CUSTOM_IMAGES = {
  gangs_admin: 'img/gangs_admin.png',
};

function appIconGradient(app) {
  const base = app.color || '#143d2b';
  return `linear-gradient(145deg, ${base} 0%, #0a1210 100%)`;
}

function resolveAppImage(app) {
  if (!app) return null;
  return app.image || APP_CUSTOM_IMAGES[app.id] || null;
}

function appImageCandidates(path) {
  const clean = String(path || '').replace(/^\/+/, '');
  if (!clean) return [];
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_tablet';
  const webPath = clean.startsWith('web/') ? clean : `web/${clean.replace(/^img\//, 'img/')}`;
  const relative = webPath.startsWith('web/') ? webPath.slice(4) : clean;
  return [...new Set([
    relative,
    webPath,
    `nui://${res}/${webPath}`,
    `https://cfx-nui-${res}/${webPath}`,
  ].filter(Boolean))];
}

function appImageUrl(path) {
  const candidates = appImageCandidates(path);
  return candidates[0] || '';
}

function findAppById(appId) {
  const home = (state.data && state.data.homeApps) || [];
  const store = (state.data && state.data.apps) || [];
  return home.find((app) => app.id === appId) || store.find((app) => app.id === appId) || { id: appId };
}

function renderSvgAppIcon(app, sizeClass) {
  const iconKey = app.icon || app.id || 'default';
  const svgPath = APP_ICON_SVGS[iconKey] || APP_ICON_SVGS[app.id] || '<path d="M7 7h10v10H7V7Z"/>';
  const label = (app.name || app.id || 'A').slice(0, 1).toUpperCase();
  return `<div class="app-icon-art${sizeClass}" style="background:${appIconGradient(app)}">
    <span class="app-icon-shine"></span>
    <svg viewBox="0 0 24 24" aria-hidden="true">${svgPath}</svg>
    ${!APP_ICON_SVGS[iconKey] && !APP_ICON_SVGS[app.id] ? `<span class="app-icon-fallback">${escapeHtml(label)}</span>` : ''}
  </div>`;
}

function bindAppIconImages(root) {
  if (!root) return;
  root.querySelectorAll('.app-icon-art--image[data-icon-path]').forEach((el) => {
    const candidates = appImageCandidates(el.getAttribute('data-icon-path'));
    const appId = el.getAttribute('data-app-id') || '';
    let index = 0;
    const fail = () => {
      if (!appId) return;
      const app = findAppById(appId);
      const sizeClass = el.classList.contains('app-icon-art--dock') ? ' app-icon-art--dock' : '';
      el.outerHTML = renderSvgAppIcon(app, sizeClass);
    };
    const tryNext = () => {
      if (index >= candidates.length) {
        fail();
        return;
      }
      const url = candidates[index];
      index += 1;
      const probe = new Image();
      probe.onload = () => {
        el.style.backgroundImage = `url("${url}")`;
      };
      probe.onerror = tryNext;
      probe.src = url;
    };
    tryNext();
  });
}

function appIconArt(app, size) {
  const sizeClass = size === 'dock' ? ' app-icon-art--dock' : '';
  const imagePath = resolveAppImage(app);
  if (imagePath) {
    return `<div class="app-icon-art app-icon-art--image${sizeClass}" data-app-id="${escapeHtml(app.id)}" data-icon-path="${escapeHtml(imagePath)}" role="img" aria-label="${escapeHtml(app.name || app.id)}"></div>`;
  }
  return renderSvgAppIcon(app, sizeClass);
}

function appTileBadge(app) {
  const unread = (state.data && state.data.unreadMessages) || 0;
  if ((app.id === 'gangs' || app.id === 'orga') && unread > 0) {
    return `<span class="app-badge">${unread > 9 ? '9+' : unread}</span>`;
  }
  return '';
}

function renderAppTile(app, opts) {
  const inDock = opts && opts.dock;
  const showLabel = !(opts && opts.hideLabel);
  return `<button type="button" class="app-tile${inDock ? ' dock-tile' : ''}" data-open-app="${escapeHtml(app.id)}">
    <span class="app-icon-wrap">
      ${appIconArt(app, inDock ? 'dock' : 'grid')}
      ${appTileBadge(app)}
    </span>
    ${showLabel ? `<span class="app-tile-label">${escapeHtml(app.name)}</span>` : ''}
  </button>`;
}

function renderHome() {
  const apps = (state.data && state.data.homeApps) || [];
  const appsStore = apps.find((app) => app.id === 'apps');
  const installed = apps.filter((app) => app.id !== 'apps');
  const dockApps = [appsStore, ...installed.slice(0, 4)].filter(Boolean);
  const gridApps = installed;

  return `<div class="tablet-home ipad-home" data-ui-version="1.2.8">
    <div class="app-grid app-grid--ipad">
      ${gridApps.map((app) => renderAppTile(app)).join('') || '<div class="empty-state ipad-empty">Ingen apps endnu.<br><small>Åbn <strong>APPs</strong> i docken nedenfor.</small></div>'}
    </div>
    <div class="page-dots" aria-hidden="true"><span class="page-dot active"></span><span class="page-dot"></span><span class="page-dot"></span></div>
    <div class="ipad-dock">
      ${dockApps.map((app) => renderAppTile(app, { dock: true, hideLabel: true })).join('')}
    </div>
  </div>`;
}

function renderStore() {
  return `<div class="tablet-store ipad-store">
    <div class="tablet-store-hero">
      <button type="button" class="store-back-btn" data-nav="home" title="Tilbage til forsiden">‹</button>
      <div>
        <p class="tablet-store-kicker">App-katalog</p>
        <h1 class="tablet-store-title">APPs</h1>
        <p class="tablet-store-sub">Hent og installer apps til din tablet</p>
      </div>
    </div>
    <div class="store-list">
      ${((state.data && state.data.apps) || []).map((app) => `
        <div class="store-card">
          ${appIconArt(app, 'grid')}
          <div class="store-info">
            <h3>${escapeHtml(app.name)}${app.adminOnly ? ' <span class="store-badge">Admin</span>' : ''}</h3>
            <p>${escapeHtml(app.desc)}</p>
          </div>
          <button type="button" class="store-get-btn${app.installed ? ' is-installed' : ''}" data-install="${escapeHtml(app.id)}" ${app.installed ? 'disabled' : ''}>
            ${app.installed ? 'Installeret' : 'Hent'}
          </button>
        </div>
      `).join('') || '<div class="empty-state">Ingen apps tilgængelige lige nu.</div>'}
    </div>
  </div>`;
}

function getTabletOverlayHost() {
  return document.querySelector('.tablet-screen') || document.getElementById('tablet-wrap') || document.body;
}

window.getTabletOverlayHost = getTabletOverlayHost;

function getOrgRole(roleId) {
  const org = state.data && state.data.org;
  const id = Number(roleId);
  return ((org && org.roles) || []).find((r) => Number(r.id) === id) || null;
}

function collectPermsFromPanel(panel) {
  const perms = {};
  panel.querySelectorAll('[data-perm-key]').forEach((input) => {
    if (input.checked) perms[input.getAttribute('data-perm-key')] = true;
  });
  const assignable = {};
  panel.querySelectorAll('[data-assignable-role]').forEach((input) => {
    if (input.checked) assignable[input.getAttribute('data-assignable-role')] = true;
  });
  if (Object.keys(assignable).length) perms.assignable_roles = assignable;
  return perms;
}

function showGangNameModal(title, placeholder, onConfirm) {
  const backdrop = document.createElement('div');
  backdrop.className = 'gang-modal-backdrop';
  backdrop.innerHTML =
    '<div class="gang-modal">' +
      '<h3>' + escapeHtml(title) + '</h3>' +
      '<input type="text" id="gang-ui-name-input" maxlength="32" placeholder="' + escapeHtml(placeholder || '') + '" />' +
      '<div class="gang-modal-actions">' +
        '<button type="button" data-act="cancel">Annuller</button>' +
        '<button type="button" data-act="ok">Bekræft</button>' +
      '</div>' +
    '</div>';
  getTabletOverlayHost().appendChild(backdrop);
  const input = backdrop.querySelector('#gang-ui-name-input');
  input.focus();
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

function showGangSettingsMenu(org) {
  const backdrop = document.createElement('div');
  backdrop.className = 'gang-perms-panel-backdrop';
  const canLeave = !!org.canLeaveOrg;
  const canDelete = !!org.canDeleteOrg;
  const leaveHint = canLeave
    ? 'Forlad banden frivilligt.'
    : 'Som eneste leder skal du først give en anden leder-rang, eller slette banden.';
  backdrop.innerHTML =
    '<div class="gang-settings-panel">' +
      '<div class="gang-perms-panel-head">' +
        '<button type="button" class="back-btn" data-act="close">‹</button>' +
        '<div><h3>Bande-indstillinger</h3><p>' + escapeHtml(org.name || 'Bande') + '</p></div>' +
      '</div>' +
      '<div class="gang-settings-body">' +
        '<button type="button" class="gang-settings-action' + (canLeave ? '' : ' disabled') + '" data-leave-org' + (canLeave ? '' : ' disabled') + '>' +
          '<span class="gang-settings-action-title">Forlad bande</span>' +
          '<span class="gang-settings-action-sub">' + escapeHtml(leaveHint) + '</span>' +
        '</button>' +
        (canDelete
          ? '<button type="button" class="gang-settings-action danger" data-delete-org>' +
              '<span class="gang-settings-action-title">Slet bande</span>' +
              '<span class="gang-settings-action-sub">Alle medlemmer fjernes og banden slettes permanent.</span>' +
            '</button>'
          : '') +
      '</div>' +
    '</div>';
  getTabletOverlayHost().appendChild(backdrop);
  const close = () => backdrop.remove();
  backdrop.querySelector('[data-act="close"]').onclick = close;
  const leaveBtn = backdrop.querySelector('[data-leave-org]');
  if (leaveBtn && canLeave) {
    leaveBtn.onclick = () => {
      close();
      showGangConfirmModal('Forlad bande', 'Er du sikker på at du vil forlade banden?', () => {
        post('leaveOrg');
      }, 'Forlad');
    };
  }
  const deleteBtn = backdrop.querySelector('[data-delete-org]');
  if (deleteBtn) {
    deleteBtn.onclick = () => {
      close();
      showGangConfirmModal('Slet bande', 'Er du sikker? Banden "' + (org.name || '') + '" slettes permanent og alle medlemmer fjernes.', () => {
        post('deleteOrg');
      });
    };
  }
}

function showGangConfirmModal(title, message, onConfirm, okLabel) {
  const backdrop = document.createElement('div');
  backdrop.className = 'gang-modal-backdrop';
  backdrop.innerHTML =
    '<div class="gang-modal">' +
      '<h3>' + escapeHtml(title) + '</h3>' +
      '<p class="gang-modal-msg">' + escapeHtml(message) + '</p>' +
      '<div class="gang-modal-actions">' +
        '<button type="button" data-act="cancel">Annuller</button>' +
        '<button type="button" data-act="ok" class="danger-text">' + escapeHtml(okLabel || 'Slet') + '</button>' +
      '</div>' +
    '</div>';
  getTabletOverlayHost().appendChild(backdrop);
  const close = () => backdrop.remove();
  backdrop.querySelector('[data-act="cancel"]').onclick = close;
  backdrop.querySelector('[data-act="ok"]').onclick = () => { close(); onConfirm(); };
}

function showGangPermsEditor(role, catalog, canEdit, orgRoles, onSave) {
  const backdrop = document.createElement('div');
  backdrop.className = 'gang-perms-panel-backdrop';
  const rows = (catalog || []).map((p) => {
    const checked = (role.permissions && role.permissions[p.key]) ? ' checked' : '';
    const disabled = canEdit ? '' : ' disabled';
    return '<label class="perm-row"><input type="checkbox" data-perm-key="' + escapeHtml(p.key) + '"' + checked + disabled + ' /><span>' + escapeHtml(p.label) + '</span></label>';
  }).join('');
  const assignable = (role.permissions && role.permissions.assignable_roles) || {};
  const isTopRole = !!(role.isTopRank || role.key === 'leader');
  const assignRows = (orgRoles || []).map((r) => {
    const rid = String(r.id);
    const checked = (isTopRole || assignable[rid] || assignable[r.id]) ? ' checked' : '';
    const disabled = (!canEdit || isTopRole) ? ' disabled' : '';
    const topLabel = (r.isTopRank || r.key === 'leader') ? ' <span class="perm-top-tag">Top</span>' : '';
    return '<label class="perm-row assignable-row"><input type="checkbox" data-assignable-role="' + escapeHtml(rid) + '"' + checked + disabled + ' /><span>' + escapeHtml(r.name) + topLabel + '</span></label>';
  }).join('');
  backdrop.innerHTML =
    '<div class="gang-perms-panel">' +
      '<div class="gang-perms-panel-head">' +
        '<button type="button" class="back-btn" data-act="close">‹</button>' +
        '<div><h3>Permissions</h3><p>' + escapeHtml(role.name) + '</p></div>' +
      '</div>' +
      '<div class="gang-perms-panel-body">' +
        '<div class="perm-section-label">Tilladelser</div>' + rows +
        '<div class="perm-section-label">Roller denne rang kan tildele</div>' +
        '<p class="perm-section-hint">Top-rang kan kun tildeles af andre med top-rang.</p>' +
        assignRows +
      '</div>' +
      '<div class="gang-perms-panel-foot">' +
        '<button type="button" data-act="cancel">Annuller</button>' +
        (canEdit ? '<button type="button" data-act="save" class="btn-save">Gem Permissions</button>' : '') +
      '</div>' +
    '</div>';
  getTabletOverlayHost().appendChild(backdrop);
  const panel = backdrop.querySelector('.gang-perms-panel');
  const close = () => backdrop.remove();
  backdrop.querySelector('[data-act="close"]').onclick = close;
  backdrop.querySelector('[data-act="cancel"]').onclick = close;
  const saveBtn = backdrop.querySelector('[data-act="save"]');
  if (saveBtn) {
    saveBtn.onclick = () => {
      close();
      onSave(collectPermsFromPanel(panel));
    };
  }
}

function bindMemberEvents() {
  const inviteBtn = document.getElementById('invite-btn');
  const inviteInput = document.getElementById('invite-id');
  if (inviteBtn && inviteInput) {
    inviteBtn.addEventListener('click', () => {
      const targetId = Number(inviteInput.value);
      if (targetId) { post('inviteMember', { targetId }); inviteInput.value = ''; }
    });
  }
  document.querySelectorAll('[data-kick]').forEach((btn) => {
    btn.addEventListener('click', () => post('kickMember', { memberId: Number(btn.dataset.kick) }));
  });
  document.querySelectorAll('[data-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      post('setMemberRole', { memberId: Number(sel.dataset.memberRole), roleId: Number(sel.value) });
    });
  });
  const createRoleBtn = document.getElementById('gang-create-role-btn');
  if (createRoleBtn) {
    createRoleBtn.addEventListener('click', () => {
      showGangNameModal('Opret ny rolle', 'Navn på rolle', (name) => {
        post('createRole', { name, permissions: {} });
      });
    });
  }
  document.querySelectorAll('[data-save-role-name]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const roleId = Number(btn.getAttribute('data-save-role-name'));
      const nameInput = document.querySelector('[data-role-name="' + roleId + '"]');
      const role = getOrgRole(roleId);
      const name = nameInput ? nameInput.value.trim() : (role && role.name) || '';
      if (!name) return;
      post('updateRole', { roleId, name, permissions: (role && role.permissions) || {} });
    });
  });
  document.querySelectorAll('[data-edit-role-perms]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const roleId = Number(btn.getAttribute('data-edit-role-perms'));
      const role = getOrgRole(roleId);
      if (!role) return;
      const catalog = (state.data && state.data.permissionsCatalog) || [];
      const perms = (state.data && state.data.org && state.data.org.myPermissions) || {};
      const canEdit = !!(perms.manage_permissions || perms.manage_roles);
      const orgRoles = (state.data && state.data.org && state.data.org.roles) || [];
      showGangPermsEditor(role, catalog, canEdit, orgRoles, (newPerms) => {
        const nameInput = document.querySelector('[data-role-name="' + roleId + '"]');
        const name = nameInput ? nameInput.value.trim() : role.name;
        post('updateRole', { roleId, name, permissions: newPerms });
      });
    });
  });
  document.querySelectorAll('[data-delete-role]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const roleId = Number(btn.getAttribute('data-delete-role'));
      const role = getOrgRole(roleId);
      showGangConfirmModal('Slet rolle', 'Er du sikker på at du vil slette "' + (role ? role.name : 'denne rolle') + '"?', () => {
        post('deleteRole', { roleId });
      });
    });
  });
  document.querySelectorAll('[data-move-role-up]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (btn.disabled) return;
      post('moveRole', { roleId: Number(btn.getAttribute('data-move-role-up')), direction: 'up' });
    });
  });
  document.querySelectorAll('[data-move-role-down]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (btn.disabled) return;
      post('moveRole', { roleId: Number(btn.getAttribute('data-move-role-down')), direction: 'down' });
    });
  });
  document.querySelectorAll('[data-gang-settings]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const org = state.data && state.data.org;
      if (org) showGangSettingsMenu(org);
    });
  });
}

function isGangView(view) {
  return view === 'app:gangs' || view === 'app:orga';
}

function renderBandeApp() {
  if (!window.GangApp) {
    return '<div class="empty-state">Bande-app kunne ikke indlæses.<br><small>Genstart ya_tablet.</small></div>';
  }
  const result = GangApp.render(state.data, state.bandeTab, {
    onTab: (tab) => {
      state.bandeTab = tab;
      GangApp.setTab(tab);
      render();
    },
    onRefresh: () => render(),
    bindMembers: bindMemberEvents
  });
  if (result.after) setTimeout(result.after, 0);
  state.bandeTab = GangApp.getTab();
  return result.html;
}

function isAdminAppView(view) {
  return view === 'app:gangs_admin' || view === 'app:admin';
}

function adminStatusBadge(org) {
  if (org.closed) return '<span class="badge locked">Lukket</span>';
  if (org.locked) return '<span class="badge locked">Låst</span>';
  return '<span class="badge open">Aktiv</span>';
}

function adminPermList(role, catalog) {
  if (role.isTopRank || role.key === 'leader') return '<span class="admin-perm-all">Alle tilladelser</span>';
  const perms = role.permissions || {};
  const enabled = (catalog || []).filter((p) => perms[p.key]);
  if (!enabled.length) return '<span class="admin-perm-none">Ingen tilladelser</span>';
  return '<div class="admin-perm-tags">' + enabled.map((p) => `<span class="admin-perm-tag">${escapeHtml(p.label)}</span>`).join('') + '</div>';
}

function renderAdminHub() {
  return `<div class="admin-shell admin-shell--hub">
    <div class="admin-top">
      <button type="button" class="back-btn" data-nav="home">‹</button>
      <div class="admin-top-info">
        <h2>Admin</h2>
        <p>Vælg en administration</p>
      </div>
    </div>
    <div class="admin-hub">
      <p class="admin-hub-intro">Vælg hvad du vil administrere på serveren.</p>
      <div class="admin-hub-grid">
        ${ADMIN_SECTIONS.map((section) => `
          <button type="button" class="admin-hub-card" data-admin-section="${section.id}">
            <div class="admin-hub-card-icon">
              <svg viewBox="0 0 24 24" aria-hidden="true">${section.icon}</svg>
            </div>
            <div class="admin-hub-card-body">
              <h3>${escapeHtml(section.title)}</h3>
              <p>${escapeHtml(section.desc)}</p>
            </div>
            <span class="admin-hub-card-chevron">›</span>
          </button>
        `).join('')}
      </div>
    </div>
  </div>`;
}

function renderAdminList() {
  const rows = state.adminRows || [];
  return `<div class="admin-shell admin-shell--list">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-hub-back>‹</button>
      <div class="admin-top-info">
        <h2>Bande Administrationer</h2>
        <p>Tryk på en bande for at redigere</p>
      </div>
    </div>
    <p class="admin-list-hint">Her kan du ændre navn, XP, niveau, farve, medlemmer, roller og territorier.</p>
    <div class="admin-list">
      ${rows.length ? rows.map((row) => `
        <button type="button" class="admin-org-card" data-admin-select="${row.id}">
          <div class="admin-org-card-main">
            <div class="name">${escapeHtml(row.name)}</div>
            <div class="meta">Lvl ${row.level || 1} · ${row.member_count || 0} medlemmer · ${row.zone_count || 0} zoner · ${row.xp || 0} XP</div>
          </div>
          <div class="admin-org-card-side">
            ${row.closed == 1 ? '<span class="badge locked">Lukket</span>' : row.locked == 1 ? '<span class="badge locked">Låst</span>' : '<span class="badge open">Aktiv</span>'}
            <span class="admin-org-open-label">Rediger</span>
            <span class="admin-org-chevron">›</span>
          </div>
        </button>
      `).join('') : '<div class="empty-state">Ingen bander fundet.</div>'}
    </div>
  </div>`;
}

function renderAdminOversigt(org) {
  const readonly = org.closed;
  return `<div class="admin-panel">
    <div class="admin-stats-grid">
      <div class="admin-stat-card"><span class="label">Medlemmer</span><strong>${org.memberCount || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Territorier</span><strong>${org.zoneCount || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Bande XP</span><strong>${org.xp || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Niveau</span><strong>${org.level || 1}</strong></div>
    </div>
    <div class="admin-form-card">
      <h3>Rediger bande</h3>
      <label class="admin-field-label">Navn</label>
      <input type="text" class="field" id="admin-org-name" maxlength="32" value="${escapeHtml(org.name || '')}" ${readonly ? 'disabled' : ''} />
      <div class="admin-field-row">
        <div>
          <label class="admin-field-label">XP</label>
          <input type="number" class="field" id="admin-org-xp" min="0" value="${org.xp || 0}" ${readonly ? 'disabled' : ''} />
        </div>
        <div>
          <label class="admin-field-label">Niveau</label>
          <input type="number" class="field" id="admin-org-level" min="1" value="${org.level || 1}" ${readonly ? 'disabled' : ''} />
        </div>
      </div>
      <label class="admin-field-label">Farve</label>
      <input type="text" class="field" id="admin-org-color" maxlength="7" value="${escapeHtml(org.color || '#143d2b')}" ${readonly ? 'disabled' : ''} />
      <p class="admin-field-hint">Ejer: ${escapeHtml(org.ownerName || org.ownerIdentifier || 'Ukendt')}</p>
      ${!readonly ? '<button type="button" class="btn admin-save-org-btn" data-admin-save-org>Gem ændringer</button>' : '<p class="admin-field-hint">Lukket bande — kun visning.</p>'}
    </div>
    ${org.locked ? '<div class="admin-locked-banner"><strong>Banden er låst.</strong> Medlemmer ser <em>UDE AF DRIFT</em> i Bande-appen. Tryk <strong>Lås op</strong> nedenfor for at åbne igen.</div>' : ''}
    ${!readonly ? `<div class="admin-actions-card">
      <h3>Handlinger</h3>
      <p class="admin-field-hint">${org.locked ? 'Banden er lukket for medlemmer, indtil du låser den op.' : 'Lås = midlertidig pause. Luk og slet alt = permanent — al data fjernes.'}</p>
      <div class="admin-actions-row">
        <button type="button" class="btn${org.locked ? '' : ' secondary'}" data-admin-lock="${org.id}" data-locked="${org.locked ? '0' : '1'}">${org.locked ? 'Lås op' : 'Lås bande'}</button>
        <button type="button" class="btn danger" data-admin-close="${org.id}">Luk og slet alt</button>
      </div>
    </div>` : ''}
  </div>`;
}

function renderAdminMedlemmer(org) {
  const roles = org.roles || [];
  const members = org.members || [];
  if (!members.length) return '<div class="admin-panel"><div class="empty-state">Ingen medlemmer i denne bande.</div></div>';
  return `<div class="admin-panel admin-member-list">
    ${members.map((m) => `
      <div class="admin-member-row">
        <div class="info">
          <div class="name">${escapeHtml(m.name)}</div>
          <div class="meta">${escapeHtml(m.identifier)}</div>
        </div>
        ${org.closed ? `<span class="badge">${escapeHtml(m.roleName)}</span>` : `
          <select class="field admin-role-select" data-admin-member-role="${m.id}">
            ${roles.map((r) => `<option value="${r.id}"${Number(r.id) === Number(m.roleId) ? ' selected' : ''}>${escapeHtml(r.name)}</option>`).join('')}
          </select>
          <button type="button" class="btn danger sm" data-admin-kick="${m.id}">Fjern</button>
        `}
      </div>
    `).join('')}
  </div>`;
}

function renderAdminRoller(org) {
  const catalog = org.permissionsCatalog || [];
  const roles = org.roles || [];
  return `<div class="admin-panel admin-role-list">
    ${roles.map((role) => {
      const count = (org.members || []).filter((m) => Number(m.roleId) === Number(role.id)).length;
      return `<div class="admin-role-card">
        <div class="admin-role-head">
          <h4>${escapeHtml(role.name)}${role.isTopRank ? ' <span class="badge leader-badge">Top</span>' : ''}</h4>
          <span class="count">${count} medlem${count === 1 ? '' : 'mer'}</span>
        </div>
        ${adminPermList(role, catalog)}
      </div>`;
    }).join('') || '<div class="empty-state">Ingen roller.</div>'}
  </div>`;
}

function renderAdminTerritorier(org) {
  const zones = org.zones || [];
  const overview = org.territoryOverview || [];
  const items = zones.length ? zones : overview.filter((z) => z.kind === 'owned');
  if (!items.length) return '<div class="admin-panel"><div class="empty-state">Ingen territorier.</div></div>';
  return `<div class="admin-panel admin-zone-list">
    ${items.map((z) => `
      <div class="admin-zone-row">
        <div class="info">
          <div class="name">${escapeHtml(z.name)}</div>
          <div class="meta">Lvl ${z.level || 1}${z.captureRequired ? ' · Capture ' + z.captureRequired : ''}</div>
        </div>
        ${!org.closed && z.id ? `<button type="button" class="btn danger sm" data-admin-delete-zone="${z.id}">Slet zone</button>` : ''}
      </div>
    `).join('')}
  </div>`;
}

function renderAdminDetail() {
  const org = state.adminOrgDetail;
  if (!org) {
    return `<div class="admin-shell"><div class="empty-state" style="padding:24px;">Indlæser bande...</div></div>`;
  }
  const tab = state.adminTab || 'oversigt';
  const body = tab === 'medlemmer' ? renderAdminMedlemmer(org)
    : tab === 'roller' ? renderAdminRoller(org)
    : tab === 'territorier' ? renderAdminTerritorier(org)
    : renderAdminOversigt(org);

  return `<div class="admin-shell">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-back>‹</button>
      <div class="admin-top-info">
        <h2>${escapeHtml(org.name)}</h2>
        <p>Bande #${org.id} · ${adminStatusBadge(org)}</p>
      </div>
    </div>
    <nav class="admin-nav">
      ${ADMIN_TABS.map((t) => `<button type="button" class="admin-nav-btn${tab === t.id ? ' active' : ''}" data-admin-tab="${t.id}">${t.label}</button>`).join('')}
    </nav>
    <div class="admin-content">${body}</div>
  </div>`;
}

function renderAdminApp() {
  if (state.adminSection === 'workshops') {
    if (state.adminWorkshopDetail) return renderAdminWorkshopDetail();
    if (state.adminWorkshopId) {
      return `<div class="admin-shell"><div class="empty-state" style="padding:24px;">Indlæser værksted...</div></div>`;
    }
    return renderAdminWorkshopList();
  }
  if (state.adminSection === 'cardealers') {
    if (state.adminShowCatalog) return renderAdminCatalog();
    if (state.adminSection === 'cardealers' && state.adminDealerDetail) return renderAdminDealerDetail();
    if (state.adminSection === 'cardealers' && state.adminDealerId) {
      return `<div class="admin-shell"><div class="empty-state" style="padding:24px;">Indlæser bilforhandler...</div></div>`;
    }
    if (state.adminSection === 'cardealers') return renderAdminDealerList();
  }
  if (state.adminSection === 'hub' && !state.adminOrgDetail && !state.adminOrgId) {
    return renderAdminHub();
  }
  if (state.adminSection === 'gangs') {
    if (state.adminOrgDetail || state.adminOrgId) return renderAdminDetail();
    return renderAdminList();
  }
  if (state.adminOrgDetail || state.adminOrgId) return renderAdminDetail();
  return renderAdminHub();
}

function dealerStatusBadge(dealer) {
  if (dealer.closed) return '<span class="badge locked">Lukket</span>';
  if (dealer.locked) return '<span class="badge locked">Låst</span>';
  return '<span class="badge open">Aktiv</span>';
}

function renderAdminDealerList() {
  const rows = state.adminDealerRows || [];
  return `<div class="admin-shell admin-shell--list">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-hub-back>‹</button>
      <div class="admin-top-info">
        <h2>Bilforhandlere</h2>
        <p>Opret og administrer forhandlere</p>
      </div>
    </div>
    <div class="admin-form-card" style="margin-bottom:12px;">
      <h3>Opret bilforhandler</h3>
      <label class="admin-field-label">Navn</label>
      <input type="text" class="field" id="admin-dealer-create-name" maxlength="48" placeholder="Fx Premium Motors" />
      <label class="admin-field-label">Ejer (spiller server-ID)</label>
      <input type="number" class="field" id="admin-dealer-create-owner" min="1" placeholder="Fx 12" />
      <button type="button" class="btn admin-save-org-btn" data-admin-create-dealer>Opret forhandler</button>
    </div>
    <div class="admin-actions-row" style="margin-bottom:12px;">
      <button type="button" class="btn secondary" data-admin-open-catalog>Globalt køretøjskatalog</button>
    </div>
    <div class="admin-list">
      ${rows.length ? rows.map((row) => `
        <button type="button" class="admin-org-card" data-admin-dealer-select="${row.id}">
          <div class="admin-org-card-main">
            <div class="name">${escapeHtml(row.name)}</div>
            <div class="meta">${row.member_count || 0} medlemmer · ${row.stock_count || 0} på lager · Ejer: ${escapeHtml(row.ownerName || 'Ukendt')}</div>
          </div>
          <div class="admin-org-card-side">
            ${row.closed == 1 ? '<span class="badge locked">Lukket</span>' : row.locked == 1 ? '<span class="badge locked">Låst</span>' : '<span class="badge open">Aktiv</span>'}
            <span class="admin-org-open-label">Rediger</span>
            <span class="admin-org-chevron">›</span>
          </div>
        </button>
      `).join('') : '<div class="empty-state">Ingen bilforhandlere endnu.</div>'}
    </div>
  </div>`;
}

function renderAdminDealerOversigt(dealer) {
  const readonly = dealer.closed;
  return `<div class="admin-panel">
    <div class="admin-stats-grid">
      <div class="admin-stat-card"><span class="label">Medlemmer</span><strong>${dealer.memberCount || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">På lager</span><strong>${dealer.stockCount || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Firma konto</span><strong>${formatMoney(dealer.balance || 0)}</strong></div>
      <div class="admin-stat-card"><span class="label">Katalog</span><strong>${dealer.catalogCount || 0}</strong></div>
    </div>
    <div class="admin-form-card">
      <h3>Rediger forhandler</h3>
      <label class="admin-field-label">Navn</label>
      <input type="text" class="field" id="admin-dealer-name" maxlength="48" value="${escapeHtml(dealer.name || '')}" ${readonly ? 'disabled' : ''} />
      <label class="admin-field-label">Farve</label>
      <input type="text" class="field" id="admin-dealer-color" maxlength="7" value="${escapeHtml(dealer.color || '#1e3a5f')}" ${readonly ? 'disabled' : ''} />
      <p class="admin-field-hint">Ejer: ${escapeHtml(dealer.ownerName || dealer.ownerIdentifier || 'Ukendt')}</p>
      ${!readonly ? `
        <label class="admin-field-label">Firma konto (admin)</label>
        <div class="admin-field-row">
          <input type="number" class="field" id="admin-dealer-balance" min="0" value="${dealer.balance || 0}" />
          <button type="button" class="btn secondary sm" data-admin-set-dealer-balance="${dealer.id}">Opdater konto</button>
        </div>
        <div class="admin-form-card" style="margin-top:12px;">
          <h3>Spawn ved salg</h3>
          <p class="admin-field-hint">Bilen spawner her når en medarbejder sælger. Brug knappen in-game eller indtast koordinater.</p>
          <div class="admin-field-row">
            <div><label class="admin-field-label">X</label><input type="number" step="0.01" class="field" id="admin-dealer-spawn-x" value="${dealer.spawnX != null ? dealer.spawnX : ''}" /></div>
            <div><label class="admin-field-label">Y</label><input type="number" step="0.01" class="field" id="admin-dealer-spawn-y" value="${dealer.spawnY != null ? dealer.spawnY : ''}" /></div>
            <div><label class="admin-field-label">Z</label><input type="number" step="0.01" class="field" id="admin-dealer-spawn-z" value="${dealer.spawnZ != null ? dealer.spawnZ : ''}" /></div>
            <div><label class="admin-field-label">Heading</label><input type="number" step="0.1" class="field" id="admin-dealer-spawn-h" value="${dealer.spawnHeading != null ? dealer.spawnHeading : ''}" /></div>
          </div>
          <div class="admin-actions-row">
            <button type="button" class="btn secondary sm" data-admin-capture-spawn="${dealer.id}">Brug min position (in-game)</button>
            <button type="button" class="btn sm" data-admin-save-spawn="${dealer.id}">Gem spawn</button>
          </div>
        </div>
        <label class="admin-field-label">Skift ejer (spiller server-ID)</label>
        <div class="admin-field-row">
          <input type="number" class="field" id="admin-dealer-owner-id" min="1" placeholder="Server-ID" />
          <button type="button" class="btn secondary sm" data-admin-set-dealer-owner="${dealer.id}">Skift ejer</button>
        </div>
        <button type="button" class="btn admin-save-org-btn" data-admin-save-dealer="${dealer.id}">Gem ændringer</button>
      ` : '<p class="admin-field-hint">Lukket forhandler — kun visning.</p>'}
    </div>
    ${dealer.locked && !dealer.closed ? '<div class="admin-locked-banner"><strong>Forhandleren er låst.</strong> Medarbejdere kan ikke bruge appen.</div>' : ''}
    ${!readonly ? `<div class="admin-actions-card">
      <h3>Handlinger</h3>
      <div class="admin-actions-row">
        <button type="button" class="btn${dealer.locked ? '' : ' secondary'}" data-admin-dealer-lock="${dealer.id}" data-locked="${dealer.locked ? '0' : '1'}">${dealer.locked ? 'Lås op' : 'Lås forhandler'}</button>
        <button type="button" class="btn danger" data-admin-close-dealer="${dealer.id}">Luk og slet alt</button>
      </div>
    </div>` : ''}
  </div>`;
}

function renderAdminDealerMedlemmer(dealer) {
  const roles = dealer.roles || [];
  const members = dealer.members || [];
  if (!members.length) return `<div class="admin-panel"><div class="empty-state">Ingen medlemmer endnu.</div></div>`;
  return `<div class="admin-panel admin-member-list">
    ${!dealer.closed ? `<div class="admin-form-card" style="margin-bottom:12px;">
      <h3>Tilføj medarbejder</h3>
      <label class="admin-field-label">Spiller server-ID</label>
      <div class="admin-field-row">
        <input type="number" class="field" id="admin-dealer-add-member-id" min="1" placeholder="Server-ID" />
        <button type="button" class="btn sm" data-admin-add-dealer-member="${dealer.id}">Tilføj</button>
      </div>
    </div>` : ''}
    ${members.map((m) => `
      <div class="admin-member-row">
        <div class="info">
          <div class="name">${escapeHtml(m.name)}</div>
          <div class="meta">${escapeHtml(m.identifier)}</div>
        </div>
        ${dealer.closed ? `<span class="badge">${escapeHtml(m.roleName)}</span>` : `
          <select class="field admin-role-select" data-admin-dealer-member-role="${m.id}" data-dealership-id="${dealer.id}">
            ${roles.map((r) => `<option value="${r.id}"${Number(r.id) === Number(m.roleId) ? ' selected' : ''}>${escapeHtml(r.name)}</option>`).join('')}
          </select>
          <button type="button" class="btn danger sm" data-admin-kick-dealer-member="${m.id}" data-dealership-id="${dealer.id}">Fjern</button>
        `}
      </div>
    `).join('')}
  </div>`;
}

function renderAdminDealerRoller(dealer) {
  const catalog = dealer.permissionsCatalog || [];
  const roles = dealer.roles || [];
  return `<div class="admin-panel admin-role-list">
    ${roles.map((role) => {
      const count = (dealer.members || []).filter((m) => Number(m.roleId) === Number(role.id)).length;
      return `<div class="admin-role-card">
        <div class="admin-role-head">
          <h4>${escapeHtml(role.name)}${role.isTopRank ? ' <span class="badge leader-badge">Top</span>' : ''}</h4>
          <span class="count">${count} medlem${count === 1 ? '' : 'mer'}</span>
        </div>
        ${adminPermList(role, catalog)}
      </div>`;
    }).join('') || '<div class="empty-state">Ingen roller.</div>'}
  </div>`;
}

function renderAdminDealerKoretojer(dealer) {
  const vehicles = state.adminDealerVehicles || [];
  if (!vehicles.length) {
    return `<div class="admin-panel"><div class="empty-state">Ingen køretøjer i import-kataloget endnu. Opret dem under "Globalt køretøjskatalog".</div></div>`;
  }
  return `<div class="admin-panel dealer-assign-list">
    <p class="admin-field-hint">Flueben = firmaet kan se og importere køretøjet. Sæt købs- og salgspris per firma.</p>
    ${vehicles.map((v) => `
      <div class="dealer-assign-row" data-catalog-id="${v.catalogId}">
        <label class="dealer-assign-check">
          <input type="checkbox" data-dealer-vehicle-enabled="${v.catalogId}" ${Number(v.enabled) === 1 ? 'checked' : ''} ${dealer.closed ? 'disabled' : ''} />
          <span>${escapeHtml(v.label)} <small>(${escapeHtml(v.model)})</small></span>
        </label>
        <div class="dealer-assign-fields">
          <div><label class="admin-field-label">Import</label><input type="number" class="field sm" data-dealer-import="${v.catalogId}" min="0" value="${v.importPrice || 0}" ${dealer.closed ? 'disabled' : ''} /></div>
          <div><label class="admin-field-label">Salgspris</label><input type="number" class="field sm" data-dealer-list="${v.catalogId}" min="0" value="${v.listPrice || 0}" ${dealer.closed ? 'disabled' : ''} /></div>
          <div><label class="admin-field-label">Maks lager</label><input type="number" class="field sm" data-dealer-max="${v.catalogId}" min="1" value="${v.maxStock || 20}" ${dealer.closed ? 'disabled' : ''} /></div>
          ${!dealer.closed ? `<button type="button" class="btn sm" data-admin-save-dealer-vehicle="${dealer.id}" data-catalog-id="${v.catalogId}">Gem</button>` : ''}
        </div>
      </div>
    `).join('')}
  </div>`;
}

function renderAdminDealerDetail() {
  const dealer = state.adminDealerDetail;
  if (!dealer) {
    return `<div class="admin-shell"><div class="empty-state" style="padding:24px;">Indlæser bilforhandler...</div></div>`;
  }
  const tab = state.adminDealerTab || 'oversigt';
  const body = tab === 'medlemmer' ? renderAdminDealerMedlemmer(dealer)
    : tab === 'roller' ? renderAdminDealerRoller(dealer)
    : tab === 'koretojer' ? renderAdminDealerKoretojer(dealer)
    : renderAdminDealerOversigt(dealer);

  return `<div class="admin-shell">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-dealer-back>‹</button>
      <div class="admin-top-info">
        <h2>${escapeHtml(dealer.name)}</h2>
        <p>Forhandler #${dealer.id} · ${dealerStatusBadge(dealer)}</p>
      </div>
    </div>
    <nav class="admin-nav">
      ${DEALER_ADMIN_TABS.map((t) => `<button type="button" class="admin-nav-btn${tab === t.id ? ' active' : ''}" data-admin-dealer-tab="${t.id}">${t.label}</button>`).join('')}
    </nav>
    <div class="admin-content">${body}</div>
  </div>`;
}

function renderAdminCatalog() {
  const rows = state.adminCatalogRows || [];
  return `<div class="admin-shell admin-shell--list">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-catalog-back>‹</button>
      <div class="admin-top-info">
        <h2>Køretøjskatalog</h2>
        <p>Global liste over køretøjer alle forhandlere kan bruge</p>
      </div>
    </div>
    <div class="admin-form-card" style="margin-bottom:12px;">
      <h3>Tilføj køretøj til import-katalog</h3>
      <div class="admin-field-row">
        <div><label class="admin-field-label">Model (spawn)</label><input type="text" class="field" id="admin-catalog-model" placeholder="zentorno" /></div>
        <div><label class="admin-field-label">Navn</label><input type="text" class="field" id="admin-catalog-label" placeholder="Zentorno" /></div>
      </div>
      <div class="admin-field-row">
        <div><label class="admin-field-label">Producent</label><input type="text" class="field" id="admin-catalog-manufacturer" placeholder="Pegassi" /></div>
        <div><label class="admin-field-label">År</label><input type="number" class="field" id="admin-catalog-year" min="1980" value="2024" /></div>
      </div>
      <div class="admin-field-row">
        <div><label class="admin-field-label">Standard import</label><input type="number" class="field" id="admin-catalog-import" min="0" value="0" /></div>
        <div><label class="admin-field-label">Standard salg</label><input type="number" class="field" id="admin-catalog-list" min="0" value="0" /></div>
        <div><label class="admin-field-label">Leverandør lager</label><input type="number" class="field" id="admin-catalog-supplier" min="0" value="50" /></div>
      </div>
      <label class="admin-field-label">Billede URL (valgfri)</label>
      <input type="text" class="field" id="admin-catalog-image" placeholder="https://..." />
      <button type="button" class="btn admin-save-org-btn" data-admin-add-catalog>Tilføj til katalog</button>
    </div>
    <div class="admin-list">
      ${rows.length ? rows.map((row) => `
        <div class="admin-zone-row">
          <div class="info">
            <div class="name">${escapeHtml(row.label)}</div>
            <div class="meta">${escapeHtml(row.model)} · ${escapeHtml(row.category || 'misc')} · Import ${row.import_price || 0} · List ${row.list_price || 0}</div>
          </div>
          <button type="button" class="btn danger sm" data-admin-remove-catalog="${row.id}">Slet</button>
        </div>
      `).join('') : '<div class="empty-state">Kataloget er tomt.</div>'}
    </div>
  </div>`;
}

function normalizeAdminWorkshopRows(rows) {
  if (Array.isArray(rows)) return rows;
  if (rows && Array.isArray(rows.rows)) return rows.rows;
  return [];
}

function workshopStatusBadge(company) {
  if (company.closed) return '<span class="badge locked">Lukket</span>';
  if (company.locked) return '<span class="badge locked">Låst</span>';
  return '<span class="badge open">Aktiv</span>';
}

function getWorkshopBrandingDefaults(companyType) {
  if (companyType === 'lscustom') {
    return { blipSprite: 72, blipColor: 5, subtitle: 'LS Customs' };
  }
  return { blipSprite: 225, blipColor: 3, subtitle: "Benny's" };
}

function getCreateWorkshopLocationCatalog(companyType, companyName) {
  const defaults = getWorkshopBrandingDefaults(companyType);
  return [{
    key: 'company_new',
    label: companyName || 'Ny butik',
    subtitle: defaults.subtitle,
    pos: {},
    radius: 18,
    blipSprite: defaults.blipSprite,
    blipColor: defaults.blipColor,
    blipScale: 0.85,
    blipEnabled: true,
  }];
}

function getWorkshopEditShopKeys(company) {
  if (!company) return [];
  if (company.shopKeys && company.shopKeys.length) return company.shopKeys;
  if (company.id) return [`company_${company.id}`];
  return [];
}

function getWorkshopEditShopCatalog(company) {
  if (company && company.shopCatalog && company.shopCatalog.length) {
    return company.shopCatalog;
  }
  return getCreateWorkshopLocationCatalog(company && company.companyType, company && company.name);
}

function renderAdminShopCheckboxes(prefix, catalog, selectedKeys, companyId, readonly, companyType) {
  const selected = new Set((selectedKeys || []).map(String));
  const list = (catalog && catalog.length ? catalog : (state.adminWorkshopShopCatalog || []))
    .filter((shop) => !companyType || shop.companyType === companyType || !shop.companyType);
  if (!list.length) return '<p class="admin-field-hint">Ingen ledige butikker for denne branding.</p>';
  return `<div class="admin-shop-picks">${list.map((shop) => {
    const taken = shop.assignedCompanyId && Number(shop.assignedCompanyId) !== Number(companyId || 0);
    const checked = selected.has(shop.key);
    return `<label class="admin-shop-pick${taken ? ' is-taken' : ''}">
      <input type="checkbox" value="${escapeHtml(shop.key)}" data-admin-shop-${prefix} ${checked ? 'checked' : ''} ${taken || readonly ? 'disabled' : ''} />
      <span class="admin-shop-pick-text">
        <strong>${escapeHtml(shop.label || shop.key)}</strong>
        ${shop.subtitle ? `<small>${escapeHtml(shop.subtitle)}</small>` : ''}
        ${taken ? `<small class="taken">Til ${escapeHtml(shop.assignedCompanyName || 'andet firma')}</small>` : ''}
      </span>
    </label>`;
  }).join('')}</div>`;
}

function getAdminSelectedShopKeys(prefix) {
  return Array.from(document.querySelectorAll(`[data-admin-shop-${prefix}]:checked`)).map((el) => el.value);
}

function getAdminShopLocations(prefix, shopKeys) {
  const out = {};
  (shopKeys || []).forEach((key) => {
    const x = document.getElementById(`admin-shop-${prefix}-x-${key}`);
    const y = document.getElementById(`admin-shop-${prefix}-y-${key}`);
    const z = document.getElementById(`admin-shop-${prefix}-z-${key}`);
    const radius = document.getElementById(`admin-shop-${prefix}-r-${key}`);
    if (!x || !y || !z) return;
    out[key] = {
      x: Number(x.value),
      y: Number(y.value),
      z: Number(z.value),
      radius: Number(radius && radius.value) || 18
    };
  });
  return out;
}

function getAdminShopBlips(prefix, shopKeys) {
  const out = {};
  (shopKeys || []).forEach((key) => {
    const sprite = document.getElementById(`admin-shop-${prefix}-blip-${key}`);
    const color = document.getElementById(`admin-shop-${prefix}-blip-color-${key}`);
    const scale = document.getElementById(`admin-shop-${prefix}-blip-scale-${key}`);
    const enabled = document.getElementById(`admin-shop-${prefix}-blip-enabled-${key}`);
    out[key] = {
      blipSprite: Number(sprite && sprite.value) || 72,
      blipColor: Number(color && color.value) || 3,
      blipScale: Number(scale && scale.value) || 0.85,
      blipEnabled: enabled ? enabled.checked : true
    };
  });
  return out;
}

function renderAdminBlipPickerModal() {
  const picker = state.adminBlipPicker;
  if (!picker) return '';
  const catalog = state.adminBlipCatalog || [];
  const query = (picker.search || '').toLowerCase();
  const filtered = catalog.filter((b) => {
    if (!query) return true;
    return String(b.id).includes(query) || String(b.label || '').toLowerCase().includes(query);
  }).slice(0, 120);
  return `<div class="admin-blip-modal-backdrop" data-admin-close-blip-picker>
    <div class="admin-blip-modal" data-stop-close>
      <div class="admin-blip-modal-head">
        <h3>Vælg blip-ikon</h3>
        <button type="button" class="btn secondary sm" data-admin-close-blip-picker>Luk</button>
      </div>
      <input type="text" class="field" placeholder="Søg blip # eller navn..." data-admin-blip-search value="${escapeHtml(picker.search || '')}" />
      <div class="admin-blip-grid">
        ${filtered.map((b) => `
          <button type="button" class="admin-blip-item${Number(picker.currentSprite) === Number(b.id) ? ' active' : ''}" data-admin-blip-pick="${b.id}">
            <strong>#${b.id}</strong>
            <span>${escapeHtml(b.label || '')}</span>
          </button>
        `).join('')}
      </div>
    </div>
  </div>`;
}

function renderAdminShopLocationEditors(prefix, shopKeys, catalog, readonly, companyName) {
  const byKey = {};
  (catalog || []).forEach((shop) => { byKey[shop.key] = shop; });
  const keys = shopKeys || [];
  if (!keys.length) {
    return '<p class="admin-field-hint">Vælg mindst én butik for at sætte position.</p>';
  }
  const colors = state.adminBlipColors || [];
  return `<div class="admin-shop-locations">${keys.map((key) => {
    const shop = byKey[key] || { key, label: key, pos: {}, radius: 18, blipSprite: 72, blipColor: 3, blipScale: 0.85, blipEnabled: true };
    const pos = shop.pos || {};
    const radius = shop.radius || 18;
    const blipName = companyName || 'Firmanavn';
    return `<div class="admin-shop-loc-card">
      <div class="admin-shop-loc-head">
        <strong>${escapeHtml(shop.label || key)}</strong>
        <span>${shop.hasCustomLocation ? 'Gemt position' : 'Standard fra config'}</span>
      </div>
      <div class="admin-field-row">
        <div><label class="admin-field-label">X</label><input type="number" step="0.01" class="field" id="admin-shop-${prefix}-x-${key}" value="${Number(pos.x || 0)}" ${readonly ? 'disabled' : ''} /></div>
        <div><label class="admin-field-label">Y</label><input type="number" step="0.01" class="field" id="admin-shop-${prefix}-y-${key}" value="${Number(pos.y || 0)}" ${readonly ? 'disabled' : ''} /></div>
        <div><label class="admin-field-label">Z</label><input type="number" step="0.01" class="field" id="admin-shop-${prefix}-z-${key}" value="${Number(pos.z || 0)}" ${readonly ? 'disabled' : ''} /></div>
        <div><label class="admin-field-label">Radius</label><input type="number" step="0.5" min="3" max="80" class="field" id="admin-shop-${prefix}-r-${key}" value="${Number(radius)}" ${readonly ? 'disabled' : ''} /></div>
      </div>
      ${!readonly ? `<button type="button" class="btn secondary sm" data-admin-capture-shop="${key}" data-admin-capture-prefix="${prefix}">Brug min position</button>` : ''}
      <div class="admin-shop-blip-box">
        <label class="admin-shop-blip-toggle">
          <input type="checkbox" id="admin-shop-${prefix}-blip-enabled-${key}" ${shop.blipEnabled !== false ? 'checked' : ''} ${readonly ? 'disabled' : ''} />
          <span>Vis blip på kortet</span>
        </label>
        <p class="admin-field-hint">Blip-navn på kortet: <strong>${escapeHtml(blipName)}</strong></p>
        <div class="admin-field-row">
          <div>
            <label class="admin-field-label">Blip-ikon</label>
            <input type="hidden" id="admin-shop-${prefix}-blip-${key}" value="${Number(shop.blipSprite || 72)}" />
            <button type="button" class="btn secondary sm" data-admin-pick-blip="${key}" data-admin-pick-prefix="${prefix}" ${readonly ? 'disabled' : ''}>Vælg blip (#${Number(shop.blipSprite || 72)})</button>
          </div>
          <div>
            <label class="admin-field-label">Farve</label>
            <select class="field" id="admin-shop-${prefix}-blip-color-${key}" ${readonly ? 'disabled' : ''}>
              ${(colors.length ? colors : [{ id: 3, label: 'Blå' }]).map((c) => `<option value="${c.id}"${Number(shop.blipColor || 3) === Number(c.id) ? ' selected' : ''}>${escapeHtml(c.label)}</option>`).join('')}
            </select>
          </div>
          <div>
            <label class="admin-field-label">Størrelse</label>
            <input type="number" step="0.05" min="0.5" max="2" class="field" id="admin-shop-${prefix}-blip-scale-${key}" value="${Number(shop.blipScale || 0.85)}" ${readonly ? 'disabled' : ''} />
          </div>
        </div>
      </div>
      <p class="admin-field-hint">Stå hvor [E]-zonen skal være (i bil), og tryk "Brug min position".</p>
    </div>`;
  }).join('')}</div>`;
}

function renderAdminWorkshopList() {
  const rows = state.adminWorkshopRows || [];
  const companyType = (state.adminWorkshopCreateType || 'bennys');
  const companyName = state.adminWorkshopCreateName || '';
  const createCatalog = getCreateWorkshopLocationCatalog(companyType, companyName);
  return `<div class="admin-shell admin-shell--list">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-hub-back>‹</button>
      <div class="admin-top-info">
        <h2>Værksteder & firmaer</h2>
        <p>Opret Benny's eller LS Customs firmaer med egen lokation og menu</p>
      </div>
    </div>
    <div class="admin-list-body">
      <div class="admin-form-card" style="margin-bottom:12px;">
        <h3>Opret værksted</h3>
        <p class="admin-field-hint" style="margin-bottom:10px;">Hvert <strong>firma</strong> får sin egen butik-zone, blip og medarbejdere. Vælg branding — Benny's eller LS Customs — så spillerne får det rigtige tuning-menu.</p>
        <div class="admin-field-row">
          <div><label class="admin-field-label">Navn</label><input type="text" class="field" id="admin-workshop-name" maxlength="48" placeholder="Fx Bennys APS" value="${escapeHtml(companyName)}" /></div>
          <div><label class="admin-field-label">Ejer spiller-ID</label><input type="number" class="field" id="admin-workshop-owner" min="1" placeholder="1" /></div>
        </div>
        <div class="admin-field-row">
          <div><label class="admin-field-label">Branding</label>
            <select class="field" id="admin-workshop-type">
              <option value="bennys"${companyType === 'bennys' ? ' selected' : ''}>Benny's</option>
              <option value="lscustom"${companyType === 'lscustom' ? ' selected' : ''}>LS Customs</option>
            </select>
          </div>
          <div><label class="admin-field-label">ESX job (valgfri)</label><input type="text" class="field" id="admin-workshop-job" placeholder="mechanic / bennys" /></div>
        </div>
        <label class="admin-field-label">Butik-position & blip</label>
        <p class="admin-field-hint" style="margin-bottom:8px;">Stå på stedet i verden og tryk <strong>Brug min position</strong> — ellers kan firmaet ikke oprettes.</p>
        <div id="admin-shop-locations-create-wrap">
          ${renderAdminShopLocationEditors('create', ['company_new'], createCatalog, false, companyName)}
        </div>
        <button type="button" class="btn admin-save-org-btn" data-admin-create-workshop>Opret værksted</button>
      </div>
      <div class="admin-list">
        ${rows.length ? rows.map((row) => `
          <button type="button" class="admin-org-card" data-admin-workshop-select="${row.id}">
            <div class="admin-org-card-main">
              <div class="name">${escapeHtml(row.name)}</div>
              <div class="meta">${escapeHtml(row.companyTypeLabel || row.company_type || '')} · ${escapeHtml(row.shopSummary || 'Ingen butikker')} · ${row.member_count || 0} medarbejdere · ${row.order_count || 0} aktive bestillinger</div>
            </div>
            <div class="admin-org-card-side">
              ${row.closed == 1 ? '<span class="badge locked">Lukket</span>' : row.locked == 1 ? '<span class="badge locked">Låst</span>' : '<span class="badge open">Aktiv</span>'}
              <span class="admin-org-chevron">›</span>
            </div>
          </button>
        `).join('') : '<div class="empty-state">Ingen værksteder oprettet endnu.</div>'}
      </div>
    </div>
    ${renderAdminBlipPickerModal()}
  </div>`;
}

function renderAdminWorkshopOversigt(company) {
  const readonly = company.closed;
  const editShopKeys = getWorkshopEditShopKeys(company);
  const editShopCatalog = getWorkshopEditShopCatalog(company);
  const branding = company.companyType === 'mechanic' ? 'lscustom' : (company.companyType || 'bennys');
  return `<div class="admin-panel">
    <div class="admin-stats-grid">
      <div class="admin-stat-card"><span class="label">Medarbejdere</span><strong>${company.memberCount || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Aktive bestillinger</span><strong>${company.activeOrders || 0}</strong></div>
      <div class="admin-stat-card"><span class="label">Firma konto</span><strong>${formatMoney(company.balance || 0)}</strong></div>
    </div>
    <div class="admin-form-card">
      <h3>Rediger værksted</h3>
      <label class="admin-field-label">Navn</label>
      <input type="text" class="field" id="admin-workshop-edit-name" maxlength="48" value="${escapeHtml(company.name || '')}" ${readonly ? 'disabled' : ''} />
      <div class="admin-field-row">
        <div><label class="admin-field-label">Branding</label>
          <select class="field" id="admin-workshop-edit-type" ${readonly ? 'disabled' : ''}>
            <option value="bennys"${branding === 'bennys' ? ' selected' : ''}>Benny's</option>
            <option value="lscustom"${branding === 'lscustom' ? ' selected' : ''}>LS Customs</option>
          </select>
        </div>
        <div><label class="admin-field-label">ESX job</label><input type="text" class="field" id="admin-workshop-edit-job" value="${escapeHtml(company.jobName || '')}" ${readonly ? 'disabled' : ''} /></div>
      </div>
      <label class="admin-field-label">Farve</label>
      <input type="text" class="field" id="admin-workshop-edit-color" maxlength="7" value="${escapeHtml(company.color || '#14b8a6')}" ${readonly ? 'disabled' : ''} />
      <label class="admin-field-label">Butik-position & blip</label>
      ${renderAdminShopLocationEditors('edit', editShopKeys, editShopCatalog, readonly, company.name || '')}
      <p class="admin-field-hint">Spillere trykker [E] i zonen for at åbne ${branding === 'lscustom' ? 'LS Customs' : "Benny's"}-menuen for dette firma.</p>
      <p class="admin-field-hint">Ejer: ${escapeHtml(company.ownerName || '')}</p>
      ${!readonly ? '<button type="button" class="btn admin-save-org-btn" data-admin-save-workshop>Gem ændringer</button>' : ''}
    </div>
    ${company.locked ? '<div class="admin-locked-banner"><strong>UDE AF DRIFT</strong> Værkstedet er låst.</div>' : ''}
    ${!readonly ? `<div class="admin-actions-card">
      <h3>Handlinger</h3>
      <div class="admin-actions-row">
        <button type="button" class="btn${company.locked ? '' : ' secondary'}" data-admin-workshop-lock="${company.id}" data-locked="${company.locked ? '0' : '1'}">${company.locked ? 'Lås op' : 'Lås værksted'}</button>
        <button type="button" class="btn danger" data-admin-close-workshop="${company.id}">Luk og slet</button>
      </div>
    </div>` : ''}
  </div>`;
}

function renderAdminWorkshopMedlemmer(company) {
  const roles = company.roles || [];
  const members = company.members || [];
  return `<div class="admin-panel">
    ${!company.closed ? `<div class="admin-form-card" style="margin-bottom:12px;">
      <h3>Tilføj medarbejder</h3>
      <div class="admin-field-row">
        <input type="number" class="field" id="admin-workshop-invite-id" min="1" placeholder="Spiller server-ID" />
        <button type="button" class="btn" data-admin-workshop-invite="${company.id}">Tilføj</button>
      </div>
    </div>` : ''}
    <div class="admin-member-list">
      ${members.length ? members.map((m) => `
        <div class="admin-member-row">
          <div class="info"><div class="name">${escapeHtml(m.name)}</div><div class="meta">${escapeHtml(m.identifier)}</div></div>
          ${!company.closed ? `<select class="field sm" data-admin-workshop-member-role="${company.id}" data-member-id="${m.id}">
            ${roles.map((r) => `<option value="${r.id}"${Number(m.roleId) === Number(r.id) ? ' selected' : ''}>${escapeHtml(r.name)}</option>`).join('')}
          </select>
          <button type="button" class="btn danger sm" data-admin-workshop-kick="${company.id}" data-member-id="${m.id}">Fjern</button>` : `<span class="badge">${escapeHtml(m.roleName || '')}</span>`}
        </div>
      `).join('') : '<div class="empty-state">Ingen medarbejdere.</div>'}
    </div>
  </div>`;
}

function renderAdminWorkshopRoller(company) {
  const roles = company.roles || [];
  const catalog = company.permissionsCatalog || [];
  return `<div class="admin-panel admin-role-list">
    ${roles.map((role) => {
      const count = (company.members || []).filter((m) => Number(m.roleId) === Number(role.id)).length;
      return `<div class="admin-role-card">
        <div class="admin-role-head">
          <h4>${escapeHtml(role.name)}${role.isTopRank ? ' <span class="badge leader-badge">Ejer</span>' : ''}</h4>
          <span class="count">${count} medarbejder${count === 1 ? '' : 'e'}</span>
        </div>
        ${adminPermList(role, catalog)}
        ${!company.closed && !role.isTopRank ? `<button type="button" class="btn danger sm" data-admin-workshop-delete-role="${company.id}" data-role-id="${role.id}">Slet rolle</button>` : ''}
      </div>`;
    }).join('') || '<div class="empty-state">Ingen roller.</div>'}
  </div>`;
}

function renderAdminWorkshopDetail() {
  const company = state.adminWorkshopDetail;
  if (!company) return `<div class="admin-shell"><div class="empty-state" style="padding:24px;">Indlæser værksted...</div></div>`;
  const tab = state.adminWorkshopTab || 'oversigt';
  const body = tab === 'medlemmer' ? renderAdminWorkshopMedlemmer(company)
    : tab === 'roller' ? renderAdminWorkshopRoller(company)
    : renderAdminWorkshopOversigt(company);
  return `<div class="admin-shell">
    <div class="admin-top">
      <button type="button" class="back-btn" data-admin-workshop-back>‹</button>
      <div class="admin-top-info">
        <h2>${escapeHtml(company.name)}</h2>
        <p>Værksted #${company.id} · ${workshopStatusBadge(company)}</p>
      </div>
    </div>
    <nav class="admin-nav">
      ${WORKSHOP_ADMIN_TABS.map((t) => `<button type="button" class="admin-nav-btn${tab === t.id ? ' active' : ''}" data-admin-workshop-tab="${t.id}">${t.label}</button>`).join('')}
    </nav>
    <div class="admin-content">${body}</div>
    ${renderAdminBlipPickerModal()}
  </div>`;
}

function wsStatusClass(status) {
  if (status === 'completed' || status === 'paid') return 'paid';
  if (status === 'cancelled') return 'unpaid';
  if (status === 'in_progress' || status === 'open') return 'pending';
  return 'unpaid';
}

function wsOrderBadgeClass(order) {
  const status = normalizeWsStatus(order.status);
  if (status === 'completed' && order.invoiceStatus !== 'paid') return 'pending';
  return wsStatusClass(status);
}

function normalizeWsStatus(status) {
  return String(status || '').trim().toLowerCase();
}

function formatOrderItemLine(item) {
  if (!item) return 'Ukendt ydelse';
  const raw = String(item.label || item.description || 'Ydelse');
  const label = raw.replace(/\s*[—–-]\s*åbning$/i, '').trim();
  if (item.lineType === 'unlock') {
    return `Åbning: ${label}`;
  }
  return `1x ${label}`;
}

function getWsOrderStatusLabel(order) {
  const status = normalizeWsStatus(order.status);
  if (status === 'completed' && order.invoiceStatus === 'unpaid') return 'Afventer betaling';
  if (status === 'completed' && !order.hasInvoice) return 'Mangler faktura';
  return order.statusLabel || order.status || 'Ukendt';
}

function wsOrderMatchesFilter(order, filter) {
  const status = normalizeWsStatus(order.status);
  if (filter === 'alle') return true;
  if (filter === 'afventer_betaling') return status === 'completed' && order.invoiceStatus !== 'paid';
  if (filter === 'mangler_faktura') return status === 'completed' && !order.hasInvoice;
  return status === filter;
}

function wsMatchesSearch(text, query) {
  if (!query) return true;
  return String(text || '').toLowerCase().includes(query.toLowerCase());
}

function renderWorkshopSidebar(tab, company, member) {
  const shopText = (company.shopLabels || []).length
    ? company.shopLabels.join(', ')
    : 'Ingen butikker tilknyttet';
  return `<aside class="ws-sidebar">
    <div class="ws-brand">
      <div class="ws-brand-icon" style="background:${escapeHtml(company.color || '#f97316')}22;border-color:${escapeHtml(company.color || '#f97316')}55;">
        <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76Z"/></svg>
      </div>
      <div class="ws-brand-text">
        <strong>${escapeHtml(company.name || 'Værksted')}</strong>
        <span>${escapeHtml(member.roleName || '')}</span>
      </div>
    </div>
    <nav class="ws-nav">
      ${WORKSHOP_NAV.map((section) => `
        <div class="ws-nav-section">
          <span class="ws-nav-label">${escapeHtml(section.label)}</span>
          ${section.items.map((item) => `
            <button type="button" class="ws-nav-btn${tab === item.id ? ' active' : ''}" data-ws-tab="${item.id}">
              <svg viewBox="0 0 24 24" aria-hidden="true">${item.icon}</svg>
              <span>${escapeHtml(item.label)}</span>
            </button>
          `).join('')}
        </div>
      `).join('')}
    </nav>
    <div class="ws-sidebar-foot">
      <span class="ws-shops-label">Butikker</span>
      <span class="ws-shops-value">${escapeHtml(shopText)}</span>
    </div>
    <button type="button" class="ws-home-btn" data-nav="home">Luk tablet</button>
  </aside>`;
}

function renderWorkshopTabBody(data, tab) {
  const company = data.company || {};
  const perms = data.permissions || {};
  if (tab === 'oversigt') {
    const stats = data.stats || {};
    return `<div class="ws-page">
      <div class="ws-page-head"><h2>Oversigt</h2></div>
      <div class="ws-stat-grid">
        <div class="ws-stat-card"><span>Afventer</span><strong>${stats.pendingOrders || 0}</strong></div>
        <div class="ws-stat-card"><span>I gang</span><strong>${stats.activeOrders || 0}</strong></div>
        <div class="ws-stat-card"><span>Åbne opkald</span><strong>${stats.openCalls || 0}</strong></div>
        <div class="ws-stat-card"><span>Ubetalt</span><strong>${stats.unpaidInvoices || 0}</strong></div>
        <div class="ws-stat-card paid"><span>Færdige ordre</span><strong>${stats.finishedOrders || 0}</strong></div>
      </div>
      <div class="ws-balance-card">
        <span>Firma konto</span>
        <strong>${formatMoney(company.balance || 0)}</strong>
      </div>
      ${(company.shopLabels || []).length ? `<div class="ws-info-card">
        <span>Dine butikker</span>
        <p>${company.shopLabels.map((l) => escapeHtml(l)).join(' · ')}</p>
        <small>Bestillinger fra disse lokationer lander her i tabletten.</small>
      </div>` : ''}
    </div>`;
  }
  if (tab === 'bestillinger') {
    const orders = data.orders || [];
    const query = state.workshopSearch || '';
    const filter = state.workshopOrderFilter || 'alle';
    const filtered = orders.filter((o) => {
      if (!wsOrderMatchesFilter(o, filter)) return false;
      const hay = `${o.orderNumber} ${o.vehiclePlate} ${o.customerName} ${o.shopLabel || ''}`;
      return wsMatchesSearch(hay, query);
    });
    return `<div class="ws-page">
      <div class="ws-page-head">
        <h2>Bestillinger</h2>
        <div class="ws-toolbar">
          <select class="ws-field sm" data-ws-order-filter>
            <option value="alle"${filter === 'alle' ? ' selected' : ''}>Alle aktive</option>
            <option value="pending"${filter === 'pending' ? ' selected' : ''}>Afventer</option>
            <option value="in_progress"${filter === 'in_progress' ? ' selected' : ''}>I gang</option>
            <option value="afventer_betaling"${filter === 'afventer_betaling' ? ' selected' : ''}>Afventer betaling</option>
            <option value="mangler_faktura"${filter === 'mangler_faktura' ? ' selected' : ''}>Mangler faktura</option>
            <option value="cancelled"${filter === 'cancelled' ? ' selected' : ''}>Annulleret</option>
          </select>
          <input type="text" class="ws-field" placeholder="Søg ordre, plade, kunde..." data-ws-search value="${escapeHtml(query)}" />
        </div>
      </div>
      <p class="ws-hint" style="margin-bottom:10px;">Aktive ordrer. Når bilen er fikset <b>og</b> fakturaen er betalt, flyttes ordren til <b>Færdige ordre</b>.</p>
      <div class="ws-table-wrap">
        <table class="ws-table">
          <thead>
            <tr>
              <th>#</th><th>Tidspunkt</th><th>Plade</th><th>Kunde</th><th>Butik</th><th>Beløb</th><th>Status</th><th></th>
            </tr>
          </thead>
          <tbody>
            ${filtered.length ? filtered.map((o) => {
              const status = normalizeWsStatus(o.status);
              return `
              <tr class="ws-row-click" data-ws-order="${o.id}">
                <td>${escapeHtml(o.orderNumber || '')}</td>
                <td>${escapeHtml(o.createdAt || '')}</td>
                <td><b>${escapeHtml(o.vehiclePlate || '')}</b></td>
                <td>${escapeHtml(o.customerName || '')}</td>
                <td>${escapeHtml(o.shopLabel || '—')}</td>
                <td>${formatMoney(o.totalPrice)}</td>
                <td><span class="ws-badge ${wsOrderBadgeClass(o)}">${escapeHtml(getWsOrderStatusLabel(o))}</span></td>
                <td class="ws-actions">
                  <button type="button" class="ws-btn sm ghost" data-ws-view-order="${o.id}">Se bestilling</button>
                  ${perms.orders && status === 'pending' ? `<button type="button" class="ws-btn sm" data-ws-quick-start="${o.id}">Start arbejde</button>` : ''}
                  ${perms.orders && status === 'in_progress' ? `<button type="button" class="ws-btn sm secondary" data-ws-quick-stop="${o.id}">Stop</button>` : ''}
                </td>
              </tr>`;
            }).join('') : '<tr><td colspan="8" class="ws-empty">Ingen bestillinger fundet.</td></tr>'}
          </tbody>
        </table>
      </div>
    </div>`;
  }
  if (tab === 'opkald') {
    const calls = data.calls || [];
    const query = state.workshopSearch || '';
    const filtered = calls.filter((c) => wsMatchesSearch(`${c.callerName} ${c.message}`, query));
    return `<div class="ws-page">
      <div class="ws-page-head">
        <h2>Opkald</h2>
        <div class="ws-toolbar">
          <input type="text" class="ws-field" placeholder="Søg opkald..." data-ws-search value="${escapeHtml(query)}" />
        </div>
      </div>
      <div class="ws-table-wrap">
        <table class="ws-table">
          <thead><tr><th>Tidspunkt</th><th>Opkalder</th><th>Besked</th><th>Status</th><th></th></tr></thead>
          <tbody>
            ${filtered.length ? filtered.map((c) => `
              <tr>
                <td>${escapeHtml(c.createdAt || '')}</td>
                <td><b>${escapeHtml(c.callerName || 'Ukendt')}</b></td>
                <td>${escapeHtml(c.message || '')}</td>
                <td><span class="ws-badge ${wsStatusClass(c.status)}">${escapeHtml(c.statusLabel || c.status)}</span></td>
                <td class="ws-actions">
                  ${perms.acceptCalls && c.status === 'open' ? `<button type="button" class="ws-btn sm" data-ws-accept-call="${c.id}">Tag</button>` : ''}
                  <button type="button" class="ws-btn sm ghost" data-ws-waypoint-call="${c.id}">GPS</button>
                  ${perms.calls ? `<button type="button" class="ws-btn sm ghost" data-ws-close-call="${c.id}">Luk</button>` : ''}
                </td>
              </tr>
            `).join('') : '<tr><td colspan="5" class="ws-empty">Ingen åbne opkald.</td></tr>'}
          </tbody>
        </table>
      </div>
    </div>`;
  }
  if (tab === 'faktura') {
    const invoices = data.invoices || [];
    const stats = data.invoiceStats || {};
    const ordersWithoutInvoice = data.ordersWithoutInvoice || [];
    const company = data.company || {};
    const query = state.workshopSearch || '';
    const filtered = invoices.filter((inv) => wsMatchesSearch(`${inv.invoiceNumber} ${inv.customerName} ${inv.description}`, query));
    const form = state.workshopInvoiceForm || {};
    const searchResults = state.workshopInvoiceSearchResults || [];
    const canInvoice = perms.invoices === true;

    const pendingOrdersBlock = canInvoice && ordersWithoutInvoice.length ? `
      <div class="ws-card">
        <h3>Bestillinger uden faktura</h3>
        <p class="ws-hint">Beløb følger prislisten fra kundens design.</p>
        ${ordersWithoutInvoice.map((order) => `
          <div class="ws-price-row">
            <div>
              <strong>${escapeHtml(order.customerName || 'Ukendt')}</strong>
              <span>${escapeHtml(order.orderNumber || '')} · ${escapeHtml(order.vehiclePlate || '')} · ${escapeHtml(order.vehicleLabel || '')}</span>
            </div>
            <div class="ws-actions-inline">
              <strong>${formatMoney(order.totalPrice)}</strong>
              <button type="button" class="ws-btn sm" data-ws-send-order-invoice="${order.id}">Send faktura</button>
            </div>
          </div>
        `).join('')}
      </div>` : '';

    const manualInvoiceBlock = canInvoice ? `
      <div class="ws-card">
        <h3>Send faktura til spiller</h3>
        <p class="ws-hint">Søg efter navn (online spillere eller tidligere kunder). Beløb kan også komme fra en bestilling ovenfor.</p>
        <div class="ws-form-grid">
          <input type="text" class="ws-field" placeholder="Søg navn..." data-ws-invoice-search value="${escapeHtml(form.customerName || '')}" />
          <input type="text" class="ws-field" placeholder="Beskrivelse (valgfri)" data-ws-invoice-desc value="${escapeHtml(form.description || '')}" />
          <input type="number" class="ws-field sm" min="1" step="1" placeholder="Beløb DKK" data-ws-invoice-amount value="${escapeHtml(form.amount || '')}" ${form.orderId ? 'disabled' : ''} />
          <button type="button" class="ws-btn" data-ws-send-manual-invoice ${form.customerName ? '' : 'disabled'}>Send faktura</button>
        </div>
        ${searchResults.length ? `<div class="ws-search-results">${searchResults.map((c, idx) => `
          <button type="button" class="ws-search-hit" data-ws-pick-customer="${idx}">
            <b>${escapeHtml(c.name || '')}</b>
            <span>${escapeHtml(c.sourceLabel || (c.online ? 'Online' : 'Tidligere kunde'))}</span>
          </button>
        `).join('')}</div>` : (form.customerName && form.customerName.length >= 2 ? '<p class="ws-hint">Ingen spillere fundet — du kan stadig sende med det indtastede navn.</p>' : '')}
      </div>` : '';

    return `<div class="ws-page ws-page-scroll">
      <div class="ws-page-head">
        <h2>Faktura</h2>
        <div class="ws-toolbar">
          <input type="text" class="ws-field" placeholder="Søg navn, faktura..." data-ws-search value="${escapeHtml(query)}" />
        </div>
      </div>
      <p class="ws-hint" style="margin-bottom:12px;">Alle sendte fakturaer. Ubetalte bliver her og i <b>Bestillinger</b> indtil kunden betaler.</p>
      <div class="ws-stat-grid">
        <div class="ws-stat-card warn"><span>Ikke betalt beløb i alt</span><strong>${formatMoney(stats.unpaidTotal || 0)}</strong></div>
        <div class="ws-stat-card"><span>Ubetalt antal</span><strong>${stats.unpaidCount || 0}</strong></div>
        <div class="ws-stat-card"><span>Firma konto</span><strong>${formatMoney(company.balance || 0)}</strong></div>
      </div>
      ${pendingOrdersBlock}
      ${manualInvoiceBlock}
      <div class="ws-table-wrap">
        <table class="ws-table">
          <thead><tr><th>#</th><th>Tidspunkt</th><th>Kunde</th><th>Beskrivelse</th><th>Beløb</th><th>Status</th></tr></thead>
          <tbody>
            ${filtered.length ? filtered.map((inv) => `
              <tr class="ws-click-row" data-ws-open-invoice="${inv.id}">
                <td>${escapeHtml(inv.invoiceNumber || '')}</td>
                <td>${escapeHtml(inv.createdAtLabel || '')}</td>
                <td>${escapeHtml(inv.customerName || '')}</td>
                <td>${escapeHtml(inv.description || '')}</td>
                <td>${formatMoney(inv.total)}</td>
                <td><span class="ws-badge ${wsStatusClass(inv.status)}">${inv.status === 'paid' ? 'Betalt' : 'Ubetalt'}</span></td>
              </tr>
            `).join('') : '<tr><td colspan="6" class="ws-empty">Ingen fakturaer fundet.</td></tr>'}
          </tbody>
        </table>
      </div>
    </div>`;
  }
  if (tab === 'faerdige_ordre') {
    const orders = data.finishedOrders || [];
    const query = state.workshopSearch || '';
    const filtered = orders.filter((o) => wsMatchesSearch(`${o.orderNumber} ${o.vehiclePlate} ${o.customerName} ${o.invoiceNumber || ''}`, query));
    return `<div class="ws-page">
      <div class="ws-page-head">
        <h2>Færdige ordre</h2>
        <div class="ws-toolbar">
          <input type="text" class="ws-field" placeholder="Søg ordre, plade, faktura..." data-ws-search value="${escapeHtml(query)}" />
        </div>
      </div>
      <p class="ws-hint" style="margin-bottom:10px;">Biler der er fikset og hvor fakturaen er <b>betalt</b>. Arkiv over afsluttede jobs.</p>
      <div class="ws-stat-grid ws-stat-grid-3">
        <div class="ws-stat-card paid"><span>Færdige ordre</span><strong>${data.finishedCount || orders.length}</strong></div>
        <div class="ws-stat-card"><span>Firma konto</span><strong>${formatMoney((data.company || {}).balance || 0)}</strong></div>
      </div>
      <div class="ws-table-wrap">
        <table class="ws-table">
          <thead>
            <tr>
              <th>#</th><th>Plade</th><th>Kunde</th><th>Beløb</th><th>Faktura</th><th>Betalt</th><th></th>
            </tr>
          </thead>
          <tbody>
            ${filtered.length ? filtered.map((o) => `
              <tr class="ws-row-click" data-ws-order="${o.id}">
                <td>${escapeHtml(o.orderNumber || '')}</td>
                <td><b>${escapeHtml(o.vehiclePlate || '')}</b></td>
                <td>${escapeHtml(o.customerName || '')}</td>
                <td>${formatMoney(o.totalPrice)}</td>
                <td>${escapeHtml(o.invoiceNumber || '—')}</td>
                <td>${escapeHtml(o.paidAtLabel || '—')}</td>
                <td class="ws-actions">
                  <button type="button" class="ws-btn sm ghost" data-ws-view-order="${o.id}">Se ordre</button>
                  ${o.invoiceId ? `<button type="button" class="ws-btn sm ghost" data-ws-open-invoice="${o.invoiceId}">Se faktura</button>` : ''}
                </td>
              </tr>
            `).join('') : '<tr><td colspan="7" class="ws-empty">Ingen færdige ordre endnu. Boost bilen, send faktura, og vent på betaling.</td></tr>'}
          </tbody>
        </table>
      </div>
    </div>`;
  }
  if (tab === 'prisliste') {
    const rows = data.priceList || [];
    const grouped = {};
    rows.forEach((row) => {
      const key = `${row.categoryKey}:${row.groupKey}`;
      if (!grouped[key]) {
        grouped[key] = {
          categoryLabel: row.categoryLabel,
          groupLabel: row.groupLabel,
          groupKey: row.groupKey,
          categoryKey: row.categoryKey,
          lines: [],
        };
      }
      grouped[key].lines.push(row);
    });
    const sections = Object.values(grouped);
    return `<div class="ws-page ws-page-scroll">
      <div class="ws-page-head"><h2>Prisliste</h2></div>
      <p class="ws-hint">Priser bruges i kunde-tuner menuen for alle butikker dette firma ejer.</p>
      ${!perms.prices ? '<div class="ws-empty-block">Du har ikke adgang til at redigere priser.</div>' : ''}
      ${sections.length ? sections.map((section) => `
        <div class="ws-card">
          <h3>${escapeHtml(section.categoryLabel)} · ${escapeHtml(section.groupLabel)}</h3>
          ${section.lines.map((line) => `
            <div class="ws-price-row">
              <div>
                <strong>${escapeHtml(line.itemLabel)}</strong>
                <span>${line.isOpenPrice ? 'Åbningspris' : 'Pris per valg'}</span>
              </div>
              <input type="number" class="ws-field sm" min="0" step="1"
                value="${Number(line.price || 0)}"
                data-ws-price-cat="${escapeHtml(line.categoryKey)}"
                data-ws-price-group="${escapeHtml(line.groupKey)}"
                data-ws-price-item="${escapeHtml(line.itemKey)}"
                ${perms.prices ? '' : 'disabled'} />
              ${perms.prices ? `<button type="button" class="ws-btn sm" data-ws-save-price="${escapeHtml(line.categoryKey)}:${escapeHtml(line.groupKey)}:${escapeHtml(line.itemKey)}">Gem</button>` : ''}
            </div>
          `).join('')}
        </div>
      `).join('') : '<div class="ws-empty-block">Ingen priser fundet.</div>'}
    </div>`;
  }
  if (tab === 'ansatte') {
    const members = data.members || [];
    const roles = data.roles || [];
    return `<div class="ws-page ws-page-scroll">
      <div class="ws-page-head"><h2>Ansatte</h2></div>
      ${perms.members ? `<div class="ws-card">
        <h3>Inviter medarbejder</h3>
        <div class="ws-toolbar">
          <input type="number" class="ws-field" id="ws-invite-id" min="1" placeholder="Spiller ID" />
          <button type="button" class="ws-btn" id="ws-invite-btn">Inviter</button>
        </div>
      </div>` : ''}
      <div class="ws-table-wrap">
        <table class="ws-table">
          <thead><tr><th>Navn</th><th>Rolle</th><th></th></tr></thead>
          <tbody>
            ${members.length ? members.map((m) => `
              <tr>
                <td><b>${escapeHtml(m.name)}</b></td>
                <td>${perms.members ? `<select class="ws-field sm" data-ws-member-role="${m.id}">
                  ${roles.map((r) => `<option value="${r.id}"${Number(m.roleId) === Number(r.id) ? ' selected' : ''}>${escapeHtml(r.name)}</option>`).join('')}
                </select>` : escapeHtml(m.roleName || '')}</td>
                <td class="ws-actions">${perms.members ? `<button type="button" class="ws-btn sm danger" data-ws-kick="${m.id}">Fjern</button>` : ''}</td>
              </tr>
            `).join('') : '<tr><td colspan="3" class="ws-empty">Ingen medarbejdere.</td></tr>'}
          </tbody>
        </table>
      </div>
    </div>`;
  }
  return '';
}

function renderWorkshopInvoiceModal() {
  const inv = state.workshopInvoiceDetail;
  if (!inv) return '';
  const paid = inv.status === 'paid';
  const items = Array.isArray(inv.items) && inv.items.length ? inv.items : null;
  const itemRows = items
    ? items.map((item) => `
        <tr>
          <td>${escapeHtml(item.label || item.description || 'Ydelse')}${item.lineType === 'unlock' ? ' <small>(åbning)</small>' : ''}</td>
          <td>${formatMoneyDec(item.price)}</td>
        </tr>
      `).join('')
    : `
        <tr>
          <td>${escapeHtml(inv.description || 'Værkstedsydelse')}</td>
          <td>${formatMoneyDec(inv.total)}</td>
        </tr>
      `;
  return `<div class="cd-invoice-modal-backdrop" data-ws-close-invoice>
    <div class="cd-invoice-paper" data-stop-close>
      <div class="cd-paper-head">
        <div>
          <h2>${escapeHtml(inv.companyName || 'Værksted')}</h2>
          <p>CVR: ${escapeHtml(inv.companyCvr || '12345678')}</p>
        </div>
        <div class="cd-paper-meta">
          <strong>FAKTURA</strong>
          <span>Nr. ${escapeHtml(inv.invoiceNumber || '')}</span>
          <span>${escapeHtml(inv.createdAtLabel || '')}</span>
        </div>
      </div>
      <div class="cd-paper-buyer">
        <h4>Kunde</h4>
        <p>${escapeHtml(inv.customerName || '')}</p>
      </div>
      <table class="cd-paper-table">
        <thead><tr><th>Bestilt / ydelse</th><th>Beløb</th></tr></thead>
        <tbody>${itemRows}</tbody>
      </table>
      <div class="cd-paper-total">
        <span>Subtotal ekskl. moms</span>
        <strong>${formatMoneyDec(inv.subtotal)}</strong>
      </div>
      <div class="cd-paper-total">
        <span>Moms ${inv.vatRate || 25}%</span>
        <strong>${formatMoneyDec(inv.vatAmount)}</strong>
      </div>
      <div class="cd-paper-total">
        <span>Total inkl. moms</span>
        <strong>${formatMoneyDec(inv.total)}</strong>
      </div>
      <div class="cd-paper-status ${paid ? 'paid' : 'unpaid'}">${paid ? `Betalt${inv.paidAtLabel ? ' · ' + escapeHtml(inv.paidAtLabel) : ''}` : 'Ikke betalt — kunden betaler med /betalfaktura [nummer]'}</div>
      <p class="cd-paper-foot">Oprettet af: ${escapeHtml(inv.createdByName || '')}</p>
      <button type="button" class="btn secondary sm" data-ws-close-invoice>Luk</button>
    </div>
  </div>`;
}

function closeWorkshopOrderModal() {
  state.workshopOrderDetail = null;
  state.workshopOrderConfirm = null;
  if (state.view === 'app:workshop') render();
}

function renderWorkshopOrderModal() {
  const order = state.workshopOrderDetail;
  if (!order) return '';
  const perms = (state.workshopData && state.workshopData.permissions) || {};
  const canManage = order.canManageOrders === true || perms.orders === true;
  const canInvoice = order.canSendInvoices === true || perms.invoices === true;
  const status = normalizeWsStatus(order.status);
  const items = order.items || [];
  const confirm = state.workshopOrderConfirm;
  let actions = '';

  if (!canManage) {
    actions = '<p class="cd-hint">Du har ikke rettigheden <b>Håndter bestillinger</b>. Bed ejer/admin om at give din rolle adgang under Ansatte → Roller.</p>';
  } else if (confirm === 'delete') {
    const invoiceHint = order.hasInvoice
      ? (order.invoiceStatus === 'paid'
        ? '<p class="cd-hint warn">Fakturaen er betalt — bestillingen kan ikke slettes.</p>'
        : `<p class="cd-hint">Tilknyttet faktura <b>${escapeHtml(order.invoiceNumber || '')}</b> slettes også. Kunden skal ikke betale mere.</p>`)
      : '';
    actions = `
      ${invoiceHint}
      <p class="cd-hint">Slet bestillingen permanent? Dette kan ikke fortrydes.</p>
      <button type="button" class="btn sm danger" data-ws-delete-confirm ${order.invoiceStatus === 'paid' ? 'disabled' : ''}>Slet permanent</button>
      <button type="button" class="btn sm secondary" data-ws-cancel-confirm>Fortryd</button>`;
  } else if (confirm === 'cancel') {
    actions = `
      <p class="cd-hint">Annuller denne bestilling?</p>
      <button type="button" class="btn sm danger" data-ws-status-confirm="cancelled">Ja, annuller</button>
      <button type="button" class="btn sm secondary" data-ws-cancel-confirm>Fortryd</button>`;
  } else if (status === 'pending') {
    actions = `
      <button type="button" class="btn sm" data-ws-status="in_progress">Start arbejde</button>
      <button type="button" class="btn sm secondary" data-ws-status="cancelled">Annuller</button>
      <button type="button" class="btn sm danger" data-ws-delete>Slet</button>`;
  } else if (status === 'in_progress') {
    actions = `
      <p class="cd-hint">Bestillingen er i gang. Gå til bilen og brug <b>Øje → Boost bil</b> (eller [E] tæt på bilen) for at udføre tuning og gemme i garagen.${order.hasInvoice ? ' Faktura er sendt — boost skal stadig udføres.' : ''}</p>
      <button type="button" class="btn sm secondary" data-ws-status="pending">Stop arbejde</button>
      <button type="button" class="btn sm secondary" data-ws-status="cancelled">Annuller</button>
      <button type="button" class="btn sm danger" data-ws-delete>Slet</button>`;
  } else if (status === 'completed' && order.invoiceStatus === 'paid') {
    actions = `<p class="cd-hint">Færdig ordre — faktura er betalt${order.paidAtLabel ? ` · ${escapeHtml(order.paidAtLabel)}` : ''}.</p>`;
  } else if (status === 'completed') {
    actions = `
      <p class="cd-hint">Bestillingen er færdig og tuning er gemt.${order.invoiceStatus === 'unpaid' ? ' Send faktura eller vent på betaling.' : ''}</p>
      <button type="button" class="btn sm danger" data-ws-delete>Slet</button>`;
  } else if (status === 'cancelled') {
    actions = `
      <p class="cd-hint">Bestillingen er annulleret.</p>
      <button type="button" class="btn sm danger" data-ws-delete>Slet</button>`;
  } else {
    actions = `<p class="cd-hint">Status: <b>${escapeHtml(order.statusLabel || order.status || 'Ukendt')}</b></p>`;
  }

  return `<div class="cd-invoice-modal-backdrop" data-ws-close-order>
    <div class="cd-ledger-panel" data-stop-close>
      <div class="cd-ledger-head">
        <span class="cd-ledger-kicker">${escapeHtml(getWsOrderStatusLabel(order))}</span>
        <h3>${escapeHtml(order.orderNumber || '')}</h3>
        <p>${escapeHtml(order.customerName || '')} · ${escapeHtml(order.vehiclePlate || '')} · ${escapeHtml(order.vehicleLabel || '')}</p>
      </div>
      <div class="cd-ledger-grid">
        <div class="cd-ledger-stat"><span>Total</span><strong>${formatMoney(order.totalPrice)}</strong></div>
        <div class="cd-ledger-stat"><span>Oprettet</span><strong>${escapeHtml(order.createdAt || '')}</strong></div>
        ${order.shopLabel ? `<div class="cd-ledger-stat"><span>Butik</span><strong>${escapeHtml(order.shopLabel)}</strong></div>` : ''}
        ${order.assignedName ? `<div class="cd-ledger-stat"><span>Mekaniker</span><strong>${escapeHtml(order.assignedName)}</strong></div>` : ''}
      </div>
      <div class="cd-faktura-section">
        <div class="cd-section-head"><b>Bestilling</b><span>${items.length} linje${items.length === 1 ? '' : 'r'}</span></div>
        ${items.length ? items.map((item) => `
          <div class="cart-line ws-order-line${item.lineType === 'unlock' ? ' is-unlock' : ''}">
            <span>${escapeHtml(formatOrderItemLine(item))}</span>
            <span>${formatMoney(item.price)}</span>
          </div>
        `).join('') : '<p class="cd-hint">Ingen dele registreret på bestillingen.</p>'}
      </div>
      <div class="admin-actions-row" style="margin-top:14px;">
        ${actions}
        ${canInvoice && !order.hasInvoice && (status === 'in_progress' || status === 'completed') ? `<button type="button" class="btn sm secondary" data-ws-invoice>Send faktura (${formatMoney(order.totalPrice)})</button>` : ''}
        ${canInvoice && !order.hasInvoice && status === 'pending' ? '<p class="cd-hint">Start arbejde før du sender faktura.</p>' : ''}
        ${order.hasInvoice && status !== 'completed' ? '<p class="cd-hint warn">Faktura er sendt/betalt — boost bilen for at færdiggøre tuning.</p>' : ''}
        ${order.hasInvoice ? `<p class="cd-hint">Faktura <b>${escapeHtml(order.invoiceNumber || '')}</b> er ${order.invoiceStatus === 'paid' ? 'betalt' : 'sendt (ubetalt)'}.</p>` : ''}
        <button type="button" class="btn sm secondary" data-ws-close-order>Luk</button>
      </div>
    </div>
  </div>`;
}

function renderWorkshopApp() {
  const data = state.workshopData;
  const tab = state.workshopTab || 'oversigt';
  const tabMeta = WORKSHOP_TABS.find((t) => t.id === tab) || WORKSHOP_TABS[0];
  if (!data) {
    return `<div class="ws-shell ws-shell-loading"><div class="ws-empty-block">Indlæser arbejdstablet...</div></div>`;
  }
  if (data.error) {
    return `<div class="ws-shell ws-shell-loading">
      <div class="ws-empty-block">${escapeHtml(data.error)}</div>
      <button type="button" class="ws-btn" data-nav="home">Tilbage</button>
    </div>`;
  }
  const company = data.company || {};
  const member = data.member || {};
  return `<div class="ws-shell">
    ${renderWorkshopSidebar(tab, company, member)}
    <div class="ws-main">
      <header class="ws-topbar">
        <div class="ws-tabs">
          <span class="ws-tab active">${escapeHtml(tabMeta.label)}</span>
        </div>
        <div class="ws-user">
          <span>${escapeHtml(member.name || 'Medarbejder')}</span>
          <small>#${company.id || ''}</small>
        </div>
      </header>
      ${company.locked ? '<div class="ws-banner">UDE AF DRIFT — firmaet er låst af admin.</div>' : ''}
      <div class="ws-content">${renderWorkshopTabBody(data, tab)}</div>
    </div>
    ${renderWorkshopOrderModal()}
    ${renderWorkshopInvoiceModal()}
  </div>`;
}

function bindWorkshopEvents() {
  document.querySelectorAll('[data-ws-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.wsTab;
      if (!tab || tab === state.workshopTab) return;
      state.workshopTab = tab;
      state.workshopSearch = '';
      state.workshopInvoiceSearchResults = [];
      state.workshopOrderDetail = null;
      state.workshopOrderConfirm = null;
      post('workshopGetAppData', { tab });
    });
  });
  document.querySelectorAll('[data-ws-search]').forEach((input) => {
    input.addEventListener('input', () => {
      state.workshopSearch = input.value || '';
      render();
    });
  });
  document.querySelectorAll('[data-ws-order-filter]').forEach((sel) => {
    sel.addEventListener('change', () => {
      state.workshopOrderFilter = sel.value || 'alle';
      render();
    });
  });
  document.querySelectorAll('[data-ws-order], [data-ws-view-order]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      if (e.target.closest('[data-ws-quick-start], [data-ws-quick-stop], [data-ws-open-invoice]')) return;
      const orderId = Number(btn.dataset.wsOrder || btn.dataset.wsViewOrder);
      if (orderId) post('workshopGetOrderDetail', { orderId });
    });
  });
  document.querySelectorAll('[data-ws-quick-start]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      post('workshopUpdateOrderStatus', { orderId: Number(btn.dataset.wsQuickStart), status: 'in_progress' });
    });
  });
  document.querySelectorAll('[data-ws-quick-stop]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      post('workshopUpdateOrderStatus', { orderId: Number(btn.dataset.wsQuickStop), status: 'pending' });
    });
  });
  document.querySelectorAll('[data-ws-accept-call]').forEach((btn) => {
    btn.addEventListener('click', () => post('workshopAcceptCall', { callId: Number(btn.dataset.wsAcceptCall) }));
  });
  document.querySelectorAll('[data-ws-close-call]').forEach((btn) => {
    btn.addEventListener('click', () => post('workshopCloseCall', { callId: Number(btn.dataset.wsCloseCall) }));
  });
  document.querySelectorAll('[data-ws-waypoint-call]').forEach((btn) => {
    btn.addEventListener('click', () => post('workshopSetCallWaypoint', { callId: Number(btn.dataset.wsWaypointCall) }));
  });
  const inviteBtn = document.getElementById('ws-invite-btn');
  const inviteInput = document.getElementById('ws-invite-id');
  if (inviteBtn && inviteInput) {
    inviteBtn.addEventListener('click', () => {
      const targetId = Number(inviteInput.value);
      if (targetId) post('workshopEmployeeInvite', { targetId });
    });
  }
  document.querySelectorAll('[data-ws-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      post('workshopEmployeeSetRole', { memberId: Number(sel.dataset.wsMemberRole), roleId: Number(sel.value) });
    });
  });
  document.querySelectorAll('[data-ws-kick]').forEach((btn) => {
    btn.addEventListener('click', () => post('workshopEmployeeKick', { memberId: Number(btn.dataset.wsKick) }));
  });
  document.querySelectorAll('[data-ws-close-order]').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (el.classList.contains('cd-invoice-modal-backdrop') && e.target !== el) return;
      closeWorkshopOrderModal();
    });
  });
  document.querySelectorAll('[data-ws-status]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const order = state.workshopOrderDetail;
      if (!order) return;
      const nextStatus = btn.dataset.wsStatus;
      if (nextStatus === 'cancelled') {
        state.workshopOrderConfirm = 'cancel';
        render();
        return;
      }
      post('workshopUpdateOrderStatus', { orderId: order.id, status: nextStatus });
      closeWorkshopOrderModal();
    });
  });
  document.querySelectorAll('[data-ws-status-confirm]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const order = state.workshopOrderDetail;
      if (!order) return;
      post('workshopUpdateOrderStatus', { orderId: order.id, status: btn.dataset.wsStatusConfirm });
      closeWorkshopOrderModal();
    });
  });
  document.querySelectorAll('[data-ws-delete]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!state.workshopOrderDetail) return;
      state.workshopOrderConfirm = 'delete';
      render();
    });
  });
  document.querySelectorAll('[data-ws-delete-confirm]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const order = state.workshopOrderDetail;
      if (!order) return;
      post('workshopDeleteOrder', { orderId: order.id });
      closeWorkshopOrderModal();
    });
  });
  document.querySelectorAll('[data-ws-cancel-confirm]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.workshopOrderConfirm = null;
      render();
    });
  });
  document.querySelectorAll('[data-ws-invoice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const order = state.workshopOrderDetail;
      if (!order) return;
      post('workshopSendInvoice', { orderId: order.id, tab: state.workshopTab || 'bestillinger' });
      closeWorkshopOrderModal();
    });
  });
  document.querySelectorAll('[data-ws-send-order-invoice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('workshopSendInvoice', { orderId: Number(btn.dataset.wsSendOrderInvoice), tab: 'faktura' });
    });
  });
  document.querySelectorAll('[data-ws-open-invoice]').forEach((row) => {
    row.addEventListener('click', (e) => {
      e.stopPropagation();
      post('workshopGetInvoiceDetail', { invoiceId: Number(row.dataset.wsOpenInvoice) });
    });
  });
  document.querySelectorAll('[data-ws-close-invoice]').forEach((el) => {
    el.addEventListener('click', (e) => {
      if (el.classList.contains('cd-invoice-modal-backdrop') && e.target !== el) return;
      state.workshopInvoiceDetail = null;
      render();
    });
  });
  const invoiceSearchInput = document.querySelector('[data-ws-invoice-search]');
  if (invoiceSearchInput) {
    invoiceSearchInput.addEventListener('input', () => {
      const value = invoiceSearchInput.value || '';
      state.workshopInvoiceForm = {
        ...state.workshopInvoiceForm,
        customerName: value,
        customerIdentifier: '',
        orderId: null,
      };
      if (value.length >= 2) post('workshopSearchInvoiceCustomers', { query: value });
      else state.workshopInvoiceSearchResults = [];
    });
  }
  document.querySelectorAll('[data-ws-pick-customer]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const idx = Number(btn.dataset.wsPickCustomer);
      const customer = (state.workshopInvoiceSearchResults || [])[idx];
      if (!customer) return;
      state.workshopInvoiceForm = {
        ...state.workshopInvoiceForm,
        customerName: customer.name || '',
        customerIdentifier: customer.identifier || '',
      };
      state.workshopInvoiceSearchResults = [];
      render();
    });
  });
  const invoiceDescInput = document.querySelector('[data-ws-invoice-desc]');
  if (invoiceDescInput) {
    invoiceDescInput.addEventListener('input', () => {
      state.workshopInvoiceForm = { ...state.workshopInvoiceForm, description: invoiceDescInput.value || '' };
    });
  }
  const invoiceAmountInput = document.querySelector('[data-ws-invoice-amount]');
  if (invoiceAmountInput) {
    invoiceAmountInput.addEventListener('input', () => {
      state.workshopInvoiceForm = { ...state.workshopInvoiceForm, amount: invoiceAmountInput.value || '' };
    });
  }
  document.querySelectorAll('[data-ws-send-manual-invoice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const form = state.workshopInvoiceForm || {};
      if (!form.customerName) return;
      post('workshopSendManualInvoice', {
        customerName: form.customerName,
        customerIdentifier: form.customerIdentifier || undefined,
        description: form.description || undefined,
        amount: form.orderId ? undefined : Number(form.amount || 0),
        orderId: form.orderId || undefined,
      });
      state.workshopInvoiceForm = { customerName: '', customerIdentifier: '', description: '', amount: '', orderId: null };
      state.workshopInvoiceSearchResults = [];
    });
  });
  document.querySelectorAll('[data-ws-save-price]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const parts = (btn.dataset.wsSavePrice || '').split(':');
      if (parts.length < 3) return;
      const [categoryKey, groupKey, itemKey] = parts;
      const input = document.querySelector(`[data-ws-price-cat="${categoryKey}"][data-ws-price-group="${groupKey}"][data-ws-price-item="${itemKey}"]`);
      const price = input ? Number(input.value) : 0;
      post('workshopSavePrice', { categoryKey, groupKey, itemKey, price });
    });
  });
}

function formatLedgerType(type) {
  const map = {
    import: 'Import',
    sale_cash: 'Salg kontant',
    sale_invoice: 'Salg faktura',
    adjustment: 'Justering'
  };
  return map[type] || type || 'Transaktion';
}

function renderCardealerTabBody(data, tab) {
  const dealer = data.dealership || {};
  const perms = data.permissions || {};
  if (tab === 'oversigt') {
    const stats = data.stats || {};
    return `<div class="cd-panel">
      <div class="cd-balance-card">
        <span class="cd-balance-label">Firma konto</span>
        <strong class="cd-balance-value">${formatMoney(dealer.balance || 0)}</strong>
      </div>
      <div class="admin-stats-grid">
        <div class="admin-stat-card"><span class="label">På lager</span><strong>${stats.stockCount || 0}</strong></div>
        <div class="admin-stat-card"><span class="label">Ubetalt</span><strong>${stats.unpaidCount || 0}</strong></div>
      </div>
    </div>`;
  }
  if (tab === 'importere') {
    const imports = data.imports || [];
    return `<div class="cd-panel cd-scroll">${imports.length ? imports.map((v) => `
      <div class="cd-vehicle-card">
        <div class="cd-vehicle-thumb" style="background-image:url('${escapeHtml(v.image || '')}')"></div>
        <div class="cd-vehicle-body">
          <div class="cd-vehicle-head">
            <h3>${escapeHtml(v.label)}</h3>
            <span class="cd-badge ${v.available ? 'open' : 'locked'}">${v.available ? 'Tilgængelig' : 'Fuld'}</span>
          </div>
          <div class="cd-vehicle-meta">
            <span>Producent: <strong>${escapeHtml(v.manufacturer || 'Ukendt')}</strong></span>
            <span>År: <strong>${v.year || '—'}</strong></span>
            <span>Købspris: <strong>${formatMoney(v.importPrice)}</strong></span>
            <span>På lager: <strong>${v.inStock || 0}/${v.maxStock || 0}</strong></span>
          </div>
          ${perms.import && v.available ? `<button type="button" class="cd-import-btn" data-cd-import="${v.assignmentId}">🛒 Import køretøj</button>` : ''}
        </div>
      </div>
    `).join('') : '<div class="empty-state">Ingen køretøjer tildelt dit firma endnu.<br><small>Admin skal slå flueben til under Køretøjer.</small></div>'}</div>`;
  }
  if (tab === 'lager') {
    const stock = data.stock || [];
    return `<div class="cd-panel cd-scroll">${stock.length ? stock.map((v) => `
      <div class="cd-vehicle-card cd-stock-card">
        <div class="cd-vehicle-thumb" style="background-image:url('${escapeHtml(v.image || '')}')"></div>
        <div class="cd-vehicle-body">
          <div class="cd-vehicle-head"><h3>${escapeHtml(v.label)}</h3><span class="cd-badge open">${escapeHtml(v.plate || '')}</span></div>
          <div class="cd-vehicle-meta">
            <span>Import: <strong>${formatMoney(v.importPrice)}</strong></span>
            <span>Min. salg: <strong>${formatMoney(v.listPrice)}</strong></span>
            <span>Importeret: <strong>${escapeHtml(v.importedAt || '')}</strong></span>
          </div>
          ${perms.sell ? `<div class="cd-sell-form">
            <div class="cd-sell-grid">
              <input type="text" class="field sm" placeholder="Køber navn *" data-cd-buyer-name="${v.id}" />
              <input type="text" class="field sm" placeholder="Fødselsdato" data-cd-buyer-dob="${v.id}" />
              <input type="text" class="field sm" placeholder="Telefon" data-cd-buyer-phone="${v.id}" />
              <input type="number" class="field sm" placeholder="Salgspris DKK" data-cd-sell-price="${v.id}" min="${v.listPrice || 0}" />
              <input type="number" class="field sm" placeholder="Køber ID (valgfri)" data-cd-sell-buyer="${v.id}" min="1" />
            </div>
            <div class="cd-pay-row">
              <label class="cd-pay-opt"><input type="radio" name="pay-${v.id}" value="invoice" checked data-cd-pay="${v.id}" /> Faktura (betales senere)</label>
              <label class="cd-pay-opt"><input type="radio" name="pay-${v.id}" value="cash" data-cd-pay="${v.id}" /> Kontant (kræver køber ID)</label>
            </div>
            <button type="button" class="btn sm cd-sell-btn" data-cd-sell="${v.id}">Gennemfør salg</button>
          </div>` : ''}
        </div>
      </div>
    `).join('') : '<div class="empty-state">Tomt lager — importér køretøjer under Importér.</div>'}</div>`;
  }
  if (tab === 'faktura') {
    const stats = data.stats || {};
    const invoices = data.salesInvoices || [];
    const ledger = data.ledger || [];
    return `<div class="cd-panel cd-scroll cd-faktura-page">
      <div class="cd-faktura-hero">
        <div class="cd-faktura-hero-copy">
          <span class="cd-faktura-kicker">Økonomi & salg</span>
          <h3>Faktura & transaktioner</h3>
          <p>Salgsfakturaer betales via telefon-app. Klik et kort for detaljer.</p>
        </div>
        <div class="cd-faktura-hero-stats">
          <div class="cd-stat-pill"><span>Firma konto</span><strong>${formatMoney(dealer.balance || 0)}</strong></div>
          <div class="cd-stat-pill warn"><span>Ubetalt</span><strong>${stats.unpaidCount || 0}</strong></div>
        </div>
      </div>
      <div class="cd-faktura-section">
        <div class="cd-section-head"><b>Salgsfakturaer</b><span>${invoices.length}</span></div>
        ${invoices.length ? `<div class="cd-faktura-grid">${invoices.map((inv) => `
          <button type="button" class="cd-mdt-card cd-faktura-card ${inv.status === 'paid' ? 'is-paid' : 'is-unpaid'}" data-cd-open-invoice="${inv.id}">
            <span class="cd-mdt-card-icon">📄</span>
            <span class="cd-mdt-card-body">
              <span class="cd-mdt-card-title"><b>${escapeHtml(inv.vehicleLabel)}</b><span>${escapeHtml(inv.plate || '')}</span></span>
              <span class="cd-mdt-card-meta"><span>${escapeHtml(inv.createdAtLabel || '')}</span><span>${escapeHtml(inv.invoiceNumber || '')}</span></span>
              <span class="cd-mdt-card-sub">${escapeHtml(inv.buyerName || 'Ukendt køber')}${inv.buyerPhone ? ' · ' + escapeHtml(inv.buyerPhone) : ''}</span>
            </span>
            <span class="cd-mdt-card-side">
              <strong>${formatMoney(inv.total)}</strong>
              <span class="cd-status-chip ${inv.status === 'paid' ? 'paid' : 'unpaid'}">${inv.status === 'paid' ? 'Betalt' : 'Ikke betalt'}</span>
            </span>
          </button>
        `).join('')}</div>` : '<div class="empty-state">Ingen salgsfakturaer endnu.</div>'}
      </div>
      <div class="cd-faktura-section">
        <div class="cd-section-head"><b>Firma transaktioner</b><span>${ledger.length}</span></div>
        ${ledger.length ? `<div class="cd-faktura-grid">${ledger.map((row) => `
          <button type="button" class="cd-mdt-card cd-ledger-card ${Number(row.amount) >= 0 ? 'is-plus' : 'is-minus'}" data-cd-ledger-id="${row.id}">
            <span class="cd-mdt-card-icon">${Number(row.amount) >= 0 ? '↗' : '↘'}</span>
            <span class="cd-mdt-card-body">
              <span class="cd-mdt-card-title"><b>${escapeHtml(row.description || 'Transaktion')}</b><span>${escapeHtml(formatLedgerType(row.type))}</span></span>
              <span class="cd-mdt-card-meta"><span>${escapeHtml(row.createdAt || '')}</span><span>${row.createdBy ? escapeHtml(row.createdBy) : 'System'}</span></span>
            </span>
            <span class="cd-mdt-card-side">
              <strong class="${Number(row.amount) >= 0 ? 'plus' : 'minus'}">${formatMoney(row.amount)}</strong>
              <span class="cd-status-chip neutral">Saldo ${formatMoney(row.balanceAfter || 0)}</span>
            </span>
          </button>
        `).join('')}</div>` : '<div class="empty-state">Ingen firma transaktioner endnu.</div>'}
      </div>
    </div>`;
  }
  return '';
}

function renderSalesInvoiceModal() {
  const inv = state.salesInvoiceDetail;
  if (!inv) return '';
  const paid = inv.status === 'paid';
  return `<div class="cd-invoice-modal-backdrop" data-cd-close-invoice>
    <div class="cd-invoice-paper" data-stop-close>
      <div class="cd-paper-head">
        <div>
          <h2>${escapeHtml(inv.dealershipName || 'Bilforhandler')}</h2>
          <p>CVR: ${escapeHtml(inv.companyCvr || '12345678')}</p>
        </div>
        <div class="cd-paper-meta">
          <strong>FAKTURA</strong>
          <span>Nr. ${escapeHtml(inv.invoiceNumber || '')}</span>
          <span>Trans. ${escapeHtml(inv.transactionNumber || '')}</span>
          <span>${escapeHtml(inv.createdAtLabel || '')}</span>
        </div>
      </div>
      <div class="cd-paper-buyer">
        <h4>Køber</h4>
        <p>${escapeHtml(inv.buyerName || '')}</p>
        ${inv.buyerDob ? `<p>Fødselsdato: ${escapeHtml(inv.buyerDob)}</p>` : ''}
        ${inv.buyerPhone ? `<p>Telefon: ${escapeHtml(inv.buyerPhone)}</p>` : ''}
      </div>
      <table class="cd-paper-table">
        <thead><tr><th>Beskrivelse</th><th>Nummerplade</th><th>Beløb ekskl. moms</th><th>Moms ${inv.vatRate || 25}%</th><th>Total</th></tr></thead>
        <tbody>
          <tr>
            <td>${escapeHtml(inv.vehicleLabel || 'Køretøj')}</td>
            <td>${escapeHtml(inv.plate || '')}</td>
            <td>${formatMoneyDec(inv.subtotal)}</td>
            <td>${formatMoneyDec(inv.vatAmount)}</td>
            <td>${formatMoneyDec(inv.total)}</td>
          </tr>
        </tbody>
      </table>
      <div class="cd-paper-total">
        <span>Total inkl. moms</span>
        <strong>${formatMoneyDec(inv.total)}</strong>
      </div>
      <div class="cd-paper-status ${paid ? 'paid' : 'unpaid'}">${paid ? 'Betalt' : 'Ikke betalt — betales via Faktura-app (kommer)'}</div>
      <p class="cd-paper-foot">Sælger: ${escapeHtml(inv.soldByName || '')} · Betaling: ${inv.paymentMethod === 'cash' ? 'Kontant' : 'Faktura'}</p>
      <button type="button" class="btn secondary sm" data-cd-close-invoice>Luk</button>
    </div>
  </div>`;
}

function renderLedgerModal() {
  const row = state.ledgerDetail;
  if (!row) return '';
  const positive = Number(row.amount) >= 0;
  return `<div class="cd-invoice-modal-backdrop" data-cd-close-ledger>
    <div class="cd-ledger-panel" data-stop-close>
      <div class="cd-ledger-head">
        <span class="cd-ledger-kicker">${escapeHtml(formatLedgerType(row.type))}</span>
        <h3>${escapeHtml(row.description || 'Transaktion')}</h3>
        <p>${escapeHtml(row.createdAt || '')}${row.createdBy ? ' · ' + escapeHtml(row.createdBy) : ''}</p>
      </div>
      <div class="cd-ledger-grid">
        <div class="cd-ledger-stat"><span>Beløb</span><strong class="${positive ? 'plus' : 'minus'}">${formatMoney(row.amount)}</strong></div>
        <div class="cd-ledger-stat"><span>Saldo efter</span><strong>${formatMoney(row.balanceAfter || 0)}</strong></div>
      </div>
      <button type="button" class="btn secondary sm" data-cd-close-ledger>Luk</button>
    </div>
  </div>`;
}

function renderGarageApp() {
  const data = state.garageData;
  if (!data) {
    return `<div class="cd-shell"><div class="empty-state" style="padding:24px;">Indlæser garage...</div></div>`;
  }

  const vehicles = data.vehicles || [];
  const rows = vehicles.length
    ? vehicles.map((v) => {
        const statusClass = v.statusCode === 'garage' ? 'gr-status-ok' : (v.statusCode === 'impound' ? 'gr-status-warn' : 'gr-status-out');
        return `<article class="cd-vehicle-card gr-vehicle-card">
          <div class="cd-vehicle-body">
            <div class="cd-vehicle-head">
              <h3>${escapeHtml(v.modelLabel || 'Køretøj')}</h3>
              <span class="gr-status-pill ${statusClass}">${escapeHtml(v.statusLabel || 'Ukendt')}</span>
            </div>
            <div class="cd-vehicle-meta">
              <span>Nummerplade <strong>${escapeHtml(v.plate || '—')}</strong></span>
              <span>Placering <strong>${escapeHtml(v.garageLabel || '—')}</strong></span>
            </div>
          </div>
        </article>`;
      }).join('')
    : '<div class="empty-state">Du har ingen køretøjer registreret.</div>';

  return `<div class="cd-shell gr-shell">
    <div class="cd-header">
      <button type="button" class="back-btn" data-nav="home">‹</button>
      <div class="cd-header-info">
        <h2>GARAGE</h2>
        <p>${vehicles.length} køretøj${vehicles.length === 1 ? '' : 'er'}</p>
      </div>
    </div>
    <div class="cd-content gr-content">${rows}</div>
  </div>`;
}

function renderCardealerApp() {
  const data = state.cardealerData;
  const tab = state.cardealerTab || 'oversigt';
  const tabMeta = CARDEALER_TABS.find((t) => t.id === tab) || CARDEALER_TABS[0];
  if (!data) {
    return `<div class="cd-shell"><div class="empty-state" style="padding:24px;">Indlæser bilforhandler...</div></div>`;
  }
  if (data.error) {
    return `<div class="cd-shell">
      <div class="cd-header">
        <button type="button" class="back-btn" data-nav="home">‹</button>
        <div class="cd-header-info"><h2>Bilforhandler</h2></div>
      </div>
      <div class="cd-panel"><div class="empty-state">${escapeHtml(data.error)}</div></div>
    </div>`;
  }
  const dealer = data.dealership || {};
  const member = data.member || {};
  return `<div class="cd-shell">
    <div class="cd-header">
      <button type="button" class="back-btn" data-nav="home">‹</button>
      <div class="cd-header-info">
        <h2>${escapeHtml(tabMeta.label.toUpperCase())}</h2>
        <p>${escapeHtml(dealer.name || '')} · ${escapeHtml(member.roleName || '')}</p>
      </div>
      <span class="cd-header-pill">${escapeHtml(tabMeta.label)}</span>
    </div>
    ${dealer.locked ? '<div class="admin-locked-banner"><strong>UDE AF DRIFT</strong> Forhandleren er låst.</div>' : ''}
    <div class="cd-content">${renderCardealerTabBody(data, tab)}</div>
    <nav class="cd-bottom-nav">
      ${CARDEALER_TABS.map((t) => `
        <button type="button" class="cd-nav-btn${tab === t.id ? ' active' : ''}" data-cd-tab="${t.id}">
          <svg viewBox="0 0 24 24" aria-hidden="true">${t.icon}</svg>
          <span>${t.label.toUpperCase()}</span>
        </button>
      `).join('')}
    </nav>
    ${renderSalesInvoiceModal()}
    ${renderLedgerModal()}
  </div>`;
}

function bindCardealerEvents() {
  document.querySelectorAll('[data-cd-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.cdTab;
      if (!tab || tab === state.cardealerTab) return;
      state.cardealerTab = tab;
      post('cardealerGetAppData', { tab });
    });
  });
  document.querySelectorAll('[data-cd-import]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('cardealerImportVehicle', { assignmentId: Number(btn.dataset.cdImport) });
    });
  });
  document.querySelectorAll('[data-cd-sell]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const stockId = Number(btn.dataset.cdSell);
      const nameEl = document.querySelector(`[data-cd-buyer-name="${stockId}"]`);
      const dobEl = document.querySelector(`[data-cd-buyer-dob="${stockId}"]`);
      const phoneEl = document.querySelector(`[data-cd-buyer-phone="${stockId}"]`);
      const priceEl = document.querySelector(`[data-cd-sell-price="${stockId}"]`);
      const buyerEl = document.querySelector(`[data-cd-sell-buyer="${stockId}"]`);
      const payEl = document.querySelector(`input[name="pay-${stockId}"]:checked`);
      post('cardealerSellVehicle', {
        stockId,
        buyerName: nameEl && nameEl.value,
        buyerDob: dobEl && dobEl.value,
        buyerPhone: phoneEl && phoneEl.value,
        salePrice: Number(priceEl && priceEl.value),
        buyerId: Number(buyerEl && buyerEl.value) || null,
        paymentMethod: (payEl && payEl.value) || 'invoice'
      });
    });
  });
  document.querySelectorAll('[data-cd-open-invoice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('cardealerGetSalesInvoice', { invoiceId: Number(btn.dataset.cdOpenInvoice) });
    });
  });
  document.querySelectorAll('[data-cd-ledger-id]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.cdLedgerId);
      const ledger = (state.cardealerData && state.cardealerData.ledger) || [];
      const row = ledger.find((item) => Number(item.id) === id);
      if (row) {
        state.ledgerDetail = row;
        render();
      }
    });
  });
  document.querySelectorAll('[data-cd-close-invoice]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.salesInvoiceDetail = null;
      render();
    });
  });
  document.querySelectorAll('[data-cd-close-ledger]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.ledgerDetail = null;
      render();
    });
  });
}

function bindAdminEvents() {
  const org = state.adminOrgDetail;
  const orgId = org && org.id;

  document.querySelectorAll('[data-admin-section]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const section = btn.dataset.adminSection;
      if (!section) return;
      state.adminSection = section;
      state.adminOrgId = null;
      state.adminOrgDetail = null;
      state.adminTab = 'oversigt';
      state.adminDealerId = null;
      state.adminDealerDetail = null;
      state.adminDealerTab = 'oversigt';
      state.adminWorkshopId = null;
      state.adminWorkshopDetail = null;
      state.adminWorkshopTab = 'oversigt';
      state.adminShowCatalog = false;
      if (section === 'gangs') post('adminListOrgs');
      if (section === 'cardealers') post('adminListDealerships');
      if (section === 'workshops') post('adminListWorkshops');
      render();
    });
  });

  document.querySelectorAll('[data-admin-hub-back]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminSection = 'hub';
      state.adminOrgId = null;
      state.adminOrgDetail = null;
      state.adminTab = 'oversigt';
      state.adminDealerId = null;
      state.adminDealerDetail = null;
      state.adminDealerTab = 'oversigt';
      state.adminWorkshopId = null;
      state.adminWorkshopDetail = null;
      state.adminWorkshopTab = 'oversigt';
      state.adminShowCatalog = false;
      render();
    });
  });

  document.querySelectorAll('[data-admin-select]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminSelect);
      if (!id) return;
      state.adminOrgId = id;
      state.adminOrgDetail = null;
      state.adminTab = 'oversigt';
      render();
      post('adminGetOrg', { orgId: id });
    });
  });

  document.querySelectorAll('[data-admin-back]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminOrgId = null;
      state.adminOrgDetail = null;
      state.adminTab = 'oversigt';
      post('adminListOrgs');
      render();
    });
  });

  document.querySelectorAll('[data-admin-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminTab = btn.dataset.adminTab || 'oversigt';
      render();
    });
  });

  document.querySelectorAll('[data-admin-save-org]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!orgId) return;
      const name = (document.getElementById('admin-org-name') || {}).value;
      const xp = (document.getElementById('admin-org-xp') || {}).value;
      const level = (document.getElementById('admin-org-level') || {}).value;
      const color = (document.getElementById('admin-org-color') || {}).value;
      post('adminUpdateOrg', {
        orgId,
        patch: { name: (name || '').trim(), xp: Number(xp), level: Number(level), color: (color || '').trim() }
      });
    });
  });

  document.querySelectorAll('[data-admin-lock]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminSetLocked', { orgId: Number(btn.dataset.adminLock), locked: btn.dataset.locked === '1' });
    });
  });

  document.querySelectorAll('[data-admin-close]').forEach((btn) => {
    btn.addEventListener('click', () => {
      showGangConfirmModal(
        'Luk bande',
        'Luk denne bande permanent? Al data slettes (medlemmer, territorier, beskeder, XP) og kan ikke genskabes.',
        () => {
          post('adminCloseOrg', { orgId: Number(btn.dataset.adminClose) });
          state.adminOrgId = null;
          state.adminOrgDetail = null;
          state.adminTab = 'oversigt';
          render();
          setTimeout(() => post('adminListOrgs'), 400);
        },
        'Luk bande'
      );
    });
  });

  document.querySelectorAll('[data-admin-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      if (!orgId) return;
      post('adminSetMemberRole', {
        orgId,
        memberId: Number(sel.dataset.adminMemberRole),
        roleId: Number(sel.value)
      });
    });
  });

  document.querySelectorAll('[data-admin-kick]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!orgId) return;
      showGangConfirmModal(
        'Fjern medlem',
        'Fjern dette medlem fra banden?',
        () => post('adminKickMember', { orgId, memberId: Number(btn.dataset.adminKick) }),
        'Fjern'
      );
    });
  });

  document.querySelectorAll('[data-admin-delete-zone]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!orgId) return;
      showGangConfirmModal(
        'Slet zone',
        'Slet denne zone permanent?',
        () => post('adminDeleteZone', { orgId, zoneId: Number(btn.dataset.adminDeleteZone) }),
        'Slet zone'
      );
    });
  });

  const dealer = state.adminDealerDetail;

  document.querySelectorAll('[data-admin-dealer-select]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminDealerSelect);
      if (!id) return;
      state.adminDealerId = id;
      state.adminDealerDetail = null;
      state.adminDealerTab = 'oversigt';
      state.adminDealerVehicles = [];
      render();
      post('adminGetDealership', { dealershipId: id });
    });
  });

  document.querySelectorAll('[data-admin-dealer-back]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminDealerId = null;
      state.adminDealerDetail = null;
      state.adminDealerTab = 'oversigt';
      post('adminListDealerships');
      render();
    });
  });

  document.querySelectorAll('[data-admin-dealer-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminDealerTab = btn.dataset.adminDealerTab || 'oversigt';
      if (state.adminDealerTab === 'koretojer' && state.adminDealerDetail) {
        post('adminGetDealershipVehicles', { dealershipId: state.adminDealerDetail.id });
      }
      render();
    });
  });

  document.querySelectorAll('[data-admin-create-dealer]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const name = (document.getElementById('admin-dealer-create-name') || {}).value;
      const ownerId = (document.getElementById('admin-dealer-create-owner') || {}).value;
      post('adminCreateDealership', { name: (name || '').trim(), ownerId: Number(ownerId) });
    });
  });

  document.querySelectorAll('[data-admin-open-catalog]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminShowCatalog = true;
      post('adminListCatalog');
      render();
    });
  });

  document.querySelectorAll('[data-admin-catalog-back]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminShowCatalog = false;
      post('adminListDealerships');
      render();
    });
  });

  document.querySelectorAll('[data-admin-add-catalog]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminAddCatalogItem', {
        model: (document.getElementById('admin-catalog-model') || {}).value,
        label: (document.getElementById('admin-catalog-label') || {}).value,
        manufacturer: (document.getElementById('admin-catalog-manufacturer') || {}).value,
        year: Number((document.getElementById('admin-catalog-year') || {}).value),
        importPrice: Number((document.getElementById('admin-catalog-import') || {}).value),
        listPrice: Number((document.getElementById('admin-catalog-list') || {}).value),
        supplierStock: Number((document.getElementById('admin-catalog-supplier') || {}).value),
        imageUrl: (document.getElementById('admin-catalog-image') || {}).value
      });
    });
  });

  document.querySelectorAll('[data-admin-remove-catalog]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminRemoveCatalogItem', { catalogId: Number(btn.dataset.adminRemoveCatalog) });
    });
  });

  document.querySelectorAll('[data-admin-save-dealer]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminSaveDealer);
      if (!id) return;
      const name = (document.getElementById('admin-dealer-name') || {}).value;
      const color = (document.getElementById('admin-dealer-color') || {}).value;
      post('adminUpdateDealership', {
        dealershipId: id,
        patch: { name: (name || '').trim(), color: (color || '').trim() }
      });
    });
  });

  document.querySelectorAll('[data-admin-set-dealer-owner]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminSetDealerOwner);
      const ownerId = Number((document.getElementById('admin-dealer-owner-id') || {}).value);
      if (!id || !ownerId) return;
      post('adminSetDealerOwner', { dealershipId: id, ownerId });
    });
  });

  document.querySelectorAll('[data-admin-dealer-lock]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminSetDealerLocked', {
        dealershipId: Number(btn.dataset.adminDealerLock),
        locked: btn.dataset.locked === '1'
      });
    });
  });

  document.querySelectorAll('[data-admin-close-dealer]').forEach((btn) => {
    btn.addEventListener('click', () => {
      showGangConfirmModal(
        'Luk bilforhandler',
        'Luk denne forhandler permanent? Al data slettes og kan ikke genskabes.',
        () => {
          post('adminCloseDealership', { dealershipId: Number(btn.dataset.adminCloseDealer) });
          state.adminDealerId = null;
          state.adminDealerDetail = null;
          state.adminDealerTab = 'oversigt';
          render();
          setTimeout(() => post('adminListDealerships'), 400);
        },
        'Luk forhandler'
      );
    });
  });

  document.querySelectorAll('[data-admin-dealer-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      post('adminSetDealerMemberRole', {
        dealershipId: Number(sel.dataset.dealershipId),
        memberId: Number(sel.dataset.adminDealerMemberRole),
        roleId: Number(sel.value)
      });
    });
  });

  document.querySelectorAll('[data-admin-kick-dealer-member]').forEach((btn) => {
    btn.addEventListener('click', () => {
      showGangConfirmModal(
        'Fjern medarbejder',
        'Fjern denne medarbejder fra forhandleren?',
        () => post('adminKickDealerMember', {
          dealershipId: Number(btn.dataset.dealershipId),
          memberId: Number(btn.dataset.adminKickDealerMember)
        }),
        'Fjern'
      );
    });
  });

  document.querySelectorAll('[data-admin-add-dealer-member]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetId = Number((document.getElementById('admin-dealer-add-member-id') || {}).value);
      if (!targetId) return;
      post('adminAddDealerMember', {
        dealershipId: Number(btn.dataset.adminAddDealerMember),
        targetId
      });
    });
  });

  document.querySelectorAll('[data-admin-set-dealer-balance]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const balance = Number((document.getElementById('admin-dealer-balance') || {}).value);
      post('adminSetDealershipBalance', { dealershipId: Number(btn.dataset.adminSetDealerBalance), balance });
    });
  });

  document.querySelectorAll('[data-admin-save-dealer-vehicle]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const catalogId = Number(btn.dataset.catalogId);
      const dealershipId = Number(btn.dataset.adminSaveDealerVehicle);
      const enabledEl = document.querySelector(`[data-dealer-vehicle-enabled="${catalogId}"]`);
      post('adminSetDealershipVehicle', {
        dealershipId,
        catalogId,
        patch: {
          enabled: !!(enabledEl && enabledEl.checked),
          importPrice: Number((document.querySelector(`[data-dealer-import="${catalogId}"]`) || {}).value),
          listPrice: Number((document.querySelector(`[data-dealer-list="${catalogId}"]`) || {}).value),
          maxStock: Number((document.querySelector(`[data-dealer-max="${catalogId}"]`) || {}).value)
        }
      });
    });
  });

  document.querySelectorAll('[data-admin-save-spawn]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminSaveSpawn);
      post('adminSaveDealerSpawn', {
        dealershipId: id,
        spawnX: Number((document.getElementById('admin-dealer-spawn-x') || {}).value),
        spawnY: Number((document.getElementById('admin-dealer-spawn-y') || {}).value),
        spawnZ: Number((document.getElementById('admin-dealer-spawn-z') || {}).value),
        spawnHeading: Number((document.getElementById('admin-dealer-spawn-h') || {}).value)
      });
    });
  });

  document.querySelectorAll('[data-admin-capture-spawn]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminCaptureDealerSpawn', { dealershipId: Number(btn.dataset.adminCaptureSpawn) });
    });
  });

  document.querySelectorAll('[data-admin-workshop-select]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const id = Number(btn.dataset.adminWorkshopSelect);
      if (!id) return;
      state.adminWorkshopId = id;
      state.adminWorkshopDetail = null;
      state.adminWorkshopTab = 'oversigt';
      render();
      post('adminGetWorkshop', { companyId: id });
    });
  });

  document.querySelectorAll('[data-admin-workshop-back]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminWorkshopId = null;
      state.adminWorkshopDetail = null;
      state.adminWorkshopTab = 'oversigt';
      post('adminListWorkshops');
      render();
    });
  });

  document.querySelectorAll('[data-admin-workshop-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminWorkshopTab = btn.dataset.adminWorkshopTab || 'oversigt';
      render();
    });
  });

  document.querySelectorAll('[data-admin-create-workshop]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const name = (document.getElementById('admin-workshop-name') || {}).value;
      const ownerId = Number((document.getElementById('admin-workshop-owner') || {}).value);
      const companyType = (document.getElementById('admin-workshop-type') || {}).value;
      const jobName = (document.getElementById('admin-workshop-job') || {}).value;
      const trimmedName = (name || '').trim();

      if (trimmedName.length < 3) {
        showTabletToast('Navn skal være mindst 3 tegn.', 'error');
        return;
      }
      if (!ownerId || ownerId < 1) {
        showTabletToast('Angiv et gyldigt ejer spiller-ID.', 'error');
        return;
      }

      const locations = getAdminShopLocations('create', ['company_new']);
      const loc = locations.company_new;
      if (!loc || (Math.abs(loc.x) < 0.01 && Math.abs(loc.y) < 0.01 && Math.abs(loc.z) < 0.01)) {
        showTabletToast('Sæt butik-position med "Brug min position" først.', 'error');
        return;
      }

      post('adminCreateWorkshop', {
        name: trimmedName,
        ownerId,
        companyType,
        jobName: (jobName || '').trim(),
        shopKeys: ['company_new'],
        shopLocations: locations,
        shopBlips: getAdminShopBlips('create', ['company_new'])
      });
    });
  });

  const wsCompany = state.adminWorkshopDetail;
  const wsCompanyId = wsCompany && wsCompany.id;

  document.querySelectorAll('[data-admin-save-workshop]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (!wsCompanyId) return;
      post('adminUpdateWorkshop', {
        companyId: wsCompanyId,
        patch: {
          name: ((document.getElementById('admin-workshop-edit-name') || {}).value || '').trim(),
          color: ((document.getElementById('admin-workshop-edit-color') || {}).value || '').trim(),
          companyType: (document.getElementById('admin-workshop-edit-type') || {}).value,
          jobName: ((document.getElementById('admin-workshop-edit-job') || {}).value || '').trim(),
          shopKeys: getWorkshopEditShopKeys(wsCompany),
          shopLocations: getAdminShopLocations('edit', getWorkshopEditShopKeys(wsCompany)),
          shopBlips: getAdminShopBlips('edit', getWorkshopEditShopKeys(wsCompany))
        }
      });
    });
  });

  document.querySelectorAll('[data-admin-workshop-lock]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminSetWorkshopLocked', {
        companyId: Number(btn.dataset.adminWorkshopLock),
        locked: btn.dataset.locked === '1'
      });
    });
  });

  document.querySelectorAll('[data-admin-close-workshop]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminCloseWorkshop', { companyId: Number(btn.dataset.adminCloseWorkshop) });
    });
  });

  document.querySelectorAll('[data-admin-workshop-invite]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const targetId = Number((document.getElementById('admin-workshop-invite-id') || {}).value);
      if (targetId) post('adminAddWorkshopMember', { companyId: Number(btn.dataset.adminWorkshopInvite), targetId });
    });
  });

  document.querySelectorAll('[data-admin-workshop-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      post('adminSetWorkshopMemberRole', {
        companyId: Number(sel.dataset.adminWorkshopMemberRole),
        memberId: Number(sel.dataset.memberId),
        roleId: Number(sel.value)
      });
    });
  });

  document.querySelectorAll('[data-admin-workshop-kick]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminKickWorkshopMember', {
        companyId: Number(btn.dataset.adminWorkshopKick),
        memberId: Number(btn.dataset.memberId)
      });
    });
  });

  document.querySelectorAll('[data-admin-workshop-delete-role]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminDeleteWorkshopRole', {
        companyId: Number(btn.dataset.adminWorkshopDeleteRole),
        roleId: Number(btn.dataset.roleId)
      });
    });
  });

function bindAdminShopBlipPickers(root) {
  const scope = root || document;
  scope.querySelectorAll('[data-admin-pick-blip]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const shopKey = btn.dataset.adminPickBlip;
      const prefix = btn.dataset.adminPickPrefix || 'edit';
      const spriteInput = document.getElementById(`admin-shop-${prefix}-blip-${shopKey}`);
      state.adminBlipPicker = {
        shopKey,
        prefix,
        currentSprite: Number(spriteInput && spriteInput.value) || 72,
        search: ''
      };
      render();
    });
  });
}

function refreshCreateShopLocationEditors() {
    const wrap = document.getElementById('admin-shop-locations-create-wrap');
    if (!wrap) return;
    const companyType = (document.getElementById('admin-workshop-type') || {}).value || 'bennys';
    const companyName = (document.getElementById('admin-workshop-name') || {}).value || '';
    state.adminWorkshopCreateType = companyType;
    state.adminWorkshopCreateName = companyName;
    wrap.innerHTML = renderAdminShopLocationEditors(
      'create',
      ['company_new'],
      getCreateWorkshopLocationCatalog(companyType, companyName),
      false,
      companyName
    );
    wrap.querySelectorAll('[data-admin-capture-shop]').forEach((captureBtn) => {
      captureBtn.addEventListener('click', () => {
        post('adminCaptureWorkshopShop', { shopKey: captureBtn.dataset.adminCaptureShop });
      });
    });
    bindAdminShopBlipPickers(wrap);
  }

  const workshopTypeSelect = document.getElementById('admin-workshop-type');
  if (workshopTypeSelect) {
    workshopTypeSelect.addEventListener('change', refreshCreateShopLocationEditors);
  }

  const workshopNameInput = document.getElementById('admin-workshop-name');
  if (workshopNameInput) {
    workshopNameInput.addEventListener('input', refreshCreateShopLocationEditors);
  }

  document.querySelectorAll('[data-admin-shop-create]').forEach((cb) => {
    cb.addEventListener('change', refreshCreateShopLocationEditors);
  });

  document.querySelectorAll('[data-admin-shop-edit]').forEach((cb) => {
    cb.addEventListener('change', () => render());
  });

  document.querySelectorAll('[data-admin-capture-shop]').forEach((btn) => {
    btn.addEventListener('click', () => {
      post('adminCaptureWorkshopShop', { shopKey: btn.dataset.adminCaptureShop });
    });
  });

  bindAdminShopBlipPickers();

  document.querySelectorAll('[data-admin-close-blip-picker]').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.adminBlipPicker = null;
      render();
    });
  });

  document.querySelectorAll('[data-admin-blip-pick]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const picker = state.adminBlipPicker;
      if (!picker) return;
      const sprite = Number(btn.dataset.adminBlipPick);
      const input = document.getElementById(`admin-shop-${picker.prefix}-blip-${picker.shopKey}`);
      if (input) input.value = sprite;
      state.adminBlipPicker = null;
      render();
    });
  });

  const blipSearch = document.querySelector('[data-admin-blip-search]');
  if (blipSearch) {
    blipSearch.addEventListener('input', () => {
      if (!state.adminBlipPicker) return;
      state.adminBlipPicker.search = blipSearch.value || '';
      render();
    });
  }

  refreshCreateShopLocationEditors();
}

function render() {
  if (!els.root) return;

  if (state.view === 'home') els.root.innerHTML = renderHome();
  else if (state.view === 'app:apps') els.root.innerHTML = renderStore();
  else if (state.view === 'app:gangs' || state.view === 'app:orga') els.root.innerHTML = renderBandeApp();
  else if (state.view === 'app:cardealer') els.root.innerHTML = renderCardealerApp();
  else if (state.view === 'app:workshop') els.root.innerHTML = renderWorkshopApp();
  else if (state.view === 'app:garage') els.root.innerHTML = renderGarageApp();
  else if (isAdminAppView(state.view)) els.root.innerHTML = renderAdminApp();

  els.root.classList.toggle('gang-screen', state.view === 'app:gangs' || state.view === 'app:orga' || state.view === 'app:cardealer' || state.view === 'app:workshop' || state.view === 'app:garage' || isAdminAppView(state.view));

  bindEvents();
  bindAppIconImages(els.root);
  if (isAdminAppView(state.view)) bindAdminEvents();
  if (state.view === 'app:cardealer') bindCardealerEvents();
  if (state.view === 'app:workshop') bindWorkshopEvents();
}

function bindEvents() {
  els.root.querySelectorAll('[data-nav]').forEach((btn) => {
    btn.addEventListener('click', () => setView(btn.dataset.nav));
  });

  els.root.querySelectorAll('[data-open-app]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const appId = btn.dataset.openApp;
      if (appId === 'apps') {
        setView('app:apps');
        return;
      }
      if (appId === 'gangs_admin' || appId === 'admin') {
        state.adminOrgId = null;
        state.adminOrgDetail = null;
        state.adminTab = 'oversigt';
        state.adminDealerId = null;
        state.adminDealerDetail = null;
        state.adminDealerTab = 'oversigt';
        state.adminShowCatalog = false;
        state.adminSection = 'gangs';
        setView('app:gangs_admin');
        post('adminListOrgs');
        return;
      }
      if (appId === 'cardealer') {
        state.cardealerData = null;
        state.cardealerTab = 'oversigt';
        setView('app:cardealer');
        post('cardealerGetAppData', { tab: 'oversigt' });
        return;
      }
      if (appId === 'garage') {
        state.garageData = null;
        setView('app:garage');
        post('garageGetAppData', {});
        return;
      }
      if (appId === 'workshop') {
        state.workshopData = null;
        state.workshopTab = 'oversigt';
        state.workshopOrderDetail = null;
        setView('app:workshop');
        post('workshopGetAppData', { tab: 'oversigt' });
        return;
      }
      if (appId === 'gangs' || appId === 'orga') {
        state.bandeTab = 'forside';
        refreshTabletData().finally(() => setView('app:gangs'));
        return;
      }
      setView(`app:${appId === 'orga' ? 'gangs' : appId}`);
    });
  });

  els.root.querySelectorAll('[data-install]').forEach((btn) => {
    btn.addEventListener('click', () => post('installApp', { appId: btn.dataset.install }));
  });

  const createBtn = document.getElementById('create-org-btn');
  const nameInput = document.getElementById('org-name-input');
  if (createBtn && nameInput) {
    createBtn.addEventListener('click', () => {
      const name = nameInput.value.trim();
      if (name) post('createOrg', { name });
    });
  }

  const inviteBtn = document.getElementById('invite-btn');
  const inviteInput = document.getElementById('invite-id');
  if (inviteBtn && inviteInput) {
    inviteBtn.addEventListener('click', () => {
      const targetId = Number(inviteInput.value);
      if (targetId) { post('inviteMember', { targetId }); inviteInput.value = ''; }
    });
  }

  els.root.querySelectorAll('[data-kick]').forEach((btn) => {
    btn.addEventListener('click', () => post('kickMember', { memberId: Number(btn.dataset.kick) }));
  });

  els.root.querySelectorAll('[data-member-role]').forEach((sel) => {
    sel.addEventListener('change', () => {
      post('setMemberRole', { memberId: Number(sel.dataset.memberRole), roleId: Number(sel.value) });
    });
  });

}

if (els.homeIndicator) {
  els.homeIndicator.addEventListener('click', () => setView('home'));
}

document.querySelectorAll('[data-action="close"]').forEach((btn) => {
  btn.addEventListener('click', () => post('close'));
});

function openTablet(data) {
  state.data = data || {};
  state.view = 'home';
  state.bandeTab = 'forside';
  state.adminRows = [];
  if (window.GangApp) GangApp.destroyMap();
  if (els.wrap) els.wrap.classList.remove('hidden');
  const uiVersion = (state.data && state.data.uiVersion) || 'unknown';
  if (uiVersion !== '1.2.8') {
    showTabletToast(`Tablet UI ${uiVersion} — genstart ya_tablet på serveren hvis du ser gammel UI.`, 'error');
  }
  setView('home');
}

function syncTablet(data) {
  const prevTab = state.bandeTab;
  if (data) {
    if (isGangLocked(data)) data.org = null;
    state.data = data;
  }
  if (isAdminAppView(state.view) && state.adminSection === 'gangs') post('adminListOrgs');
  if (isAdminAppView(state.view) && state.adminSection === 'cardealers' && !state.adminShowCatalog) post('adminListDealerships');
  if (isAdminAppView(state.view) && state.adminSection === 'workshops') post('adminListWorkshops');
  state.bandeTab = prevTab;
  if (window.GangApp) {
    GangApp.setTab(prevTab);
    if (state.view === 'app:gangs' || state.view === 'app:orga') GangApp.destroyMap();
  }
  if (window.GangSkillTree && GangSkillTree.isOpen()) {
    const locked = isGangLocked(state.data);
    if (locked) GangSkillTree.close();
    else GangSkillTree.sync(state.data);
  }
  render();
}

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'open') openTablet(msg.data);
  if (msg.action === 'sync') syncTablet(msg.data);
  if (msg.action === 'toast') showTabletToast(msg.message, msg.type);
  if (msg.action === 'newMessage' && (state.view === 'app:gangs' || state.view === 'app:orga')) {
    state.bandeTab = 'beskeder';
    render();
  }
  if (msg.action === 'adminOrgs') {
    state.adminRows = msg.rows || [];
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminOrgDetail') {
    state.adminOrgDetail = msg.detail || null;
    if (msg.detail && msg.detail.id) state.adminOrgId = msg.detail.id;
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminDealerships') {
    state.adminDealerRows = msg.rows || [];
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminDealershipDetail') {
    state.adminDealerDetail = msg.detail || null;
    if (msg.detail && msg.detail.id) state.adminDealerId = msg.detail.id;
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminCatalog') {
    state.adminCatalogRows = msg.rows || [];
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'cardealerDashboard') {
    state.cardealerData = msg.data || null;
    if (state.view === 'app:cardealer') render();
  }
  if (msg.action === 'cardealerAppData') {
    state.cardealerData = msg.data || null;
    if (msg.data && msg.data.tab) state.cardealerTab = msg.data.tab;
    if (state.view === 'app:cardealer') render();
  }
  if (msg.action === 'openApp' && msg.appId === 'workshop') {
    state.workshopData = null;
    state.workshopTab = 'oversigt';
    state.workshopOrderDetail = null;
    setView('app:workshop');
    post('workshopGetAppData', { tab: 'oversigt' });
  }
  if (msg.action === 'adminWorkshops') {
    state.adminWorkshopRows = normalizeAdminWorkshopRows(msg.rows);
    state.adminWorkshopShopCatalog = Array.isArray(msg.shopCatalog) ? msg.shopCatalog : [];
    state.adminBlipCatalog = Array.isArray(msg.blipCatalog) ? msg.blipCatalog : [];
    state.adminBlipColors = Array.isArray(msg.blipColors) ? msg.blipColors : [];
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminWorkshopDetail') {
    state.adminWorkshopDetail = msg.detail || null;
    if (msg.detail && msg.detail.id) state.adminWorkshopId = msg.detail.id;
    if (msg.detail && msg.detail.blipCatalog) state.adminBlipCatalog = msg.detail.blipCatalog;
    if (msg.detail && msg.detail.blipColors) state.adminBlipColors = msg.detail.blipColors;
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'adminShopCaptured' && msg.shopKey) {
    ['create', 'edit'].forEach((prefix) => {
      const x = document.getElementById(`admin-shop-${prefix}-x-${msg.shopKey}`);
      const y = document.getElementById(`admin-shop-${prefix}-y-${msg.shopKey}`);
      const z = document.getElementById(`admin-shop-${prefix}-z-${msg.shopKey}`);
      if (x) x.value = Number(msg.x || 0).toFixed(2);
      if (y) y.value = Number(msg.y || 0).toFixed(2);
      if (z) z.value = Number(msg.z || 0).toFixed(2);
    });
    showTabletToast('Position sat fra din nuværende placering.', 'success');
  }
  if (msg.action === 'workshopAppData') {
    state.workshopData = msg.data || null;
    if (msg.data && msg.data.tab) state.workshopTab = msg.data.tab;
    state.workshopOrderConfirm = null;
    const openOrderId = state.workshopOrderDetail && state.workshopOrderDetail.id;
    if (openOrderId && (state.workshopTab === 'bestillinger' || state.workshopTab === 'faerdige_ordre')) {
      post('workshopGetOrderDetail', { orderId: openOrderId });
    }
    if (state.view === 'app:workshop') render();
  }
  if (msg.action === 'workshopOrderDetail') {
    if (msg.data && msg.data.error) {
      showTabletToast(msg.data.error, 'error');
    } else {
      state.workshopOrderDetail = msg.data && msg.data.order ? {
        ...msg.data.order,
        canManageOrders: msg.data.canManageOrders === true,
        canSendInvoices: msg.data.canSendInvoices === true,
      } : null;
      if (state.view === 'app:workshop') render();
    }
  }
  if (msg.action === 'workshopInvoiceDetail') {
    if (msg.data && msg.data.error) {
      showTabletToast(msg.data.error, 'error');
    } else {
      state.workshopInvoiceDetail = msg.data && msg.data.invoice;
      if (state.view === 'app:workshop') render();
    }
  }
  if (msg.action === 'workshopInvoiceSearch') {
    state.workshopInvoiceSearchResults = (msg.data && msg.data.customers) || [];
    if (state.view === 'app:workshop') render();
  }
  if (msg.action === 'garageAppData') {
    state.garageData = msg.data || null;
    if (state.view === 'app:garage') render();
  }
  if (msg.action === 'cardealerSalesInvoice') {
    if (msg.data && msg.data.error) {
      showTabletToast(msg.data.error, 'error');
    } else {
      state.salesInvoiceDetail = msg.data && msg.data.invoice;
      if (state.view === 'app:cardealer') render();
    }
  }
  if (msg.action === 'adminDealershipVehicles') {
    state.adminDealerVehicles = (msg.data && msg.data.vehicles) || [];
    if (isAdminAppView(state.view)) render();
  }
  if (msg.action === 'close') {
    if (window.GangSkillTree) GangSkillTree.close();
    if (window.GangApp) GangApp.destroyMap();
    const toastHost = document.getElementById('tablet-toast-host');
    if (toastHost) toastHost.innerHTML = '';
    if (els.wrap) els.wrap.classList.add('hidden');
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') post('close');
});
