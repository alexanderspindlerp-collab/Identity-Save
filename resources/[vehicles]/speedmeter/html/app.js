const radar = document.getElementById('radar');
const plate = document.getElementById('plate');
const targetSpeed = document.getElementById('targetSpeed');
const patrolSpeed = document.getElementById('patrolSpeed');
const lockState = document.getElementById('lockState');
const recording = document.getElementById('recording');

function padSpeed(value) {
    const num = Number(value || 0);
    return String(Math.max(0, Math.min(999, Math.round(num)))).padStart(3, '0');
}

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || !msg.action) return;

    if (msg.action === 'show') {
        radar.classList.remove('hidden');
        return;
    }

    if (msg.action === 'hide') {
        radar.classList.add('hidden');
        return;
    }

    if (msg.action === 'update') {
        const data = msg.data || {};
        plate.textContent = data.plate || '--------';
        targetSpeed.textContent = padSpeed(data.targetSpeed);
        patrolSpeed.textContent = padSpeed(data.patrolSpeed);

        lockState.textContent = data.locked ? 'LÅST' : 'IKKE LÅST';
        lockState.classList.toggle('locked', !!data.locked);

        recording.textContent = data.recording ? 'OPTAGER' : 'OPTAGER IKKE';
        recording.classList.toggle('recording', !!data.recording);
    }
});
