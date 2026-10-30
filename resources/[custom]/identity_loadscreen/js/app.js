const defaultTips = [
    'Respekter alle spillere — in-character og out-of-character.',
    'Brug /report hvis du har brug for hjælp fra staff.',
    'Hold dig in-character i offentlige områder.',
    'Din handling har konsekvenser i byen.',
    'Læs serverreglerne på Discord før du spiller.',
];

let initCount = 0;
let dataFileCount = 0;
let dataFileProgress = 0;
let mapLoadCount = 0;
let mapLoadProgress = 0;

const progressBar = document.getElementById('progress-bar');
const progressText = document.getElementById('progress-text');
const statusText = document.getElementById('status-text');
const tipText = document.getElementById('tip-text');

function setProgress(fraction) {
    const pct = Math.max(0, Math.min(100, Math.floor(fraction * 100)));
    progressBar.style.width = `${pct}%`;
    progressText.textContent = `${pct}%`;
}

function rotateTips(list) {
    const pool = Array.isArray(list) && list.length ? list : defaultTips;
    let index = 0;
    tipText.textContent = pool[0];
    setInterval(() => {
        index = (index + 1) % pool.length;
        tipText.textContent = pool[index];
    }, 6000);
}

function tryBackgroundMedia() {
    const video = document.getElementById('bg-video');
    const layerA = document.getElementById('bg-image-a');
    const sources = ['assets/background.webm', 'assets/background.mp4'];

    const tryVideo = (index) => {
        if (index >= sources.length) {
            tryImageBackground();
            return;
        }

        video.src = sources[index];
        video.classList.remove('hidden');
        video.onloadeddata = () => {
            layerA.style.opacity = '0.15';
        };
        video.onerror = () => tryVideo(index + 1);
    };

    const tryImageBackground = () => {
        const img = new Image();
        img.onload = () => {
            layerA.style.backgroundImage = `linear-gradient(to top, rgba(4, 8, 12, 0.92), rgba(4, 8, 12, 0.25)), url('assets/background.jpg')`;
            layerA.classList.remove('no-image');
        };
        img.onerror = () => {
            layerA.classList.add('no-image');
        };
        img.src = 'assets/background.jpg';
    };

    tryVideo(0);
}

function applyBranding(data) {
    if (data.serverName) document.getElementById('server-name').textContent = data.serverName;
    if (data.tagline) document.getElementById('tagline').textContent = data.tagline;
    if (data.subtitle) document.getElementById('subtitle').textContent = data.subtitle;
    if (data.tips) rotateTips(data.tips);
    else rotateTips(defaultTips);

    const links = document.getElementById('links');
    links.innerHTML = '';
    if (data.discord) {
        const a = document.createElement('a');
        a.href = data.discord;
        a.textContent = 'Discord';
        links.appendChild(a);
    }
    if (data.website) {
        const a = document.createElement('a');
        a.href = data.website;
        a.textContent = 'Website';
        links.appendChild(a);
    }
}

/* ── Terminal / boot-sekvens ── */
function startTerminal(lines) {
    const body = document.getElementById('terminal-body');
    if (!body || !lines?.length) return;

    let index = 0;
    const appendLine = () => {
        if (index >= lines.length) {
            setTimeout(() => {
                body.innerHTML = '';
                index = 0;
                appendLine();
            }, 4000);
            return;
        }

        const line = document.createElement('div');
        line.className = 'terminal-line';
        const raw = lines[index];
        if (raw.includes('OK')) {
            line.innerHTML = raw.replace('OK', '<span class="ok">OK</span>');
        } else if (raw.includes('pending')) {
            line.innerHTML = raw.replace('pending', '<span class="pending">pending</span>');
        } else {
            line.textContent = raw;
        }
        body.appendChild(line);

        while (body.children.length > 8) {
            body.removeChild(body.firstChild);
        }

        index += 1;
        setTimeout(appendLine, 420 + Math.random() * 280);
    };

    appendLine();
}

/* ── RP chips ── */
function renderRpChips() {
    const el = document.getElementById('rp-chips');
    if (!el) return;

    const chips = ['Serious RP', 'ESX Legacy', 'Konsekvens', 'Karakter'];
    chips.forEach((text) => {
        const chip = document.createElement('span');
        chip.className = 'rp-chip';
        chip.textContent = text;
        el.appendChild(chip);
    });
}

/* ── Historie-kort (roterende) ── */
function startLoreCarousel(moments) {
    const card = document.getElementById('lore-card');
    const yearEl = document.getElementById('lore-year');
    const titleEl = document.getElementById('lore-title');
    const textEl = document.getElementById('lore-text');
    if (!card || !moments?.length) return;

    let index = 0;

    const show = () => {
        const item = moments[index];
        card.classList.remove('visible');

        setTimeout(() => {
            yearEl.textContent = item.year || '';
            titleEl.textContent = item.title || '';
            textEl.textContent = item.text || '';
            card.classList.add('visible');
        }, 600);

        index = (index + 1) % moments.length;
    };

    show();
    setInterval(show, 7000);
}

