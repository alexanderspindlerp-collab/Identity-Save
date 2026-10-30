
const $ = (id) => document.getElementById(id);
const clamp = (n,min=0,max=100)=>Math.max(min,Math.min(max,Number(n)||0));
const post = (name, data={}) => fetch(`https://${GetParentResourceName()}/${name}`, {method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)}).catch(()=>{});

const HEALTH_ARC = 2 * Math.PI * 36;
const ARMOR_ARC = 2 * Math.PI * 40;

const DEFAULT_POSITIONS = {
  playerHud: { left: 2.05, bottom: 2.05 },
  playerHudNp: { left: 1.55, bottom: 2.05 },
  vehHud: { left: 17.35, bottom: 4.25 },
  minimap: { left: 0.4, bottom: 0.8, width: 16.38, height: 18.3 }
};

const state = {
  hud:false,
  car:false,
  unit:'KMH',
  hudStyle:1,
  lastPlayerData:null,
  editMode:false,
  positions: JSON.parse(JSON.stringify(DEFAULT_POSITIONS)),
  savedPositions: JSON.parse(JSON.stringify(DEFAULT_POSITIONS)),
  drag:null
};

function setSafezone(size){
  document.documentElement.style.setProperty('--safe-left', '0px');
  document.documentElement.style.setProperty('--safe-bottom', '0px');
}
window.addEventListener('resize',()=>setSafezone(window.__hudSafezone || 1.0));

function setRing(id, value, color){
  const el=$(id); if(!el) return;
  el.style.setProperty('--value', clamp(value));
  if(color) el.style.setProperty('--color', color);
}

function setArc(el, percent, total){
  if(!el) return;
  const val = clamp(percent);
  el.style.strokeDashoffset = String(total - (val / 100) * total);
}

function setHealthRing(value, armor){
  const health = clamp(value);
  const armorVal = clamp(armor || 0);
  const item = $('healthItem');

  setArc($('healthArc'), health, HEALTH_ARC);
  setArc($('armorArc'), armorVal, ARMOR_ARC);

  if(item){
    item.classList.toggle('has-armor', armorVal > 0);
    item.classList.toggle('low-health', health <= 25);
  }

  const healthNum = $('healthValue');
  if(healthNum) healthNum.textContent = Math.round(health);
}

function setNoPixelHud(data){
  const health = clamp(data.health ?? data.hp ?? 100);
  const armor = clamp(data.armor || 0);
  const hunger = clamp(data.hunger ?? 100);
  const thirst = clamp(data.thirst ?? 100);

  const healthFill = $('npHealthFill');
  const armorFill = $('npArmorFill');
  const hungerFill = $('npHungerFill');
  const thirstFill = $('npThirstFill');
  const healthRow = $('npHealthRow');
  const armorRow = $('npArmorRow');
  const voiceRow = $('npVoiceRow');

  if(healthFill){
    healthFill.style.width = `${health}%`;
    healthFill.style.setProperty('--healthValue', `${health}%`);
    healthFill.classList.toggle('low', health <= 25);
  }
  if(armorFill){
    armorFill.style.width = `${armor}%`;
    armorFill.style.setProperty('--armorValue', `${armor}%`);
  }
  if(hungerFill){
    hungerFill.style.width = `${hunger}%`;
    hungerFill.style.setProperty('--hungerValue', `${hunger}%`);
  }
  if(thirstFill){
    thirstFill.style.width = `${thirst}%`;
    thirstFill.style.setProperty('--thirstValue', `${thirst}%`);
  }
  if(healthRow) healthRow.classList.toggle('has-armor', armor > 0);
  if(armorRow) armorRow.classList.toggle('hidden', armor <= 0);
  if(voiceRow) voiceRow.classList.toggle('talking', !!data.talking);
}

