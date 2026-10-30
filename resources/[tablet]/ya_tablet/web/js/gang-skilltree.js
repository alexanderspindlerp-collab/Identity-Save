window.GangSkillTree = (function () {
  var state = {
    open: false,
    data: null,
    branches: {},
    skills: [],
    points: 0,
    selectedId: null,
    activeBranch: 'all',
    gangPost: null
  };

  var skillMap = new Map();
  var overlayEl = null;

  function esc(s) {
    return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function getEls() {
    if (!overlayEl) return {};
    return {
      overlay: overlayEl,
      points: overlayEl.querySelector('#gang-st-points'),
      tabs: overlayEl.querySelector('#gang-st-tabs'),
      branchHeaders: overlayEl.querySelector('#gang-st-branch-headers'),
      nodes: overlayEl.querySelector('#gang-st-nodes'),
      canvas: overlayEl.querySelector('#gang-st-canvas'),
      detailIcon: overlayEl.querySelector('#gang-st-detail-icon'),
      detailBranch: overlayEl.querySelector('#gang-st-detail-branch'),
      detailTitle: overlayEl.querySelector('#gang-st-detail-title'),
      detailDesc: overlayEl.querySelector('#gang-st-detail-desc'),
      detailCost: overlayEl.querySelector('#gang-st-detail-cost'),
      detailLevel: overlayEl.querySelector('#gang-st-detail-level'),
      detailRequires: overlayEl.querySelector('#gang-st-detail-requires'),
      detailNote: overlayEl.querySelector('#gang-st-detail-note'),
      btnUpgrade: overlayEl.querySelector('#gang-st-btn-upgrade'),
      btnClose: overlayEl.querySelector('#gang-st-btn-close'),
      earnHint: overlayEl.querySelector('#gang-st-earn-hint')
    };
  }

  function ensureOverlay() {
    if (overlayEl) return overlayEl;
    var host = document.querySelector('.tablet-screen');
    if (!host) host = document.body;

    overlayEl = document.createElement('div');
    overlayEl.id = 'gang-st-overlay';
    overlayEl.className = 'gang-st-overlay hidden';
    overlayEl.innerHTML =
      '<div class="gang-st-backdrop"></div>' +
      '<section class="gang-st-board">' +
        '<header class="gang-st-topbar">' +
          '<div class="gang-st-brand">' +
            '<span class="gang-st-brand-mark"></span>' +
            '<div><p class="gang-st-brand-kicker">Bande</p><h1>Bande Skill Board</h1></div>' +
          '</div>' +
          '<div class="gang-st-top-actions">' +
            '<div class="gang-st-earn-pill" id="gang-st-earn-hint">Brug bande XP på opgraderinger</div>' +
            '<div class="gang-st-points-pill"><span class="gang-st-points-label">Bande XP</span><strong id="gang-st-points">0</strong></div>' +
            '<button type="button" class="gang-st-btn-ghost" id="gang-st-btn-close">Luk</button>' +
          '</div>' +
        '</header>' +
        '<div class="gang-st-layout">' +
          '<div class="gang-st-main">' +
            '<nav class="gang-st-branch-tabs" id="gang-st-tabs"></nav>' +
            '<main class="gang-st-canvas-wrap">' +
              '<div id="gang-st-branch-headers" class="gang-st-branch-headers"></div>' +
              '<canvas id="gang-st-canvas"></canvas>' +
              '<div id="gang-st-nodes" class="gang-st-nodes-layer"></div>' +
            '</main>' +
          '</div>' +
          '<aside class="gang-st-detail-panel">' +
            '<div class="gang-st-panel-icon" id="gang-st-detail-icon">BG</div>' +
            '<p class="gang-st-panel-branch" id="gang-st-detail-branch">Vælg skill</p>' +
            '<h2 id="gang-st-detail-title">Klik på en node</h2>' +
            '<p class="gang-st-panel-desc" id="gang-st-detail-desc">Opgrader banden og territorier med jeres bande XP.</p>' +
            '<div class="gang-st-panel-section"><h3>Niveau</h3><p id="gang-st-detail-level" class="gang-st-panel-cost">—</p></div>' +
            '<div class="gang-st-panel-section"><h3>Næste opgradering</h3><p id="gang-st-detail-cost" class="gang-st-panel-cost">—</p></div>' +
            '<div class="gang-st-panel-section"><h3>Krav</h3><ul id="gang-st-detail-requires" class="gang-st-panel-list"></ul></div>' +
            '<p class="gang-st-panel-note" id="gang-st-detail-note"></p>' +
            '<div class="gang-st-panel-actions"><button type="button" class="gang-st-btn-primary gang-st-btn-wide" id="gang-st-btn-upgrade" disabled>Opgrader</button></div>' +
          '</aside>' +
        '</div>' +
      '</section>';

    host.appendChild(overlayEl);

    overlayEl.querySelector('#gang-st-btn-close').addEventListener('click', close);
    overlayEl.querySelector('#gang-st-btn-upgrade').addEventListener('click', function () {
      var skill = state.selectedId ? skillMap.get(state.selectedId) : null;
      if (!skill || !state.gangPost) return;
      var payload = { skillKey: skill.key };
      if (skill.zoneId) payload.zoneId = skill.zoneId;
      state.gangPost('unlockSkill', payload);
    });

    window.addEventListener('resize', function () {
      if (state.open) renderNodes();
    });

    return overlayEl;
  }

  function buildGraph(data) {
    var skillBoard = (data && data.skillBoard) || {};
    var branches = {
      gang: { id: 'gang', label: 'Bande', color: '#4dffc8', tag: 'BG', headerX: 0.5 }
    };
    var skills = [];

    (skillBoard.gang || []).forEach(function (node, index) {
      var count = (skillBoard.gang || []).length;
      var x = count <= 1 ? 0.5 : 0.28 + index * (0.44 / Math.max(1, count - 1));
      skills.push({
        id: 'gang:' + node.key,
        key: node.key,
        zoneId: null,
        title: node.label,
        desc: node.desc,
        cost: node.nextCost,
        level: node.level || 0,
        maxLevel: node.maxLevel || 1,
        branch: 'gang',
        x: x,
        y: 0.38,
        requireLevels: node.requires || {},
        canUpgrade: node.canUpgrade,
        locked: node.locked,
        isGang: true
      });
    });

    (skillBoard.zones || []).forEach(function (tree) {
      var branchId = 'zone_' + tree.zoneId;
      branches[branchId] = {
        id: branchId,
        label: tree.zoneName,
        color: '#a78bfa',
        tag: 'ZN',
        headerX: 0.5
      };
      (tree.skills || []).forEach(function (node, index) {
        var count = (tree.skills || []).length;
        var x = count <= 1 ? 0.5 : 0.28 + index * (0.44 / Math.max(1, count - 1));
        skills.push({
          id: branchId + ':' + node.key,
          key: node.key,
          zoneId: tree.zoneId,
          title: node.label,
          desc: node.desc,
          cost: node.nextCost,
          level: node.level || 0,
          maxLevel: node.maxLevel || 1,
          branch: branchId,
          x: x,
          y: 0.58,
          requireLevels: node.requires || {},
          canUpgrade: node.canUpgrade,
          locked: node.locked,
          isGang: false
        });
      });
    });

    return { branches: branches, skills: skills };
  }

  function getSkill(id) {
    return skillMap.get(id);
  }

  function parentSkillId(skill, reqKey) {
    if (skill.branch === 'gang') return 'gang:' + reqKey;
    return skill.branch + ':' + reqKey;
  }

  function requirementsMet(skill) {
    if (skill.locked) return false;
    var reqLevels = skill.requireLevels || {};
    for (var key in reqLevels) {
      if (!Object.prototype.hasOwnProperty.call(reqLevels, key)) continue;
      var parent = getSkill(parentSkillId(skill, key));
      if (!parent || (parent.level || 0) < (Number(reqLevels[key]) || 1)) return false;
    }
    return true;
  }

  function nodeStatus(skill) {
    if ((skill.level || 0) >= (skill.maxLevel || 1)) return 'unlocked';
    if (requirementsMet(skill) && skill.canUpgrade) return 'available';
    if ((skill.level || 0) > 0) return 'partial';
    return 'locked';
  }

  function branchColor(branchId) {
    return (state.branches[branchId] && state.branches[branchId].color) || '#4dffc8';
  }

  function canManageSkill(skill) {
    var org = state.data && state.data.org;
    if (!org || !skill) return false;
    if (skill.isGang) {
      return !!(org.myPermissions && (org.myPermissions.manage_org || org.myPermissions.manage_zones));
    }
    return !!(org.myPermissions && org.myPermissions.manage_zones);
  }

  function applyData(data) {
    state.data = data || {};
    var graph = buildGraph(state.data);
    state.branches = graph.branches;
    state.skills = graph.skills;
    state.points = (state.data.org && state.data.org.xp) || 0;
    skillMap.clear();
    state.skills.forEach(function (s) { skillMap.set(s.id, s); });
  }

  function renderTabs() {
    var els = getEls();
    if (!els.tabs) return;
    var items = [{ id: 'all', label: 'Alle grene', color: '#ffffff' }];
    Object.keys(state.branches).forEach(function (id) {
      var b = state.branches[id];
      items.push({ id: id, label: b.label, color: b.color });
    });
    els.tabs.innerHTML = items.map(function (item) {
      return '<button type="button" class="gang-st-branch-tab' + (state.activeBranch === item.id ? ' active' : '') + '" data-branch="' + esc(item.id) + '">' +
        '<span class="gang-st-dot" style="background:' + esc(item.color) + '"></span><span>' + esc(item.label) + '</span></button>';
    }).join('');
    els.tabs.querySelectorAll('.gang-st-branch-tab').forEach(function (btn) {
      btn.addEventListener('click', function () {
        state.activeBranch = btn.getAttribute('data-branch') || 'all';
        renderBoard();
      });
    });
  }

  function renderBranchHeaders() {
    var els = getEls();
    if (!els.branchHeaders) return;
    if (state.activeBranch !== 'all') {
      els.branchHeaders.innerHTML = '';
      return;
    }
    els.branchHeaders.innerHTML = Object.keys(state.branches).map(function (id) {
      var b = state.branches[id];
      return '<div class="gang-st-branch-header" style="left:' + ((b.headerX || 0.5) * 100) + '%">' +
        '<span class="gang-st-branch-header-dot" style="background:' + esc(b.color) + '"></span><span>' + esc(b.label) + '</span></div>';
    }).join('');
  }

  function drawLines(width, height, skills) {
    var els = getEls();
    if (!els.canvas) return;
    var ctx = els.canvas.getContext('2d');
    var dpr = window.devicePixelRatio || 1;
    els.canvas.width = width * dpr;
    els.canvas.height = height * dpr;
    els.canvas.style.width = width + 'px';
    els.canvas.style.height = height + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);

    skills.forEach(function (skill) {
      var reqLevels = skill.requireLevels || {};
      Object.keys(reqLevels).forEach(function (reqKey) {
        var parent = getSkill(parentSkillId(skill, reqKey));
        if (!parent) return;
        var x1 = parent.x * width;
        var y1 = parent.y * height;
        var x2 = skill.x * width;
        var y2 = skill.y * height;
        var parentOk = (parent.level || 0) >= (Number(reqLevels[reqKey]) || 1);
        var active = parentOk && (skill.level || 0) > 0;
        var pending = parentOk && requirementsMet(skill) && (skill.level || 0) < (skill.maxLevel || 1);

        ctx.beginPath();
        ctx.moveTo(x1, y1);
        var cx = (x1 + x2) / 2;
        ctx.bezierCurveTo(cx, y1, cx, y2, x2, y2);

        if (active) {
          ctx.strokeStyle = branchColor(skill.branch);
          ctx.lineWidth = 2.2;
          ctx.setLineDash([]);
          ctx.globalAlpha = 0.85;
        } else if (pending) {
          ctx.strokeStyle = 'rgba(255,255,255,0.35)';
          ctx.lineWidth = 1.6;
          ctx.setLineDash([6, 6]);
          ctx.globalAlpha = 0.7;
        } else {
          ctx.strokeStyle = 'rgba(255,255,255,0.08)';
          ctx.lineWidth = 1.2;
          ctx.setLineDash([]);
          ctx.globalAlpha = 1;
        }
        ctx.stroke();
        ctx.setLineDash([]);
        ctx.globalAlpha = 1;
      });
    });
  }

  function renderNodes() {
    var els = getEls();
    if (!els.nodes) return;
    els.nodes.innerHTML = '';
    var rect = els.nodes.getBoundingClientRect();
    if (!rect.width || !rect.height) {
      setTimeout(function () { if (state.open) renderNodes(); }, 80);
      return;
    }
    var skills = state.skills;
    if (!skills.length) {
      els.nodes.innerHTML = '<div class="gang-st-empty">Ingen skills konfigureret endnu.</div>';
      return;
    }

    skills.forEach(function (skill) {
      var branch = state.branches[skill.branch] || {};
      var status = nodeStatus(skill);
      var dimmed = state.activeBranch !== 'all' && skill.branch !== state.activeBranch;
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'gang-st-skill-node ' + status + (state.selectedId === skill.id ? ' selected' : '') + (dimmed ? ' dimmed' : '');
      btn.style.left = (skill.x * 100) + '%';
      btn.style.top = (skill.y * 100) + '%';
      var tag = (branch.tag || 'SK').slice(0, 2);
      var glow = (status === 'unlocked' || status === 'partial') ? 'box-shadow:0 0 22px ' + branchColor(skill.branch) + '55;border-color:' + branchColor(skill.branch) : '';
      btn.innerHTML =
        '<div class="gang-st-node-ring" style="' + glow + '">' +
          '<span class="gang-st-node-core">' + esc(tag) + '</span>' +
        '</div>' +
        '<span class="gang-st-skill-label">' + esc(skill.title) + ' · ' + esc((skill.level || 0) + '/' + (skill.maxLevel || 1)) + '</span>';
      btn.addEventListener('click', function () {
        state.selectedId = skill.id;
        renderNodes();
        renderDetail();
      });
      els.nodes.appendChild(btn);
    });

    drawLines(rect.width, rect.height, skills);
  }

  function renderDetail() {
    var els = getEls();
    var skill = state.selectedId ? getSkill(state.selectedId) : null;
    if (!skill) {
      els.detailTitle.textContent = 'Klik på en node';
      els.detailDesc.textContent = 'Opgrader banden og territorier med jeres bande XP.';
      els.detailLevel.textContent = '—';
      els.detailCost.textContent = '—';
      els.detailNote.textContent = '';
      els.btnUpgrade.disabled = true;
      els.btnUpgrade.textContent = 'Opgrader';
      if (els.detailRequires) els.detailRequires.innerHTML = '<li class="gang-st-muted">—</li>';
      return;
    }

    var branch = state.branches[skill.branch] || {};
    var status = nodeStatus(skill);
    var canAct = canManageSkill(skill);
    els.detailIcon.textContent = branch.tag || 'SK';
    els.detailIcon.style.background = (branch.color || '#4dffc8') + '22';
    els.detailIcon.style.color = branch.color || '#4dffc8';
    els.detailBranch.textContent = branch.label || skill.branch;
    els.detailTitle.textContent = skill.title;
    els.detailDesc.textContent = skill.desc || '';
    els.detailLevel.textContent = 'Niveau ' + (skill.level || 0) + ' / ' + (skill.maxLevel || 1);

    if (status === 'unlocked') {
      els.detailCost.textContent = 'Max niveau';
      els.detailNote.textContent = 'Denne skill er fuldt opgraderet.';
      els.btnUpgrade.disabled = true;
      els.btnUpgrade.textContent = 'Max niveau';
    } else if (!requirementsMet(skill)) {
      els.detailCost.textContent = skill.cost ? (skill.cost + ' bande XP') : '—';
      els.detailNote.textContent = 'Opfyld kravene først.';
      els.btnUpgrade.disabled = true;
      els.btnUpgrade.textContent = 'Låst';
    } else if (!canAct) {
      els.detailCost.textContent = skill.cost ? (skill.cost + ' bande XP') : '—';
      els.detailNote.textContent = 'Du har ikke tilladelse til at opgradere.';
      els.btnUpgrade.disabled = true;
      els.btnUpgrade.textContent = 'Ingen adgang';
    } else {
      var canAfford = state.points >= (skill.cost || 0);
      els.detailCost.textContent = (skill.cost || 0) + ' bande XP';
      els.detailNote.textContent = canAfford ? 'Klar til opgradering.' : 'Banden mangler XP.';
      els.btnUpgrade.disabled = !canAfford;
      els.btnUpgrade.textContent = 'Opgrader · ' + (skill.cost || 0) + ' XP';
    }

    if (els.detailRequires) {
      var reqLevels = skill.requireLevels || {};
      var keys = Object.keys(reqLevels);
      if (!keys.length) {
        els.detailRequires.innerHTML = '<li class="gang-st-muted">Ingen krav</li>';
      } else {
        els.detailRequires.innerHTML = keys.map(function (key) {
          var parent = getSkill(parentSkillId(skill, key));
          var ok = parent && (parent.level || 0) >= (Number(reqLevels[key]) || 1);
          var label = parent ? parent.title : key;
          return '<li><span class="' + (ok ? 'gang-st-ok' : 'gang-st-bad') + '">' + (ok ? '✓' : '○') + ' ' + esc(label) + ' nv. ' + reqLevels[key] + '</span></li>';
        }).join('');
      }
    }
  }

  function renderBoard() {
    var els = getEls();
    if (els.points) els.points.textContent = String(state.points);
    if (els.earnHint) {
      var sb = (state.data && state.data.skillBoard) || {};
      els.earnHint.textContent = (sb.zoneCount || 0) + ' / ' + (sb.maxZoneSlots || 1) + ' territorier · salg i rival-zoner giver XP';
    }
    renderTabs();
    renderBranchHeaders();
    renderNodes();
    renderDetail();
  }

  function scheduleRenderBoard() {
    requestAnimationFrame(function () {
      renderBoard();
      setTimeout(function () { renderNodes(); }, 60);
    });
  }

  function open(data, gangPostFn) {
    ensureOverlay();
    state.gangPost = gangPostFn;
    state.open = true;
    state.activeBranch = 'all';
    state.selectedId = null;
    applyData(data);
    overlayEl.classList.remove('hidden');
    scheduleRenderBoard();
  }

  function sync(data) {
    if (!state.open) return;
    var selected = state.selectedId;
    var branch = state.activeBranch;
    applyData(data);
    state.selectedId = selected;
    state.activeBranch = branch;
    scheduleRenderBoard();
  }

  function close() {
    if (!overlayEl) return;
    state.open = false;
    state.selectedId = null;
    overlayEl.classList.add('hidden');
  }

  return {
    open: open,
    close: close,
    sync: sync,
    isOpen: function () { return state.open; }
  };
})();
