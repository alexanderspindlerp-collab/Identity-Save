const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_skilltree';

const DEFAULT_CATEGORY = 'criminal';

const state = {
  categories: [],
  branches: {},
  skills: [],
  points: 0,
  unlocked: [],
  pointRewards: {},
  activeCategory: DEFAULT_CATEGORY,
  selectedId: null,
  activeBranch: 'all'
};

const skillMap = new Map();

const els = {
  app: document.getElementById('app'),
  points: document.getElementById('points-value'),
  boardKicker: document.getElementById('board-kicker'),
  boardTitle: document.getElementById('board-title'),
  tabs: document.getElementById('branch-tabs'),
  branchHeaders: document.getElementById('branch-headers'),
  nodes: document.getElementById('nodes-layer'),
  canvas: document.getElementById('lines-canvas'),
  panelEarn: document.getElementById('panel-earn'),
  earnHint: document.getElementById('earn-hint'),
  detailIcon: document.getElementById('detail-icon'),
  detailBranch: document.getElementById('detail-branch'),
  detailTitle: document.getElementById('detail-title'),
  detailDesc: document.getElementById('detail-desc'),
  detailCost: document.getElementById('detail-cost'),
  detailRewards: document.getElementById('detail-rewards'),
  detailRequires: document.getElementById('detail-requires'),
  detailBlocks: document.getElementById('detail-blocks'),
  detailNote: document.getElementById('detail-note'),
  btnUnlock: document.getElementById('btn-unlock'),
  btnRefund: document.getElementById('btn-refund'),
  btnReset: document.getElementById('btn-reset-branch'),
  btnClose: document.getElementById('btn-close')
};