function setHudStyle(style){
  const nextStyle = Number(style) === 2 ? 2 : 1;
  state.hudStyle = nextStyle;
  document.body.dataset.hudStyle = String(nextStyle);

  document.querySelectorAll('.hud-style-btn').forEach((btn)=>{
    btn.classList.toggle('active', Number(btn.dataset.style) === nextStyle);
  });

  if(state.lastPlayerData) applyPlayerVisibility(state.lastPlayerData);
}

function applyPlayerVisibility(data){
  const visible = !!data.show && data.isPaused !== 1;
  const hud1 = $('playerHud');
  const hud2 = $('playerHudNp');

  if(hud1) hud1.classList.toggle('hidden', !visible || state.hudStyle !== 1);
  if(hud2) hud2.classList.toggle('hidden', !visible || state.hudStyle !== 2);
}

function getHudElement(id){
  return document.querySelector(`[data-hud-id="${id}"]`) || $(id);
}

function applyPosition(id, pos){
  const el = getHudElement(id);
  if(!el || !pos) return;

  if(pos.left !== undefined) el.style.left = `${pos.left}vw`;
  if(pos.bottom !== undefined) el.style.bottom = `${pos.bottom}vh`;
  if(pos.width !== undefined) el.style.width = `${pos.width}vw`;
  if(pos.height !== undefined) el.style.height = `${pos.height}vh`;
  el.style.right = 'auto';
  el.style.top = 'auto';
}

function applyAllPositions(positions, minimapOffset){
  const next = { ...DEFAULT_POSITIONS, ...(positions || {}) };

  if(minimapOffset && (!positions || !positions.minimap)){
    const base = DEFAULT_POSITIONS.minimap;
    next.minimap = {
      ...base,
      left: Number((base.left + (minimapOffset.x || 0) * 100).toFixed(2)),
      bottom: Number((base.bottom + (minimapOffset.y || 0) * 100).toFixed(2))
    };
  }

  state.positions = JSON.parse(JSON.stringify(next));
  state.savedPositions = JSON.parse(JSON.stringify(next));

  Object.keys(DEFAULT_POSITIONS).forEach((id)=> applyPosition(id, state.positions[id]));
}

function getMinimapOffset(pos){
  const current = pos || state.positions.minimap || DEFAULT_POSITIONS.minimap;
  const base = DEFAULT_POSITIONS.minimap;
  return {
    x: (Number(current.left) - base.left) * 0.01,
    y: (Number(current.bottom) - base.bottom) * 0.01
  };
}

function saveCurrentPositions(){
  post('saveHudPositions', {
    positions: state.positions,
    minimap: getMinimapOffset()
  });
  state.savedPositions = JSON.parse(JSON.stringify(state.positions));
}

function setEditMode(enabled){
  state.editMode = !!enabled;
  document.body.classList.toggle('edit-mode', state.editMode);

  const bar = $('editModeBar');
  const mapZone = $('minimapDragZone');
  if(bar) bar.classList.toggle('hidden', !state.editMode);
  if(mapZone) mapZone.classList.toggle('hidden', !state.editMode);

  if(!state.editMode){
    document.querySelectorAll('.hud-draggable.dragging').forEach((el)=> el.classList.remove('dragging'));
    state.drag = null;
  }
}

function cancelEditMode(){
  applyAllPositions(state.savedPositions);
  setEditMode(false);
  post('setEditMode', { enabled: false });
  post('previewMinimapOffset', { minimap: getMinimapOffset(state.savedPositions.minimap) });
}

function finishEditMode(){
  saveCurrentPositions();
  setEditMode(false);
  post('setEditMode', { enabled: false });
}

function startDrag(event, el){
  if(!state.editMode || !el) return;
  event.preventDefault();

  const rect = el.getBoundingClientRect();
  state.drag = {
    el,
    id: el.dataset.hudId,
    offsetX: event.clientX - rect.left,
    offsetY: event.clientY - rect.top
  };
  el.classList.add('dragging');
}

