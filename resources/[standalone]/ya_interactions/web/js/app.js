const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ya_interactions';

const ICONS = {
  skills: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><circle cx="12" cy="5" r="2.2" fill="currentColor" stroke="none"/><circle cx="6" cy="19" r="2.2" fill="currentColor" stroke="none"/><circle cx="18" cy="19" r="2.2" fill="currentColor" stroke="none"/><path d="M12 7v4M12 11 6 17M12 11l6 6"/></svg>',
  job: '<svg viewBox="0 0 24 24"><path d="M9 5a3 3 0 0 1 3-3h1a3 3 0 0 1 3 3v1h3a2 2 0 0 1 2 2v4H3V8a2 2 0 0 1 2-2h4V5Zm2 1h3V5a1 1 0 0 0-1-1h-1a1 1 0 0 0-1 1v1ZM3 14h18v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4Z"/></svg>',
  car: '<svg viewBox="0 0 24 24"><path d="M5 11l1.5-4.5A3 3 0 0 1 9.35 4h5.3a3 3 0 0 1 2.85 2.5L19 11h.5A1.5 1.5 0 0 1 21 12.5V17h-2v2h-3v-2H8v2H5v-2H3v-4.5A1.5 1.5 0 0 1 4.5 11H5Zm2.2 0h9.6l-1.1-3.5A1.2 1.2 0 0 0 14.55 6h-5.1A1.2 1.2 0 0 0 8.3 7.5L7.2 11ZM6.5 15.25a1.25 1.25 0 1 0 0-2.5 1.25 1.25 0 0 0 0 2.5Zm11 0a1.25 1.25 0 1 0 0-2.5 1.25 1.25 0 0 0 0 2.5Z"/></svg>',
  back: '<svg viewBox="0 0 24 24"><path d="M10 5 3 12l7 7v-4h5.5a4.5 4.5 0 0 0 0-9H13v3h2.5a1.5 1.5 0 0 1 0 3H10V5Z"/></svg>'
};

const els = {
  prompt: document.getElementById('interaction-prompt'),
  promptKey: document.querySelector('.prompt-key'),
  promptLabel: document.querySelector('.prompt-label'),
  menu: document.getElementById('dock-menu'),
  cards: document.getElementById('dock-cards'),
  row: document.getElementById('dock-row'),
  sub: document.getElementById('dock-sub')
};

let mainItems = [];
let subItems = [];
let cardItems = [];
let mainActiveIndex = 0;
let subActiveIndex = 0;
let menuVisible = false;
let panelMode = null;

function post(name, data = {}) {
  fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).catch(() => {});
}

function hidePanels() {
  panelMode = null;
  subItems = [];
  cardItems = [];
  els.sub.classList.add('hidden');
  els.sub.innerHTML = '';
  els.cards.classList.add('hidden');
  els.cards.innerHTML = '';
}

function renderMainRow() {
  els.row.innerHTML = mainItems.map((item, index) => {
    const icon = ICONS[item.icon] || ICONS.job;
    const expanded = panelMode && mainItems[mainActiveIndex]?.id === item.id;
    return `
      <button type="button" class="dock-item${index === mainActiveIndex ? ' active' : ''}${expanded ? ' expanded' : ''}${item.disabled ? ' disabled' : ''}"
        data-id="${item.id}" data-index="${index}">
        <span class="dock-icon">${icon}</span>
        <span class="dock-title">${item.title || item.label}</span>
        <span class="dock-desc">${item.desc || ''}</span>
      </button>`;
  }).join('');
}

function renderSubRow() {
  els.sub.innerHTML = subItems.map((item, index) => {
    const icon = ICONS[item.icon] || ICONS.job;
    return `
      <button type="button" class="dock-item sub-item${index === subActiveIndex ? ' active' : ''}${item.disabled ? ' disabled' : ''}"
        data-id="${item.id}" data-index="${index}">
        <span class="dock-icon">${icon}</span>
        <span class="dock-title">${item.title || item.label}</span>
      </button>`;
  }).join('');
}

function renderSkillCards() {
  els.cards.innerHTML = cardItems.map((cat) => `
    <button type="button" class="skill-card${cat.enabled === false ? ' disabled' : ''}" data-id="${cat.id}" ${cat.enabled === false ? 'disabled' : ''}>
      <span class="skill-card-accent" style="background:${cat.color || '#4dffc8'}"></span>
      <span class="skill-card-title">${cat.title}</span>
      <span class="skill-card-desc">${cat.desc || ''}</span>
      <span class="skill-card-action">${cat.enabled === false ? 'SNART' : 'Vælg'}</span>
    </button>
  `).join('');
}

function showMain(items, defaultIndex) {
  hidePanels();
  mainItems = items || [];
  mainActiveIndex = defaultIndex ?? 0;
  if (mainActiveIndex >= mainItems.length) mainActiveIndex = 0;
  renderMainRow();
}