/* ── Optagelses-kort (bodycam/CCTV) ── */
function buildRecordingCard(rec, hasImage) {
    const tone = rec.tone || 'teal';
    const card = document.createElement('div');
    card.className = `rec-card rec-card--${tone}`;

    const media = document.createElement('div');
    media.className = `rec-media rec-media--${tone}`;
    if (hasImage) {
        media.style.backgroundImage = `linear-gradient(to top, rgba(0,0,0,0.65), transparent 45%), url('${rec.image}')`;
    }

    const scan = document.createElement('div');
    scan.className = 'rec-scanlines';

    const overlay = document.createElement('div');
    overlay.className = 'rec-overlay';
    overlay.innerHTML = `
        <div class="rec-top">
            <span><span class="rec-dot"></span> <span class="rec-tag">${rec.tag || 'REC'}</span></span>
            <span class="rec-id">#${rec.id || '000'}</span>
        </div>
        <div class="rec-bottom">
            <div>${rec.location || ''} · ${rec.time || ''}</div>
            <div class="rec-caption">${rec.caption || ''}</div>
        </div>
    `;

    card.appendChild(media);
    card.appendChild(scan);
    card.appendChild(overlay);
    return card;
}

function startRecordings(recordings) {
    const container = document.getElementById('recordings');
    if (!container || !recordings?.length) return;

    const cards = new Array(recordings.length);
    let resolved = 0;

    const tryStart = () => {
        if (resolved < recordings.length) return;

        let slotIndex = 0;
        let visibleCard = null;

        const cycle = () => {
            const entry = cards[slotIndex % cards.length];
            slotIndex += 1;
            if (!entry) return;

            if (visibleCard) {
                visibleCard.classList.remove('visible');
                setTimeout(() => {
                    if (visibleCard?.parentNode) visibleCard.parentNode.removeChild(visibleCard);
                }, 600);
            }

            container.appendChild(entry.el);
            requestAnimationFrame(() => entry.el.classList.add('visible'));
            visibleCard = entry.el;
        };

        setTimeout(cycle, 1200);
        setInterval(cycle, 5500);
    };

    recordings.forEach((rec, i) => {
        if (!rec.image) {
            cards[i] = { el: buildRecordingCard(rec, false) };
            resolved += 1;
            tryStart();
            return;
        }

        const img = new Image();
        img.onload = () => {
            cards[i] = { el: buildRecordingCard(rec, true) };
            resolved += 1;
            tryStart();
        };
        img.onerror = () => {
            cards[i] = { el: buildRecordingCard(rec, false) };
            resolved += 1;
            tryStart();
        };
        img.src = rec.image;
    });
}

function initLiveLayer(data) {
    renderRpChips();
    startTerminal(data.terminalLines);
    startLoreCarousel(data.loreMoments);
    startRecordings(data.recordings);
}

async function loadConfig() {
    try {
        const res = await fetch('config.json');
        if (!res.ok) throw new Error('config missing');
        const data = await res.json();
        applyBranding(data);
        initLiveLayer(data);
    } catch {
        applyBranding({});
        initLiveLayer({
            terminalLines: [
                '> boot identity_core ... OK',
                '> load esx_legacy ... OK',
                '> spawn los_santos ... pending',
            ],
            loreMoments: [
                { year: 'RP', title: 'Serious Roleplay', text: 'Skab dit liv. Lev din historie.' },
            ],
            recordings: [
                { tag: 'BODYCAM', id: '042', location: 'Los Santos', time: '02:14', caption: 'Nattevagt', tone: 'teal' },
            ],
        });
    }
}

const handlers = {
    startInitFunctionOrder(data) {
        initCount = data.count || 1;
        statusText.textContent = 'Initialiserer';
    },

    initFunctionInvoking(data) {
        if (!initCount) return;
        setProgress((data.idx || 0) / initCount * 0.35);
        statusText.textContent = 'Loader scripts';
    },

    startDataFileEntries(data) {
        dataFileCount = data.count || 1;
        statusText.textContent = 'Indlæser filer';
    },

    performMapLoadFunction() {
        mapLoadProgress += 1;
        if (!mapLoadCount) mapLoadCount = 1;
        const base = 0.35 + (mapLoadProgress / mapLoadCount) * 0.45;
        setProgress(base);
        statusText.textContent = 'Loader kort';
    },

    onDataFileEntry(data) {
        dataFileProgress += 1;
        if (!dataFileCount) dataFileCount = 1;
        const base = 0.35 + (dataFileProgress / dataFileCount) * 0.25;
        setProgress(base);
    },

    loadProgress(data) {
        const fraction = typeof data.loadFraction === 'number' ? data.loadFraction : 0;
        setProgress(Math.max(fraction, parseFloat(progressBar.style.width) / 100 || 0));
        statusText.textContent = fraction >= 0.95 ? 'Gør klar' : 'Indlæser byen';
    },

    onLogLine(data) {
        if (data && data.message) {
            statusText.textContent = data.message.slice(0, 48);
        }
    },
};

window.addEventListener('message', (event) => {
    const data = event.data || {};
    const handler = handlers[data.eventName];
    if (handler) handler(data);
});

document.addEventListener('DOMContentLoaded', () => {
    tryBackgroundMedia();
    loadConfig();
    setProgress(0.04);
});
