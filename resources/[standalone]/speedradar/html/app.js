const radar = document.getElementById('radar');
const scope = document.getElementById('scope');
const speed = document.getElementById('speed');
const distanceEl = document.getElementById('distance');
const plate = document.getElementById('plate');
const statusText = document.getElementById('status');
const zoom = document.getElementById('zoom');
const historyEl = document.getElementById('history');
const printout = document.getElementById('printout');
const printOfficer = document.getElementById('printOfficer');
const printCreated = document.getElementById('printCreated');
const printRows = document.getElementById('printRows');
const closePrint = document.getElementById('closePrint');

function resetTarget() {
    speed.textContent = '---';
    distanceEl.textContent = '---';
    plate.textContent = '---';
}

function formatDanishTime(timestamp, includeDate = false) {
    if (!timestamp) return 'DK tid';
    const date = new Date(timestamp * 1000);
    return new Intl.DateTimeFormat('da-DK', {
        timeZone: 'Europe/Copenhagen',
        day: includeDate ? '2-digit' : undefined,
        month: includeDate ? '2-digit' : undefined,
        year: includeDate ? 'numeric' : undefined,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
    }).format(date);
}

function renderHistory(items = []) {
    historyEl.innerHTML = '';
    if (!items.length) {
        historyEl.innerHTML = '<div class="empty">Ingen målinger endnu</div>';
        return;
    }

    items.forEach((item) => {
        const row = document.createElement('div');
        row.className = 'history-row';
        row.innerHTML = `<span>${formatDanishTime(item.timestamp)}</span><b>${item.plate || '---'}</b><span>${item.speed} km/t</span><span>${item.distance} m</span>`;
        historyEl.appendChild(row);
    });
}

function renderPrintout(metadata = {}) {
    if (metadata.printData) {
        metadata.officer = metadata.officer || metadata.printData.officer;
        metadata.created = metadata.created || metadata.printData.created;
        metadata.readings = metadata.readings || metadata.printData.readings;
    }

    printOfficer.textContent = metadata.officer || 'Ukendt';
    printCreated.textContent = formatDanishTime(metadata.created, true);
    printRows.innerHTML = '';

    const readings = Array.isArray(metadata.readings)
        ? metadata.readings
        : (Array.isArray(metadata.measurements) ? metadata.measurements : []);
    if (!readings.length) {
        printRows.innerHTML = '<tr><td colspan="5">Ingen målinger på udskriften.</td></tr>';
        return;
    }

    readings.forEach((item, index) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${index + 1}</td><td>${formatDanishTime(item.timestamp, true)}</td><td>${item.plate || 'UKENDT'}</td><td>${item.speed || 0} km/t</td><td>${item.distance || 0} m</td>`;
        printRows.appendChild(tr);
    });
}

async function closePrintout() {
    printout.classList.add('hidden');
    await fetch(`https://${GetParentResourceName()}/closePrintout`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({})
    });
}

closePrint.addEventListener('click', closePrintout);
document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !printout.classList.contains('hidden')) closePrintout();
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'show') {
        radar.classList.remove('hidden');
        statusText.textContent = 'STANDBY';
        renderHistory(data.history || []);
        return;
    }
    if (data.action === 'hide') {
        radar.classList.add('hidden');
        scope.classList.add('hidden');
        resetTarget();
        statusText.textContent = 'STANDBY';
        return;
    }
    if (data.action === 'scope') {
        scope.classList.toggle('hidden', !data.state);
        statusText.textContent = data.state ? 'SCANNER' : 'STANDBY';
        if (data.fov) zoom.textContent = data.fov;
        return;
    }
    if (data.action === 'zoom') {
        zoom.textContent = data.fov ?? '---';
        return;
    }
    if (data.action === 'history') {
        renderHistory(data.history || []);
        return;
    }
    if (data.action === 'printout') {
        printout.classList.toggle('hidden', !data.state);
        if (data.state) renderPrintout(data.metadata || {});
        return;
    }
    if (data.action === 'update') {
        if (data.hasTarget) {
            speed.textContent = data.speed;
            distanceEl.textContent = data.distance;
            plate.textContent = data.plate || 'UNKNOWN';
            statusText.textContent = 'TARGET LOCKED';
        } else {
            resetTarget();
            statusText.textContent = scope.classList.contains('hidden') ? 'STANDBY' : 'NO TARGET';
        }
    }
});