function showJobSub(items) {
  panelMode = 'job';
  subItems = items || [];
  subActiveIndex = 0;
  cardItems = [];
  els.cards.classList.add('hidden');
  els.cards.innerHTML = '';
  els.sub.classList.remove('hidden');
  renderSubRow();
  renderMainRow();
}

function showSkillCards(categories) {
  panelMode = 'skills';
  cardItems = categories || [];
  subItems = [];
  els.sub.classList.add('hidden');
  els.sub.innerHTML = '';
  els.cards.classList.remove('hidden');
  renderSkillCards();
  renderMainRow();
}

function openMenu(data) {
  if (data.mode === 'sub') {
    showMain(data.items || mainItems, data.defaultIndex);
    showJobSub(data.options || []);
  } else {
    showMain(data.items || mainItems, data.defaultIndex);
  }
  menuVisible = true;
  els.menu.classList.add('visible');
  els.menu.setAttribute('aria-hidden', 'false');
}

function closeMenu() {
  menuVisible = false;
  hidePanels();
  els.menu.classList.remove('visible');
  els.menu.setAttribute('aria-hidden', 'true');
}

function handleMainClick(index) {
  mainActiveIndex = index;
  const item = mainItems[index];
  if (!item || item.disabled) return;

  renderMainRow();

  if (item.id === 'job') {
    post('selectOption', { id: 'job', context: 'expand' });
    return;
  }

  if (item.id === 'skills') {
    post('selectOption', { id: 'skills', context: 'expand' });
    return;
  }

  post('selectOption', { id: item.id, context: 'main' });
}

function handleSubClick(index) {
  subActiveIndex = index;
  const item = subItems[index];
  if (!item || item.disabled) return;
  renderSubRow();
  post('selectOption', { id: item.id, context: 'sub' });
}

els.row.addEventListener('click', (e) => {
  const btn = e.target.closest('.dock-item');
  if (!btn || btn.classList.contains('disabled')) return;
  handleMainClick(Number(btn.dataset.index));
});

els.sub.addEventListener('click', (e) => {
  const btn = e.target.closest('.sub-item');
  if (!btn || btn.classList.contains('disabled')) return;
  handleSubClick(Number(btn.dataset.index));
});

els.cards.addEventListener('click', (e) => {
  const btn = e.target.closest('.skill-card:not(.disabled)');
  if (!btn) return;
  post('selectSkillCategory', { id: btn.dataset.id });
});

function navigate(direction) {
  if (panelMode === 'job' && subItems.length) {
    subActiveIndex = direction === 'left'
      ? (subActiveIndex - 1 < 0 ? subItems.length - 1 : subActiveIndex - 1)
      : (subActiveIndex + 1 >= subItems.length ? 0 : subActiveIndex + 1);
    renderSubRow();
    return;
  }

  if (!mainItems.length) return;
  mainActiveIndex = direction === 'left'
    ? (mainActiveIndex - 1 < 0 ? mainItems.length - 1 : mainActiveIndex - 1)
    : (mainActiveIndex + 1 >= mainItems.length ? 0 : mainActiveIndex + 1);
  renderMainRow();
}

function selectActive() {
  if (panelMode === 'job' && subItems.length) {
    handleSubClick(subActiveIndex);
    return;
  }

  const item = mainItems[mainActiveIndex];
  if (!item) return;

  if (item.id === 'job' || item.id === 'skills') {
    handleMainClick(mainActiveIndex);
    return;
  }

  post('selectOption', { id: item.id, context: 'main' });
}

window.addEventListener('message', (event) => {
  const data = event.data || {};

  if (data.action === 'showPrompt') {
    if (els.promptKey) els.promptKey.textContent = data.key || 'F1';
    if (els.promptLabel) els.promptLabel.textContent = data.label || 'Garage';
    els.prompt.classList.add('visible');
  }

  if (data.action === 'hidePrompt') {
    els.prompt.classList.remove('visible');
  }

  if (data.action === 'showMenu') {
    openMenu({
      items: data.items,
      defaultIndex: data.defaultIndex,
      mode: data.mode,
      options: data.options
    });
  }

  if (data.action === 'showJobSub') {
    if (!menuVisible) return;
    mainActiveIndex = mainItems.findIndex((i) => i.id === 'job');
    if (mainActiveIndex < 0) mainActiveIndex = 0;
    showJobSub(data.options || []);
  }

  if (data.action === 'showSkillCards') {
    if (!menuVisible) return;
    mainActiveIndex = mainItems.findIndex((i) => i.id === 'skills');
    if (mainActiveIndex < 0) mainActiveIndex = 0;
    showSkillCards(data.categories || []);
  }

  if (data.action === 'hideMenu') {
    closeMenu();
  }

  if (data.action === 'navigate') {
    navigate(data.direction);
  }

  if (data.action === 'selectActive') {
    selectActive();
  }
});