function moveDrag(event){
  if(!state.drag) return;

  const { el, id, offsetX, offsetY } = state.drag;
  const leftPx = event.clientX - offsetX;
  const bottomPx = window.innerHeight - (event.clientY - offsetY) - el.offsetHeight;

  const leftVw = clamp((leftPx / window.innerWidth) * 100, 0, 96);
  const bottomVh = clamp((bottomPx / window.innerHeight) * 100, 0, 96);

  if(!state.positions[id]) state.positions[id] = { ...DEFAULT_POSITIONS[id] };
  state.positions[id].left = Number(leftVw.toFixed(2));
  state.positions[id].bottom = Number(bottomVh.toFixed(2));

  applyPosition(id, state.positions[id]);

  if(id === 'minimap'){
    queueMinimapPreview();
  }
}

let minimapPreviewTimer = null;
function queueMinimapPreview(){
  if(minimapPreviewTimer) return;
  minimapPreviewTimer = setTimeout(()=>{
    minimapPreviewTimer = null;
    post('previewMinimapOffset', { minimap: getMinimapOffset() });
  }, 40);
}

function endDrag(){
  if(!state.drag) return;
  state.drag.el.classList.remove('dragging');
  state.drag = null;
}

function initDragSystem(){
  document.querySelectorAll('.hud-draggable').forEach((el)=>{
    el.addEventListener('mousedown', (event)=> startDrag(event, el));
  });

  window.addEventListener('mousemove', moveDrag);
  window.addEventListener('mouseup', endDrag);

  $('savePositions')?.addEventListener('click', finishEditMode);
  $('resetPositions')?.addEventListener('click', ()=>{
    applyAllPositions(DEFAULT_POSITIONS);
    saveCurrentPositions();
  });
  $('cancelEditMode')?.addEventListener('click', cancelEditMode);

  $('toggleEditMode')?.addEventListener('click', ()=>{
    $('hudMenu')?.classList.add('hidden');
    setEditMode(true);
    post('startEditMode');
  });

  window.addEventListener('keydown', (event)=>{
    if(!state.editMode) return;
    if(event.key === 'Enter'){
      event.preventDefault();
      finishEditMode();
    }
    if(event.key === 'Escape'){
      event.preventDefault();
      cancelEditMode();
    }
  });
}

function setSpeed(speed){
  const s = String(Math.max(0, Math.floor(Number(speed)||0))).padStart(3,'0').slice(-3);
  let seen=false;
  $('speedValue').innerHTML = [...s].map(ch=>{ if(ch!=='0') seen=true; return `<span class="${seen?'':'dim'}">${ch}</span>`}).join('');
}
function buildRpm(){
  const wrap=$('rpmBars'); wrap.innerHTML='';
  for(let i=0;i<20;i++){ const d=document.createElement('div'); d.className='rpm-seg'; wrap.appendChild(d); }
}
function setRpm(rpm){
  const filled=Math.round(clamp((Number(rpm)||0)*100,0,100)/5);
  [...$('rpmBars').children].forEach((seg,i)=>{
    let cls='rpm-seg';
    if(i<filled){
      let c='teal';
      if(i>=17) c='red'; else if(i>=15) c='orange'; else if(i>=13) c='yellow';
      cls += ' on '+c;
    }
    seg.className=cls;
  });
}
function setFuel(v){
  const val=clamp(v); const fill=$('fuelFill'); fill.style.height=val+'%';
  fill.style.background = val<18 ? '#ff2438' : val<30 ? '#ff9d00' : '#00f8b9';
}
function setGear(g){
  let gear = (g===0||g==='0')?'N':String(g||'N');
  $('gearValue').textContent = gear;
}

function updatePlayer(data){
  state.lastPlayerData = data;
  state.hud = !!data.show && data.isPaused !== 1;
  applyPlayerVisibility(data);

  const health = data.health ?? data.hp ?? 100;
  const armor = data.armor || 0;

  setHealthRing(health, armor);
  setRing('hungerRing', data.hunger ?? 100, '#ffa500');
  setRing('thirstRing', data.thirst ?? 100, '#38ced3');
  setNoPixelHud(data);

  const voice=$('voiceItem');
  if(voice) voice.classList.toggle('talking', !!data.talking);
}