function post(name, data = {}) {
  fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function categorySkills() {
  if (!state.activeCategory) return [];
  return state.skills.filter((s) => s.category === state.activeCategory);
}

function categoryBranches() {
  const out = {};
  Object.entries(state.branches).forEach(([id, branch]) => {
    if (branch.category === state.activeCategory) out[id] = branch;
  });
  return out;
}

function hasUnlocked(id) {
  return state.unlocked.includes(id);
}

function getSkill(id) {
  return skillMap.get(id);
}

function titleFor(id) {
  const skill = getSkill(id);
  return skill ? skill.title : id;
}

function requirementsMet(skill) {
  return (skill.requires || []).every((id) => hasUnlocked(id));
}

function isBlocked(skill) {
  return (skill.blocks || []).some((id) => hasUnlocked(id));
}

function getDependents(skillId) {
  return categorySkills().filter((s) => (s.requires || []).includes(skillId) && hasUnlocked(s.id));
}

function nodeStatus(skill) {
  if (hasUnlocked(skill.id)) return 'unlocked';
  if (isBlocked(skill)) return 'blocked';
  if (requirementsMet(skill)) return 'available';
  return 'locked';
}

function branchColor(branchId) {
  const branches = categoryBranches();
  return (branches[branchId] && branches[branchId].color) || '#4dffc8';
}

function applyData(data) {
  state.categories = data.categories || [];
  state.branches = data.branches || {};
  state.skills = data.skills || [];
  state.points = data.points || 0;
  state.unlocked = data.unlocked || [];
  state.pointRewards = data.pointRewards || {};
  skillMap.clear();
  state.skills.forEach((s) => skillMap.set(s.id, s));
}

function openBoard(categoryId) {
  const id = categoryId || DEFAULT_CATEGORY;
  const cat = state.categories.find((c) => c.id === id) || { title: 'KRIMINEL' };

  state.activeCategory = id;
  state.selectedId = null;
  state.activeBranch = 'all';

  els.boardKicker.textContent = cat.title || 'KRIMINEL';
  els.boardTitle.textContent = 'Kriminel · Skilltree';

  requestAnimationFrame(() => renderBoard());
}

function renderTabs() {
  const branches = categoryBranches();
  const items = [
    { id: 'all', label: 'Alle grene', color: '#ffffff' },
    ...Object.entries(branches).map(([id, b]) => ({ id, label: b.label, color: b.color }))
  ];

  els.tabs.innerHTML = items.map((item) => `
    <button type="button" class="branch-tab${state.activeBranch === item.id ? ' active' : ''}" data-branch="${item.id}">
      <span class="dot" style="background:${item.color}"></span>
      <span>${item.label}</span>
    </button>
  `).join('');

  els.tabs.querySelectorAll('.branch-tab').forEach((btn) => {
    btn.addEventListener('click', () => {
      state.activeBranch = btn.dataset.branch;
      renderBoard();
    });
  });
}

function renderBranchHeaders() {
  const branches = categoryBranches();
  els.branchHeaders.innerHTML = Object.entries(branches).map(([id, b]) => `
    <div class="branch-header" style="left:${(b.headerX || 0.5) * 100}%">
      <span class="branch-header-dot" style="background:${b.color}"></span>
      <span>${b.label}</span>
    </div>
  `).join('');
}

function renderEarnPanel() {
  const labels = {
    street_sale: 'Gadesalg',
    phone_sale: 'Telefonsalg',
    house_robbery: 'Husrøveri',
    mission: 'Missioner'
  };
  const streetBonus = hasUnlocked('crim_gade_mester') ? 1 : 0;
  const streetTotal = (state.pointRewards?.street_sale || 1) + streetBonus;
  const rows = Object.entries(state.pointRewards || {}).map(([key, val]) => {
    const amount = key === 'street_sale' ? streetTotal : val;
    const extra = key === 'street_sale' && streetBonus > 0
      ? ' <span class="earn-upgrade">(Gade-mester)</span>'
      : key === 'street_sale'
        ? ' <span class="earn-muted">· opgrader i KRIMINEL</span>'
        : '';
    return `<div class="earn-row"><span>${labels[key] || key}${extra}</span><strong>+${amount} pt</strong></div>`;
  }).join('');
  els.panelEarn.innerHTML = rows || '<p class="muted">Ingen point-kilder konfigureret.</p>';
  if (els.earnHint) {
    els.earnHint.textContent = streetBonus > 0
      ? 'Gade-mester aktiv — dobbelt points ved salg'
      : 'Tjen points i KRIMINEL · Gade-mester giver +2 ved salg';
  }
}

function renderNodes() {
  els.nodes.innerHTML = '';
  const skills = categorySkills();
  const rect = els.nodes.getBoundingClientRect();
  const branches = categoryBranches();

  skills.forEach((skill) => {
    const branch = branches[skill.branch] || {};
    const status = nodeStatus(skill);
    const dimmed = state.activeBranch !== 'all' && skill.branch !== state.activeBranch;

    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `skill-node ${status}${state.selectedId === skill.id ? ' selected' : ''}${dimmed ? ' dimmed' : ''}`;
    btn.style.left = `${skill.x * 100}%`;
    btn.style.top = `${skill.y * 100}%`;

    const glow = status === 'unlocked' ? `box-shadow:0 0 22px ${branch.color}55; border-color:${branch.color}` : '';
    btn.innerHTML = `
      <div class="node-ring" style="${glow}">
        <span class="node-core">${branch.tag ? branch.tag.slice(0, 2) : 'SK'}</span>
      </div>
      <span class="skill-label">${skill.title}</span>
    `;

    btn.addEventListener('click', () => selectSkill(skill.id));
    els.nodes.appendChild(btn);
  });

  drawLines(rect.width, rect.height, skills);
}

function drawLines(width, height, skills) {
  const ctx = els.canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  els.canvas.width = width * dpr;
  els.canvas.height = height * dpr;
  els.canvas.style.width = `${width}px`;
  els.canvas.style.height = `${height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  ctx.clearRect(0, 0, width, height);

  skills.forEach((skill) => {
    (skill.requires || []).forEach((reqId) => {
      const parent = getSkill(reqId);
      if (!parent) return;

      const x1 = parent.x * width;
      const y1 = parent.y * height;
      const x2 = skill.x * width;
      const y2 = skill.y * height;
      const active = hasUnlocked(parent.id) && hasUnlocked(skill.id);
      const pending = hasUnlocked(parent.id) && requirementsMet(skill) && !hasUnlocked(skill.id) && !isBlocked(skill);

      ctx.beginPath();
      ctx.moveTo(x1, y1);
      const cx = (x1 + x2) / 2;
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

function listOrPlaceholder(target, items, mapper) {
  target.innerHTML = '';
  if (!items || !items.length) {
    const li = document.createElement('li');
    li.className = 'muted';
    li.textContent = '—';
    target.appendChild(li);
    return;
  }
  items.forEach((item) => {
    const li = document.createElement('li');
    li.innerHTML = mapper(item);
    target.appendChild(li);
  });
}

function selectSkill(id) {
  state.selectedId = id;
  renderNodes();
  renderDetail();
}

function renderDetail() {
  const skill = state.selectedId ? getSkill(state.selectedId) : null;
  const branches = categoryBranches();

  if (!skill) {
    els.detailTitle.textContent = 'Klik på en node';
    els.detailDesc.textContent = 'Se krav, belønning og lås op med dine points.';
    els.detailCost.textContent = '—';
    els.btnUnlock.disabled = true;
    els.btnRefund.disabled = true;
    els.btnReset.disabled = true;
    return;
  }

  const branch = branches[skill.branch] || {};
  const status = nodeStatus(skill);
  const dependents = getDependents(skill.id);

  els.detailIcon.textContent = branch.tag || 'SK';
  els.detailIcon.style.background = `${branch.color || '#4dffc8'}22`;
  els.detailIcon.style.color = branch.color || '#4dffc8';
  els.detailBranch.textContent = branch.label || skill.branch;
  els.detailTitle.textContent = skill.title;
  els.detailDesc.textContent = skill.desc || '';
  els.detailCost.textContent = `${skill.cost || 1} point${(skill.cost || 1) > 1 ? 's' : ''}`;

  listOrPlaceholder(els.detailRewards, skill.rewards || [], (r) => r);
  listOrPlaceholder(els.detailRequires, skill.requires || [], (id) => {
    const ok = hasUnlocked(id);
    return `<span class="${ok ? 'ok' : 'bad'}">${ok ? '✓' : '○'} ${titleFor(id)}</span>`;
  });
  listOrPlaceholder(els.detailBlocks, skill.blocks || [], (id) => `<span class="bad">${titleFor(id)}</span>`);

  if (status === 'unlocked') {
    els.detailNote.textContent = dependents.length
      ? 'Kan ikke fjernes — andre skills afhænger af denne.'
      : 'Du har låst denne skill op.';
    els.btnUnlock.disabled = true;
    els.btnUnlock.textContent = '✓ Låst op';
    els.btnRefund.disabled = dependents.length > 0;
    els.btnReset.disabled = false;
  } else if (status === 'blocked') {
    els.detailNote.textContent = 'Gensidigt udelukkende med en allerede valgt skill.';
    els.btnUnlock.disabled = true;
    els.btnUnlock.textContent = 'Blokeret';
    els.btnRefund.disabled = true;
    els.btnReset.disabled = false;
  } else if (status === 'available') {
    const canAfford = state.points >= (skill.cost || 1);
    els.detailNote.textContent = canAfford ? 'Klar til at låse op.' : 'Du mangler points.';
    els.btnUnlock.disabled = !canAfford;
    els.btnUnlock.textContent = `Lås op · ${skill.cost || 1} point`;
    els.btnRefund.disabled = true;
    els.btnReset.disabled = false;
  } else {
    els.detailNote.textContent = 'Lås forudsætninger op først.';
    els.btnUnlock.disabled = true;
    els.btnUnlock.textContent = 'Låst';
    els.btnRefund.disabled = true;
    els.btnReset.disabled = false;
  }
}

function renderBoard() {
  els.points.textContent = String(state.points);
  renderTabs();
  renderBranchHeaders();
  renderEarnPanel();
  renderNodes();
  renderDetail();
}

function openUI(data) {
  applyData(data);
  els.app.classList.remove('hidden');
  openBoard(data.startCategory || DEFAULT_CATEGORY);
}

function closeUI() {
  els.app.classList.add('hidden');
  state.selectedId = null;
}

els.btnClose.addEventListener('click', () => post('close'));
els.btnUnlock.addEventListener('click', () => state.selectedId && post('unlock', { id: state.selectedId }));
els.btnRefund.addEventListener('click', () => state.selectedId && post('refund', { id: state.selectedId }));
els.btnReset.addEventListener('click', () => {
  const skill = state.selectedId ? getSkill(state.selectedId) : null;
  if (skill) post('resetBranch', { branch: skill.branch });
});

document.addEventListener('keydown', (e) => {
  if (els.app.classList.contains('hidden')) return;
  if (e.key === 'Escape') post('close');
});

window.addEventListener('resize', () => {
  if (!els.app.classList.contains('hidden')) renderNodes();
});

window.addEventListener('message', (event) => {
  const msg = event.data || {};
  if (msg.action === 'open') openUI(msg.data || {});
  if (msg.action === 'sync') {
    applyData(msg.data || {});
    renderBoard();
  }
  if (msg.action === 'close') closeUI();
});
