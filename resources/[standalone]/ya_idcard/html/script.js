const app = document.getElementById('app');

function setText(id, value) {
  const el = document.getElementById(id);
  if (!el) return;
  el.innerHTML = value || '-';
}

function setCard(data) {
  setText('fullName', data.fullName);
  setText('dob', data.dob);
  setText('sex', data.sex);
  setText('address', String(data.address || '').replace(/, /g, '<br>'));
  setText('issuer', data.issuer);
  setText('issued', data.issued);
  setText('expires', data.expires);
  setText('cardId', data.cardId);

  const categories = Array.isArray(data.categories) ? data.categories.map(String).map(v => v.toUpperCase()) : [];
  ['A', 'B', 'C'].forEach((cat) => {
    const row = document.querySelector(`[data-cat="${cat}"]`);
    const date = document.getElementById(`date${cat}`);
    const has = categories.includes(cat);
    row.classList.toggle('disabled', !has);
    date.textContent = has ? (data.issued || '-') : '-';
  });
}

window.addEventListener('message', (event) => {
  const payload = event.data || {};

  if (payload.action === 'show') {
    setCard(payload.data || {});
    app.classList.remove('hidden');
  }

  if (payload.action === 'hide') {
    app.classList.add('hidden');
  }
});

document.addEventListener('keydown', (event) => {
  if (event.key.toLowerCase() === 'e') {
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', body: '{}' });
  }
});