function updateVehicle(data){
  state.car = !!data.show && data.isPaused !== 1;
  $('vehHud').classList.toggle('hidden', !state.car);
  if(!state.car) return;
  setSpeed(data.speed||0); setFuel(data.fuel||0); setRpm(data.rpm||0); setGear(data.gear);
  if(data.unit) $('speedUnit').textContent = data.unit;
  $('streetDirection').textContent = data.direction || '';
  $('streetName').textContent = data.street || '';
  $('streetBlock').classList.toggle('hidden', !(data.street || data.direction));
}

function setSpeedLimiterIcon(enabled){
  const limiterIconElement = document.getElementById('limiterIcon');
  if(!limiterIconElement) return;

  if(enabled){
    limiterIconElement.classList.remove('hidden');
    limiterIconElement.classList.add('active');
  }else{
    limiterIconElement.classList.remove('active');
    limiterIconElement.classList.add('hidden');
  }
}

function setLowFuelIcon(enabled){
  const lowFuelElement = document.getElementById('lowFuelIcon');
  if(!lowFuelElement) return;

  if(enabled){
    lowFuelElement.classList.remove('hidden');
    lowFuelElement.classList.add('active');
  }else{
    lowFuelElement.classList.remove('active');
    lowFuelElement.classList.add('hidden');
  }
}

function readFuelFromHudMessage(data){
  if(!data) return null;

  const possibleValues = [
    data.fuel,
    data.vehicleFuel,
    data.fuelLevel,
    data.carFuel,
    data.statusFuel
  ];

  for(const value of possibleValues){
    if(value === undefined || value === null) continue;
    const numberValue = Number(value);
    if(!Number.isNaN(numberValue)) return numberValue;
  }

  return null;
}

window.addEventListener('message', (e)=>{
  const d = e.data || {};
  if(d.action === 'speedLimiter') setSpeedLimiterIcon(!!d.enabled);
  if(d.action==='hudtick') updatePlayer(d);
  if(d.action==='car') updateVehicle(d);
  if(d.action==='open') $('hudMenu').classList.remove('hidden');
  if(d.action==='close') $('hudMenu').classList.add('hidden');
  if(d.action==='safezone'){ window.__hudSafezone = 1.0; setSafezone(1.0); }
  if(d.action==='hudreset') location.reload();
  if(d.action==='setHudStyle') setHudStyle(d.style || 1);
  if(d.action==='setEditMode') setEditMode(!!d.enabled);
  if(d.action==='loadPositions') applyAllPositions(d.positions, d.minimap);
});

$('closeMenu').addEventListener('click',()=>{ $('hudMenu').classList.add('hidden'); post('closeMenu'); });
$('restartHud').addEventListener('click',()=>{ post('restartHud'); location.reload(); });

document.querySelectorAll('.hud-style-btn').forEach((btn)=>{
  btn.addEventListener('click', ()=>{
    const style = Number(btn.dataset.style) || 1;
    setHudStyle(style);
    post('setHudStyle', { style });
  });
});

initDragSystem();
applyAllPositions(DEFAULT_POSITIONS);
buildRpm(); setSpeed(0); setRpm(0); setFuel(0);
setSafezone(1.0);
setHudStyle(1);
setHealthRing(100, 0);

window.addEventListener('message', function(event){
  const fuelWarningData = event.data || {};

  if(fuelWarningData.action === 'lowFuelWarning'){
    setLowFuelIcon(!!fuelWarningData.enabled);
    return;
  }

  const hudFuelValue = readFuelFromHudMessage(fuelWarningData);
  if(hudFuelValue !== null){
    setLowFuelIcon(hudFuelValue <= 25);
  }
});
