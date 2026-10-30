const badgeApp = document.getElementById('badgeApp');
const badgePhoto = document.getElementById('badgePhoto');
const badgePhotoFallback = document.getElementById('badgePhotoFallback');
const badgePnr = document.getElementById('badgePnr');

window.addEventListener('message', (event) => {
  const msg = event.data || {};

  if (msg.action === 'showBadge') {
    const data = msg.data || {};
    badgePnr.textContent = data.pnumber || '0000';

    if (data.photo && data.photo !== '') {
      badgePhoto.src = data.photo;
      badgePhoto.classList.add('visible');
      badgePhotoFallback.classList.add('hidden');
    } else {
      badgePhoto.src = '';
      badgePhoto.classList.remove('visible');
      badgePhotoFallback.classList.remove('hidden');
    }

    badgeApp.classList.remove('hidden');
  }

  if (msg.action === 'hideBadge') {
    badgeApp.classList.add('hidden');
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !badgeApp.classList.contains('hidden')) {
    fetch(`https://${GetParentResourceName()}/closeBadge`, { method: 'POST', body: '{}' });
  }
});
