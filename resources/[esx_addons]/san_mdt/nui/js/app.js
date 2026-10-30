const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'san_mdt';
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
function safeStorageJson(key, fallback = []){
  try {
    const raw = localStorage.getItem(key);
    if(!raw) return fallback;
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : fallback;
  } catch (_) {
    try { localStorage.removeItem(key); } catch (__) {}
    return fallback;
  }
}

let currentIncident = null;
let incidents = [];
let activePage = 'dashboard';
let profiles = [];
let activeProfile = null;
let profileListMode = true;
let criminalSearchResults = [];
let criminalSearchTimer = null;
let civilianSearchResults = [];
let civilianSearchTimer = null;
let vehicleSearchResults = [];
let registryVehicleResults = [];
let activeVehicleProfile = null;
let vehicleRegistrySearchTimer = null;
let vehicleSearchTimer = null;
let activeProfilePreview = null;
let openProfilePreviewStack = [];
let mdtTags = safeStorageJson('san_mdt_tags_v1');
let mdtReports = safeStorageJson('san_mdt_reports_v1');
let krimReports = safeStorageJson('san_mdt_krim_reports_v1');
let reportScope = 'politi';
let mdtCharges = [];
let licenseRevocationCooldownHours = 48;
let chargePermissions = { add:false, edit:false, delete:false };
let vehicleReturnPermission = false;
let vehicleReturnLockedPermission = false;
let vehicleReturnPermanentPermission = false;
let chargeSearchTimer = null;
let incidentChargesExpanded = false;
let activeCriminalChargesIndex = null;
const chargeCategoryMeta = {
  green: { label:'Mindre forseelse', cls:'green' },
  yellow: { label:'Trafik / klip', cls:'yellow' },
  orange: { label:'Alvorlig', cls:'orange' },
  red: { label:'Grov kriminalitet', cls:'red' },
  blue: { label:'Særlig / administrativ', cls:'blue' }
};

const reportTypeTemplates = {
  incident: { label:'Hændelse', badge:'HÆNDELSE', color:'#00e6b7', title:'Ny hændelse', body:`<h2>HÆNDELSE</h2><p><b>Lokation:</b> </p><p><b>Tidspunkt:</b> </p><p><b>Involverede:</b> </p><p><b>Hændelsesforløb:</b><br>Forklar specifikt hvad der skete, hvem der gjorde hvad, og hvordan patruljen reagerede.</p><p><b>Beviser:</b> </p><p><b>Konklusion / videre handling:</b> </p>` },
  report: { label:'Rapport', badge:'RAPPORT', color:'#2f8cff', title:'Ny rapport', body:`<h2>RAPPORT</h2><p><b>Emne:</b> </p><p><b>Lokation:</b> </p><p><b>Tidspunkt:</b> </p><p><b>Beskrivelse:</b><br>Skriv hvad rapporten omhandler, hvad der blev observeret, og hvilken handling der blev foretaget.</p><p><b>Konklusion:</b> </p>` },
  wanted: { label:'Efterlysning', badge:'EFTERLYSNING', color:'#ffd23f', title:'Ny efterlysning', body:`<h2>EFTERLYSNING</h2><p><b>Efterlyst person/køretøj:</b> </p><p><b>Årsag:</b> Flugt / mistanke / aktiv sag.</p><p><b>Sidst set:</b> </p><p><b>Kendetegn:</b> </p><p><b>Risikovurdering:</b> </p>` },
  shooting: { label:'Skyderi', badge:'SKYDERI', color:'#ff3b5c', title:'Ny skyderapport', body:`<h2>SKYDERI RAPPORT</h2><p><b>Lokation:</b> </p><p><b>Tidspunkt for skud:</b> </p><p><b>Patruljer på stedet:</b> </p><p><b>Gerningssted:</b><br>Beskriv fund, hylstre, skader, vidner og flugtretning.</p><p><b>Involverede personer/køretøjer:</b> </p><p><b>Beviser:</b> Bodycam, dashcam, billeder, våben, DNA/fingeraftryk.</p><p><b>Videre efterforskning:</b> </p>` },
  heist: { label:'Heist', badge:'HEIST', color:'#ff8a2a', title:'Ny heist-rapport', body:`<h2>HEIST RAPPORT</h2><p><b>Lokation:</b> </p><p><b>Objekt/bank/butik:</b> </p><p><b>Gerningsmænd:</b> </p><p><b>Våben/køretøjer:</b> </p><p><b>Forløb:</b> </p><p><b>Udbytte/skader:</b> </p><p><b>Videre efterforskning:</b> </p>` },
  theft: { label:'Tyveri', badge:'TYVERI', color:'#b46cff', title:'Ny tyverirapport', body:`<h2>TYVERI RAPPORT</h2><p><b>Lokation:</b> </p><p><b>Stjålet genstand/køretøj:</b> </p><p><b>Forurettet:</b> </p><p><b>Mistænkte:</b> </p><p><b>Forløb:</b> </p><p><b>Beviser:</b> </p>` },
  complaint: { label:'Anmeldelse', badge:'ANMELDELSE', color:'#7bd88f', title:'Ny anmeldelse', body:`<h2>ANMELDELSE</h2><p><b>Anmelder:</b> </p><p><b>Forhold:</b> </p><p><b>Lokation:</b> </p><p><b>Beskrivelse:</b> </p><p><b>Ønsket handling:</b> </p>` },
  traffic: { label:'Færdselsforhold', badge:'FÆRDSEL', color:'#35c2ff', title:'Ny færdselsrapport', body:`<h2>FÆRDSELSRAPPORT</h2><p><b>Lokation:</b> </p><p><b>Køretøj/nummerplade:</b> </p><p><b>Fører:</b> </p><p><b>Forhold:</b> </p><p><b>Forløb:</b> </p><p><b>Konklusion:</b> </p>` },
  weapons: { label:'Våbenrapport', badge:'VÅBEN', color:'#ff4d6d', title:'Ny våbenrapport', body:`<h2>VÅBENRAPPORT</h2><p><b>Våbentype:</b> </p><p><b>Beslaglagt hvor:</b> </p><p><b>Fundet på:</b> </p><p><b>Serienummer:</b> </p><p><b>Forløb:</b> </p>` },
  drugs: { label:'Narkorapport', badge:'NARKO', color:'#00d084', title:'Ny narkorapport', body:`<h2>NARKORAPPORT</h2><p><b>Stof/type:</b> </p><p><b>Mængde:</b> </p><p><b>Fundsted:</b> </p><p><b>Mistænkte:</b> </p><p><b>Forløb:</b> </p>` },
  gang: { label:'Bandeaktivitet', badge:'BANDE', color:'#c03cff', title:'Ny bande-rapport', body:`<h2>BANDEAKTIVITET</h2><p><b>Gruppering/tag:</b> </p><p><b>Lokation:</b> </p><p><b>Observation:</b> </p><p><b>Køretøjer/personer:</b> </p><p><b>Risiko:</b> </p>` }
};
function currentReportTypeMeta(i){ return reportTypeTemplates[(i && i.report_type) || 'incident'] || reportTypeTemplates.incident; }

const enabledPages = { dashboard:true, profiles:true, vehicles:true, incidents:true, admin_employees:true, admin_roles:true, admin_tags:true, admin_logs:true, admin_stats:false, admin_mail:true, reports:true, charges:true, krim_dna:true, krim_fingerprint:true, fleet:true, nsk_gangs:true, nsk_observations:true, nsk_connections:true, nsk_activity:true, files:true, invoices:false, evidence:false, self_profile:true };
const mdtRoles = ['Rigspolitiet','Inspektør','NSK Chef','NSK Afdeling','Kommissær','Assistent 1. Grad','Assistent','Betjent','Elev','Receptionist','Rengøring','Suspenderet'];
const MDT_AWARD_DEFS = {
  brave: { label:'Brave', icon:'🛡', cls:'award-brave', desc:'Ærefortjeneste for mod og dedikation i tjenesten.' },
  excellence: { label:'Excellence', icon:'★', cls:'award-excellence', desc:'Fremragende indsats anerkendt af ledelsen.' },
  service: { label:'Tjenestemedalje', icon:'🎖', cls:'award-service', desc:'Langvarig og loyal tjeneste.' },
  valor: { label:'Tapperhed', icon:'⚔', cls:'award-valor', desc:'Ekstraordinær handlekraft under pres.' }
};
let dashboardOfficerData = { officers:{}, roleOrder:mdtRoles.slice(), canSendMail:true, stats:{}, officerCount:0 };
let dashboardOfficerSearch = '';
let dashboardCachedPayload = null;
let activeOfficerProfile = null;
let mdtNskView = false;
let mdtNskManage = false;
let nskOverview = { gangs: [], members: [], territories: [] };
let nskGangBoard = null;
let nskSelectedGangId = null;
const NSK_GANG_BOARD_TIERS = [
  { key:'boss', label:'Leder', icon:'♔' },
  { key:'underboss', label:'Næstkommanderende', icon:'♕' },
  { key:'capo', label:'Capo / Sergeant', icon:'◆' },
  { key:'soldier', label:'Soldat', icon:'●' },
  { key:'prospect', label:'Prospect', icon:'○' },
  { key:'unknown', label:'Ukendt rang', icon:'?' },
];
const vehicleModelLabelCache = {};
function isVehicleModelNumeric(v){
  return /^-?\d+$/.test(String(v == null ? '' : v).trim());
}
function vehicleModelHashKey(v){
  if(!v) return '';
  if(v.modelHash != null && v.modelHash !== '') return String(v.modelHash);
  if(isVehicleModelNumeric(v.model)) return String(v.model);
  return '';
}
function displayVehicleModel(v){
  if(!v) return 'Ukendt model';
  const hash = vehicleModelHashKey(v);
  if(hash && vehicleModelLabelCache[hash]) return vehicleModelLabelCache[hash];
  if(v.model && !isVehicleModelNumeric(v.model)) return v.model;
  return v.model || 'Ukendt model';
}
async function hydrateVehicleModels(vehicles){
  if(!Array.isArray(vehicles) || !vehicles.length) return;
  const hashes = [...new Set(vehicles.map(vehicleModelHashKey).filter(Boolean))].filter((h) => !vehicleModelLabelCache[h] && isVehicleModelNumeric(h));
  if(!hashes.length) return;
  try{
    const r = await nui('resolveVehicleModels', { hashes });
    if(r?.models) Object.assign(vehicleModelLabelCache, r.models);
  }catch(_){}
  vehicles.forEach((v) => {
    const hash = vehicleModelHashKey(v);
    if(hash && vehicleModelLabelCache[hash]) v.model = vehicleModelLabelCache[hash];
  });
}
function vehicleStatusBadge(status, opts = {}){
  const s = String(status || '').toLowerCase();
  const big = opts.big ? ' big' : '';
  if(s.includes('permanent')) return `<span class="vehicle-impound-badge permanent${big}"><i aria-hidden="true">⛔</i><span>Politiopbevaring</span></span>`;
  if(s.includes('låst')) return `<span class="vehicle-impound-badge locked${big}"><i aria-hidden="true">🔒</i><span>Låst impound</span></span>`;
  if(s.includes('impound') || s.includes('beslaglagt')) return `<span class="vehicle-impound-badge impound${big}"><i aria-hidden="true">P</i><span>Impound</span></span>`;
  if(s.includes('garage')) return `<span class="vehicle-status ok${big}">I garage</span>`;
  if(s.includes('efterlyst')) return `<span class="vehicle-status danger${big}">Efterlyst</span>`;
  return `<span class="vehicle-status ok${big}">${escapeHtml(status || 'Ude')}</span>`;
}
const mdtDivisions = ['Patrulje','Færdsel','Efterforskning','NSK','AKS','PET','Hundepatrulje','Helikopter','Civil','Intern Affairs','Ledelse'];
const MDT_BADGE_PREFIX_BY_DIVISION = {
  Patrulje:'B', Færdsel:'F', Efterforskning:'E', NSK:'E', AKS:'B', PET:'E',
  'Hundepatrulje':'B', Helikopter:'B', Civil:'E', 'Intern Affairs':'E', Ledelse:'E',
};
function policeBadgePrefix(division){
  const d = String(division || '').trim();
  if(MDT_BADGE_PREFIX_BY_DIVISION[d]) return MDT_BADGE_PREFIX_BY_DIVISION[d];
  const low = d.toLowerCase();
  if(low.includes('færd') || low.includes('faerd') || low.includes('trafik')) return 'F';
  if(low.includes('efter') || low.includes('nsk') || low.includes('pet') || low.includes('civil') || low.includes('led')) return 'E';
  return 'B';
}
function pnumberDigitsOnly(v){
  let raw = String(v || '').trim().replace(/^[A-Z]-?/i, '').replace(/^P-?/i, '');
  const digits = raw.replace(/\D/g, '').slice(-4);
  return digits ? digits.padStart(4, '0') : '';
}
function parseStoredBadgePrefix(v){
  const raw = String(v || '').trim().toUpperCase();
  const m = raw.match(/^([BFE])[- ]?/);
  return m ? m[1] : '';
}
function normalizeBadgePrefix(prefix, division){
  const p = String(prefix || '').trim().toUpperCase();
  if(/^[BFE]$/.test(p)) return p;
  return policeBadgePrefix(division);
}
function buildPoliceBadge(prefix, digits, division){
  const d = pnumberDigitsOnly(digits);
  if(!d) return '';
  return normalizeBadgePrefix(prefix, division) + d;
}
function parseEmployeeBadge(emp){
  const raw = emp?.pnumber || emp?.badge || emp?.grade || '';
  return {
    prefix: parseStoredBadgePrefix(raw) || policeBadgePrefix(emp?.division || 'Patrulje'),
    digits: pnumberDigitsOnly(raw),
  };
}
function formatPoliceBadge(pnumber, division){
  const digits = pnumberDigitsOnly(pnumber);
  if(!digits) return '';
  const prefix = parseStoredBadgePrefix(pnumber) || policeBadgePrefix(division);
  return prefix + digits;
}
function officerBadge(emp){
  if(!emp) return '';
  return emp.badge || formatPoliceBadge(emp.pnumber || emp.grade || '', emp.division || 'Patrulje') || '';
}
function mailSenderBadgeFromMail(m){
  if(!m) return '';
  if(m.sender_badge) return String(m.sender_badge).trim();
  const dept = String(m.department || '');
  const match = dept.match(/Privat mail fra\s+([A-Z]\d{4})/i);
  return match ? match[1].toUpperCase() : '';
}
function isPrivateMail(m){
  return m && (m.recipient_type === 'private' || (m.recipient && m.recipient !== 'frontpage' && m.recipient_type !== 'frontpage'));
}
function mailSenderLabel(m){
  if(!m) return 'Ukendt';
  if(m.sender_role && String(m.sender_role).toLowerCase() === 'rigspolitiet') return 'Rigspolitiet';
  if(m.department && /^rigspolitiet$/i.test(String(m.department).trim())) return 'Rigspolitiet';
  const badge = mailSenderBadgeFromMail(m);
  if(badge) return badge;
  return m.sender || 'Ukendt';
}
function mailRecipientLabel(m){
  if(!m) return 'Ukendt';
  if(m.recipient_role && String(m.recipient_role).toLowerCase() === 'rigspolitiet') return 'Rigspolitiet';
  if(m.recipient_badge) return m.recipient_badge;
  return m.recipient_name || m.recipient || 'Ukendt';
}
function mailCardTitle(m){
  if(m?.mail_direction === 'sent') return `Email til ${mailRecipientLabel(m)}`;
  if(isPrivateMail(m)) return `Email fra ${mailSenderLabel(m)}`;
  return `NYHED - ID: ${m.id || ''}`;
}
function mailCardMeta(m){
  if(m?.mail_direction === 'sent'){
    const to = mailRecipientLabel(m);
    const name = m.recipient_name || '';
    return name && name !== to ? `Sendt til ${name} (${to})` : `Sendt til ${to}`;
  }
  if(isPrivateMail(m)){
    const from = mailSenderLabel(m);
    if(/^rigspolitiet$/i.test(from)) return 'Privat mail fra Rigspolitiet';
    if(/^[A-Z]\d{4}$/.test(from)) return `Privat mail fra ${from}`;
    return m.sender ? `Privat mail fra ${m.sender}` : 'Privat mail';
  }
  return m.department || 'Rigspolitiet';
}
function mailReadStatusLine(m){
  if(m?.mail_direction === 'sent'){
    const seen = Number(m.recipient_seen || 0) === 1;
    return seen
      ? `Modtager har set${m.recipient_seen_at ? ' · ' + (fmtDate(m.recipient_seen_at) || '') : ''}`
      : 'Modtager har ikke set endnu';
  }
  const unread = Number(m.unread || 0) === 1;
  return unread ? 'Du har ikke set endnu' : (m.seen_at ? `Du har set · ${fmtDate(m.seen_at) || ''}` : 'Du har set');
}
function mailStatusShort(m){
  if(m?.mail_direction === 'sent') return Number(m.recipient_seen || 0) === 1 ? 'Set af modtager' : 'Ikke set';
  return Number(m.unread || 0) === 1 ? 'Ikke set' : 'Set';
}
function mailStatusClass(m){
  if(m?.mail_direction === 'sent') return Number(m.recipient_seen || 0) === 1 ? 'seen' : 'unseen';
  return Number(m.unread || 0) === 1 ? 'unseen' : 'seen';
}
function renderSelfProfileMailCard(m){
  const unreadCls = (m.mail_direction !== 'sent' && Number(m.unread || 0) === 1) ? ' unread' : '';
  const threadNote = Number(m.thread_count || 0) > 1 ? `<span class="mail-thread-pill">${Number(m.thread_count)} i tråden</span>` : '';
  return `<div class="mail-card clickable${unreadCls}" data-open-mail-id="${escapeHtml(m.id)}">
    <div class="mail-card-top">
      <b>${escapeHtml(mailCardTitle(m))}</b>
      <span class="mail-status ${mailStatusClass(m)}">${escapeHtml(mailStatusShort(m))}</span>
    </div>
    <div class="mail-card-subject">${escapeHtml(m.subject || 'Besked')}${threadNote}</div>
    <div class="mail-card-foot">
      <span>${escapeHtml(mailCardMeta(m))}</span>
      <span>${escapeHtml(fmtDate(m.created_at) || '')}</span>
    </div>
    <div class="mail-card-read">${escapeHtml(mailReadStatusLine(m))}</div>
  </div>`;
}
function renderMailThreadMessages(messages){
  if(!messages || !messages.length) return '';
  return `<div class="mail-thread-list">${messages.map((msg) => {
    const label = msg.is_mine ? 'Dig' : (msg.sender_badge ? `${escapeHtml(msg.sender_name || 'Betjent')} (${escapeHtml(msg.sender_badge)})` : escapeHtml(msg.sender_name || msg.sender || 'Betjent'));
    return `<div class="mail-thread-msg ${msg.is_mine ? 'mine' : 'theirs'}">
      <div class="mail-thread-msg-head"><b>${label}</b><small>${escapeHtml(fmtDate(msg.created_at) || '')}</small></div>
      <div class="mail-thread-msg-body">${escapeHtml(msg.body || '').replace(/\n/g, '<br>')}</div>
    </div>`;
  }).join('')}</div>`;
}
function renderMailReplyPanel(threadData, mailId){
  if(!threadData || !isPrivateMail({ recipient_type: 'private' })) return '';
  const adminToggle = threadData.canManageReplies ? `
    <label class="mail-reply-admin">
      <input type="checkbox" id="mailReplyAllowedToggle" ${threadData.replyAllowed ? 'checked' : ''}>
      <span>Tillad svar i tråden (Rigspolitiet)</span>
    </label>` : '';
  const repliesOpen = threadData.canReply !== false && threadData.replyAllowed !== false;
  if(!repliesOpen){
    return `${adminToggle}<p class="mail-reply-closed">Svar er lukket for denne tråd.${threadData.canManageReplies ? ' Slå "Tillad svar i tråden" til for at åbne igen.' : ''}</p>`;
  }
  return `${adminToggle}
    <div class="mail-reply-box">
      <label>Skriv svar</label>
      <textarea id="mailReplyBody" placeholder="Fortsæt samtalen..."></textarea>
      <button type="button" class="save" id="mailReplySendBtn">Send svar</button>
    </div>`;
}
function mailModalTitle(m){
  return isPrivateMail(m) ? 'Email' : (m && m.mail ? 'Nyhed / Mail' : 'Mail');
}
let employees = [];
let reportOfficerSearchResults = [];
let incidentOfficerSearchResults = [];
let adminRoles = [];
let selfProfile = null;
let mailDirectory = [];
let selectedMailProfile = null;
let mailHistory = [];
let mailNewsList = [];
let activeMailMode = 'profile';
let dashboardMails = [];
let pendingSeenMailIds = new Set();
let permissionCatalog = [];
let permissionDebug = null;
let mdtOwnPermissions = [];
let mdtAdminView = false;
let mdtEmployeeAdmin = false;
let mdtCanDeleteIncident = false;
const NSK_AUTO_ROLES = ['nsk chef', 'nsk afdeling', 'nsk_chef', 'nsk_afdeling'];
window.MDT_PERM_DEBUG = false;
const blankLists = { objects:[], criminals:[], charges:[], tags:[], evidence:[], officers:[], civilians:[], vehicles:[], references:[] };



function permissionCategoriesFromCatalog(){
  const catalog = permissionCatalog.length ? permissionCatalog : [
    {key:'vehicles.impound.locked.release',label:'Frigiv låst impound',category:'Køretøjspermissions',description:'Frigiv normal impound med lås.'},
    {key:'vehicles.impound.permanent.release',label:'Frigiv politiopbevaring',category:'Køretøjspermissions',description:'Frigiv permanent impound / politiopbevaring.'},
    {key:'vehicles.view',label:'Se køretøjer',category:'Køretøjspermissions',description:'Søg i køretøjsregister.'},
    {key:'vehicles.manage',label:'Administrer køretøjer',category:'Køretøjspermissions',description:'Administrer køretøjsdata.'},
    {key:'incidents.create',label:'Opret hændelser',category:'Hændelser',description:'Kan oprette hændelser.'},
    {key:'incidents.edit',label:'Rediger hændelser',category:'Hændelser',description:'Kan redigere hændelser.'},
    {key:'incidents.delete',label:'Slet hændelser',category:'Hændelser',description:'Kan slette hændelser.'},
    {key:'incidents.issue_fine',label:'Udsted bøder',category:'Hændelser',description:'Kan udstede bøder/fakturaer fra hændelser.'},
    {key:'profiles.licenses.manage',label:'Administrer licenser',category:'Profiler',description:'Kan tilføje/fjerne kørekort og andre licenser i MDT.'},
    {key:'charges.add',label:'Tilføj sigtelser',category:'Sigtelser',description:'Kan oprette sigtelser.'},
    {key:'charges.edit',label:'Rediger sigtelser',category:'Sigtelser',description:'Kan redigere sigtelser.'},
    {key:'charges.delete',label:'Slet sigtelser',category:'Sigtelser',description:'Kan slette sigtelser.'},
    {key:'evidence.locker',label:'Evidence locker',category:'Beviser',description:'Kan åbne evidence locker.'},
    {key:'employees.hire',label:'Ansæt',category:'Ansatte',description:'Kan ansætte.'},
    {key:'employees.fire',label:'Afsked',category:'Ansatte',description:'Kan afskedige.'},
    {key:'employees.rank',label:'Rang/rolle',category:'Ansatte',description:'Kan ændre rang.'},
    {key:'administration.view',label:'Se Administration',category:'Administration',description:'Kan åbne Administration dropdown i MDT.'},
    {key:'admin.roles.manage',label:'Administrer permissions',category:'Administration',description:'Kun Rigspolitiet bør have denne.'},
    {key:'mail.send',label:'Send mail',category:'Administration',description:'Kan sende mail.'},
    {key:'mdt.view',label:'Åbn MDT',category:'Basis',description:'Basisadgang.'},
    {key:'nsk.view',label:'Se NSK',category:'NSK',description:'Kan åbne NSK-afdelingen.'},
    {key:'nsk.manage',label:'Administrer NSK',category:'NSK',description:'Kan oprette bander og territorier.'},
    {key:'profiles.gang.view',label:'Se bandemarkering',category:'NSK',description:'Kan se bande-boks på profiler.'},
    {key:'profiles.gang.register',label:'Banderegistrering',category:'NSK',description:'Kan registrere bandemedlemmer.'}
  ];
  const grouped = {};
  catalog.forEach(p => { const c = p.category || 'Andet'; (grouped[c] ||= []).push(p); });
  return grouped;
}

async function loadPermissionCatalog(){
  const r = await nui('getPermissionCatalog', {});
  if(r && r.ok){ permissionCatalog = r.catalog || []; permissionDebug = r.debug || null; }
}

function renderPermissionCards(selected = []){
  const selectedSet = new Set((selected || []).map(String));
  const grouped = permissionCategoriesFromCatalog();
  return `<div class="perm-category-grid">${Object.entries(grouped).map(([cat, list]) => `
    <section class="perm-category-card">
      <h3>${escapeHtml(cat)}</h3>
      <div class="perm-card-list">
        ${list.map(p => `<button type="button" class="perm-card ${selectedSet.has(p.key) ? 'selected' : ''}" data-perm-card="${escapeHtml(p.key)}">
          <i>${selectedSet.has(p.key) ? '✓' : ''}</i>
          <b>${escapeHtml(p.label || p.key)}</b>
          <small>${escapeHtml(p.description || p.key)}</small>
          <code>${escapeHtml(p.key)}</code>
        </button>`).join('')}
      </div>
    </section>`).join('')}</div>`;
}

function bindPermissionCards(){
  $$('#modalFields [data-perm-card]').forEach(btn => {
    btn.onclick = () => {
      btn.classList.toggle('selected');
      const i = btn.querySelector('i'); if(i) i.textContent = btn.classList.contains('selected') ? '✓' : '';
    };
  });
}

function selectedPermissionCards(){ return $$('#modalFields [data-perm-card].selected').map(x => x.dataset.permCard).filter(Boolean); }

function logPermDebug(label, extra){
  if(!window.MDT_PERM_DEBUG) return;
  console.log('[SAN MDT PERM]', label, extra || {}, { vehicleReturnLockedPermission, vehicleReturnPermanentPermission, permissionDebug });
}

async function nui(name, data = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 12000);
  try {
    const r = await fetch(`https://${res}/${name}`, {
      method: 'POST',
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: JSON.stringify(data),
      signal: controller.signal
    });
    clearTimeout(timeout);
    try { return await r.json(); } catch (_) { return { ok:false, message:'Ugyldigt svar fra MDT callback.' }; }
  } catch (e) {
    clearTimeout(timeout);
    console.error(e);
    return { ok:false, message:'MDT callback timeout. Tjek server/client console.' };
  }
}

function sanCloseDispatchUi(removeToasts){
  sanDispatchPanelOpen = false;
  document.body.classList.remove('san-dispatch-panel-open');
  document.getElementById('sanDispatchPanel')?.classList.remove('open');
  document.getElementById('sanDispatchDetailOverlay')?.classList.remove('open');
  if(removeToasts) document.getElementById('sanDispatchToastHost')?.remove();
}
function showApp(v){
  $('#app')?.classList.toggle('hidden', !v);
  if(!v){
    setLookThrough(false, false);
    sanCloseDispatchUi(true);
  }
}


// SAN MDT V2 LOGIN OVERLAY
let mdtLoggedIn = false;
let mdtLoginRendering = false;
function mdtSetAuthLocked(locked){
  document.getElementById('app')?.classList.toggle('mdt-auth-locked', !!locked);
}
function mdtRemoveLogin(){
  const o=document.getElementById('mdtLoginOverlay');
  if(o) o.remove();
  mdtSetAuthLocked(false);
}
function mdtNotifyClientAuthenticated(){
  nui('mdtAuthenticated', {}).catch(()=>{});
  syncReportAnpgFlags();
}
function mdtRenderLogin(prefill){
  mdtLoginRendering = true;
  mdtRemoveLogin();
  mdtSetAuthLocked(true);
  const wrap=document.createElement('div');
  wrap.id='mdtLoginOverlay';
  wrap.className='mdt-login-overlay';
  wrap.innerHTML=`<div class="mdt-login-shell">
    <div class="mdt-login-brand">
      <div class="mdt-login-crest" aria-hidden="true">⚜</div>
      <div class="mdt-login-brand-copy">
        <div class="mdt-login-brand-title"><span class="mdt-login-slash">//</span> <span class="mdt-login-politi">POLITI</span></div>
        <div class="mdt-login-brand-sub">Los Santos Politi · Mobile Data Terminal</div>
      </div>
    </div>
    <div class="mdt-login-card">
      <h2>Log ind på MDT</h2>
      <p>Indtast dit tjenestenummer (fx B0042, E1203) og MDT-kode fra Ansatte. Standardkode er 1234 hvis ingen personlig kode er sat.</p>
      <label>Brugernavn</label>
      <input id="mdtLoginUser" autocomplete="off" value="${escapeHtml((prefill&&prefill.pnumber)||'')}" placeholder="fx B0042, E1203 eller navn">
      <label>Kode</label>
      <input id="mdtLoginCode" type="password" autocomplete="off" placeholder="MDT-kode">
      <button id="mdtLoginBtn" class="primary">Login</button>
      <small id="mdtLoginMsg"></small>
    </div>
  </div>`;
  const app = document.getElementById('app');
  (app || document.body).appendChild(wrap);
  const login=async()=>{
    const btn=document.getElementById('mdtLoginBtn'); const msg=document.getElementById('mdtLoginMsg');
    if(btn){btn.disabled=true; btn.textContent='Logger ind...';}
    const r=await nui('loginMdt',{username:document.getElementById('mdtLoginUser')?.value||'', code:document.getElementById('mdtLoginCode')?.value||''});
    if(!r||!r.ok){ if(msg) msg.textContent=(r&&r.message)||'Kunne ikke logge ind.'; if(btn){btn.disabled=false; btn.textContent='Login';} return; }
    mdtLoggedIn=true; mdtRemoveLogin(); mdtNotifyClientAuthenticated(); toast('Logget ind på MDT.'); setPage('self'); refreshSelfProfile(); refreshFleet(); refreshWiretapSession();
  };
  document.getElementById('mdtLoginBtn')?.addEventListener('click', login);
  document.getElementById('mdtLoginUser')?.addEventListener('keydown', e => {
    if(e.key === 'Tab' && !e.shiftKey){ e.preventDefault(); document.getElementById('mdtLoginCode')?.focus(); }
    if(e.key === 'Enter'){ e.preventDefault(); document.getElementById('mdtLoginCode')?.focus(); }
  });
  document.getElementById('mdtLoginCode')?.addEventListener('keydown', e=>{ if(e.key==='Enter') login(); });
  setTimeout(()=>document.getElementById('mdtLoginUser')?.focus(),50);
  mdtLoginRendering = false;
}
async function mdtEnsureLogin(){
  if (mdtLoggedIn) return true;
  mdtSetAuthLocked(true);
  try {
    const r = await nui('getMdtSession', {});
    if (!r || r.ok === false) {
      if (r && r.message) toast(r.message);
      if (!mdtLoginRendering) mdtRenderLogin({});
      return false;
    }
    if (r.loggedIn) {
      mdtLoggedIn = true;
      mdtRemoveLogin();
      mdtNotifyClientAuthenticated();
      return true;
    }
    if (!mdtLoginRendering) mdtRenderLogin({ pnumber: r.pnumber || '' });
    return false;
  } catch (e) {
    if (!mdtLoginRendering) mdtRenderLogin({});
    return false;
  }
}
function mdtHardCloseVisual(){
  mdtLoggedIn=false; mdtRemoveLogin(); sanCloseDispatchUi(true); showApp(false); setLookThrough(false,false);
}

let lookThroughActive = false;
let mdtLookThroughFocusReleased = false;
let mdtLookThroughNotifyLock = false;

function setLookThrough(active, notify = false){
  active = !!active;
  lookThroughActive = active;
  const app = $('#app');
  if(app){
    // One class controls the WHOLE MDT opacity. Never use pointer-events:none here,
    // otherwise the tablet cannot be clicked again after look-through mode.
    app.classList.toggle('mdt-lookthrough-active', active);
    app.classList.remove('look-through','tap-transparent','mdt-mouse-outside');
  }
  document.documentElement.classList.toggle('mdt-lookthrough-root', active);
  document.documentElement.classList.remove('look-through-root','tap-transparent');
  document.body.classList.toggle('mdt-lookthrough-root', active);
  document.body.classList.remove('look-through-root','tap-transparent');

  if(notify && !mdtLookThroughNotifyLock){
    mdtLookThroughNotifyLock = true;
    nui(active ? 'mdtLookThrough' : 'mdtRestoreFocus', {}).finally(()=>{
      setTimeout(()=>{ mdtLookThroughNotifyLock = false; }, 120);
    });
  }
}

function setMdtLookThroughState({ visual = false, releaseFocus = false, notify = false } = {}){
  mdtLookThroughFocusReleased = !!releaseFocus;
  setLookThrough(!!visual || mdtLookThroughFocusReleased, notify);
}

function toast(input, type = 'info'){
  const payload = typeof input === 'object' && input !== null ? input : { message: String(input || ''), type };
  const itemType = payload.type || type || 'info';
  const title = payload.title || (itemType === 'error' ? 'Ingen adgang' : itemType === 'success' ? 'Succes' : itemType === 'warning' ? 'Advarsel' : 'MDT');
  const message = payload.message || payload.body || String(input || '');
  const source = payload.source || 'MDT';
  const duration = Number(payload.duration || 5200);

  let stack = $('#mdtNotifyStack');
  if(!stack){
    stack = document.createElement('div');
    stack.id = 'mdtNotifyStack';
    const host = $('#app') || document.body;
    host.appendChild(stack);
  }

  const el = document.createElement('div');
  el.className = `mdt-notification mdt-notification--${itemType}`;
  el.style.setProperty('--duration', duration + 'ms');
  el.innerHTML = `
    <div class="mdt-notification__icon">${itemType === 'success' ? '✓' : itemType === 'info' ? 'i' : '!'}</div>
    <div class="mdt-notification__content">
      <div class="mdt-notification__meta"><span>${escapeHtml(source)}</span><strong>${escapeHtml(itemType.toUpperCase())}</strong></div>
      <div class="mdt-notification__title">${escapeHtml(title)}</div>
      ${message ? `<div class="mdt-notification__message">${escapeHtml(message)}</div>` : ''}
      ${duration > 0 ? '<div class="mdt-notification__progress"></div>' : ''}
    </div>
    <button type="button" class="mdt-notification__close" aria-label="Luk notifikation">×</button>`;
  el.querySelector('.mdt-notification__close')?.addEventListener('click', () => el.remove());
  stack.prepend(el);
  [...stack.children].slice(5).forEach(x => x.remove());
  if(duration > 0) setTimeout(() => el.remove(), duration);
}
function escapeHtml(s){ return String(s ?? '').replace(/[&<>'"]/g, m => ({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[m])); }
function safeTagColor(c){ c=String(c||'#00e6b7').trim(); return /^#[0-9a-fA-F]{6}$/.test(c) ? c : '#00e6b7'; }
function tagBadgeStyle(t){ const c=safeTagColor((typeof t==='object'&&t.color)||'#00e6b7'); return `--tag-color:${c};`; }
function textOnly(html){ const d=document.createElement('div'); d.innerHTML=html||''; return d.textContent || d.innerText || ''; }

function validImageUrl(url){
  url = String(url || '').trim();
  return /^https?:\/\//i.test(url) || /^nui:\/\//i.test(url) || /^\.\.?\//.test(url) || /^img\//i.test(url);
}
function profileImageHtml(url, name, cls='profile-img'){
  url = String(url || '').trim();
  if(validImageUrl(url)) return `<img class="${cls}" src="${escapeHtml(url)}" alt="${escapeHtml(name || 'Profilbillede')}" onerror="this.style.display='none';this.nextElementSibling.style.display='grid'">` + `<div class="${cls}-fallback" style="display:none">${escapeHtml((name||'?').slice(0,1).toUpperCase())}</div>`;
  return `<div class="${cls}-fallback">${escapeHtml((name||'?').slice(0,1).toUpperCase())}</div>`;
}
function fmtDate(v){ if(!v) return ''; const d=new Date(v); if(isNaN(d)) return String(v); return d.toLocaleDateString('da-DK')+' '+d.toLocaleTimeString('da-DK',{hour:'2-digit',minute:'2-digit'}); }
function normalizeIncident(i){
  i = i || {};
  const lists = {};
  Object.keys(blankLists).forEach((k) => { lists[k] = Array.isArray(i[k]) ? i[k] : []; });
  return Object.assign({
    id:null, draft:false, incident_no:'---', title:'', description:'', status:'Aktiv', location:'', locked:false,
    created_by:'', created_at:null, updated_at:null, last_edited_by:'', last_edited_at:null
  }, lists, i);
}
function markDirty(){ if(currentIncident) $('#saveState').textContent = 'Ikke gemte ændringer'; }
function updateCountsNoDirty(){ const txt=textOnly($('#incidentEditor')?.innerHTML||''); $('#wordCount').textContent='WORDS: '+(txt.trim()?txt.trim().split(/\s+/).length:0); $('#charCount').textContent='CHARACTERS: '+txt.length; }
function updateCounts(){
  clearTimeout(window.__incidentCountTimer);
  window.__incidentCountTimer = setTimeout(() => { updateCountsNoDirty(); markDirty(); }, 250);
}

const pageLabels = { dashboard:'Forside', profiles:'Profiler', vehicles:'Køretøjsregister', incidents:'Hændelser', reports:'Rapporter', charges:'Sigtelser', fleet:'Flådestyring', nsk_gangs:'NSK · Bander', nsk_observations:'NSK · Observationer', nsk_connections:'NSK · Forbindelser', nsk_activity:'NSK · Aktivitet', files:'Organiserede Filer', admin_tags:'Tags', admin_employees:'Ansatte', admin_roles:'Roller', admin_logs:'MDT-Logs', admin_mail:'Mail System', self_profile:'Min Profil' };
const openTabs = new Set(['dashboard']);
const tabIncidents = {};
let activeTabKey = 'dashboard';
let currentIncidentTabKey = null;
function tabLabel(key){
  if(key.startsWith('incident:')){
    const inc = tabIncidents[key] || currentIncident || {};
    return escapeHtml(inc.title || inc.incident_no || 'Ny rapport');
  }
  return pageLabels[key] || key;
}
function setActiveTab(label, page){
  page = page || Object.keys(pageLabels).find(k => pageLabels[k] === label) || activePage || 'dashboard';
  openTabs.add(page); activeTabKey = page;
  renderTabs(page);
}
function renderTabs(active){
  const tabs = $('#tabs');
  if(!tabs) return;
  const add = $('#topPlus');
  [...tabs.querySelectorAll('.tab:not(.add)')].forEach(t => t.remove());
  [...openTabs].forEach(key => {
    const b = document.createElement('button');
    b.className = 'tab' + (key === active ? ' active' : '');
    b.dataset.tab = key;
    b.innerHTML = `${tabLabel(key)} <span>×</span>`;
    b.onclick = (e) => {
      if(e.target && e.target.tagName === 'SPAN'){
        e.stopPropagation();
        if(openTabs.size > 1){
          openTabs.delete(key); delete tabIncidents[key];
          const next = [...openTabs].pop() || 'dashboard';
          if(next.startsWith('incident:')) openIncident(tabIncidents[next], next); else setPage(next);
        }
        return;
      }
      if(key.startsWith('incident:')) openIncident(tabIncidents[key], key); else setPage(key);
    };
    tabs.insertBefore(b, add || null);
  });
}
function incidentTabKey(i){ return 'incident:' + (i && i.id ? i.id : ('draft-' + (i && i.__draftKey ? i.__draftKey : Date.now()))); }
function setIncidentListMode(listMode){
  const sec = $('#incidents'); if(!sec) return;
  sec.classList.toggle('incident-list-mode', !!listMode);
  sec.classList.toggle('incident-detail-mode', !listMode);
  $('#backToIncidentList')?.classList.toggle('hidden', !!listMode);
  const head = $('#incidentNumber')?.closest('.incident-head');
  if(head) head.classList.toggle('hidden', !!listMode);
}
const NSK_PAGES = ['nsk_gangs','nsk_observations','nsk_connections','nsk_activity'];
const KRIM_PAGES = ['krim_dna','krim_fingerprint'];
function isNskPage(page){ return NSK_PAGES.includes(page); }
function isKrimPage(page){ return KRIM_PAGES.includes(page); }
function syncKrimNavState(page){
  const krimMain = $('.krim-main');
  const krimDrop = $('.krim-dropdown');
  const onKrim = isKrimPage(page) || (page === 'reports' && reportScope === 'krim');
  if(krimMain){
    krimMain.classList.toggle('active', isKrimPage(page) || (page === 'reports' && reportScope === 'krim'));
    if(onKrim){
      krimMain.classList.remove('closed');
      krimDrop && krimDrop.classList.remove('closed');
    }
  }
  $$('.krim-subnav').forEach((b) => b.classList.toggle('active', (page === 'reports' && reportScope === 'krim' && b.dataset.page === 'reports') || b.dataset.page === page));
}
function toggleKrimDropdown(forceOpen){
  const krimMain = $('.krim-main');
  const krimDrop = $('.krim-dropdown');
  if(!krimMain || !krimDrop) return false;
  const open = typeof forceOpen === 'boolean' ? forceOpen : krimDrop.classList.contains('closed');
  if(open){
    krimDrop.classList.remove('closed');
    krimMain.classList.remove('closed');
  } else {
    krimDrop.classList.add('closed');
    krimMain.classList.add('closed');
  }
  return open;
}
function openKrimPage(page){
  toggleKrimDropdown(true);
  if(page === 'reports'){
    reportScope = 'krim';
    setPage('reports');
    return;
  }
  setPage(page || 'krim_dna');
}
async function refreshKrimDna(){
  const search = $('#krimDnaSearch')?.value || '';
  const r = await nui('getKrimDna', { search });
  const box = $('#krimDnaList'); if(!box) return;
  const rows = (r && r.rows) || [];
  if(!rows.length){
    box.innerHTML = '<div class="krim-empty"><b>Ingen DNA registreret</b><span>Søg efter ID eller navn — eller indsamle prøver in-game.</span></div>';
    return;
  }
  box.innerHTML = `<div class="krim-row head"><span>Borger</span><span>DNA-ID</span><span>Indsamlet</span><span>Identifier</span></div>` + rows.map(row => `<div class="krim-row"><span>${escapeHtml(row.name || 'Ukendt')}</span><span>${escapeHtml(row.dna_id || '—')}</span><span>${escapeHtml(fmtDate(row.dna_collected_at) || '—')}</span><span>${escapeHtml(short(row.identifier || '', 28))}</span></div>`).join('');
}
async function refreshKrimFingerprints(){
  const search = $('#krimFpSearch')?.value || '';
  const r = await nui('getKrimFingerprints', { search });
  const box = $('#krimFpList'); if(!box) return;
  const rows = (r && r.rows) || [];
  if(!rows.length){
    box.innerHTML = '<div class="krim-empty"><b>Ingen fingeraftryk registreret</b><span>Søg efter ID eller navn — eller scan in-game.</span></div>';
    return;
  }
  box.innerHTML = `<div class="krim-row head"><span>Borger</span><span>FP-ID</span><span>Indsamlet</span><span>Identifier</span></div>` + rows.map(row => `<div class="krim-row"><span>${escapeHtml(row.name || 'Ukendt')}</span><span>${escapeHtml(row.fingerprint_id || '—')}</span><span>${escapeHtml(fmtDate(row.fingerprint_collected_at) || '—')}</span><span>${escapeHtml(short(row.identifier || '', 28))}</span></div>`).join('');
}
function syncNskNavState(page){
  const nskMain = $('.nsk-main');
  const nskDrop = $('.nsk-dropdown');
  const onNsk = isNskPage(page);
  if(nskMain){
    nskMain.classList.toggle('active', onNsk);
    if(onNsk && mdtNskView){
      nskMain.classList.remove('closed');
      nskDrop && nskDrop.classList.remove('closed');
    }
  }
  if(nskDrop && !mdtNskView) nskDrop.classList.add('closed');
  $$('.nsk-subnav').forEach((b) => b.classList.toggle('active', b.dataset.page === page));
}
function toggleNskDropdown(forceOpen){
  const nskMain = $('.nsk-main');
  const nskDrop = $('.nsk-dropdown');
  if(!nskMain || !nskDrop) return false;
  refreshNskAccess();
  if(!mdtNskView){
    nskDrop.classList.add('closed');
    nskMain.classList.add('closed');
    toast({ type:'error', title:'Ingen adgang', message:'Du mangler NSK-adgang (NSK afdeling, nsk.view eller NSK Chef).' });
    return false;
  }
  const open = typeof forceOpen === 'boolean' ? forceOpen : nskDrop.classList.contains('closed');
  if(open){
    nskDrop.classList.remove('closed');
    nskMain.classList.remove('closed');
  } else {
    nskDrop.classList.add('closed');
    nskMain.classList.add('closed');
  }
  return open;
}
function setPage(page){
  if(!enabledPages[page]) { toast('Dette modul er ikke tilgængeligt endnu.'); return; }
  activePage = page;
  $$('.page').forEach(p => p.classList.toggle('active', p.id === page));
  $$('.nav').forEach(n => n.classList.toggle('active', !isNskPage(page) && !isKrimPage(page) && n.dataset.page === page && !(page === 'reports' && reportScope === 'krim')));
  syncNskNavState(page);
  syncKrimNavState(page);
  // TABFIX: left navigation must not create/switch tabs. Active window state is handled by V27.
  if(typeof renderTabs === 'function') renderTabs(activeTabKey || 'dashboard');
  if(page === 'dashboard' && (Date.now() - (window.__dashboardDataAt || 0) > 5000)) refreshDashboardFromServer();
  if(page === 'incidents') { setIncidentListMode(true); refreshIncidents(); }
  if(page === 'vehicles') { renderVehicleRegistryResults(); if(!activeVehicleProfile) renderVehicleProfileEmpty(); }
  if(page === 'profiles') { setProfileListMode(!activeProfile); refreshProfiles(); }
  if(page === 'admin_employees') refreshEmployees();
  if(page === 'admin_roles') refreshRoles();
  if(page === 'admin_tags') renderAdminTags();
  if(page === 'admin_logs') refreshAuditLogs();
  if(page === 'admin_mail') refreshMailSystem();
  if(page === 'self_profile') refreshSelfProfile();
  if(page === 'charges') refreshCharges();
  if(page === 'krim_dna') refreshKrimDna();
  if(page === 'krim_fingerprint') refreshKrimFingerprints();
  if(page === 'reports') renderReportsPage();
  if(page === 'fleet') refreshFleet();
  else stopFleetPolling();
  if(page === 'nsk_gangs'){
    refreshNskOverview();
    requestAnimationFrame(() => { ensureNskMap(); applyNskMapView(); });
  }
  if(page === 'nsk_observations') refreshNskObservations();
  if(page === 'nsk_connections') refreshNskConnections();
  if(page === 'nsk_activity') refreshNskActivity();
  if(page === 'files') refreshFilesPage();
}




function renderIncidentList(){
  const box = $('#recentIncidents'); if(!box) return;
  box.innerHTML = '';
  if(!incidents.length){
    box.innerHTML = '<div class="incident-wide-card empty-card no-click"><b>Ingen hændelser fundet</b><small>Ingen rapporter matcher din søgning.</small></div>';
    return;
  }
  incidents.forEach(i => {
    i = normalizeIncident(i);
    const el = document.createElement('div');
    el.className = 'incident-wide-card' + (currentIncident && currentIncident.id === i.id ? ' active' : '');
    const no = escapeHtml(i.incident_no || 'KLADDE');
    const tags = Array.isArray(i.tags) ? i.tags.slice(0,4) : [];
    const tagHtml = tags.length ? tags.map(t => { const name = (typeof t === 'object' ? t.name : t) || 'Tag'; return `<span class="incident-tag-chip" style="${tagBadgeStyle(t)}"><b>${escapeHtml(name)}</b></span>`; }).join('') : '<span class="incident-tag-chip muted">Ingen tags</span>';
    const rmeta = currentReportTypeMeta(i);
    el.innerHTML = `<div class="card-main"><div class="card-title"><b>${escapeHtml(i.title || 'Ny rapport')}</b><span>${escapeHtml(rmeta.badge)}</span></div><div class="card-meta"><span class="idpill">ID: ${no}</span><span>Oprettet af: ${escapeHtml(i.created_by || 'Ukendt')}</span><span>${escapeHtml(fmtDate(i.created_at) || 'Ingen dato')}</span></div><div class="card-meta edited-meta"><span>Senest redigeret af: ${escapeHtml(i.last_edited_by || i.created_by || 'Ingen')}</span><span>${escapeHtml(fmtDate(i.last_edited_at || i.updated_at) || 'Aldrig')}</span></div></div><div class="card-tags">${tagHtml}</div>`;
    el.onauxclick = (ev) => { if(ev.button === 1){ ev.preventDefault(); openIncidentPopup(i); } };
    el.onclick = (ev) => { if(ev.shiftKey || ev.ctrlKey){ openIncidentPopup(i); return; } openIncident(i); };
    box.appendChild(el);
  });
}

function openIncident(i, tabKey = null){
  currentIncident = normalizeIncident(i);
  currentIncidentTabKey = tabKey || incidentTabKey(currentIncident);
  tabIncidents[currentIncidentTabKey] = currentIncident;
  openTabs.add(currentIncidentTabKey); activeTabKey = currentIncidentTabKey;
  $$('.page').forEach(p => p.classList.toggle('active', p.id === 'incidents'));
  $$('.nav').forEach(n => n.classList.toggle('active', n.dataset.page === 'incidents'));
  renderTabs(currentIncidentTabKey);
  setIncidentListMode(false);
  $('#incidentNumber').textContent = currentIncident.draft ? 'KLADDE' : (currentIncident.incident_no || '---');
  $('#incidentCreated').textContent = currentIncident.draft ? 'Ny kladde - ikke gemt endnu' : `Oprettet af ${currentIncident.created_by || 'Ukendt'} - ${fmtDate(currentIncident.created_at)} · Senest redigeret af ${currentIncident.last_edited_by || currentIncident.created_by || 'Ingen'} - ${fmtDate(currentIncident.last_edited_at || currentIncident.updated_at) || 'Aldrig'}`;
  $('#incidentOfficer').textContent = currentIncident.officers?.[0]?.name ? `Betjente i hændelsen: ${currentIncident.officers[0].name}` : '';
  $('#saveState').textContent = currentIncident.draft ? 'Kladde - ikke gemt endnu' : 'Ingen ændringer at gemme';
  $('#incidentTitle').value = currentIncident.title || '';
    $('#incidentEditor').innerHTML = currentIncident.description || '';
  syncIncidentDeleteButton();
  renderLists();
  renderIncidentList();
  updateCountsNoDirty();
}
async function refreshIncidents(){
  const r = await nui('getIncidents', { search: $('#incidentSearch')?.value || '' });
  if(r && r.incidents) {
    if(typeof r.canDelete === 'boolean') mdtCanDeleteIncident = r.canDelete;
    incidents = r.incidents.map(normalizeIncident);
    renderIncidentList();
    syncIncidentDeleteButton();
  }
  else toast(r?.message || 'Kunne ikke hente hændelser.');
}
function newIncident(){
  const officer = $('#officerName')?.textContent || 'Betjent';
  currentIncident = normalizeIncident({
    id:null, draft:true, __draftKey:Date.now(), incident_no:'KLADDE', report_type:'incident', title:'Ny hændelse', description:reportTypeTemplates.incident.body, status:'Aktiv', location:'',
    objects:[], criminals:[], tags:[], evidence:[], officers:[{name:officer}], civilians:[], vehicles:[], references:[],
    created_by:officer, created_at:null, updated_at:null, last_edited_by:'', last_edited_at:null, locked:false
  });
  setPage('incidents');
  openIncident(currentIncident, incidentTabKey(currentIncident));
}
function collectIncident(){ if(!currentIncident) return null; const inc = Object.assign({}, currentIncident, { title: $('#incidentTitle').value, report_type: currentIncident.report_type || 'incident', description: $('#incidentEditor').innerHTML }); if(currentIncidentTabKey) tabIncidents[currentIncidentTabKey]=inc; return inc; }
async function saveIncident(){
  const inc = collectIncident();
  if(!inc){ toast('Ingen hændelse valgt.'); return; }
  const btn = $('#saveIncident'); const old = btn.textContent;
  btn.disabled = true; btn.textContent = 'Gemmer...';
  try{
    const r = await nui('saveIncident', { incident: inc });
    if (r && r.ok){
      currentIncident = normalizeIncident(r.incident || inc); currentIncident.draft = false;
      if(currentIncidentTabKey){ delete tabIncidents[currentIncidentTabKey]; openTabs.delete(currentIncidentTabKey); }
      currentIncidentTabKey = incidentTabKey(currentIncident); tabIncidents[currentIncidentTabKey]=currentIncident; openTabs.add(currentIncidentTabKey);
      $('#saveState').textContent = 'Ingen ændringer at gemme';
      await refreshIncidents();
      openIncident(currentIncident, currentIncidentTabKey);
      toast(r.message || 'Hændelse gemt.');
    } else toast(r?.message || 'Kunne ikke gemme.');
  } finally { btn.disabled = false; btn.textContent = old; }
}
async function deleteIncident(){
  if(!currentIncident) return;
  if(currentIncident.draft || !currentIncident.id){
    currentIncident=null;
    setIncidentListMode(true);
    renderIncidentList();
    toast('Kladde lukket.');
    return;
  }

  // Ingen browser-confirm her. CEF/FiveM kan låse NUI ved native confirm-dialogs.
  const btn = $('#deleteIncident');
  const oldText = btn.textContent;
  const id = currentIncident.id;
  btn.disabled = true;
  btn.textContent = 'Sletter...';

  try{
    const r = await nui('deleteIncident', { id });
    if(r && r.ok){
      incidents = incidents.filter(x => Number(x.id) !== Number(id));
      currentIncident = null;
      setIncidentListMode(true);
      renderIncidentList();
      toast(r.message || 'Hændelsen er slettet.');
      setTimeout(refreshIncidents, 600);
    } else {
      toast(r?.message || 'Kunne ikke slette hændelsen.');
    }
  } catch(e){
    console.error(e);
    toast('Fejl ved sletning. UI er låst op igen.');
  } finally {
    btn.disabled = false;
    btn.textContent = oldText;
  }
}


function getPersonCharges(person){
  if(!person) return [];
  if(!Array.isArray(person.mdtCharges)) person.mdtCharges = [];
  return person.mdtCharges;
}
function addChargeToPerson(person, charge){
  const arr = getPersonCharges(person);
  const found = arr.find(x => String(x.id||'') === String(charge.id||'') || (String(x.paragraph||'') === String(charge.paragraph||'') && String(x.name||'') === String(charge.name||'')));
  if(found){ found.count = Number(found.count||1) + 1; }
  else arr.push({ id:charge.id, paragraph:charge.paragraph, name:charge.name, description:charge.description, category:charge.category, law_group:charge.law_group||'', jail:Number(charge.jail||0), fine:Number(charge.fine||0), points:Number(charge.points||0), revocation:charge.revocation||'', impound: !!(charge.impound || charge.vehicle_impound || charge.vehicleSeizure), count:1 });
  person.charges = arr.reduce((a,c)=>a+Number(c.count||1),0);
}
function personPenaltyTotals(person){
  const arr = getPersonCharges(person);
  const red = person.chargeReduction || { jail:0, fine:0, points:0 };
  const base = arr.reduce((a,c)=>{ const n=Number(c.count||1); a.jail += Number(c.jail||0)*n; a.fine += Number(c.fine||0)*n; a.points += Number(c.points||0)*n; if(c.revocation) a.revocation.add(c.revocation); return a; }, {jail:0,fine:0,points:0,revocation:new Set()});
  return { base, final:{ jail:Math.max(0,base.jail-Number(red.jail||0)), fine:Math.max(0,base.fine-Number(red.fine||0)), points:Math.max(0,base.points-Number(red.points||0)), revocation:[...base.revocation].join(', ') || 'Ingen' } };
}
function personFineStatusHtml(person, idx, totals){
  const inv = person && person.invoice;
  if(inv){
    const paid = !!inv.paid;
    const when = inv.issued_at ? String(inv.issued_at).slice(0, 16).replace('T', ' ') : '';
    return `<div class="person-fine-box issued"><div class="person-fine-status ${paid ? 'paid' : 'pending'}"><b>${paid ? 'Bøde betalt' : 'Bøde udstedt'}</b><small>${money(Number(inv.amount||0))}${when ? ` · ${escapeHtml(when)}` : ''}${inv.issued_by ? ` · ${escapeHtml(inv.issued_by)}` : ''}</small></div></div>`;
  }
  const canIssue = !!(person && person.identifier) && totals.final.fine > 0 && !!(currentIncident && currentIncident.id);
  const hint = !currentIncident?.id ? 'Gem hændelsen først.' : (!person?.identifier ? 'Tilføj person via profil-søgning.' : (totals.final.fine <= 0 ? 'Ingen bøde at udstede.' : ''));
  return `<div class="person-fine-box"><button type="button" class="save small" data-person-issue-fine="${idx}" ${canIssue ? '' : 'disabled'}>Udsted bøde (${money(totals.final.fine)})</button>${hint ? `<small class="person-fine-hint">${escapeHtml(hint)}</small>` : ''}</div>`;
}
async function issuePersonFine(personIdx){
  const person = currentIncident?.criminals?.[personIdx];
  if(!person){ toast('Person ikke fundet.'); return; }
  if(!currentIncident?.id){ toast('Gem hændelsen først, før du udsteder bøde.'); return; }
  if(person.invoice){ toast('Bøde er allerede udstedt til denne person på hændelsen.'); return; }
  const totals = personPenaltyTotals(person);
  if(totals.final.fine <= 0){ toast('Der er ingen bøde at udstede.'); return; }
  if(!person.identifier){ toast('Personen mangler identifier — tilføj via profil-søgning.'); return; }
  const btn = document.querySelector(`[data-person-issue-fine="${personIdx}"]`);
  const old = btn ? btn.textContent : '';
  if(btn){ btn.disabled = true; btn.textContent = 'Udsteder...'; }
  try{
    const r = await nui('issueIncidentFine', { incidentId: currentIncident.id, personIndex: personIdx });
    if(r && r.ok){
      person.invoice = r.invoice || person.invoice;
      person.chargeFlags = person.chargeFlags || { wanted:false, handled:false, indictment:false };
      person.chargeFlags.handled = true;
      renderLists();
      toast(r.message || 'Bøde udstedt.');
    } else {
      toast(r?.message || 'Kunne ikke udstede bøde.');
    }
  } finally {
    if(btn){ btn.disabled = false; btn.textContent = old || `Udsted bøde (${money(totals.final.fine)})`; }
  }
}
function criminalChargePanel(person, idx){
  const arr = getPersonCharges(person);
  const totals = personPenaltyTotals(person);
  const totalExtra = `${totals.final.points > 0 ? `<span>${totals.final.points} klip</span>` : ''}${hasChargeRevocation({revocation: totals.final.revocation}) ? `<span>${escapeHtml(totals.final.revocation)}</span>` : ''}${arr.some(c=>c && c.impound) ? `<span>Beslaglæggelse af køretøj</span>` : ''}`;
  const toolbarExtra = `${totals.final.points > 0 ? ` | ${totals.final.points} klip` : ''}${hasChargeRevocation({revocation: totals.final.revocation}) ? ` | ${escapeHtml(totals.final.revocation)}` : ''}${arr.some(c=>c && c.impound) ? ` | Beslaglæggelse af køretøj` : ''}`;
  const rows = arr.length ? arr.map((c,i)=>{ const meta = chargeCategoryMeta[c.category||'green'] || chargeCategoryMeta.green; const n=Number(c.count||1); const extras = `${Number(c.points||0)*n > 0 ? ` · ${Number(c.points||0)*n} klip` : ''}${hasChargeRevocation(c) ? ` · ${escapeHtml(chargeRevocationText(c))}` : ''}${c.impound ? ' · Beslaglæggelse af køretøj' : ''}`; return `<div class="person-charge-line charge-${escapeHtml(meta.cls)}" data-person-charge-detail="${idx}:${i}"><div><b>${n}x § ${escapeHtml(c.paragraph||'?')} ${escapeHtml(c.name||'Sigtelse')}</b><small>${Number(c.jail||0)*n} mdr · ${money(Number(c.fine||0)*n)}${extras}</small></div><button class="tiny danger" data-person-charge-remove="${idx}:${i}">Fjern</button></div>`; }).join('') : '<div class="person-charge-empty">Ingen sigtelser på denne person.</div>';
  const red = person.chargeReduction || {jail:0,fine:0,points:0};
  const flags = person.chargeFlags || { wanted:false, handled:false, indictment:false };
  return `<div class="criminal-charge-panel">
    <div class="person-charge-toolbar"><button class="save small" data-person-add-charge="${idx}">+ Tilføj sigtelse</button><span>Total ${totals.final.jail} måneder | ${money(totals.final.fine)}${toolbarExtra}</span></div>
    <div class="person-charge-list">${rows}</div>
    <div class="person-total-box"><b>Total</b><span>${totals.final.jail} måneder</span><span>${money(totals.final.fine)}</span>${totalExtra}</div>
    <div class="person-reduction-box"><label>Nedsættelse af straf</label><div><input data-reduction="${idx}:jail" type="number" min="0" value="${Number(red.jail||0)}" placeholder="Tid"><input data-reduction="${idx}:fine" type="number" min="0" value="${Number(red.fine||0)}" placeholder="Bøde"><input data-reduction="${idx}:points" type="number" min="0" value="${Number(red.points||0)}" placeholder="Klip"></div><small>Nedsættelser kan ikke sænke under 0.</small></div>
    ${personFineStatusHtml(person, idx, totals)}
    ${personLicenseSanctionActionHtml(person, idx, totals, arr)}
    <div class="person-toggle-box"><label>Efterlyst <button class="toggle ${flags.wanted?'on':'off'}" data-person-flag="${idx}:wanted"><span></span></button></label><label>Behandlet <button class="toggle ${flags.handled?'on':'off'}" data-person-flag="${idx}:handled"><span></span></button></label><label>Tilkendegivelse <button class="toggle ${flags.indictment?'on':'off'}" data-person-flag="${idx}:indictment"><span></span></button></label></div>
  </div>`;
}
function openPersonChargeDetail(personIdx, chargeIdx){
  const person = currentIncident?.criminals?.[personIdx];
  const c = getPersonCharges(person)[chargeIdx];
  if(!c) return;
  const meta = chargeCategoryMeta[c.category||'green'] || chargeCategoryMeta.green;
  const law = chargeLawGroup(c);
  $('#modalTitle').textContent = `§ ${c.paragraph || '?'} - ${c.name || 'Sigtelse'}`;
  $('#modalFields').innerHTML = `<div class="charge-detail-modal charge-${escapeHtml(meta.cls)}"><p class="charge-law-label">${escapeHtml(law.label)}</p><p>${escapeHtml(c.description || 'Ingen beskrivelse.')}</p>${chargePenaltyHtml(c)}</div>`;
  $('#modalSave').style.display = 'none';
  $('#modal').classList.remove('hidden');
}
function itemHtml(type, item, idx){
  if(type === 'tags') { return `<span class="tag case-tag" style="${tagBadgeStyle(item)}" data-tag-info="${idx}"><b>${escapeHtml(item.name || item)}</b><button data-remove="${type}" data-idx="${idx}">×</button></span>`; }
  if(type === 'criminals') {
    const charges = getPersonCharges(item);
    const expanded = activeCriminalChargesIndex === idx;
    const chargeCount = charges.reduce((a,c)=>a+Number(c.count||1),0);
    return `<div class="criminal-wrap ${expanded ? 'open' : ''}"><div class="item criminal-pill" data-criminal-open="${idx}"><div><b>${escapeHtml(item.name || 'Ukendt')}</b><small>${escapeHtml(item.dob || 'Ingen fødselsdato')} · ${chargeCount} sigtelser</small></div><div class="item-actions"><button class="iconbtn" data-criminal-profile="${idx}" title="Åbn profil">▣</button><button class="iconbtn" data-criminal-charges="${idx}" title="Se/tilføj sigtelser">⚒</button><button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>${expanded ? criminalChargePanel(item, idx) : ''}</div>`;
  }
  if(type === 'civilians') return `<div class="item civilian-pill"><div><b>${escapeHtml(item.name || 'Ukendt borger')}</b><small>${escapeHtml(item.dob || 'Ingen fødselsdato')} · ${escapeHtml(item.phone || 'Ingen telefon')}</small></div><div class="item-actions"><button class="iconbtn" data-civilian-profile="${idx}" title="Åbn profil">▣</button><button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>`;
  if(type === 'charges') {
    const meta = chargeCategoryMeta[item.category || 'green'] || chargeCategoryMeta.green;
    return `<div class="item incident-charge-card charge-card charge-${escapeHtml(meta.cls)}" data-incident-charge="${idx}">
      <div class="charge-topline"><span class="charge-category">${escapeHtml(meta.label)}</span><span class="charge-paragraph">§ ${escapeHtml(item.paragraph || '?')}</span></div>
      <div class="charge-title-row"><h3>${escapeHtml(item.name || 'Sigtelse')}</h3><div class="item-actions"><button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>
      <p>${escapeHtml(item.description || 'Ingen beskrivelse.')}</p>
      ${chargePenaltyHtml(item)}
    </div>`;
  }
  if(type === 'evidence') {
    const flags = [
      item.acknowledged ? 'Erkender' : 'Erkender ikke',
      item.secured ? 'Sikret' : 'Ikke sikret',
      item.attached ? 'Vedlagt' : 'Ikke vedlagt'
    ];
    return `<div class="item evidence-card-modern"><div><b>${escapeHtml(item.name || item.title || 'Bevis')}</b><small>${escapeHtml(item.kind || 'Bevis')} ${item.note ? '· '+escapeHtml(item.note) : ''}</small><div class="evidence-badges">${flags.map((f,i)=>`<span class="evidence-badge ${((i===0&&item.acknowledged)||(i===1&&item.secured)||(i===2&&item.attached))?'on':'off'}">${escapeHtml(f)}</span>`).join('')}</div></div><div class="item-actions"><button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>`;
  }
  if(type === 'vehicles') return `<div class="item vehicle-pill" data-incident-vehicle="${idx}" title="Venstreklik: åbn køretøjsprofil"><div><b>${escapeHtml(item.plate || item.name || 'Ukendt køretøj')}</b><small><strong>${escapeHtml(item.model || item.vehicleName || 'Ukendt model')}</strong> · Type: ${escapeHtml(item.type || 'Ukendt type')} · Ejer: ${escapeHtml(item.ownerName || item.owner || 'Ukendt')} ${item.status ? '· '+escapeHtml(item.status) : ''}</small></div><div class="item-actions">${item.owner ? `<button class="iconbtn" data-vehicle-owner-profile="${idx}" title="Åbn ejerprofil">▣</button>` : ''}<button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>`;
  if(type === 'officers') return `<div class="item officer-pill"><div><b>${escapeHtml(item.name || 'Ukendt betjent')}</b><small>${escapeHtml(item.badge || formatPoliceBadge(item.pnumber, item.division) || item.rank || item.role || 'Politi')}${item.division ? ` · ${escapeHtml(item.division)}` : ''}</small></div><div class="item-actions">${item.identifier ? `<button class="iconbtn" data-incident-officer-profile="${idx}" title="Åbn profil">▣</button>` : ''}<button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>`;
  return `<div class="item"><div><b>${escapeHtml(item.name || item.title || item.plate || item || 'Objekt')}</b>${item.note ? `<small>${escapeHtml(item.note)}</small>` : ''}</div><div class="item-actions"><button class="iconbtn red" data-remove="${type}" data-idx="${idx}">🗑</button></div></div>`;
}

function openTagInfo(idx){
  if(!currentIncident) return;
  const tag = (currentIncident.tags || [])[idx];
  if(!tag) return;
  const name = typeof tag === 'string' ? tag : (tag.name || 'Tag');
  const kind = typeof tag === 'string' ? 'Ukendt' : (tag.kind || 'Ukendt');
  const color = typeof tag === 'string' ? '#00e6b7' : (tag.color || '#00e6b7');
  const info = typeof tag === 'string' ? '' : (tag.info || tag.note || tag.description || 'Ingen ekstra information på dette tag.');
  $('#modalTitle').textContent = 'Tag information';
  $('#modalFields').innerHTML = `<div class="tag-info-box tag-info-rich" style="--tag-color:${escapeHtml(color)}"><div class="tag-info-top"><span class="tag-info-badge" style="background:${escapeHtml(color)};border-color:${escapeHtml(color)}"><b>${escapeHtml(name)}</b></span></div><div class="tag-info-data"><label>Type</label><b>${escapeHtml(kind)}</b><label>Information</label><p>${escapeHtml(info || 'Ingen ekstra note på dette tag.')}</p></div></div>`;
  $('#modalSave').style.display = 'none';
  $('#modal').classList.remove('hidden');
}

function renderPenaltySummary(){
  const el = $('#incidentPenaltySummary');
  if(!el || !currentIncident) return;
  const arr = currentIncident.charges || [];
  if(!arr.length){ el.innerHTML = ''; return; }
  const fine = arr.reduce((a,c)=>a+Number(c.fine||0),0);
  const jail = arr.reduce((a,c)=>a+Number(c.jail||0),0);
  el.innerHTML = `<div class="incident-penalty-grid"><span><small>Samlet bøde</small><b>${money(fine)}</b></span><span><small>Fængsel</small><b>${jail} mdr</b></span>${chargeSummaryExtraHtml(arr)}</div>`;
}

function renderLists(){
  if(!currentIncident) currentIncident = normalizeIncident({});
  Object.keys(blankLists).forEach(type => {
    const el = $('#'+type+'Items'); if(!el) return;
    const arr = currentIncident[type] || [];
    const emptyNames = { objects:'objekter tilføjet', criminals:'kriminelle', charges:'sigtelser', tags:'tags', evidence:'beviser', officers:'betjente', civilians:'borgere', vehicles:'køretøjer', references:'referencer' };
    if(type === 'charges' && arr.length){
      const visible = incidentChargesExpanded ? arr : arr.slice(0,5);
      const toggle = arr.length > 5 ? `<button class="charge-toggle" data-toggle-incident-charges>${incidentChargesExpanded ? 'Vis færre ▲' : `Vis alle ${arr.length} ▼`}</button>` : '';
      el.innerHTML = visible.map((it,idx)=>itemHtml(type,it,idx)).join('') + toggle;
    } else {
      el.innerHTML = arr.length ? arr.map((it,idx)=>itemHtml(type,it,idx)).join('') : `Ingen ${emptyNames[type] || type}`;
    }
  });
  renderPenaltySummary();
}
function closeModal(){
  $('#modal')?.classList.remove('modal-charge-picker','nsk-modal');
  if(pendingSeenMailIds && pendingSeenMailIds.size){
    Array.from(pendingSeenMailIds).forEach(id => markMailSeenFast(id));
    pendingSeenMailIds.clear();
  }
  const m = $('#modal');
  if(m) m.classList.add('hidden');
  const save = $('#modalSave');
  const cancel = $('#modalCancel'); if(cancel){ cancel.textContent = 'Annuller'; cancel.style.display = ''; }
  if(save){ save.style.display = ''; save.disabled = false; save.textContent = 'Tilføj'; save.onclick = null; }
  criminalSearchResults = [];
  civilianSearchResults = [];
  vehicleSearchResults = [];
}

function renderChargePickerSidePanel(){
  const persons = $('#chargePickerPersons');
  const vehs = $('#chargePickerVehicles');
  if (!persons && !vehs) return;
  const criminals = currentIncident?.criminals || [];
  const vehicles = currentIncident?.vehicles || [];
  if (persons) {
    persons.innerHTML = criminals.length ? criminals.map((p) => `<div class="charge-side-item"><b>${escapeHtml(p.name || 'Ukendt')}</b><small>${escapeHtml(p.dob || '')}</small></div>`).join('') : '<div class="charge-side-empty">Ingen personer endnu.</div>';
  }
  if (vehs) {
    vehs.innerHTML = vehicles.length ? vehicles.map((car) => `<div class="charge-side-item"><b>${escapeHtml(car.plate || 'Ukendt')}</b><small>${escapeHtml(car.model || 'Ukendt model')} · ${escapeHtml(car.ownerName || car.owner || '')}</small></div>`).join('') : '<div class="charge-side-empty">Ingen køretøjer endnu.</div>';
  }
}

function incidentChargePickerShellHtml(){
  return `
    <div class="charge-pick-layout">
      <div class="charge-pick-shell">
        <div class="charge-pick-head">
          <input id="incidentChargeSearch" placeholder="Søg paragraf, sigtelse, kategori eller beskrivelse...">
          <small>Klik på sigtelser for at vælge dem. Tryk <b>Tilføj sigtelser</b> for at gemme, eller <b>Luk</b> for at annullere.</small>
        </div>
        <div id="incidentChargePickList" class="incident-charge-picker modern scums-grid scums-grouped"><div class="admin-empty">Henter sigtelser...</div></div>
      </div>
      <aside class="charge-pick-side">
        <div class="charge-side-box charge-selected-box">
          <h4>VALGTE SIGTELSER</h4>
          <div id="chargePickerSelected" class="charge-selected-list"><div class="charge-side-empty">Ingen sigtelser valgt endnu.</div></div>
          <div id="chargePickerStatus" class="charge-picker-status">0 valgt · Total 0 mdr | 0 kr.</div>
        </div>
        <div class="charge-side-box">
          <h4>TILFØJ PERSON</h4>
          <div id="chargePickerPersons" class="charge-side-list"></div>
          <button type="button" class="ghost small" data-charge-add-person>+ Tilføj person</button>
        </div>
        <div class="charge-side-box">
          <h4>KØRETØJ</h4>
          <div id="chargePickerVehicles" class="charge-side-list"></div>
          <button type="button" class="ghost small" data-charge-add-vehicle>+ Tilføj køretøj</button>
        </div>
      </aside>
    </div>`;
}

async function openIncidentChargePicker(personIndex = null){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  const personMode = personIndex !== null && currentIncident.criminals && currentIncident.criminals[personIndex];
  const selected = [];

  $('#modalTitle').textContent = personMode ? 'Tilføj sigtelser til person' : 'Tilføj sigtelser';
  $('#modal').classList.add('modal-charge-picker');
  $('#modalFields').innerHTML = incidentChargePickerShellHtml();
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Tilføj sigtelser';
  $('#modalSave').disabled = true;
  const cancel = $('#modalCancel');
  if(cancel){ cancel.style.display = ''; cancel.textContent = 'Luk'; cancel.onclick = closeModal; }
  $('#modal').classList.remove('hidden');

  let charges = Array.isArray(mdtCharges) && mdtCharges.length ? mdtCharges : null;
  if(!charges){
    try {
      const r = await nui('getCharges', { search:'' });
      charges = (r && r.charges) || [];
      mdtCharges = charges;
    } catch (_) {
      charges = [];
    }
  }
  const pickerRows = buildChargePickerRows(charges);

  const selectedKey = (c) => String(c.id || `${c.paragraph || ''}-${c.name || ''}`);
  const selectedSet = () => new Set(selected.map(selectedKey));
  const selectedTotals = () => selected.reduce((a,c)=>{
    a.jail += Number(c.jail||0);
    a.fine += Number(c.fine||0);
    a.points += Number(c.points||0);
    if(hasChargeRevocation(c)) a.revocations.add(chargeRevocationText(c));
    if(c && (c.impound || c.vehicle_impound || c.vehicleSeizure)) a.impounds += 1;
    return a;
  }, {jail:0, fine:0, points:0, revocations:new Set(), impounds:0});

  const updateStatus = () => {
    const t = selectedTotals();
    const extra = `${t.points > 0 ? ` | ${t.points} klip` : ''}${t.revocations.size ? ` | Frakendelse` : ''}${t.impounds ? ` | Beslaglæggelse ${t.impounds}` : ''}`;
    const statusEl = $('#chargePickerStatus');
    if(statusEl) statusEl.textContent = `${selected.length} valgt · Total ${t.jail} mdr | ${money(t.fine)}${extra}`;
    const selectedEl = $('#chargePickerSelected');
    if(selectedEl){
      if(!selected.length){
        selectedEl.innerHTML = '<div class="charge-side-empty">Ingen sigtelser valgt endnu.</div>';
      } else {
        selectedEl.innerHTML = selected.map((c) => {
          const meta = chargeCategoryMeta[c.category || 'green'] || chargeCategoryMeta.green;
          const extras = [];
          if(Number(c.points || 0) > 0) extras.push(`${Number(c.points)} klip`);
          if(hasChargeRevocation(c)) extras.push(chargeRevocationText(c));
          if(c.impound || c.vehicle_impound || c.vehicleSeizure) extras.push('Beslaglæggelse');
          const extraLine = extras.length ? ` · ${extras.join(' · ')}` : '';
          const key = selectedKey(c);
          return `<div class="charge-selected-item charge-${escapeHtml(meta.cls)}"><div><b>§ ${escapeHtml(c.paragraph || '?')} ${escapeHtml(c.name || 'Sigtelse')}</b><small>${Number(c.jail || 0)} mdr · ${money(Number(c.fine || 0))}${escapeHtml(extraLine)}</small></div><button type="button" class="tiny danger" data-charge-selected-remove="${escapeHtml(key)}" title="Fjern">×</button></div>`;
        }).join('');
      }
    }
    const save = $('#modalSave');
    if(save) save.disabled = selected.length === 0;
  };

  const drawChargeList = () => {
    const box = $('#incidentChargePickList');
    if(!box) return;
    const q = ($('#incidentChargeSearch')?.value || '').toLowerCase().trim();
    const filtered = q ? pickerRows.filter((row) => row.searchHay.includes(q)) : pickerRows;
    if(!filtered.length){
      box.innerHTML = '<div class="admin-empty">Ingen sigtelser fundet.</div>';
      return;
    }
    const grouped = new Map();
    filtered.forEach((row) => {
      if(!grouped.has(row.lawKey)) grouped.set(row.lawKey, { label: row.lawLabel, items: [] });
      grouped.get(row.lawKey).items.push(row);
    });
    const picked = selectedSet();
    const sections = [];
    CHARGE_LAW_ORDER.forEach((key) => {
      const group = grouped.get(key);
      if(!group) return;
      grouped.delete(key);
      sections.push(`<section class="charge-picker-group"><div class="charge-picker-group-title"><span>${escapeHtml(group.label)}</span><b>${group.items.length} sigtelser</b></div><div class="charge-picker-grid">${group.items.map((row) => chargePickerCardHtml(row, picked.has(row.key))).join('')}</div></section>`);
    });
    grouped.forEach((group) => {
      sections.push(`<section class="charge-picker-group"><div class="charge-picker-group-title"><span>${escapeHtml(group.label)}</span><b>${group.items.length} sigtelser</b></div><div class="charge-picker-grid">${group.items.map((row) => chargePickerCardHtml(row, picked.has(row.key))).join('')}</div></section>`);
    });
    box.innerHTML = sections.join('');
  };

  $('#modalSave').onclick = () => {
    selected.forEach(c => {
      if(personMode){
        addChargeToPerson(currentIncident.criminals[personIndex], c);
        activeCriminalChargesIndex = personIndex;
      } else {
        currentIncident.charges = currentIncident.charges || [];
        currentIncident.charges.push({ id:c.id, paragraph:c.paragraph, name:c.name, description:c.description, category:c.category, jail:Number(c.jail||0), fine:Number(c.fine||0), points:Number(c.points||0), revocation:c.revocation || '', impound: !!(c.impound || c.vehicle_impound || c.vehicleSeizure) });
      }
    });
    if(selected.length){
      incidentChargesExpanded = false;
      renderLists();
      markDirty();
      toast(`${selected.length} sigtelse${selected.length === 1 ? '' : 'r'} tilføjet.`, 'success');
    }
    closeModal();
  };

  renderChargePickerSidePanel();
  drawChargeList();
  updateStatus();

  const searchInput = $('#incidentChargeSearch');
  if(searchInput){
    searchInput.oninput = () => {
      clearTimeout(window.__chargePickSearchTimer);
      window.__chargePickSearchTimer = setTimeout(drawChargeList, 100);
    };
    setTimeout(() => searchInput.focus(), 30);
  }

  $('#modalFields').onclick = (e) => {
    const removeBtn = e.target.closest('[data-charge-selected-remove]');
    if(removeBtn){
      const key = removeBtn.dataset.chargeSelectedRemove;
      const found = selected.findIndex((x) => selectedKey(x) === key);
      if(found >= 0) selected.splice(found, 1);
      drawChargeList();
      updateStatus();
      return;
    }
    if (e.target.closest('[data-charge-add-person]')) { openPersonSearchModal('criminals'); return; }
    if (e.target.closest('[data-charge-add-vehicle]')) { openVehicleSearchModal(); return; }
  };

  const pickList = $('#incidentChargePickList');
  if(pickList){
    pickList.onclick = (e) => {
      const btn = e.target.closest('[data-pick-charge]');
      if(!btn) return;
      const c = charges[Number(btn.dataset.pickCharge)];
      if(!c) return;
      const key = selectedKey(c);
      const found = selected.findIndex((x) => selectedKey(x) === key);
      if(found >= 0){
        selected.splice(found, 1);
        btn.classList.remove('picked', 'selected');
      } else {
        selected.push(c);
        btn.classList.add('picked', 'selected');
      }
      updateStatus();
    };
  }
}

function openEvidenceAddModal(){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  $('#modalTitle').textContent = 'Tilføj bevis';
  $('#modalFields').innerHTML = `<div class="evidence-form-modern">
    <div class="evidence-row"><label>Type</label><select id="evidenceKind"><option>Billede</option><option>Video/bodycam</option><option>DNA</option><option>Fingeraftryk</option><option>Vidneudsagn</option><option>Dokument</option><option>Lokation/GPS</option><option>Våben/fund</option><option>Andet</option></select></div>
    <label>Navn</label><input id="evidenceName" placeholder="Fx Bodycam fra anholdelse">
    <label>Notat / link / reference</label><textarea id="evidenceNote" placeholder="Skriv noter, URL, beskrivelse eller reference..."></textarea>
  </div>`;
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Tilføj';
  $('#modalSave').onclick = () => {
    const name = ($('#evidenceName')?.value || '').trim();
    if(!name){ toast('Skriv et navn på beviset.'); return; }
    currentIncident.evidence = currentIncident.evidence || [];
    currentIncident.evidence.push({
      kind:$('#evidenceKind')?.value || 'Bevis',
      name,
      note:$('#evidenceNote')?.value || '',
      acknowledged:false,
      secured:false,
      attached:false,
      followup:false
    });
    renderLists(); markDirty(); closeModal();
  };
}


function saveLocalTags(){ localStorage.setItem('san_mdt_tags_v1', JSON.stringify(mdtTags || [])); }
function tagKindOptions(selected=''){
  const kinds = ['Bande','Gruppering','Gadebande','Rockerklub','Mafia','Forening','Ukendt'];
  return kinds.map(k=>`<option ${k===selected?'selected':''}>${k}</option>`).join('');
}
function renderAdminTags(){
  const box = $('#adminTagsList'); if(!box) return;
  if(!mdtTags.length){ box.innerHTML = '<div class="admin-empty">Ingen tags endnu. Opret det første tag.</div>'; return; }
  box.innerHTML = mdtTags.map((t,idx)=>`<div class="admin-tag-row" style="--tag-color:${escapeHtml(t.color||'#00e6b7')}"><span class="admin-tag-dot"></span><div><b>${escapeHtml(t.name||'Tag')}</b><small>${escapeHtml(t.kind||'Ukendt')} · ${escapeHtml(t.info||'Ingen information')}</small></div><button class="ghost small" data-edit-admin-tag="${idx}">Rediger</button><button class="danger small" data-delete-admin-tag="${idx}">Slet</button></div>`).join('');
}
function openAdminTagModal(idx=null){
  const editing = idx !== null && mdtTags[idx];
  const t = editing ? mdtTags[idx] : {name:'', kind:'Ukendt', color:'#00e6b7', info:''};
  $('#modalTitle').textContent = editing ? 'Rediger tag' : 'Opret tag';
  $('#modalFields').innerHTML = `<div class="tag-admin-form"><label>Navn</label><input id="tagName" value="${escapeHtml(t.name||'')}" placeholder="Fx Families / Rockerklub"><label>Type</label><select id="tagKind">${tagKindOptions(t.kind||'Ukendt')}</select><label>Farve</label><input id="tagColor" type="color" value="${escapeHtml(t.color||'#00e6b7')}"><label>Information</label><textarea id="tagInfo" placeholder="Kort information om tagget...">${escapeHtml(t.info||'')}</textarea></div>`;
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Gem tag';
  $('#modal').classList.remove('hidden');
  $('#modalSave').onclick = () => {
    const obj = { name:($('#tagName')?.value||'').trim(), kind:$('#tagKind')?.value||'Ukendt', color:$('#tagColor')?.value||'#00e6b7', info:$('#tagInfo')?.value||'' };
    if(!obj.name){ toast('Skriv et navn på tagget.'); return; }
    if(editing) mdtTags[idx] = obj; else mdtTags.push(obj);
    saveLocalTags(); renderAdminTags(); closeModal(); toast('Tag gemt.');
  };
}
function openTagPickerModal(){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  $('#modalTitle').textContent = 'Vælg tags';
  const tags = mdtTags || [];
  const selectedNames = new Set((currentIncident.tags || []).map(x => (x && (x.name || x))));
  $('#modalFields').innerHTML = tags.length ? `<div class="tag-picker-grid scums-tag-grid">${tags.map((t,idx)=>{
    const picked = selectedNames.has(t.name);
    return `<button class="tag-pick-card scum-tag-card ${picked ? 'picked' : ''}" data-pick-tag="${idx}" style="${tagBadgeStyle(t)}">
      <div class="scum-tag-title">${escapeHtml(t.name)}</div>
      <div class="scum-tag-row"><span>Tag</span><span>${escapeHtml(t.info||'Ingen information')}</span><span>${picked ? 'Valgt' : 'Vælg'}</span></div>
    </button>`;
  }).join('')}</div>` : '<div class="admin-empty">Ingen tags oprettet endnu. Gå til Administration → Tags.</div>';
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Luk';
  $('#modalSave').onclick = closeModal;
  const cancel = $('#modalCancel'); if(cancel) cancel.style.display = 'none';
  $('#modal').classList.remove('hidden');
}

function openGenericAddModal(type){
  if(type === 'references') return openReferencePickerModal();
  let html = '<input id="mName" placeholder="Tekst"><input id="mNote" placeholder="Note / ekstra info">';
  let title = 'Tilføj '+type;
  if(type === 'vehicles'){ title='Tilføj køretøj'; html='<input id="mName" placeholder="Nummerplade / køretøj"><input id="mNote" placeholder="Note">'; }
  $('#modalTitle').textContent = title;
  $('#modalFields').innerHTML = html;
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Tilføj';
  $('#modalSave').onclick = () => {
    let obj = type === 'tags' ? { name:$('#mName').value } : { name:$('#mName').value, note:$('#mNote')?.value || '' };
    if((obj.name || '').trim()){ currentIncident[type] = currentIncident[type] || []; currentIncident[type].push(obj); renderLists(); markDirty(); }
    closeModal();
  };
}
function openReferencePickerModal(){
  $('#modalTitle').textContent = 'Tilføj rapport-reference';
  const cards = (incidents||[]).filter(x => !currentIncident || x.id !== currentIncident.id).slice(0,30).map((i,idx)=>{
    const m=currentReportTypeMeta(i);
    return `<button class="reference-report-card" data-pick-reference="${idx}"><div><b>${escapeHtml(i.title||'Ny rapport')}</b><span>${escapeHtml(m.badge)}</span></div><small>ID: ${escapeHtml(i.incident_no||'---')} · ${escapeHtml(i.created_by||'Ukendt')}</small><em>Vælg</em></button>`;
  }).join('') || '<div class="admin-empty">Ingen andre rapporter/hændelser fundet.</div>';
  $('#modalFields').innerHTML = `<div class="reference-picker-ui"><input id="manualReferenceText" placeholder="Manuel reference / sagsnummer / URL"><textarea id="manualReferenceNote" placeholder="Note / ekstra info"></textarea><h4>Link til eksisterende rapport/hændelse</h4><div class="reference-card-grid">${cards}</div></div>`;
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display=''; $('#modalSave').textContent='Tilføj manuel';
  $('#modalSave').onclick = () => { const name=$('#manualReferenceText')?.value||''; if(name.trim()){ currentIncident.references=currentIncident.references||[]; currentIncident.references.push({name, note:$('#manualReferenceNote')?.value||'', type:'Manuel'}); renderLists(); markDirty(); } closeModal(); };
}
function addCriminalToIncident(profile){
  if(!currentIncident) return;
  const obj = {
    name: profile.name || 'Ukendt borger',
    dob: profile.dob || '',
    phone: profile.phone || '',
    identifier: profile.identifier || '',
    charges: 0,
    mdtCharges: [],
    chargeReduction: { jail:0, fine:0, points:0 },
    chargeFlags: { wanted:false, handled:false, indictment:false }
  };
  currentIncident.criminals = currentIncident.criminals || [];
  if(obj.identifier && currentIncident.criminals.some(c => c.identifier === obj.identifier)) { toast('Personen er allerede tilføjet.'); return; }
  currentIncident.criminals.push(obj);
  renderLists();
  markDirty();
  toast(obj.name + ' tilføjet som kriminel.');
  if ($('#chargePickerPersons')) renderChargePickerSidePanel();
  else closeModal();
}

function addCivilianToIncident(profile){
  if(!currentIncident) return;
  const obj = {
    name: profile.name || 'Ukendt borger',
    dob: profile.dob || '',
    phone: profile.phone || '',
    identifier: profile.identifier || ''
  };
  currentIncident.civilians = currentIncident.civilians || [];
  if(obj.identifier && currentIncident.civilians.some(c => c.identifier === obj.identifier)) { toast('Borgeren er allerede tilføjet.'); return; }
  currentIncident.civilians.push(obj);
  renderLists();
  markDirty();
  toast(obj.name + ' tilføjet som involveret borger.');
  closeModal();
}

function officerSearchMatches(emp, q){
  return [emp.name, emp.fullname, emp.identifier, emp.role, emp.rank, emp.division, emp.pnumber, emp.badge, officerBadge(emp)].join(' ').toLowerCase().includes(q);
}

async function searchIncidentOfficers(){
  const q = ($('#incidentOfficerSearchInput')?.value || '').toLowerCase().trim();
  if(!employees.length){
    const r = await nui('getEmployees', { search: q });
    employees = (r && r.employees) || employees || [];
  }
  incidentOfficerSearchResults = (employees || []).filter((e) => !q || officerSearchMatches(e, q)).slice(0, 40);
  const box = $('#incidentOfficerSearchResults');
  if(!box) return;
  box.innerHTML = incidentOfficerSearchResults.length
    ? incidentOfficerSearchResults.map((e, idx) => `<div class="criminal-result-card officer-result-card" data-add-incident-officer="${idx}"><div class="result-avatar">★</div><div class="result-main"><b>${escapeHtml(e.name || 'Ukendt betjent')}</b><small>${escapeHtml(e.role || e.rank || 'Politi')} · ${escapeHtml(e.division || '')} · ${escapeHtml(officerBadge(e) || e.identifier || '')}</small></div><div class="result-action">Tilføj betjent</div></div>`).join('')
    : '<div class="profile-search-empty">Ingen betjente fundet. Prøv navn, tjenestenummer eller afdeling.</div>';
}

function openIncidentOfficerSearchModal(){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  $('#modalTitle').textContent = 'Tilføj betjent';
  $('#modalFields').innerHTML = `
    <div class="criminal-search-ui officer-search-ui">
      <input id="incidentOfficerSearchInput" placeholder="Søg betjent, rang, tjenestenummer eller afdeling..." autofocus>
      <div class="search-help">Vælg en betjent fra listen. Kun politi-ansatte kan tilføjes.</div>
      <div id="incidentOfficerSearchResults" class="criminal-results"><div class="profile-search-empty">Henter betjente...</div></div>
    </div>`;
  $('#modalSave').style.display = 'none';
  const cancel = $('#modalCancel');
  if(cancel){ cancel.style.display = ''; cancel.textContent = 'Luk'; cancel.onclick = closeModal; }
  $('#modal').classList.remove('hidden');
  const input = $('#incidentOfficerSearchInput');
  if(input){
    input.oninput = () => {
      clearTimeout(window.__incidentOfficerSearchTimer);
      window.__incidentOfficerSearchTimer = setTimeout(searchIncidentOfficers, 120);
    };
    setTimeout(() => input.focus(), 50);
  }
  searchIncidentOfficers();
}

function addOfficerToIncident(emp){
  if(!currentIncident || !emp) return;
  const obj = {
    name: emp.name || emp.fullname || 'Ukendt betjent',
    identifier: emp.identifier || '',
    rank: emp.role || emp.rank || 'Politi',
    role: emp.role || emp.rank || '',
    division: emp.division || '',
    pnumber: emp.pnumber || '',
    badge: officerBadge(emp)
  };
  currentIncident.officers = currentIncident.officers || [];
  if(obj.identifier && currentIncident.officers.some((o) => o.identifier === obj.identifier)){
    toast('Betjenten er allerede tilføjet.');
    return;
  }
  if(!obj.identifier && currentIncident.officers.some((o) => String(o.name || '').toLowerCase() === String(obj.name || '').toLowerCase())){
    toast('Betjenten er allerede tilføjet.');
    return;
  }
  currentIncident.officers.push(obj);
  renderLists();
  markDirty();
  if($('#incidentOfficer')) $('#incidentOfficer').textContent = `Betjente i hændelsen: ${obj.name}`;
  toast(obj.name + ' tilføjet som betjent.');
  closeModal();
}
function addVehicleToIncident(vehicle){
  if(!currentIncident) return;
  const obj = {
    plate: vehicle.plate || '',
    model: vehicle.model || vehicle.vehicleName || '',
    owner: vehicle.owner || '',
    ownerName: vehicle.ownerName || '',
    status: vehicle.status || '',
    type: vehicle.type || vehicle.vehicleType || '',
    image: vehicle.image || ''
  };
  if(!obj.plate) return;
  currentIncident.vehicles = currentIncident.vehicles || [];
  if(currentIncident.vehicles.some(v => String(v.plate || '').toUpperCase() === String(obj.plate).toUpperCase())) { toast('Køretøjet er allerede tilføjet.'); return; }
  currentIncident.vehicles.push(obj);
  renderLists();
  markDirty();
  toast(obj.plate + ' tilføjet til hændelsen.');
  if ($('#chargePickerVehicles')) renderChargePickerSidePanel();
  else closeModal();
}
function renderPersonSearchResults(kind){
  const box = kind === 'civilians' ? $('#civilianSearchResults') : $('#criminalSearchResults'); if(!box) return;
  const arr = kind === 'civilians' ? civilianSearchResults : criminalSearchResults;
  if(!arr.length){
    box.innerHTML = '<div class="profile-search-empty">Skriv navn, telefon, fødselsdato, identifier eller nummerplade for at søge.</div>';
    return;
  }
  const addAttr = kind === 'civilians' ? 'data-add-civilian' : 'data-add-criminal';
  const prevAttr = kind === 'civilians' ? 'data-preview-civilian' : 'data-preview-criminal';
  box.innerHTML = arr.map((p,idx)=>`<div class="criminal-result-card" ${addAttr}="${idx}" ${prevAttr}="${idx}">
    <div class="result-avatar">☷</div>
    <div class="result-main"><b>${escapeHtml(p.name || 'Ukendt borger')}</b><small>Telefon: ${escapeHtml(p.phone || 'Ingen data')} · Født: ${escapeHtml(p.dob || 'Ukendt')}</small></div>
    <div class="result-action">Tilføj</div>
  </div>`).join('');
}
function renderCriminalSearchResults(){ renderPersonSearchResults('criminals'); }
async function searchPeople(kind){
  const input = kind === 'civilians' ? $('#civilianSearchInput') : $('#criminalSearchInput');
  const q = input?.value || '';
  const r = await nui('getProfiles', { search: q });
  if(kind === 'civilians') civilianSearchResults = (r && r.profiles) || [];
  else criminalSearchResults = (r && r.profiles) || [];
  renderPersonSearchResults(kind);
}
async function searchCriminals(){ return searchPeople('criminals'); }
function openPersonSearchModal(kind){
  const isCivilian = kind === 'civilians';
  $('#modalTitle').textContent = isCivilian ? 'Tilføj involveret borger' : 'Tilføj kriminel';
  $('#modalFields').innerHTML = `<div class="criminal-search-ui">
    <input id="${isCivilian ? 'civilianSearchInput' : 'criminalSearchInput'}" placeholder="Søg navn, telefon, fødselsdato, identifier eller nummerplade..." autofocus>
    <div class="search-help">Venstreklik: tilføj til hændelse · Højreklik: se profil uden at lukke hændelsen</div>
    <div id="${isCivilian ? 'civilianSearchResults' : 'criminalSearchResults'}" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div>
  </div>`;
  $('#modalSave').style.display = 'none';
  $('#modal').classList.remove('hidden');
  setTimeout(()=>$(isCivilian ? '#civilianSearchInput' : '#criminalSearchInput')?.focus(), 50);
  const input = $(isCivilian ? '#civilianSearchInput' : '#criminalSearchInput');
  input.addEventListener('input', () => {
    if(isCivilian){ clearTimeout(civilianSearchTimer); civilianSearchTimer = setTimeout(()=>searchPeople('civilians'), 120); }
    else { clearTimeout(criminalSearchTimer); criminalSearchTimer = setTimeout(()=>searchPeople('criminals'), 120); }
  });
}
function openCriminalSearchModal(){ return openPersonSearchModal('criminals'); }
function renderVehicleSearchResults(){
  const box = $('#vehicleSearchResults'); if(!box) return;
  if(!vehicleSearchResults.length){
    box.innerHTML = '<div class="profile-search-empty">Skriv nummerplade, registreringsnummer, model eller ejer for at søge.</div>';
    return;
  }
  box.innerHTML = vehicleSearchResults.map((v,idx)=>`<div class="vehicle-result-card" data-add-vehicle="${idx}" data-preview-vehicle-owner="${idx}">
    <div class="vehicle-thumb">${v.image ? `<img src="${escapeHtml(v.image)}">` : '🚘'}</div>
    <div class="result-main"><b>${escapeHtml(v.plate || 'Ukendt nummerplade')}</b><small><span class="vehicle-model">${escapeHtml(v.model || 'Ukendt model')}</span> · Type: ${escapeHtml(v.type || 'Ukendt type')} · Ejer: ${escapeHtml(v.ownerName || v.owner || 'Ukendt')} · ${escapeHtml(v.status || '')}</small></div>
    <div class="result-action">Tilføj</div>
  </div>`).join('');
}
async function searchVehiclesModal(){
  const q = $('#vehicleSearchInput')?.value || '';
  const r = await nui('getVehicles', { search: q });
  vehicleSearchResults = (r && r.vehicles) || [];
  renderVehicleSearchResults();
}
function openVehicleSearchModal(){
  $('#modalTitle').textContent = 'Tilføj køretøj';
  $('#modalFields').innerHTML = `<div class="criminal-search-ui">
    <input id="vehicleSearchInput" placeholder="Søg nummerplade, registreringsnummer, model eller ejer..." autofocus>
    <div class="search-help">Venstreklik: tilføj køretøj · Højreklik: åbn ejerens profil uden at lukke hændelsen</div>
    <div id="vehicleSearchResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div>
  </div>`;
  $('#modalSave').style.display = 'none';
  $('#modal').classList.remove('hidden');
  setTimeout(()=>$('#vehicleSearchInput')?.focus(),50);
  $('#vehicleSearchInput').addEventListener('input', () => { clearTimeout(vehicleSearchTimer); vehicleSearchTimer = setTimeout(searchVehiclesModal, 120); });
}
function addToList(type){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  if(type === 'criminals') return openPersonSearchModal('criminals');
  if(type === 'civilians') return openPersonSearchModal('civilians');
  if(type === 'vehicles') return openVehicleSearchModal();
  if(type === 'tags') return openTagPickerModal();
  if(type === 'charges') return openIncidentChargePicker();
  if(type === 'evidence') return openEvidenceAddModal();
  if(type === 'officers') return openIncidentOfficerSearchModal();
  openGenericAddModal(type);
}

let dashboardRefreshInFlight = false;
async function refreshDashboardFromServer(){
  if(dashboardRefreshInFlight) return false;
  dashboardRefreshInFlight = true;
  try {
    const r = await nui('getDashboard', {});
    if(r && r.ok !== false){
      renderDashboard(r);
      return true;
    }
    toast(r?.message || 'Kunne ikke hente forsiden.');
    return false;
  } finally {
    dashboardRefreshInFlight = false;
  }
}

function normalizeDashboardNewsItem(n){
  n = n || {};
  const recipientType = String(n.recipient_type || n.targetType || n.type || '').toLowerCase();
  const recipient = String(n.recipient || n.to || '').toLowerCase();
  const isFrontpageMail = !!n.mail && (recipientType === 'frontpage' || recipient === 'frontpage' || recipientType === 'news');
  return Object.assign({}, n, {
    mail: n.mail ? 1 : 0,
    recipient_type: isFrontpageMail ? 'frontpage' : (n.recipient_type || recipientType || ''),
    title: n.title || n.subject || 'Ingen titel',
    description: n.description || n.summary || n.body || ''
  });
}
function uniqueDashboardNews(news){
  const seen = new Set();
  const out = [];
  (news || []).forEach(raw => {
    const n = normalizeDashboardNewsItem(raw);
    const prefix = n.mail ? 'mail:' : 'news:';
    const key = prefix + String(n.id || n.title || Math.random());
    if(seen.has(key)){
      if(window.__mdtDebugNews) console.warn('[MDT news duplicate filter]', key, n);
      return;
    }
    seen.add(key); out.push(n);
  });
  return out;
}
function renderNewsCard(n){
  n = normalizeDashboardNewsItem(n);
  const isMail = !!n.mail;
  const type = isMail ? (n.recipient_type === 'private' ? 'MAIL' : 'NYHED') : 'NYHED';
  const seen = !isMail || Number(n.unread || 0) === 0 || !!n.seen_at;
  const desc = n.description || n.summary || n.title || n.subject || 'Ingen beskrivelse';
  return `<div class="home-row news clickable home-news-card ${isMail && !seen ? 'unread' : ''}" data-open-newsmail="${escapeHtml(n.id)}" data-news-type="${escapeHtml(type)}">
    <div class="news-left-top"><span class="mdt-chip news">${escapeHtml(type)}</span><b class="news-title">${escapeHtml(n.title || n.subject || 'Ingen titel')}</b></div>
    ${isMail ? `<span class="mdt-chip news-status ${seen?'seen':'unseen'}">${seen?'SET':'IKKE SET'}</span>` : `<span class="mdt-chip news-status seen">NYHED</span>`}
    <small class="news-desc">${escapeHtml(desc)}</small>
    <span class="mdt-chip id news-id">ID: ${escapeHtml(n.id || '')}</span>
  </div>`;
}
function localDashboardWantedVehicles(){
  const out = [];
  (allReportsCombined() || []).map(normalizeReport).forEach(r => {
    (r.vehicles || []).forEach(v => {
      if(!v || !v.wanted) return;
      out.push({
        local: true,
        kind: 'vehicle',
        id: r.report_no || r.id,
        report_id: r.id || r.report_no,
        title: v.plate || v.model || 'Efterlyst køretøj',
        description: [v.model, v.ownerName || v.owner, r.title].filter(Boolean).join(' · '),
        type: 'KØRETØJ'
      });
    });
  });
  return out;
}
function localDashboardWantedPersons(){
  const out = [];
  (allReportsCombined() || []).map(normalizeReport).forEach(r => {
    [...(r.suspects || []), ...(r.civilians || [])].forEach(p => {
      if(!p || !p.wanted) return;
      out.push({
        local: true,
        kind: 'person',
        id: r.report_no || r.id,
        report_id: r.id || r.report_no,
        title: p.name || 'Efterlyst person',
        description: [p.dob, r.title].filter(Boolean).join(' · '),
        type: 'PERSON'
      });
    });
  });
  return out;
}
function renderDashboardWantedCard(w, fallbackType){
  const label = w.type || fallbackType || 'EFTERLYST';
  const rid = w.report_id || w.report || w.id || '';
  return `<div class="home-row wanted-clickable" data-open-wanted-report="${escapeHtml(rid)}">
    <div class="avatar">⚠</div>
    <div><b>${escapeHtml(w.title || w.name || 'Efterlysning')}</b><small>${escapeHtml(w.description || w.reason || '')}</small><div class="wanted-card-meta"><span class="mdt-chip unseen">${escapeHtml(label)}</span><span class="mdt-chip id">ID: ${escapeHtml(w.id || w.case_no || '')}</span></div></div>
  </div>`;
}
function officerRoleClass(role){ return String(role||'').toLowerCase() === 'rigspolitiet' ? 'role-rigspolitiet' : ''; }
function officerNameHtml(name, role){
  const safe = escapeHtml(name || 'Ukendt');
  return officerRoleClass(role) ? `<span class="officer-name-shimmer">${safe}</span>` : safe;
}
function officerStatusDot(o){
  if(o && o.onDuty) return '<span class="officer-status-dot duty" title="På arbejde"></span>';
  if(o && o.online) return '<span class="officer-status-dot online" title="Online"></span>';
  return '<span class="officer-status-dot" title="Offline"></span>';
}
function officerDirectoryHay(o){
  return [o.name,o.badge,o.pnumber,o.division,o.role,o.identifier].join(' ').toLowerCase();
}
function sortedDashboardRoles(officers, roleOrder){
  const order = (roleOrder && roleOrder.length) ? roleOrder : mdtRoles;
  const keys = Object.keys(officers || {});
  return order.filter(r => keys.includes(r)).concat(keys.filter(k => !order.includes(k)).sort((a,b)=>String(a).localeCompare(String(b),'da')));
}
function renderOfficerRow(o){
  const roleCls = officerRoleClass(o.role);
  const offlineCls = o.online ? '' : ' offline';
  return `<div class="officer-row${offlineCls}" data-officer-profile="${escapeHtml(o.identifier||'')}" data-officer-name="${escapeHtml(o.name||'')}">
    <span class="initials">${escapeHtml(o.initials||'--')}</span>
    <span class="officer-name">${officerNameHtml(o.name, o.role)}</span>
    <span class="officer-meta">${officerStatusDot(o)}<span class="officer-pill-mini">${escapeHtml(o.badge || formatPoliceBadge(o.pnumber, o.division) || '')}</span></span>
  </div>`;
}
function renderOfficerAwardBadge(a){
  const def = MDT_AWARD_DEFS[String(a.award_key||'').toLowerCase()] || {};
  const label = a.award_label || def.label || a.award_key || 'Award';
  const cls = def.cls || 'award-generic';
  const icon = def.icon || '🏅';
  const note = a.note ? ` title="${escapeHtml(a.note)}"` : '';
  return `<span class="officer-award-badge ${cls}"${note}><span class="award-icon">${icon}</span><span>${escapeHtml(label)}</span></span>`;
}
function closeOfficerProfileModal(){
  document.querySelectorAll('.officer-profile-overlay').forEach(el => el.remove());
  activeOfficerProfile = null;
}
async function sendOfficerProfileMail(identifier){
  const subject = $('#officerMailSubject')?.value || '';
  const body = $('#officerMailBody')?.value || '';
  if(!identifier){ toast('Ingen modtager valgt.'); return; }
  if(!subject || !body){ toast('Udfyld emne og besked.'); return; }
  const r = await nui('sendMail', { to:identifier, targetType:'private', subject, body, summary:'' });
  toast(r?.message || (r?.ok ? 'Mail sendt.' : 'Kunne ikke sende mail.'));
  if(r?.ok){
    const sub = $('#officerMailSubject'); const bod = $('#officerMailBody');
    if(sub) sub.value = '';
    if(bod) bod.value = '';
  }
}
function renderOfficerProfileModal(p){
  closeOfficerProfileModal();
  activeOfficerProfile = p || null;
  if(!p) return;
  const roleCls = officerRoleClass(p.role);
  const statusText = p.onDuty ? 'På arbejde' : (p.online ? 'Online' : 'Offline');
  const statusCls = p.onDuty ? 'available' : (p.online ? 'online' : 'service');
  const awards = (p.awards || []).map(renderOfficerAwardBadge).join('') || '<div class="officer-profile-empty">Ingen awarder tildelt endnu.</div>';
  const mailBlock = p.canSendMail ? `
    <div class="officer-mail-compose">
      <h3>Send mail</h3>
      <input id="officerMailSubject" placeholder="Emne">
      <textarea id="officerMailBody" placeholder="Skriv besked til ${escapeHtml(p.name||'betjenten')}..."></textarea>
      <button class="save" id="officerMailSendBtn" type="button">Send mail</button>
    </div>` : '<div class="officer-profile-empty">Du har ikke adgang til at sende mails.</div>';
  const overlay = document.createElement('div');
  overlay.className = 'officer-profile-overlay';
  overlay.innerHTML = `<div class="officer-profile-card ${roleCls}">
    <div class="officer-profile-head">
      <div class="officer-profile-photo">${profileImageHtml(p.profile_image, p.name, 'officer-profile-img')}</div>
      <div>
        <h2>${officerNameHtml(p.name, p.role)}</h2>
        <p>${escapeHtml(p.role || 'Ukendt rolle')} · ${escapeHtml(p.division || 'Patrulje')} · ${escapeHtml(p.badge || formatPoliceBadge(p.pnumber, p.division))}</p>
      </div>
      <button class="close-officer-profile" type="button" title="Luk">×</button>
    </div>
    <div class="officer-profile-body">
      <div class="officer-profile-details">
        <div class="officer-info-grid">
          <div class="officer-info-box"><span>Status i politiet</span><b class="${statusCls}">${escapeHtml(statusText)}</b></div>
          <div class="officer-info-box"><span>Telefon</span><b>${escapeHtml(p.phone || 'Ingen data')}</b></div>
          <div class="officer-info-box"><span>Tjenestenummer</span><b>${escapeHtml(p.badge || formatPoliceBadge(p.pnumber, p.division) || 'Ukendt')}</b></div>
          <div class="officer-info-box"><span>Afdeling</span><b>${escapeHtml(p.division || 'Patrulje')}</b></div>
        </div>
        <div class="officer-awards-section">
          <h3>Awarder fra ledelse</h3>
          <div class="officer-awards-grid">${awards}</div>
        </div>
      </div>
      <div class="officer-profile-side">${mailBlock}</div>
    </div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.querySelector('.close-officer-profile')?.addEventListener('click', closeOfficerProfileModal);
  overlay.addEventListener('mousedown', e => { if(e.target === overlay) closeOfficerProfileModal(); });
  overlay.querySelector('#officerMailSendBtn')?.addEventListener('click', () => sendOfficerProfileMail(p.identifier));
}
async function openOfficerProfile(identifier){
  if(!identifier){ toast('Ingen betjent valgt.'); return; }
  const r = await nui('getOfficerProfile', { identifier });
  if(!r?.ok || !r.profile){ toast(r?.message || 'Kunne ikke åbne betjent-profil.'); return; }
  renderOfficerProfileModal(r.profile);
}
function renderDashboard(data){
  data = data || {};
  window.__dashboardDataAt = Date.now();
  if(data.officers || data.stats || data.officerCount != null || data.roleOrder || data.news || data.wanted || data.bolos){
    dashboardCachedPayload = Object.assign({}, dashboardCachedPayload || {}, data);
  }
  const payload = Object.assign({}, dashboardCachedPayload || {}, data);
  const officers = payload.officers || {};
  const stats = payload.stats || {};
  const news = uniqueDashboardNews(payload.news || []);
  dashboardMails = news.filter(n => n && n.mail);
  const wantedVehicles = localDashboardWantedVehicles().concat((payload.wanted || []).map(x => Object.assign({ type: 'PERSON/KØRETØJ' }, x)));
  const wantedPersons = localDashboardWantedPersons().concat(payload.bolos || []);
  dashboardOfficerData = {
    officers,
    roleOrder: payload.roleOrder || mdtRoles.slice(),
    canSendMail: payload.canSendMail !== false,
    stats,
    officerCount: Number(payload.officerCount || 0) || Object.values(officers).reduce((n, arr) => n + (arr ? arr.length : 0), 0)
  };
  const q = (dashboardOfficerSearch || '').trim().toLowerCase();
  const roles = sortedDashboardRoles(officers, dashboardOfficerData.roleOrder);
  let visibleCount = 0;
  const groupsHtml = roles.map(role => {
    const list = (officers[role] || []).filter(o => !q || officerDirectoryHay(o).includes(q));
    if(!list.length) return '';
    visibleCount += list.length;
    return `<div class="grade-box ${officerRoleClass(role)}"><div class="grade-title"><span>${escapeHtml(role)}</span><em>${list.length}</em></div>${list.map(renderOfficerRow).join('')}</div>`;
  }).filter(Boolean).join('');
  const total = dashboardOfficerData.officerCount;
  const oc = $('#officerCount'); if(oc) oc.textContent = String(q ? visibleCount : total);
  const di = $('#dashStatIncidents'); if(di) di.textContent = String(stats.incidents || 0);
  const dl = $('#dashStatLocked'); if(dl) dl.textContent = String(stats.lockedVehicles || 0);
  const wc = $('#wantedCount'); if(wc) wc.textContent = String(wantedVehicles.length);
  const nc = $('#newsCount'); if(nc) nc.textContent = String(news.length);
  const bc = $('#boloCount'); if(bc) bc.textContent = String(wantedPersons.length);
  const wl = $('#wantedList');
  if(wl) wl.innerHTML = wantedVehicles.length
    ? wantedVehicles.map(w => renderDashboardWantedCard(w, 'KØRETØJ')).join('')
    : '<div class="home-row"><div></div><div><b>Ingen efterlysninger</b><small>Der er ingen aktive efterlysninger.</small></div></div>';
  const nl = $('#newsList');
  if(nl) nl.innerHTML = news.length
    ? news.map(renderNewsCard).join('')
    : '<div class="home-row news"><div></div><div><b>Ingen nyheder</b><small>Der er ingen nyheder endnu.</small></div></div>';
  const bl = $('#boloList');
  if(bl) bl.innerHTML = wantedPersons.length
    ? wantedPersons.map(w => renderDashboardWantedCard(w, 'PERSON')).join('')
    : '<div class="home-row bolo"><div></div><div><b>Ingen efterlyste personer</b><small>Der er ingen aktive efterlyste personer.</small></div></div>';
  const og = $('#officerGroups');
  if(og){
    og.innerHTML = groupsHtml || `<div class="dashboard-empty-state">
      <b>${q ? 'Ingen betjente fundet' : 'Ingen betjente online/registreret'}</b>
      <small>${q ? 'Prøv et andet søgeord.' : 'Betjente vises her når de er ansat i politiet eller er online i byen.'}</small>
      <button type="button" class="save" id="officerDirectoryRetry">Opdater forsiden</button>
    </div>`;
    const retry = $('#officerDirectoryRetry');
    if(retry) retry.onclick = () => refreshDashboardFromServer();
  }
}
function insertDashboardNewsCardRealtime(mail){
  if(!mail) return;
  const n = normalizeDashboardNewsItem(Object.assign({}, mail, { mail:1, recipient_type:'frontpage', unread:1 }));
  dashboardMails = uniqueDashboardNews([n].concat(dashboardMails || [])).filter(x => x && x.mail);
  const list = $('#newsList');
  if(list){
    const empty = list.querySelector('.home-row:not(.clickable)');
    if(empty) list.innerHTML = '';
    if(!list.querySelector(`[data-open-newsmail="${CSS.escape(String(n.id))}"]`)){
      list.insertAdjacentHTML('afterbegin', renderNewsCard(n));
    }
  }
  const c = $('#newsCount');
  if(c) c.textContent = String(document.querySelectorAll('#newsList .home-row.clickable').length || dashboardMails.length || 1);
}
async function refreshProfiles(){
  const r = await nui('getProfiles', { search: $('#profileSearch')?.value || '' });
  profiles = (r && r.profiles) || [];
  renderProfileResults();
}
function setProfileListMode(listMode){
  profileListMode = !!listMode;
  const sec = $('#profiles');
  if(sec){
    sec.classList.toggle('profile-list-mode', profileListMode);
    sec.classList.toggle('profile-detail-mode', !profileListMode);
  }
}
function renderProfileResults(){
  const box = $('#profileResults'); if(!box) return;
  if(!profiles.length){
    box.innerHTML = '<div class="profile-wide-card empty-card"><b>Ingen profiler fundet</b><small>Søg efter navn, telefon, fødselsdato eller identifier.</small></div>';
    return;
  }
  box.innerHTML = profiles.map((p,idx)=>{
    const isActive = activeProfile && activeProfile.identifier === p.identifier;
    const gangBadge = p.gang ? `<span class="profile-gang-pill" style="--gang-color:${escapeHtml(p.gang.color || '#ff3048')}">${escapeHtml(p.gang.tag || p.gang.name || 'Bande')}</span>` : '';
    return `<div class="profile-wide-card ${isActive ? 'active' : ''} ${p.gang ? 'has-gang' : ''}" data-profile="${idx}">
      <div class="profile-card-icon">${profileImageHtml(p.profile_image, p.name, 'profile-card-img')}</div>
      <div class="profile-card-main">
        <div class="profile-card-title"><b>${escapeHtml(p.name || 'Ukendt borger')}</b><span>PROFIL</span>${gangBadge}</div>
        <div class="profile-card-meta"><span>Telefon: ${escapeHtml(p.phone || 'Ingen data')}</span><span>Født: ${escapeHtml(p.dob || 'Ukendt')}</span></div>
      </div>
      <div class="profile-card-status">Åbn</div>
    </div>`;
  }).join('');
}
function profileBackToList(){
  activeProfile = null;
  setProfileListMode(true);
  renderProfileResults();
}
async function openProfile(idx){
  const base = profiles[idx]; if(!base) return;
  const r = await nui('getProfile', { identifier: base.identifier });
  activeProfile = (r && r.profile) || base;
  if(activeProfile?.vehicles?.length) await hydrateVehicleModels(activeProfile.vehicles);
  if(activeProfile?.can_register_gang && !(nskOverview.gangs || []).length){
    const nsk = await nui('getNskOverview', {});
    if(nsk && nsk.ok){ nskOverview = nsk; mdtNskManage = !!nsk.can_manage; }
  }
  setProfileListMode(false);
  renderProfileDetail();
}
function formatLicenseRestoreWait(p){
  const hours = Number(p.license_cooldown_hours || licenseRevocationCooldownHours || 48);
  if(p.license_can_restore === false){
    const remain = Math.max(0, Number(p.license_restore_remaining_seconds || 0));
    const h = Math.floor(remain / 3600);
    const m = Math.ceil((remain % 3600) / 60);
    const at = p.license_restore_at ? String(p.license_restore_at).slice(0, 16).replace('T', ' ') : '';
    return at ? `Kan få nyt kørekort ca. ${at} (${h} t ${m} min tilbage)` : `Kan få nyt kørekort efter ${hours} timer (${h} t ${m} min tilbage)`;
  }
  return `Kan få nyt kørekort igen efter ${hours} timers karensperiode`;
}
function profileLicenseInfo(p){
  const points = Math.max(0, Number(p.license_points || 0));
  const max = Math.max(1, Number(p.license_max_points || 3));
  if (p.license_revoked) {
    const wait = formatLicenseRestoreWait(p);
    return { counter: 'Frakendt', strong: 'Frakendt', small: wait, revoked: true, canRestore: p.license_can_restore !== false };
  }
  return { counter: `${Math.min(points, max)}/${max}`, strong: String(points), small: points ? `${points} aktive klip` : 'Ingen aktive klip', revoked: false, canRestore: true };
}
function personHasLicenseSanction(person, totals, arr){
  if(person?.licenseSanction) return false;
  const hasPts = totals.final.points > 0;
  const hasRev = hasChargeRevocation({ revocation: totals.final.revocation });
  return (hasPts || hasRev) && (arr || []).some((c)=> Number(c.points||0) > 0 || hasChargeRevocation(c));
}
function personLicenseSanctionStatusHtml(person, totals){
  const s = person?.licenseSanction;
  if(!s) return '';
  const when = s.applied_at ? String(s.applied_at).slice(0, 16).replace('T', ' ') : '';
  const text = s.revoked
    ? `Frakendt · ${Number(s.points||0)} klip${when ? ` · ${when}` : ''}`
    : `${Number(s.points||0)} klip registreret${when ? ` · ${when}` : ''}`;
  return `<div class="person-fine-box issued"><div class="person-fine-status ${s.revoked ? 'pending' : 'paid'}"><b>Kørekortssanktion udført</b><small>${escapeHtml(text)}${s.reason ? ` · ${escapeHtml(s.reason)}` : ''}</small></div></div>`;
}
function personLicenseSanctionActionHtml(person, idx, totals, arr){
  if(person?.licenseSanction) return personLicenseSanctionStatusHtml(person, totals);
  if(!personHasLicenseSanction(person, totals, arr)) return '';
  const canApply = !!(person?.identifier) && !!(currentIncident?.id);
  const hint = !currentIncident?.id ? 'Gem hændelsen først.' : (!person?.identifier ? 'Tilføj person via profil-søgning.' : '');
  const label = `${totals.final.points > 0 ? `${totals.final.points} klip` : ''}${totals.final.points > 0 && hasChargeRevocation({revocation: totals.final.revocation}) ? ' + ' : ''}${hasChargeRevocation({revocation: totals.final.revocation}) ? 'frakendelse' : ''}`;
  return `<div class="person-fine-box"><button type="button" class="save small warn" data-person-license-sanction="${idx}" ${canApply ? '' : 'disabled'}>Udfør kørekortssanktion (${label})</button>${hint ? `<small class="person-fine-hint">${escapeHtml(hint)}</small>` : '<small class="person-fine-hint">Kræver bekræftelse før kørekort fjernes.</small>'}</div>`;
}
async function openLicenseSanctionConfirm(personIdx){
  const person = currentIncident?.criminals?.[personIdx];
  if(!person || !currentIncident?.id){ toast('Gem hændelsen og tilføj person først.'); return; }
  const r = await nui('previewIncidentLicenseSanction', { incidentId: currentIncident.id, personIndex: personIdx });
  if(!r || !r.ok){ toast(r?.message || 'Kunne ikke forberede kørekortssanktion.'); return; }
  const p = r.preview || {};
  const chargeRows = (p.charges || []).map((c)=>{
    const bits = [];
    if(Number(c.points||0) > 0) bits.push(`${c.points} klip`);
    if(c.revocation) bits.push(`Frakendelse: ${c.revocation}`);
    return `<div class="license-confirm-line"><b>§ ${escapeHtml(c.paragraph||'?')} ${escapeHtml(c.name||'Sigtelse')}</b><small>${escapeHtml(bits.join(' · ') || 'Sanktion')}</small></div>`;
  }).join('') || '<p class="profile-muted">Ingen sigtelser med klip/frakendelse.</p>';
  const cooldownHours = Number(p.cooldown_hours || licenseRevocationCooldownHours || 48);
  const revokeText = p.will_revoke
    ? `<p class="license-confirm-warn"><b>Bekræft frakendelse:</b> Kørekortet fratages (${escapeHtml((p.licenses_to_remove||[]).join(', ') || 'drive')}). Borgeren kan tidligst få nyt kørekort igen efter <b>${cooldownHours} timer</b>.</p>`
    : `<p class="license-confirm-note">Kørekortet beholdes. Aktive klip bliver ${Number(p.current_points||0)} → <b>${Number(p.new_points||0)}</b> / ${Number(p.max_points||3)}.</p>`;

  $('#modalTitle').textContent = 'Bekræft kørekortssanktion';
  $('#modalFields').innerHTML = `
    <div class="license-confirm-modal">
      <p><b>${escapeHtml(p.person_name||'Ukendt')}</b> · Hændelse ${escapeHtml(p.incident_no||'')}</p>
      ${revokeText}
      <div class="license-confirm-list">${chargeRows}</div>
      <small class="profile-muted">Handlingen registreres permanent i personens kørekort-historik.</small>
    </div>`;
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = p.will_revoke ? 'Bekræft og fratag kørekort' : 'Bekræft og registrer klip';
  $('#modalSave').disabled = false;
  const cancel = $('#modalCancel');
  if(cancel){ cancel.style.display = ''; cancel.textContent = 'Annuller'; cancel.onclick = closeModal; }
  $('#modalSave').onclick = async ()=>{
    $('#modalSave').disabled = true;
    const apply = await nui('applyIncidentLicenseSanction', { incidentId: currentIncident.id, personIndex: personIdx, confirmed: true });
    closeModal();
    if(apply && apply.ok){
      person.licenseSanction = apply.sanction || person.licenseSanction;
      person.chargeFlags = person.chargeFlags || { wanted:false, handled:false, indictment:false };
      person.chargeFlags.handled = true;
      renderLists();
      toast(apply.message || 'Kørekortssanktion udført.');
    } else toast(apply?.message || 'Kunne ikke udføre kørekortssanktion.');
    $('#modalSave').onclick = null;
  };
}
function renderLicenseHistoryHtml(p){
  const rows = Array.isArray(p.license_history) ? p.license_history : [];
  if(!rows.length) return '<p class="profile-muted">Ingen registrerede klip eller frakendelser endnu.</p>';
  const labels = { points:'Klip', revocation:'Frakendelse', license_removed:'Kørekort frataget', license_restored:'Kørekort genudstedt' };
  return rows.map((h)=>{
    const when = h.created_at ? String(h.created_at).slice(0, 16).replace('T', ' ') : '';
    const title = h.charge_name ? `§ ${h.charge_paragraph||'?'} ${h.charge_name}` : (labels[h.event_type] || h.event_type || 'Hændelse');
    const bits = [];
    if(Number(h.points_delta||0) > 0) bits.push(`+${h.points_delta} klip`);
    if(h.points_after != null && h.event_type === 'points') bits.push(`Total: ${h.points_after}`);
    if(h.reason) bits.push(h.reason);
    if(h.licenses_removed) bits.push(`Fjernet: ${h.licenses_removed}`);
    if(h.incident_no) bits.push(h.incident_no);
    if(h.officer_name) bits.push(h.officer_name);
    if(when) bits.push(when);
    return `<div class="license-history-row ${escapeHtml(h.event_type||'')}"><div><b>${escapeHtml(title)}</b><small>${escapeHtml(bits.join(' · '))}</small></div></div>`;
  }).join('');
}
function renderUnpaidBillsHtml(p){
  const bills = p.unpaid_bills || [];
  if (!bills.length) return '<p class="profile-muted">Ingen udestående bøder/fakturaer til det offentlige.</p>';
  return bills.slice(0, 8).map((b) => `<div class="unpaid-row"><div><b>${escapeHtml(b.label || 'Faktura')}</b><small>${escapeHtml(b.sender || 'Ukendt')}</small></div><span>${Number(b.amount || 0).toLocaleString('da-DK')} kr.</span></div>`).join('');
}
function profileLicenseSummary(p){
  const rows = Array.isArray(p.licenses) ? p.licenses : [];
  if(p.license_revoked){
    const wait = formatLicenseRestoreWait(p);
    return { tag:'<span class="tag danger">Frakendt</span>', text: wait };
  }
  if(!rows.length) return { tag:'<span class="tag warn">Ingen licenser</span>', text:'Ingen registrerede licenser' };
  const labels = rows.map((l)=>escapeHtml(l.label || l.type || 'Licens')).join(', ');
  return { tag:'<span class="tag ok">Har licenser</span>', text:labels };
}
function renderProfileLicensesHtml(p){
  const rows = Array.isArray(p.licenses) ? p.licenses : [];
  const catalog = Array.isArray(p.license_catalog) ? p.license_catalog : [];
  const canManage = !!p.can_manage_licenses;
  const owned = new Set(rows.map((l)=>String(l.type||'')));
  const list = rows.length ? rows.map((l)=>`<div class="profile-license-row"><div><b>${escapeHtml(l.label || l.type || 'Licens')}</b><small>${escapeHtml(l.type || '')}</small></div>${canManage ? `<button type="button" class="tiny danger" data-profile-license-action="remove:${escapeHtml(l.type||'')}">Fjern</button>` : ''}</div>`).join('') : '<p class="profile-muted">Ingen licenser registreret.</p>';
  const revokeCooldown = p.license_revoked && p.license_can_restore === false;
  const missing = canManage ? catalog.filter((c)=>!owned.has(String(c.type||''))).map((c)=>{
    const disabled = revokeCooldown ? 'disabled' : '';
    const title = revokeCooldown ? ` title="${escapeHtml(formatLicenseRestoreWait(p))}"` : '';
    return `<button type="button" class="ghost small" data-profile-license-action="add:${escapeHtml(c.type||'')}" ${disabled}${title}>+ ${escapeHtml(c.label || c.type || 'Licens')}</button>`;
  }).join('') : '';
  const cooldownNote = revokeCooldown ? `<p class="profile-muted license-restore-wait">${escapeHtml(formatLicenseRestoreWait(p))}</p>` : '';
  return `${list}${cooldownNote}${missing ? `<div class="profile-license-add">${missing}</div>` : ''}`;
}
async function updateProfileLicense(action, licenseType){
  if(!activeProfile?.identifier) return;
  const r = await nui('updateProfileLicense', { identifier:activeProfile.identifier, action, licenseType });
  if(r && r.ok){
    activeProfile.licenses = r.licenses || activeProfile.licenses || [];
    activeProfile.has_drive_license = (activeProfile.licenses||[]).some((l)=>String(l.type||'')==='drive');
    if(r.clips_reset){
      activeProfile.license_points = 0;
      activeProfile.license_revoked = false;
      activeProfile.license_revocation_note = '';
      activeProfile.license_can_restore = true;
      activeProfile.license_restore_remaining_seconds = 0;
    }
    const profileRefresh = await nui('getProfile', { identifier: activeProfile.identifier });
    if(profileRefresh?.ok && profileRefresh.profile) activeProfile = profileRefresh.profile;
    renderProfileDetail();
    toast(r.message || 'Licens opdateret.');
  } else toast(r?.message || 'Kunne ikke opdatere licens.');
}
function renderProfileDetail(){
  const view = $('#profileView'); if(!view || !activeProfile) return;
  const p = activeProfile;
  const lic = profileLicenseInfo(p);
  const vehicles = p.vehicles || [];
  const vehicleHtml = vehicles.length ? vehicles.map(car=>{
    const locked = String(car.status || '').toLowerCase().includes('låst');
    const impound = String(car.status || '').toLowerCase().includes('impound') || String(car.status || '').toLowerCase().includes('beslaglagt');
    return `<div class="profile-vehicle-row">
      <div class="vehicle-left"><span class="vehicle-icon">▣</span><div><b>${escapeHtml(car.plate || 'Ukendt')}</b><small>${escapeHtml(displayVehicleModel(car))}</small></div></div>
      <div class="vehicle-badges">${locked ? '<em class="locked-badge">LÅST</em>' : ''}${impound ? vehicleStatusBadge(car.status) : '<span class="mini-badge green">Garage/Ude</span>'}</div>
    </div>`;
  }).join('') : '<div class="profile-empty-row">Ingen køretøjer fundet.</div>';
  const licSummary = profileLicenseSummary(p);
  const licenseTag = lic.revoked ? '<span class="tag danger">Frakendt</span>' : licSummary.tag;

  view.innerHTML = `
    <div class="profile-detail-top">
      <button class="ghost" id="profileBack">← Tilbage</button>
      <div class="profile-detail-title"><b>${escapeHtml(p.name || 'Ukendt borger')}</b><small>Telefon: ${escapeHtml(p.phone || 'Ingen data')} · Født: ${escapeHtml(p.dob || 'Ukendt')}</small></div>
      <button class="save secondary" id="saveProfileBtn">Gem profil</button>
    </div>
    ${wantedProfileBanner(p)}
    ${gangProfileBanner(p)}
    <div class="profile-detail-grid">
      <section class="profile-left-card">
        <div class="profile-photo profile-photo-real" id="profilePhotoPreview">
          ${profileImageHtml(p.profile_image, p.name, 'profile-large-img')}
        </div>
        <div class="profile-field compact"><label>PROFILBILLEDE URL</label><input id="profileImageUrl" value="${escapeHtml(p.profile_image || '')}" placeholder="https://..."></div>
        <div class="profile-note-box" contenteditable="true" data-placeholder="Noter omkring borgeren..."></div>
      </section>

      <section class="profile-main-card">
        <h3>DETALJER</h3>
        <div class="profile-field"><label>NAVN</label><input value="${escapeHtml(p.name || '')}" readonly></div>
        <div class="profile-field"><label>KØN</label><input value="${escapeHtml(p.sex || 'Ukendt')}" readonly></div>
        <div class="profile-field"><label>FØDSELSDATO</label><input value="${escapeHtml(p.dob || 'Ukendt')}" readonly></div>
        <div class="profile-field"><label>TELEFON</label><input value="${escapeHtml(p.phone || 'Ingen data')}" readonly></div>
        <div class="profile-field inline-action wiretap-actions"><label>NARKO TEL. ID</label><input id="wiretapPhoneId" placeholder="NT-xxxxxx" autocomplete="off"><button id="startWiretapBtn" class="save secondary">Start aflytning</button><button id="stopWiretapBtn" class="save danger hidden">Stop aflytning</button></div>
        <p id="wiretapLockInfo" class="wiretap-lock-info hidden"></p>
        <div class="profile-field"><label>JOB</label><input value="${escapeHtml(p.job || 'Ukendt')}" readonly></div>
      </section>

      <aside class="profile-right-card">
        <div class="profile-side-section"><h3>ØKONOMI / UDESTÅENDE</h3><div class="profile-money"><span>Samlet udestående</span><b>${escapeHtml(p.unpaid_formatted || p.unpaid || '0 kr.')}</b></div><div class="unpaid-list">${renderUnpaidBillsHtml(p)}</div></div>
        <div class="profile-side-section profile-licenses-section"><h3>LICENSER ${p.can_manage_licenses ? '<small>Administration</small>' : ''}</h3><div class="pill-row">${licenseTag}</div><small class="profile-muted">${licSummary.text}</small><div class="profile-license-list">${renderProfileLicensesHtml(p)}</div></div>
        <div class="profile-side-section profile-license-history-section"><h3>KØREKORTREGISTER <span class="right-counter">${escapeHtml(lic.counter)}</span></h3><div class="license-meter ${lic.revoked ? 'revoked' : ''}"><strong>${escapeHtml(lic.strong)}</strong><small>${escapeHtml(lic.small)}</small></div><div class="license-history-list">${renderLicenseHistoryHtml(p)}</div></div>
        ${renderProfileGangAdminHtml(p)}
        <div class="profile-side-section vehicles-list"><h3>KØRETØJER</h3>${vehicleHtml}</div>
      </aside>
    </div>`;
  $('#profileBack') && ($('#profileBack').onclick = profileBackToList);
  const imgInput = view.querySelector('#profileImageUrl');
  const photoPreview = view.querySelector('#profilePhotoPreview');
  if (imgInput && photoPreview) {
    imgInput.oninput = () => {
      photoPreview.innerHTML = profileImageHtml(imgInput.value, p.name, 'profile-large-img');
    };
  }
  const saveBtn = view.querySelector('#saveProfileBtn');
  const noteBox = view.querySelector('.profile-note-box');
  if (noteBox && p.notes) noteBox.textContent = p.notes;
  if (saveBtn) {
    saveBtn.onclick = async () => {
      saveBtn.disabled = true;
      const r = await nui('saveProfile', {
        identifier: p.identifier,
        notes: noteBox ? noteBox.innerText.trim() : '',
        profile_image: imgInput ? imgInput.value.trim() : ''
      });
      saveBtn.disabled = false;
      if (r && r.ok) {
        activeProfile.notes = noteBox ? noteBox.innerText.trim() : '';
        activeProfile.profile_image = imgInput ? imgInput.value.trim() : '';
        toast(r.message || 'Profil gemt.');
      } else toast((r && r.message) || 'Kunne ikke gemme profil.');
    };
  }
  const gangRegBtn = view.querySelector('[data-profile-gang-register]');
  const gangRemBtn = view.querySelector('[data-profile-gang-remove]');
  if(gangRegBtn){
    gangRegBtn.onclick = async () => {
      const gangId = Number($('#profileGangSelect')?.value || 0);
      const role = ($('#profileGangRole')?.value || 'Medlem').trim();
      if(!gangId){ toast('Vælg en bande.'); return; }
      const resp = await nui('registerNskGangMember', { identifier: p.identifier, person_name: p.name, gang_id: gangId, role });
      if(resp && resp.ok){
        activeProfile.gang = resp.gang || activeProfile.gang;
        toast(resp.message || 'Bandemedlem registreret.');
        renderProfileDetail();
        refreshProfiles();
      } else toast(resp?.message || 'Kunne ikke registrere bandemedlem.');
    };
  }
  if(gangRemBtn){
    gangRemBtn.onclick = async () => {
      const resp = await nui('removeNskGangMember', { identifier: p.identifier });
      if(resp && resp.ok){
        activeProfile.gang = null;
        toast(resp.message || 'Banderegistrering fjernet.');
        renderProfileDetail();
        refreshProfiles();
      } else toast(resp?.message || 'Kunne ikke fjerne bandemarkering.');
    };
  }
  const wireBtn = view.querySelector('#startWiretapBtn');
  const wireStopBtn = view.querySelector('#stopWiretapBtn');
  const wireInput = view.querySelector('#wiretapPhoneId');
  const lockInfo = view.querySelector('#wiretapLockInfo');
  if (wireInput) {
    wireInput.onchange = wireInput.onblur = async () => {
      const phoneId = (wireInput.value || '').trim();
      if (!phoneId || !lockInfo) return;
      const lr = await nui('getWiretapLock', { phoneId });
      if (lr && lr.lock && lr.lock.ownerName) {
        lockInfo.textContent = `Aflytning påbegyndt af: ${lr.lock.ownerName}`;
        lockInfo.classList.remove('hidden');
      } else lockInfo.classList.add('hidden');
    };
  }
  if (wireBtn && wireInput) {
    wireBtn.onclick = async () => {
      const phoneId = (wireInput.value || '').trim();
      if (!phoneId) { toast('Indtast narkotelefon ID (fx NT-482910).'); return; }
      const r = await nui('startNarkoWiretap', { phoneId });
      if (r && r.ok) {
        mdtWiretapPhoneId = r.phoneId || phoneId;
        openMdtWiretapOverlay(mdtWiretapPhoneId, r.logs || [], r.session || null);
        startMdtWiretapPoll();
        updateWiretapProfileButtons();
        toast('Aflytning startet — MDT forbliver åben.');
      } else toast((r && r.message) || 'Kunne ikke starte aflytning.');
    };
  }
  if (wireStopBtn) {
    wireStopBtn.onclick = async () => {
      const r = await nui('stopNarkoWiretap', {});
      if (r && r.ok) {
        stopMdtWiretapPoll();
        closeMdtWiretapOverlay(true);
        mdtWiretapPhoneId = null;
        updateWiretapProfileButtons();
        toast(r.message || 'Aflytning stoppet og gemt.');
        if (activePage === 'files') refreshFilesPage();
      } else toast((r && r.message) || 'Kunne ikke stoppe aflytning.');
    };
  }
  updateWiretapProfileButtons();
}
function closeProfilePreview(id){
  const el = id ? document.getElementById(id) : document.querySelector('.profile-preview-overlay:last-of-type');
  if(el) el.remove();
  openProfilePreviewStack = [...document.querySelectorAll('.profile-preview-overlay')].map(x=>x.id);
  activeProfilePreview = null;
}
async function openProfilePreviewByIdentifier(identifier){
  if(!identifier){ toast('Ingen profil-id fundet.'); return; }
  const r = await nui('getProfile', { identifier });
  activeProfilePreview = (r && r.profile) || null;
  if(!activeProfilePreview){ toast('Kunne ikke åbne profil.'); return; }
  renderProfilePreview(activeProfilePreview);
}
function renderProfilePreview(p){
  const overlayId = 'profilePreviewOverlay_' + Date.now();
  const offset = Math.min(openProfilePreviewStack.length * 22, 88);
  const vehicles = (p.vehicles || []).slice(0,10).map(car => {
    const status = escapeHtml(car.status || 'Ukendt');
    const locked = status.toLowerCase().includes('låst');
    const impound = status.toLowerCase().includes('impound') || status.toLowerCase().includes('beslaglagt');
    return `<div class="preview-vehicle-row"><div><b>${escapeHtml(car.plate || 'Ukendt')}</b><small>${escapeHtml(car.model || 'Ukendt model')} · Type: ${escapeHtml(car.type || 'Ukendt type')}</small></div><span class="${locked ? 'locked-badge' : (impound ? 'mini-badge blue' : 'mini-badge green')}">${locked ? 'LÅST' : status}</span></div>`;
  }).join('') || '<div class="profile-empty-row">Ingen køretøjer fundet.</div>';

  const overlay = document.createElement('div');
  overlay.id = overlayId;
  overlay.className = 'profile-preview-overlay profile-full-modal-overlay';
  overlay.style.setProperty('--stack-offset', offset + 'px');
  overlay.style.zIndex = String(11100 + document.querySelectorAll('.profile-preview-overlay').length);
  overlay.innerHTML = `<div class="profile-preview-card profile-full-modal-card">
    <div class="preview-head profile-modal-head">
      <div class="preview-avatar">☷</div>
      <div><h2>${escapeHtml(p.name || 'Ukendt borger')}</h2><small>${escapeHtml(p.identifier || '')}</small></div>
      <button id="closeProfilePreview" title="Luk">×</button>
    </div>
    ${wantedProfileBanner(p)}<div class="profile-modal-grid">
      <section class="profile-modal-photo">
        <div class="profile-photo compact profile-photo-real">${profileImageHtml(p.profile_image, p.name, 'profile-large-img')}</div>
        <div class="profile-note-box compact" contenteditable="false">${escapeHtml(p.notes || 'Ingen noter gemt endnu.')}</div>
      </section>
      <section class="profile-modal-details">
        <h3>Detaljer</h3>
        <div class="preview-grid wide">
          <div><label>Navn</label><b>${escapeHtml(p.name || 'Ukendt')}</b></div>
          <div><label>Identifier</label><b>${escapeHtml(p.identifier || 'Ukendt')}</b></div>
          <div><label>Fødselsdato</label><b>${escapeHtml(p.dob || 'Ukendt')}</b></div>
          <div><label>Telefon</label><b>${escapeHtml(p.phone || 'Ingen data')}</b></div>
          <div><label>Job</label><b>${escapeHtml(p.job || 'Ukendt')}</b></div>
          <div><label>Køn</label><b>${escapeHtml(p.sex || 'Ukendt')}</b></div>
        </div>
        <h3>Køretøjer</h3>
        <div class="preview-vehicles-scroll">${vehicles}</div>
      </section>
      <aside class="profile-modal-side">
        <div class="profile-side-section"><h3>Økonomi / Udestående</h3><div class="profile-money"><span>Samlet</span><b>${escapeHtml(p.unpaid_formatted || p.unpaid || '0 kr.')}</b></div><div class="unpaid-list">${renderUnpaidBillsHtml(p)}</div></div>
        <div class="profile-side-section"><h3>Licenser</h3><div class="pill-row">${profileLicenseInfo(p).revoked ? '<span class="tag danger">Frakendt</span>' : '<span class="tag ok">Kørekort</span>'}</div></div>
        <div class="profile-side-section"><h3>Kørekort - aktive klip <span class="right-counter">${escapeHtml(profileLicenseInfo(p).counter)}</span></h3><div class="license-meter"><strong>${escapeHtml(profileLicenseInfo(p).strong)}</strong><small>${escapeHtml(profileLicenseInfo(p).small)}</small></div></div>
      </aside>
    </div>
    <div class="preview-actions"><button class="ghost" id="previewClose2">Luk profil</button></div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.querySelector('#closeProfilePreview').onclick = () => closeProfilePreview(overlayId);
  overlay.querySelector('#previewClose2').onclick = () => closeProfilePreview(overlayId);
  overlay.addEventListener('mousedown', e => { if(e.target === overlay) closeProfilePreview(overlayId); });
  openProfilePreviewStack.push(overlayId);
}
function vehicleStatusClass(status){
  const s = String(status || '').toLowerCase();
  if(s.includes('permanent')) return 'danger';
  if(s.includes('låst') || s.includes('impound')) return 'warn';
  if(s.includes('efterlyst')) return 'danger';
  return 'ok';
}
function setVehicleRegistryMode(mode){
  const sec = $('#vehicles');
  if(!sec) return;
  const detail = mode === 'detail';
  sec.classList.toggle('vehicle-list-mode', !detail);
  sec.classList.toggle('vehicle-detail-mode', detail);
}
function renderVehicleRegistryResults(){
  const box = $('#vehicleRegistryResults'); if(!box) return;
  if(!registryVehicleResults.length){
    box.innerHTML = '<div class="vehicle-empty-search">Ingen køretøjer fundet.</div>';
    return;
  }
  box.innerHTML = registryVehicleResults.map((v,idx)=>{
    const active = activeVehicleProfile && activeVehicleProfile.plate === v.plate;
    return `<div class="vehicle-registry-card ${active ? 'active' : ''}" data-open-registry-vehicle="${idx}">
      <div class="vehicle-registry-icon">▣</div>
      <div class="vehicle-registry-main"><b>${escapeHtml(v.plate || 'Ukendt')}</b><small><span class="vehicle-model-name">${escapeHtml(displayVehicleModel(v))}</span> · Ejer: ${escapeHtml(v.ownerName || 'Ukendt')}</small></div>
      ${vehicleStatusBadge(v.status)}
    </div>`;
  }).join('');
}
async function searchVehicleRegistry(){
  const q = $('#vehicleRegistrySearch')?.value || '';
  if(!q.trim()){
    registryVehicleResults = [];
    activeVehicleProfile = null;
    setVehicleRegistryMode('list');
    const box = $('#vehicleRegistryResults');
    if(box) box.innerHTML = '<div class="vehicle-empty-search"><b>Ingen køretøjer fundet</b><span>Søg efter nummerplade, model eller ejer.</span></div>';
    renderVehicleProfileEmpty();
    return;
  }
  const r = await nui('getVehicles', { search: q });
  vehicleReturnPermission = !!(r && r.canReturn);
  vehicleReturnLockedPermission = !!(r && r.canReturnLocked);
  vehicleReturnPermanentPermission = !!(r && r.canReturnPermanent);
  logPermDebug('vehicle search permissions', r);
  registryVehicleResults = (r && r.vehicles) || [];
  activeVehicleProfile = null;
  setVehicleRegistryMode('list');
  renderVehicleRegistryResults();
  renderVehicleProfileEmpty();
  await hydrateVehicleModels(registryVehicleResults);
  if(activeVehicleProfile) await hydrateVehicleModels([activeVehicleProfile]);
  renderVehicleRegistryResults();
  if(activeVehicleProfile) renderVehicleProfile();
}
async function openRegistryVehicle(idx){
  const v = registryVehicleResults[idx]; if(!v) return;
  activeVehicleProfile = Object.assign({}, v, { reports: [], _loadingDetail: true, _loadingReports: true });
  setVehicleRegistryMode('detail');
  renderVehicleRegistryResults();
  renderVehicleProfile();
  try {
    const r = await nui('getVehicleDetail', { plate: v.plate, includeReports: false });
    activeVehicleProfile = (r && r.vehicle) ? Object.assign({}, v, r.vehicle, { reports: [], _loadingDetail: false, _loadingReports: true }) : Object.assign({}, v, { _loadingDetail: false, _loadingReports: false });
    await hydrateVehicleModels([activeVehicleProfile]);
    renderVehicleProfile();
    const targetPlate = (r && r.vehicle && r.vehicle.plate) || v.plate;
    nui('getVehicleLinkedReports', { plate: targetPlate }).then((lr) => {
      if (!activeVehicleProfile || String(activeVehicleProfile.plate || '') !== String(targetPlate || '')) return;
      activeVehicleProfile.reports = (lr && lr.reports) || [];
      activeVehicleProfile._loadingReports = false;
      renderVehicleProfile();
    }).catch(() => {
      if (activeVehicleProfile) { activeVehicleProfile._loadingReports = false; renderVehicleProfile(); }
    });
  } catch (_) {
    activeVehicleProfile = Object.assign({}, v, { _loadingDetail: false, _loadingReports: false });
    renderVehicleProfile();
    toast('Kunne ikke hente køretøjsprofil.');
  }
}
function renderVehicleProfileEmpty(){
  const view = $('#vehicleProfileView'); if(view) view.innerHTML = '<div class="vehicle-profile-empty">Vælg et køretøj fra søgningen for at se data.</div>';
}
function renderVehicleProfile(){
  const view = $('#vehicleProfileView'); if(!view || !activeVehicleProfile) return;
  const v = activeVehicleProfile;
  const statusText = String(v.status || 'Ukendt');
  const statusLower = statusText.toLowerCase();
  const isWanted = v.wanted === true || statusLower.includes('efterlyst');
  const statusCls = vehicleStatusClass(v.status);
  const isPermanent = statusLower.includes('permanent') || String(v.impound_type || '').toLowerCase() === 'permanent';
  const isLocked = statusLower.includes('låst') || String(v.impound_type || '').toLowerCase() === 'locked' || Number(v.locked || v.impound_locked || 0) === 1;
  const isImpound = statusLower.includes('impound') || statusLower.includes('beslaglagt') || isPermanent || isLocked;
  const isGarage = statusLower.includes('garage');
  const canReleaseLocked = !!vehicleReturnLockedPermission;
  const canReleasePermanent = !!vehicleReturnPermanentPermission;
  const canReleaseHere = isPermanent ? canReleasePermanent : (isLocked ? canReleaseLocked : false);
  const missingReleasePerm = isPermanent ? 'vehicles.impound.permanent.release' : 'vehicles.impound.locked.release';
  const modelLabel = displayVehicleModel(v);
  const reports = v.reports || [];
  const reportHtml = v._loadingReports
    ? '<div class="vehicle-muted-box">Henter linkede rapporter...</div>'
    : (reports.length ? reports.slice(0,6).map(r=>`<div class="vehicle-report-row clickable" data-open-incident-ref="${escapeHtml(r.incident_no||r.id||'')}"><div><b>#${escapeHtml(r.id||r.incident_no||'---')} - ${escapeHtml(r.title||'Hændelse')}</b><small>${escapeHtml(fmtDate(r.date)||'')} · ${escapeHtml(r.officer||'')}</small></div><span class="vehicle-status warn">${escapeHtml(r.status||'Aktiv')}</span></div>`).join('') : '<div class="vehicle-muted-box">Ingen hændelser/rapport-link med dette køretøj endnu.</div>');
  const vehicleImg = (v.profile_image || v.image) ? `<img src="${escapeHtml(v.profile_image || v.image)}" alt="Køretøj" class="vehicle-profile-img" id="vehiclePhotoPreview">` : `<div class="vehicle-plate-visual" id="vehiclePhotoPreview"><small>San Andreas</small><b>${escapeHtml(v.plate || 'Ukendt')}</b></div>`;
  const impoundHtml = isImpound ? `
    <section class="vehicle-impound-card profile-style-card">
      <div class="vehicle-impound-head">
        <div><small>IMPOUND</small><h3>${isPermanent ? 'Politiopbevaring' : (isLocked ? 'Låst impound' : 'Normal impound')}</h3></div>
        ${vehicleStatusBadge(v.status, { big: true })}
      </div>
      <div class="vehicle-impound-grid">
        <div><label>Nummerplade</label><b>${escapeHtml(v.plate || 'Ukendt')}</b></div>
        <div><label>Status</label><b>${escapeHtml(v.status || 'Ukendt')}</b></div>
        <div><label>Årsag</label><b>${escapeHtml(v.reason || v.impound_reason || 'Ingen årsag registreret')}</b></div>
        <div><label>Betjent</label><b>${escapeHtml(v.officer || v.impound_officer || 'System')}</b></div>
      </div>
      <div class="vehicle-impound-actions">
        ${canReleaseHere ? `<button class="release-neon-card" data-return="${escapeHtml(v.plate||'')}"><b>${isPermanent ? 'Frigiv fra politiopbevaring' : 'Frigiv låst impound'}</b><small>Åbner bekræftelse med pris</small></button>` : (!isLocked && !isPermanent ? `<button class="ghost disabled" disabled title="Normal impound: ejer henter via kaution">Ejer henter via kaution</button>` : `<span class="perm-hidden-note">Frigivelse kræver ${missingReleasePerm}</span>`)}
      </div>
    </section>` : '';
  view.innerHTML = `
    <div class="profile-detail-top vehicle-detail-top">
      <button class="ghost" id="vehicleBackToSearch">← Tilbage</button>
      <div class="profile-detail-title"><b>${escapeHtml(v.plate || 'Ukendt')}</b><small>${escapeHtml(v.ownerName || 'Ukendt ejer')} · ${escapeHtml(modelLabel)}</small></div>
      <button class="save secondary" id="saveVehicleProfileBtn" ${v._loadingDetail ? 'disabled' : ''}>${v._loadingDetail ? 'Henter...' : 'Gem profil'}</button>
      ${vehicleStatusBadge(v.status, { big: true })}
    </div>
    ${impoundHtml}
    <div class="profile-detail-grid vehicle-detail-grid">
      <section class="profile-left-card vehicle-left-card">
        ${vehicleImg}
        <div class="profile-field compact"><label>BILLEDE URL</label><input id="vehicleImageUrl" value="${escapeHtml(v.profile_image || v.image || '')}" placeholder="https://..."></div>
        <div class="profile-note-box vehicle-note-box" contenteditable="true" data-placeholder="Noter om køretøjet..."></div>
        <div class="vehicle-model-chip"><b>${escapeHtml(modelLabel)}</b><small>${escapeHtml(v.type || 'Køretøj')}</small></div>
      </section>
      <section class="profile-main-card">
        <h3>DETALJER</h3>
        <div class="profile-field"><label>EJER</label><input value="${escapeHtml(v.ownerName || 'Ukendt')}" readonly></div>
        <div class="profile-field"><label>NUMMERPLADE</label><input value="${escapeHtml(v.plate || 'Ukendt')}" readonly></div>
        <div class="profile-field"><label>MODEL</label><input value="${escapeHtml(modelLabel)}" readonly></div>
        <div class="profile-field"><label>TYPE</label><input value="${escapeHtml(v.type || 'Ukendt')}" readonly></div>
        <div class="vehicle-actions-row compact">
          <button class="save" data-open-owner-profile>Åbn ejerprofil</button>
          <button class="save secondary" id="trackVehicleBtn">Spor køretøj</button>
        </div>
      </section>
      <aside class="profile-right-card">
        <div class="profile-side-section"><h3>STATUS</h3>
          <div class="vehicle-status-list">
            <div><span>Status</span><b class="vehicle-status ${statusCls}">${escapeHtml(v.status || 'Ukendt')}</b></div>
            <div><span>Efterlyst</span><b class="vehicle-status ${isWanted?'danger':'ok'}">${isWanted?'Ja':'Nej'}</b></div>
            ${isWanted && v.anpgReason ? `<div><span>ANPG</span><b class="vehicle-status danger">${escapeHtml(v.anpgReason)}${v.anpgDetail ? ' · ' + escapeHtml(v.anpgDetail) : ''}</b></div>` : ''}
            <div><span>Impound</span><b>${isImpound ? vehicleStatusBadge(v.status) : '<span class="vehicle-status ok">Nej</span>'}</b></div>
            <div><span>Låst</span><b class="vehicle-status ${isLocked?'warn':'ok'}">${isLocked?'Ja':'Nej'}</b></div>
            <div><span>Garage</span><b class="vehicle-status ${isGarage?'ok':'warn'}">${isGarage?'Ja':'Nej'}</b></div>
          </div>
        </div>
        <div class="profile-side-section"><h3>LINKEDE RAPPORTER</h3>${reportHtml}</div>
        <div class="profile-side-section"><h3>AKTIVITET</h3><div class="vehicle-timeline compact"><div><i>●</i><b>Data hentet fra køretøjsregister</b><small>${new Date().toLocaleString('da-DK')}</small></div></div></div>
      </aside>
    </div>
  `;
  $('#vehicleBackToSearch') && ($('#vehicleBackToSearch').onclick = () => { setVehicleRegistryMode('list'); setTimeout(()=>$('#vehicleRegistrySearch')?.focus(),50); });
  const noteBox = view.querySelector('.vehicle-note-box');
  if (noteBox && v.notes) noteBox.textContent = v.notes;
  const imgInput = view.querySelector('#vehicleImageUrl');
  const photoPreview = view.querySelector('#vehiclePhotoPreview');
  if (imgInput && photoPreview) {
    imgInput.oninput = () => {
      const url = imgInput.value.trim();
      if (url) photoPreview.outerHTML = `<img src="${escapeHtml(url)}" alt="Køretøj" class="vehicle-profile-img" id="vehiclePhotoPreview">`;
      else photoPreview.outerHTML = `<div class="vehicle-plate-visual" id="vehiclePhotoPreview"><small>San Andreas</small><b>${escapeHtml(v.plate || 'Ukendt')}</b></div>`;
    };
  }
  const saveVehBtn = view.querySelector('#saveVehicleProfileBtn');
  if (saveVehBtn) {
    saveVehBtn.onclick = async () => {
      saveVehBtn.disabled = true;
      const r = await nui('saveVehicleProfile', {
        plate: v.plate,
        notes: noteBox ? noteBox.innerText.trim() : '',
        profile_image: imgInput ? imgInput.value.trim() : ''
      });
      saveVehBtn.disabled = false;
      if (r && r.ok) {
        activeVehicleProfile.notes = noteBox ? noteBox.innerText.trim() : '';
        activeVehicleProfile.profile_image = imgInput ? imgInput.value.trim() : '';
        toast(r.message || 'Køretøjsprofil gemt.');
      } else toast((r && r.message) || 'Kunne ikke gemme.');
    };
  }
  const trackBtn = view.querySelector('#trackVehicleBtn');
  if (trackBtn) {
    trackBtn.onclick = async () => {
      trackBtn.disabled = true;
      const r = await nui('trackVehicle', { plate: v.plate });
      trackBtn.disabled = false;
      toast((r && r.message) || ((r && r.ok) ? 'GPS sat.' : 'Kunne ikke spore køretøj.'));
      if (r && r.ok && activePage === 'files') refreshFilesPage();
    };
  }
  view.querySelectorAll('[data-open-incident-ref]').forEach((el) => {
    el.onclick = () => {
      const id = el.dataset.openIncidentRef;
      const inc = (incidents || []).find((i) => String(i.incident_no || i.id) === String(id));
      if (inc) openIncident(inc);
      else toast('Hændelsen er ikke indlæst — søg under Hændelser.');
    };
  });
}
async function refreshVehicles(){
  const r = await nui('refreshPermanentVehicles', {});
  const rows = r?.vehicles || [];
  const canReturn = !!(r && r.canReturn);
  const canReturnLocked = !!(r && r.canReturnLocked);
  const canReturnPermanent = !!(r && r.canReturnPermanent);
  $('#modalTitle').textContent = 'Beslaglagte og låste køretøjer';
  $('#modalFields').innerHTML = `<div class="perm-list-modal">${rows.length ? rows.map(v=>{
    const isPermanentRow = String(v.status||'').toLowerCase().includes('permanent') || String(v.impound_type||'').toLowerCase()==='permanent';
    const allowedRow = isPermanentRow ? canReturnPermanent : canReturnLocked;
    const returnButton = allowedRow ? `<button class="save" data-return="${escapeHtml(v.plate)}">${isPermanentRow?'Frigiv fra politiopbevaring':'Lås op / giv tilbage'}</button>` : `<button class="ghost disabled" disabled title="Kræver permission">Låst</button>`;
    return `<div class="vehicle-card"><div><b>${escapeHtml(v.plate)}</b><span> · ${escapeHtml(v.owner||'Ukendt ejer')}</span>${Number(v.locked||v.impound_locked||0)===1?'<em class="locked-badge">LÅST</em>':''}<br><small>${escapeHtml(v.model || 'Ukendt model')} · Type: ${escapeHtml(v.type || 'Ukendt type')} · ${escapeHtml(v.status || v.reason || 'Beslaglagt/låst')}</small></div>${returnButton}</div>`;
  }).join('') : '<div class="vehicle-muted-box">Ingen beslaglagte eller låste køretøjer.</div>'}</div>`;
  $('#modalSave').onclick = closeModal;
  $('#modalSave').textContent = 'Luk';
  $('#modal').classList.remove('hidden');
}
function openReturnModal(plate){
  $('#modalTitle').textContent = 'Frigiv køretøj til normal impound';
  $('#modalFields').innerHTML = `<label>Nummerplade</label><input id="returnPlate" value="${escapeHtml(plate)}" disabled><label>Kaution / impound-pris</label><input id="returnPrice" type="number" min="0" value="0" placeholder="Indtast kaution/pris - 0 er gratis">`;
  $('#modal').classList.remove('hidden');
  setTimeout(()=>$('#returnPrice')?.focus(),50);
  $('#modalSave').onclick = async () => {
    const price = Number($('#returnPrice')?.value || 0) || 0;
    const btn = $('#modalSave'), old = btn.textContent;
    btn.disabled = true; btn.textContent = 'Sender...';
    try{
      logPermDebug('release request', { plate, price });
      const r = await nui('returnPermanentVehicle', { plate, price });
      if(r && r.ok){
        $('#modal').classList.add('hidden');
        toast(r.message || 'Køretøjet er frigivet til normal impound.');
        setTimeout(() => { searchVehicleRegistry(); }, 350);
      } else {
        toast((r && r.message) || 'Kunne ikke give køretøjet tilbage.');
      }
    } catch(e){
      console.error(e);
      toast('Fejl ved frigivelse. UI er låst op igen.');
    } finally { btn.disabled = false; btn.textContent = old; }
  };
}



function syncIncidentDeleteButton(){
  const btn = $('#deleteIncident');
  if(!btn) return;
  const hidden = !mdtCanDeleteIncident || currentIncident?.locked || currentIncident?.draft || !currentIncident?.id;
  btn.style.display = hidden ? 'none' : '';
}

function isRigspolitietJob(job, debug){
  const j = job || debug?.job || {};
  const grade = Number(j.grade ?? j.grade_number ?? 0);
  const gradeLabel = String(j.grade_label || j.grade_name || '').toLowerCase();
  const candidates = (debug?.candidates || []).map((c) => String(c).toLowerCase());
  const roleNames = (debug?.roles || []).map((r) => String(r?.name || '').toLowerCase());
  return grade >= 7
    || gradeLabel === 'rigspolitiet'
    || gradeLabel === 'boss'
    || candidates.includes('rigspolitiet')
    || roleNames.includes('rigspolitiet');
}
function refreshAdministrationAccess(){
  const perms = new Set((mdtOwnPermissions || []).map(x => String(x).toLowerCase()));
  const checks = permissionDebug?.checks || {};
  const isRigspolitiet = isRigspolitietJob(null, permissionDebug);
  mdtAdminView = isRigspolitiet || perms.has('administration.view') || perms.has('admin.roles.manage') || checks.administrationView === true || checks.rolesManage === true;
  mdtEmployeeAdmin = checks.employeeAdmin === true || mdtAdminView;
  mdtCanDeleteIncident = checks.deleteIncident === true;
  syncIncidentDeleteButton();
  const hireBtn = $('#hireEmployeeBtn');
  if(hireBtn) hireBtn.style.display = mdtEmployeeAdmin ? '' : 'none';
  const main = $('.admin-main');
  const drop = $('.admin-dropdown');
  if(main){
    main.classList.toggle('admin-locked', !mdtAdminView);
    main.setAttribute('aria-disabled', mdtAdminView ? 'false' : 'true');
    main.title = mdtAdminView ? '' : 'Kræver administration.view eller Rigspolitiet';
  }
  if(drop){
    if(!mdtAdminView) drop.classList.add('closed');
  }
  refreshNskAccess();
}
function refreshNskAccess(){
  const perms = new Set((mdtOwnPermissions || []).map(x => String(x).toLowerCase()));
  const checks = permissionDebug?.checks || {};
  const roleNames = [
    ...(permissionDebug?.roles || []).map(r => String(r?.name || '')),
    ...(permissionDebug?.candidates || []),
    String(selfProfile?.role || ''),
    String(permissionDebug?.job?.grade_label || ''),
    String(permissionDebug?.job?.grade_name || ''),
  ].map((n) => String(n).toLowerCase()).filter(Boolean);
  const division = String(permissionDebug?.division || selfProfile?.division || '').toLowerCase();
  const hasNskRole = roleNames.some((n) => NSK_AUTO_ROLES.includes(n));
  const hasNskDivision = division === 'nsk';
  mdtNskView = checks.nskView === true || perms.has('nsk.view') || perms.has('nsk.manage') || hasNskRole || hasNskDivision;
  mdtNskManage = checks.nskManage === true || perms.has('nsk.manage') || NSK_AUTO_ROLES.slice(0, 2).some((r) => roleNames.includes(r)) || hasNskDivision;
  const main = $('.nsk-main');
  const drop = $('.nsk-dropdown');
  if(main){
    main.classList.toggle('nsk-locked', !mdtNskView);
    main.title = mdtNskView ? '' : 'Kræver NSK-adgang (NSK afdeling, nsk.view eller NSK Chef)';
  }
  if(drop && !mdtNskView) drop.classList.add('closed');
  else if(drop && isNskPage(activePage)) drop.classList.remove('closed');
  document.querySelectorAll('.nsk-manage-only').forEach((el) => el.classList.toggle('hidden', !mdtNskManage));
}
function openNskPage(page){
  refreshNskAccess();
  if(!mdtNskView){
    toast({ type:'error', title:'Ingen adgang', message:'Du mangler NSK-adgang. Kontakt NSK Chef eller få tildelt NSK afdeling / nsk.view.' });
    return;
  }
  toggleNskDropdown(true);
  setPage(page || 'nsk_gangs');
}
function openAdminPage(page){
  if(!mdtAdminView){
    toast({ type:'error', title:'Ingen adgang', message:'Du mangler administration.view eller Rigspolitiet.' });
    refreshAdministrationAccess();
    return;
  }
  setPage(page);
}

async function openEvidenceLocker(){
  if(!currentIncident){ toast('Vælg eller opret en hændelse først.'); return; }
  if(currentIncident.draft || !currentIncident.id){ toast('Gem hændelsen før du åbner evidence locker.'); return; }
  const btn = document.querySelector('[data-open-evidence-locker]');
  const old = btn ? btn.textContent : '';
  if(btn){ btn.disabled = true; btn.textContent = 'ÅBNER...'; }
  try{
    const r = await nui('openEvidenceLocker', { incidentId: currentIncident.id, incidentNo: currentIncident.incident_no, title: currentIncident.title });
    if(r && r.ok){
      toast(r.message || 'Evidence locker åbnes i ox_inventory.');
    } else {
      toast(r?.message || 'Kunne ikke åbne evidence locker.');
    }
  } finally {
    if(btn){ btn.disabled = false; btn.textContent = old || 'ÅBN LOCKER'; }
  }
}


function openHireModal(){
  $('#modalTitle').textContent = 'Ansæt medarbejder';
  $('#modalFields').innerHTML = `<label>Identifier</label><input id="hireIdentifier" placeholder="char1:... / steam:..."><label>Rolle</label><select id="hireRole">${mdtRoles.map(r=>`<option>${escapeHtml(r)}</option>`).join('')}</select><label>Afdeling</label><select id="hireDivision">${mdtDivisions.map(d=>`<option>${escapeHtml(d)}</option>`).join('')}</select>`;
  $('#modal').classList.remove('hidden');
  $('#modalSave').onclick = async () => {
    const identifier = $('#hireIdentifier').value.trim();
    const role = $('#hireRole').value; const division = $('#hireDivision').value;
    const r = await nui('updateEmployee', { identifier, role, division, pnumber:'' });
    $('#modal').classList.add('hidden'); toast(r?.message || 'Ansættelse sendt.'); refreshEmployees();
  };
}

function normalizeRolePermissions(perms){
  if(Array.isArray(perms)) return perms.map((p) => String(p));
  if(perms && typeof perms === 'object') return Object.keys(perms).filter((k) => perms[k]);
  return [];
}

function renderEmployees(){
  const box = $('#employeesBody'); if(!box) return;
  if(!employees.length){ box.innerHTML = '<div class="admin-empty">Ingen ansatte fundet.</div>'; return; }
  box.innerHTML = employees.map((e,idx)=>{
    const badge = officerBadge(e);
    const adminBtn = mdtEmployeeAdmin ? `<button class="ghost small emp-admin-gear" data-employee-admin="${idx}" title="Administrer medarbejder">⚙️</button>` : '';
    return `<div class="employee-row employee-row-clean">
      <div class="emp-name emp-name-with-photo">${profileImageHtml(e.profile_image, e.name, 'emp-thumb')}<div><b>${escapeHtml(e.name||'Ukendt')}</b><small>${escapeHtml(e.identifier||'')}</small></div></div>
      <div class="emp-static"><b>${escapeHtml(badge || '—')}</b></div>
      <div class="emp-static"><span>${escapeHtml(e.role || 'Betjent')}</span></div>
      <div class="emp-static"><span>${escapeHtml(e.division || 'Patrulje')}</span></div>
      <div class="emp-actions">${adminBtn}</div>
    </div>`;
  }).join('');
}

function generateEmployeePassword(emp){
  const p = String(emp?.pnumber || emp?.grade || '00').replace(/[^0-9A-Za-z]/g,'') || '00';
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let a='', b='';
  for(let i=0;i<4;i++){ a += chars[Math.floor(Math.random()*chars.length)]; b += chars[Math.floor(Math.random()*chars.length)]; }
  return `PO-${p}-${a}-${b}`;
}

function openEmployeeLoginModal(idx){
  const emp = employees[idx]; if(!emp) return;
  const username = employeeUsername(emp);
  $('#modalTitle').textContent = 'MDT login';
  $('#modalFields').innerHTML = `
    <div class="employee-login-modal">
      <div class="login-meta-row"><span>Navn</span><b>${escapeHtml(emp.name || 'Ukendt')}</b></div>
      <div class="login-meta-row"><span>Identifier</span><small>${escapeHtml(emp.identifier || '')}</small></div>
      <div class="login-meta-row"><span>Tjenestenummer</span><b>${escapeHtml(username)}</b></div>
      <div class="login-meta-row"><span>Brugernavn</span><b>${escapeHtml(username)}</b></div>
      <label>Adgangskode</label>
      <div class="login-password-row">
        <input id="empLoginPassword" type="password" value="${escapeHtml(emp.mdt_password || '')}" placeholder="Skriv adgangskode">
        <button id="empShowPassword" class="ghost small" type="button">Se kode</button>
      </div>
      <div class="login-modal-actions">
        <button id="empGeneratePassword" class="ghost small" type="button">Generer kode</button>
      </div>
      <p class="modal-subtitle">Denne kode bruges sammen med brugernavnet ${escapeHtml(username)} på MDT login.</p>
    </div>`;
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Gem kode';
  $('#modal').classList.remove('hidden');
  const pass = $('#empLoginPassword');
  const showBtn = $('#empShowPassword');
  const genBtn = $('#empGeneratePassword');
  if(showBtn) showBtn.onclick = () => {
    const show = pass.type === 'password';
    pass.type = show ? 'text' : 'password';
    showBtn.textContent = show ? 'Skjul kode' : 'Se kode';
  };
  if(genBtn) genBtn.onclick = () => {
    pass.value = generateEmployeePassword(emp);
    pass.type = 'text';
    if(showBtn) showBtn.textContent = 'Skjul kode';
  };
  $('#modalSave').onclick = async () => {
    const newPass = pass?.value || '';
    emp.mdt_password = newPass;
    emp.mdt_username = username;
    const badgeParts = parseEmployeeBadge(emp);
    const r = await nui('updateEmployee', {
      identifier: emp.identifier,
      role: emp.role,
      division: emp.division || 'Patrulje',
      badge_prefix: badgeParts.prefix,
      pnumber: badgeParts.digits,
      profile_image: emp.profile_image || '',
      mdt_password: newPass
    });
    if(r?.ok){ closeModal(); toast('MDT login-kode gemt.'); refreshEmployees(); }
    else toast(r?.message || 'Kunne ikke gemme MDT-kode.');
  };
}

async function openEmployeePermsModal(idx){
  const emp = employees[idx]; if(!emp) return;
  if(!permissionCatalog.length) await loadPermissionCatalog();
  $('#modalTitle').textContent = 'Medarbejder permissions';
  $('#modalFields').innerHTML = `<p class="modal-subtitle">${escapeHtml(emp.name || emp.identifier)}</p><div class="perm-debug-strip"><b>Bemærk</b><span>Adgang styres server-side via rollen. Denne visning er kun overblik for medarbejderen.</span></div>${renderPermissionCards(emp.permissions || [])}`;
  bindPermissionCards();
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Gem lokalt';
  $('#modal').classList.remove('hidden');
  $('#modalSave').onclick = () => {
    emp.permissions = selectedPermissionCards();
    closeModal();
    renderEmployees();
    toast('Permissions markeret lokalt. Rolle-systemet bestemmer adgang server-side.');
  };
}

function employeeUsername(emp){
  if(emp?.badge) return emp.badge;
  const { prefix, digits } = parseEmployeeBadge(emp);
  return buildPoliceBadge(prefix, digits, emp?.division || 'Patrulje') || 'B0000';
}
function employeeBadgePreview(prefix, digits, division){
  return buildPoliceBadge(prefix, digits, division) || '—';
}

async function openEmployeeAdminModal(idx, tab='profile'){
  const emp = employees[idx]; if(!emp) return;
  if(tab === 'permissions' && !permissionCatalog.length) await loadPermissionCatalog();
  const tabs = [
    ['permissions','Permissions'],
    ['profile','Administrer profil'],
    ['login','MDT Login'],
    ['fire','Afsked']
  ];
  const badgeParts = parseEmployeeBadge(emp);
  $('#modalTitle').textContent = 'Medarbejder administration';
  $('#modalFields').innerHTML = `
    <div class="employee-admin-modal">
      <div class="employee-admin-head">
        ${profileImageHtml(emp.profile_image, emp.name, 'emp-admin-avatar')}
        <div><b>${escapeHtml(emp.name || 'Ukendt')}</b><small>${escapeHtml(employeeUsername(emp))} · ${escapeHtml(emp.role || 'Betjent')} · ${escapeHtml(emp.division || 'Patrulje')}</small></div>
      </div>
      <div class="employee-admin-tabs">
        ${tabs.map(([key,label])=>`<button type="button" class="ghost small ${tab===key?'active':''}" data-emp-admin-tab="${key}">${escapeHtml(label)}</button>`).join('')}
      </div>
      <div class="employee-admin-content">
        ${tab==='permissions' ? renderEmployeeAdminPermissions(emp) : ''}
        ${tab==='profile' ? renderEmployeeAdminProfile(emp, badgeParts) : ''}
        ${tab==='login' ? renderEmployeeAdminLogin(emp) : ''}
        ${tab==='fire' ? renderEmployeeAdminFire(emp) : ''}
      </div>
    </div>`;
  $('#modalSave').style.display = tab === 'fire' ? 'none' : '';
  $('#modalSave').textContent = tab === 'login' ? 'Gem kode' : (tab === 'permissions' ? 'Gem permissions' : 'Gem ændringer');
  $('#modal').classList.remove('hidden');
  bindEmployeeAdminModal(idx, tab);
}

function renderEmployeeAdminPermissions(emp){
  const perms = emp.permissions || [];
  return `<div class="perm-debug-strip"><b>Permissions</b><span>Rollen ${escapeHtml(emp.role || 'Betjent')} giver standard-adgang. Her kan du give direkte ekstra permissions til denne medarbejder.</span></div>${renderPermissionCards(perms)}`;
}

function renderEmployeeAdminProfile(emp, badgeParts){
  const prefix = badgeParts?.prefix || policeBadgePrefix(emp?.division || 'Patrulje');
  const digits = badgeParts?.digits || '';
  const preview = employeeBadgePreview(prefix, digits, emp?.division || 'Patrulje');
  return `
    <label>Profilbillede URL</label>
    <div class="employee-profile-image-edit">
      ${profileImageHtml(emp.profile_image, emp.name, 'emp-admin-avatar')}
      <input id="empAdminImage" value="${escapeHtml(emp.profile_image || '')}" placeholder="Billede-link / URL">
    </div>
    <label>Navn</label><input id="empAdminName" value="${escapeHtml(emp.name || '')}" placeholder="Navn" disabled>
    <label>Tjenestenummer</label>
    <div class="employee-badge-edit">
      <div><label class="sub">Bogstav</label><select id="empAdminBadgePrefix"><option value="B" ${prefix==='B'?'selected':''}>B · Patrulje / AKS</option><option value="F" ${prefix==='F'?'selected':''}>F · Færdsel</option><option value="E" ${prefix==='E'?'selected':''}>E · Efterforskning / NSK / Ledelse</option></select></div>
      <div><label class="sub">4 cifre</label><input id="empAdminPnumber" value="${escapeHtml(digits)}" placeholder="0099" maxlength="4" inputmode="numeric"></div>
    </div>
    <p class="employee-badge-preview">Vises som <b id="empAdminBadgePreview">${escapeHtml(preview)}</b> i MDT, login og flådestyring.</p>
    <label>Rolle</label><select id="empAdminRole">${mdtRoles.map(r=>`<option ${String(emp.role||'').toLowerCase()===r.toLowerCase()?'selected':''}>${escapeHtml(r)}</option>`).join('')}</select>
    <label>Afdeling</label><select id="empAdminDivision">${mdtDivisions.map(d=>`<option ${String(emp.division||'Patrulje').toLowerCase()===d.toLowerCase()?'selected':''}>${escapeHtml(d)}</option>`).join('')}</select>
    ${mdtEmployeeAdmin ? `<div class="employee-award-grant"><label>Tildel award fra ledelse</label><div class="employee-award-grant-row"><select id="empAdminAwardKey">${Object.entries(MDT_AWARD_DEFS).map(([k,d])=>`<option value="${escapeHtml(k)}">${escapeHtml(d.label)}</option>`).join('')}</select><input id="empAdminAwardNote" placeholder="Kort note (valgfri)"><button id="empAdminAwardBtn" class="save" type="button">Tildel</button></div></div>` : ''}
    <p class="modal-subtitle">Ansatte-listen viser kun data. Rolle, afdeling, tjenestenummer og billede ændres her.</p>`;
}
function bindEmployeeBadgePreview(){
  const sync = () => {
    const preview = $('#empAdminBadgePreview');
    if(!preview) return;
    const prefix = $('#empAdminBadgePrefix')?.value || 'B';
    const digits = pnumberDigitsOnly($('#empAdminPnumber')?.value || '');
    const division = $('#empAdminDivision')?.value || 'Patrulje';
    preview.textContent = employeeBadgePreview(prefix, digits, division);
  };
  $('#empAdminBadgePrefix')?.addEventListener('change', sync);
  $('#empAdminPnumber')?.addEventListener('input', sync);
  $('#empAdminDivision')?.addEventListener('change', sync);
  sync();
}

function renderEmployeeAdminLogin(emp){
  return `
    <div class="login-meta-row"><span>Brugernavn</span><b>${escapeHtml(employeeUsername(emp))}</b></div>
    <label>Adgangskode</label>
    <div class="login-password-row">
      <input id="empAdminPassword" type="password" value="${escapeHtml(emp.mdt_password || '')}" placeholder="Skriv adgangskode">
      <button id="empAdminShowPassword" class="ghost small" type="button">Se kode</button>
    </div>
    <div class="login-modal-actions"><button id="empAdminGeneratePassword" class="ghost small" type="button">Generer PO-kode</button></div>
    <p class="modal-subtitle">Koden bruges sammen med tjenestenummeret på MDT login.</p>`;
}

function renderEmployeeAdminFire(emp){
  return `
    <div class="employee-danger-zone">
      <b>⚠️ Afskedig medarbejder</b>
      <p>Dette sætter medarbejderen som suspenderet/afskediget og fjerner aktiv adgang.</p>
      <button id="empAdminFireBtn" class="danger" type="button">✕ Afskedig medarbejder</button>
    </div>`;
}

function bindEmployeeAdminModal(idx, tab){
  $$('#modalFields [data-emp-admin-tab]').forEach(btn => btn.onclick = () => openEmployeeAdminModal(idx, btn.dataset.empAdminTab));
  const emp = employees[idx]; if(!emp) return;
  if(tab === 'permissions'){
    bindPermissionCards();
    $('#modalSave').onclick = async () => {
      const permissions = selectedPermissionCards();
      emp.permissions = permissions;
      const r = await nui('saveEmployeePermissions', { identifier: emp.identifier, permissions });
      if(r?.ok){ closeModal(); toast('Permissions gemt.'); refreshEmployees(); }
      else toast(r?.message || 'Kunne ikke gemme permissions.');
    };
  }
  if(tab === 'profile'){
    bindEmployeeBadgePreview();
    $('#empAdminAwardBtn')?.addEventListener('click', async ()=>{
      const awardKey = $('#empAdminAwardKey')?.value || 'brave';
      const def = MDT_AWARD_DEFS[awardKey] || {};
      const r = await nui('grantOfficerAward', { identifier: emp.identifier, award_key: awardKey, award_label: def.label || awardKey, note: $('#empAdminAwardNote')?.value || '' });
      toast(r?.message || (r?.ok ? 'Award tildelt.' : 'Kunne ikke tildele award.'));
      if(r?.ok && $('#empAdminAwardNote')) $('#empAdminAwardNote').value = '';
    });
    $('#modalSave').onclick = async () => {
      const role = $('#empAdminRole')?.value || emp.role;
      const division = $('#empAdminDivision')?.value || emp.division || 'Patrulje';
      const badge_prefix = normalizeBadgePrefix($('#empAdminBadgePrefix')?.value || '', division);
      const pnumberDigits = pnumberDigitsOnly($('#empAdminPnumber')?.value || emp.pnumber || '');
      const fullBadge = buildPoliceBadge(badge_prefix, pnumberDigits, division);
      const profile_image = $('#empAdminImage')?.value || '';
      emp.role = role; emp.division = division; emp.pnumber = fullBadge; emp.badge = fullBadge; emp.profile_image = profile_image; emp.mdt_username = fullBadge || employeeUsername(emp);
      const r = await nui('updateEmployee', { identifier: emp.identifier, role, division, badge_prefix, pnumber: pnumberDigits, profile_image, mdt_password: emp.mdt_password || '' });
      if(r?.ok){ closeModal(); toast('Medarbejderprofil gemt.'); refreshEmployees(); }
      else toast(r?.message || 'Kunne ikke gemme profil.');
    };
  }
  if(tab === 'login'){
    const pass = $('#empAdminPassword');
    const showBtn = $('#empAdminShowPassword');
    const genBtn = $('#empAdminGeneratePassword');
    if(showBtn) showBtn.onclick = () => {
      const show = pass.type === 'password';
      pass.type = show ? 'text' : 'password';
      showBtn.textContent = show ? 'Skjul kode' : 'Se kode';
    };
    if(genBtn) genBtn.onclick = () => {
      pass.value = generateEmployeePassword(emp);
      pass.type = 'text';
      if(showBtn) showBtn.textContent = 'Skjul kode';
    };
    $('#modalSave').onclick = async () => {
      const newPass = pass?.value || '';
      emp.mdt_password = newPass;
      emp.mdt_username = employeeUsername(emp);
      const badgeParts = parseEmployeeBadge(emp);
      const r = await nui('updateEmployee', { identifier: emp.identifier, role: emp.role, division: emp.division || 'Patrulje', badge_prefix: badgeParts.prefix, pnumber: badgeParts.digits, profile_image: emp.profile_image || '', mdt_password: newPass });
      if(r?.ok){ closeModal(); toast('MDT login-kode gemt.'); refreshEmployees(); }
      else toast(r?.message || 'Kunne ikke gemme MDT-kode.');
    };
  }
  if(tab === 'fire'){
    const fireBtn = $('#empAdminFireBtn');
    if(fireBtn) fireBtn.onclick = async () => {
      const r = await nui('updateEmployee', { identifier: emp.identifier, role:'Suspenderet', division: emp.division || 'Patrulje', fire:true });
      toast(r?.message || (r?.ok ? 'Medarbejder afskediget.' : 'Kunne ikke afskedige.'));
      if(r?.ok){ closeModal(); refreshEmployees(); }
    };
  }
}

async function refreshEmployees(){
  const r = await nui('getEmployees', { search: $('#employeeSearch')?.value || '' });
  if(r && r.ok){
    if(typeof r.canEdit === 'boolean') mdtEmployeeAdmin = r.canEdit || mdtAdminView;
    employees = r.employees || [];
    renderEmployees();
  }
  else toast(r?.message || 'Kunne ikke hente ansatte.');
}
async function saveEmployee(idx, silent = false){
  const emp = employees[idx]; if(!emp) return;
  const roleEl = document.querySelector(`[data-emp-role="${idx}"]`);
  const divEl = document.querySelector(`[data-emp-division="${idx}"]`);
  const pnumEl = document.querySelector(`[data-emp-pnum="${idx}"]`);
  const imageEl = document.querySelector(`[data-emp-image="${idx}"]`);
  const passEl = document.querySelector(`[data-emp-pass="${idx}"]`);
  const role = roleEl?.value || emp.role;
  const division = divEl?.value || emp.division;
  const pnumber = pnumEl?.value || emp.pnumber || '';
  const profile_image = imageEl?.value || emp.profile_image || '';
  const mdt_password = passEl?.value || emp.mdt_password || '';

  // Gem lokalt med det samme, så UI ikke hopper tilbage mens serveren opdaterer.
  emp.role = role;
  emp.division = division;
  emp.pnumber = pnumber;
  emp.profile_image = profile_image;
  emp.mdt_password = mdt_password;
  const badgeParts = parseEmployeeBadge(emp);
  emp.pnumber = buildPoliceBadge(badgeParts.prefix, pnumberDigitsOnly(pnumber), division);
  emp.badge = emp.pnumber;
  emp.mdt_username = emp.pnumber || employeeUsername(emp);

  const r = await nui('updateEmployee', { identifier: emp.identifier, role, division, badge_prefix: badgeParts.prefix, pnumber: pnumberDigitsOnly(pnumber), profile_image, mdt_password });
  if(!silent || !r?.ok) toast(r?.message || (r?.ok ? 'Ansat opdateret.' : 'Kunne ikke opdatere.'));

  // Opdater listen efter serveren har gemt, men uden at kræve tryk på Opdater-knappen.
  if(r?.ok) setTimeout(refreshEmployees, 250);
}
function scheduleEmployeeSave(idx, delay = 350){
  clearTimeout(window.__empSaveTimer);
  window.__empSaveTimer = setTimeout(() => saveEmployee(idx, true), delay);
}
async function fireEmployee(idx){
  const emp = employees[idx]; if(!emp) return;
  const r = await nui('updateEmployee', { identifier: emp.identifier, role:'Suspenderet', division: emp.division || 'Patrulje', fire:true });
  toast(r?.message || (r?.ok ? 'Medarbejder afskediget.' : 'Kunne ikke afskedige.'));
  if(r?.ok) refreshEmployees();
}
function renderRoles(){
  const box = $('#rolesList'); if(!box) return;
  const roles = adminRoles.length ? adminRoles : mdtRoles.map(r => ({name:r, permissions:[]}));
  box.innerHTML = roles.map((r,idx)=>`<div class="role-card">
    <div><b>${escapeHtml(r.name)}</b><small>${escapeHtml(normalizeRolePermissions(r.permissions).join(', ') || 'Ingen permissions endnu')}</small></div>
    <button class="ghost small" data-role-edit="${idx}">Administrer permissions</button>
    <button class="danger small" data-role-delete="${idx}">Fjern</button>
  </div>`).join('');
}
async function refreshRoles(){
  const r = await nui('getRoles', {});
  if(r && r.ok){ adminRoles = r.roles || []; renderRoles(); } else renderRoles();
}
async function openRoleModal(idx){
  if(!permissionCatalog.length) await loadPermissionCatalog();
  const role = (adminRoles.length ? adminRoles : mdtRoles.map(name=>({name,permissions:[]})))[idx] || {name:'Ny rolle',permissions:[]};
  const rolePerms = normalizeRolePermissions(role.permissions);
  $('#modalTitle').textContent = 'Administrer rolle-permissions';
  $('#modalFields').innerHTML = `
    <label>Rollenavn</label>
    <input id="roleName" value="${escapeHtml(role.name||'')}">
    <div class="perm-debug-strip">
      <b>Permission debug aktiv</b>
      <span>Impound unlock kræver præcis <code>vehicles.impound.locked.release</code> eller <code>vehicles.impound.permanent.release</code>.</span>
    </div>
    ${renderPermissionCards(rolePerms)}`;
  bindPermissionCards();
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Gem permissions';
  $('#modalSave').onclick = async () => {
    const permissions = selectedPermissionCards();
    const name = $('#roleName').value.trim();
    logPermDebug('saving role', { name, permissions });
    const r = await nui('saveRole', { name, permissions });
    $('#modal').classList.add('hidden'); toast(r?.message || 'Rolle gemt.'); await refreshRoles(); await loadPermissionCatalog();
  };
}
async function refreshMailSystem(){
  const r = await nui('getMailDirectory', { search: $('#mailProfileSearch')?.value || '' });
  if(r?.ok){ mailDirectory = r.employees || []; renderMailSystem(); }
  else renderMailSystem();
}
function renderMailSystem(){
  const hidden=$('#mailPrivateRecipient'); if(hidden && selectedMailProfile) hidden.value = selectedMailProfile.identifier || '';
  renderMailProfileResults();
  updateSelectedMailProfileLabel();
  setMailMode(activeMailMode || 'profile', true);
}
function setMailMode(mode, silent=false){
  activeMailMode = mode || 'profile';
  $$('.mail-mode-card').forEach(b => b.classList.toggle('active', b.dataset.mailMode === activeMailMode));
  $$('.mail-mode-panel').forEach(p => p.classList.remove('active'));
  const panel = $('#mailMode' + activeMailMode.charAt(0).toUpperCase() + activeMailMode.slice(1));
  if(panel) panel.classList.add('active');
  if(!silent && activeMailMode === 'profile') renderMailProfileResults();
  if(activeMailMode === 'news') refreshMailNewsList();
}
function updateSelectedMailProfileLabel(){
  const label = $('#selectedMailProfileLabel');
  if(!label) return;
  if(!selectedMailProfile){ label.textContent = 'Ingen profil valgt'; return; }
  label.textContent = `${selectedMailProfile.name || selectedMailProfile.identifier}${officerBadge(selectedMailProfile) ? ' · '+officerBadge(selectedMailProfile) : ''}`;
}
function renderMailProfileResults(){
  const box = $('#mailProfileResults'); if(!box) return;
  if(!mailDirectory.length){ box.innerHTML = '<div class="admin-empty">Ingen profiler fundet.</div>'; return; }
  box.innerHTML = mailDirectory.map(e=>`<button type="button" class="mail-profile-result ${selectedMailProfile && selectedMailProfile.identifier===e.identifier?'active':''}" data-mail-profile="${escapeHtml(e.identifier)}"><span><b>${escapeHtml(e.name || e.identifier)}</b><small>${escapeHtml(e.identifier)} ${officerBadge(e)?('· '+escapeHtml(officerBadge(e))):''}</small></span><span>Vælg</span></button>`).join('');
}
function updateMailMode(){ setMailMode(activeMailMode || 'profile', true); }
function selectMailProfile(identifier){
  if(!identifier) return;
  selectedMailProfile = mailDirectory.find(e=>String(e.identifier)===String(identifier)) || { identifier };
  const hidden=$('#mailPrivateRecipient'); if(hidden) hidden.value = identifier;
  renderMailProfileResults();
  updateSelectedMailProfileLabel();
  refreshMailHistory(identifier);
}
async function refreshMailHistory(identifier){
  identifier = identifier || selectedMailProfile?.identifier || $('#mailPrivateRecipient')?.value || '';
  const list=$('#mailHistoryList');
  if(!identifier){ if(list) list.innerHTML='<div class="admin-empty">Ingen profil valgt.</div>'; return; }
  const prof = selectedMailProfile || mailDirectory.find(e=>String(e.identifier)===String(identifier)) || {identifier};
  $('#mailHistoryProfile') && ($('#mailHistoryProfile').textContent = `${prof.name || prof.identifier}${officerBadge(prof) ? ' · '+officerBadge(prof) : ''}`);
  if(list) list.innerHTML='<div class="admin-empty">Henter mails...</div>';
  const r = await nui('getSentMailsForProfile', { identifier });
  mailHistory = r?.mails || [];
  if(!list) return;
  if(!mailHistory.length){ list.innerHTML='<div class="admin-empty">Ingen sendte mails til denne betjent.</div>'; return; }
  list.innerHTML = mailHistory.map(m=>`<div class="mail-history-card clickable" data-open-mail-id="${escapeHtml(m.id)}"><div class="mail-history-head"><b>${escapeHtml(mailCardTitle(m))}</b><span class="mail-status ${m.seen ? 'seen':'unseen'}">${m.seen ? 'Set':'Ikke set'}</span></div><small>${escapeHtml(m.subject || 'Mail')}</small><small>${escapeHtml(mailCardMeta(m))} · ${escapeHtml(fmtDate(m.created_at) || '')}</small>${m.seen_at?`<small>Set: ${escapeHtml(fmtDate(m.seen_at) || '')}</small>`:''}</div>`).join('');
}
function findMailById(id){
  return (mailHistory || []).find(x=>String(x.id)===String(id))
    || (dashboardMails || []).find(x=>String(x.id)===String(id))
    || ((selfProfile && selfProfile.mails) || []).find(x=>String(x.id)===String(id))
    || ((selfProfile && selfProfile.sentMails) || []).find(x=>String(x.id)===String(id));
}
function markMailSeenFast(id, mailObj){
  // Når en mail/nyhed åbnes, skal den ALTID stå som Set med det samme.
  // DB-opdateringen køres i baggrunden, så UI ikke hænger. Ved luk forsøges den igen, hvis serveren var langsom.
  if(!id) return;
  const sid = String(id);
  const applyLocalSeen = (m) => { if(m && String(m.id)===sid){ m.seen = 1; m.unread = 0; if(!m.seen_at) m.seen_at = new Date().toISOString(); } };
  if(mailObj) applyLocalSeen(mailObj);
  (mailHistory || []).forEach(applyLocalSeen);
  (dashboardMails || []).forEach(applyLocalSeen);
  ((selfProfile && selfProfile.mails) || []).forEach(applyLocalSeen);

  const openedMail = mailObj || findMailById(sid);
  document.querySelectorAll(`[data-open-mail-id="${CSS.escape(sid)}"], [data-open-newsmail="${CSS.escape(sid)}"]`).forEach(row => {
    row.classList.remove('unread');
    const status = row.querySelector('.mail-status');
    const mail = openedMail || findMailById(sid);
    if(status && mail){
      status.classList.remove('unseen', 'seen');
      status.classList.add(mailStatusClass(mail));
      status.textContent = mailStatusShort(mail);
    } else if(status){
      status.classList.remove('unseen');
      status.classList.add('seen');
      status.textContent = 'Set';
    }
  });
  const dot = $('#profileNotifyDot');
  if(dot && selfProfile && openedMail?.mail_direction !== 'sent' && Number(openedMail?.unread || 0) === 1){
    selfProfile.unread = Math.max(0, Number(selfProfile.unread || 0) - 1);
    dot.classList.toggle('show', Number(selfProfile.unread || 0) > 0);
  }

  pendingSeenMailIds.add(sid);
  nui('markMailSeen', { id: sid }).then(r => {
    if(!r?.ok) return;
    pendingSeenMailIds.delete(sid);
    if(activePage === 'admin_mail') refreshMailHistory();
    if(activePage === 'self_profile') refreshSelfProfile();
  }).catch(() => {});
}
let activeMailThreadData = null;
async function openMailModalById(id){
  const m = findMailById(id);
  if(!m) return;
  let threadData = null;
  if(isPrivateMail(m)){
    const r = await nui('getMailThread', { mailId: id }).catch(() => null);
    if(r?.ok) threadData = r;
  }
  openPaperMailModal(m, mailModalTitle(m), threadData);
  markMailSeenFast(id, m);
}
function bindMailThreadModal(mailId, threadData){
  activeMailThreadData = threadData || null;
  const replyBtn = $('#mailReplySendBtn');
  if(replyBtn){
    replyBtn.onclick = async () => {
      const body = $('#mailReplyBody')?.value?.trim() || '';
      if(!body){ toast('Skriv et svar først.'); return; }
      replyBtn.disabled = true;
      const r = await nui('sendMail', { replyToId: mailId, body, targetType: 'private' });
      replyBtn.disabled = false;
      toast(r?.message || (r?.ok ? 'Svar sendt.' : 'Kunne ikke sende svar.'));
      if(r?.ok){
        const refreshed = await nui('getMailThread', { mailId }).catch(() => null);
        if(refreshed?.ok){
          const box = $('#mailThreadMount');
          if(box) box.innerHTML = renderMailThreadMessages(refreshed.messages);
          const replyMount = $('#mailReplyMount');
          if(replyMount) replyMount.innerHTML = renderMailReplyPanel(refreshed, mailId);
          bindMailThreadModal(mailId, refreshed);
        }
        if(activePage === 'self_profile') refreshSelfProfile();
      }
    };
  }
  const toggle = $('#mailReplyAllowedToggle');
  if(toggle && threadData?.canManageReplies){
    toggle.onchange = async () => {
      const allowed = !!toggle.checked;
      const r = await nui('setMailReplyAllowed', { threadId: threadData.threadId, allowed });
      toast(r?.message || (r?.ok ? 'Indstilling gemt.' : 'Kunne ikke gemme.'));
      if(r?.ok){
        threadData.replyAllowed = allowed;
        threadData.canReply = allowed;
        const replyMount = $('#mailReplyMount');
        if(replyMount) replyMount.innerHTML = renderMailReplyPanel(threadData, mailId);
        bindMailThreadModal(mailId, threadData);
      } else {
        toggle.checked = !allowed;
      }
    };
  }
}
function openPaperMailModal(m, title, threadData){
  if(m && m.id) pendingSeenMailIds.add(String(m.id));
  const fromLine = m.mail_direction === 'sent'
    ? mailCardMeta(m)
    : (isPrivateMail(m) ? mailCardMeta(m) : (m.department || 'Rigspolitiet'));
  const fromTitle = m.mail_direction === 'sent'
    ? mailCardTitle(m)
    : (isPrivateMail(m) ? `Email fra ${mailSenderLabel(m)}` : `Sendt af ${m.sender || 'MDT'}`);
  const threadMessages = threadData?.messages?.length
    ? renderMailThreadMessages(threadData.messages)
    : `<div class="paper-mail-body">${escapeHtml(m.body || m.description || '').replace(/\n/g,'<br>')}</div>`;
  const replyPanel = threadData ? renderMailReplyPanel(threadData, m.id) : '';
  $('#modalTitle').textContent = title || mailModalTitle(m);
  $('#modalFields').innerHTML = `<div class="paper-mail-ui paper-mail-threaded">
    <div class="paper-mail-head"><span>${escapeHtml(fromLine)}</span><small>${escapeHtml(fmtDate(m.created_at) || '')}</small></div>
    <h1>${escapeHtml(threadData?.subject || m.title || m.subject || 'Mail')}</h1>
    <p class="paper-mail-from">${escapeHtml(fromTitle)}</p>
    <p class="paper-mail-read">${escapeHtml(mailReadStatusLine(m))}</p>
    <div id="mailThreadMount">${threadMessages}</div>
    <div id="mailReplyMount">${replyPanel}</div>
  </div>`;
  $('#modalSave').style.display = ''; $('#modalSave').textContent = 'Luk'; $('#modalSave').onclick = closeModal;
  const cancel=$('#modalCancel'); if(cancel) cancel.style.display='none';
  $('#modal').classList.remove('hidden');
  if(threadData) bindMailThreadModal(m.id, threadData);
}
async function sendPrivateMail(){
  const to = selectedMailProfile?.identifier || $('#mailPrivateRecipient')?.value || '';
  const subject = $('#privateMailSubject')?.value || '';
  const body = $('#privateMailBody')?.value || '';
  if(!to){ toast('Vælg en politi-profil under Søg Profil først.'); setMailMode('profile'); return; }
  const r = await nui('sendMail', { to, targetType:'private', subject, body, summary:'' });
  toast(r?.message || (r?.ok ? 'Mail sendt.' : 'Kunne ikke sende mail.'));
  if(r?.ok){ ['privateMailSubject','privateMailBody'].forEach(id=>{ const el=$('#'+id); if(el) el.value=''; }); refreshMailHistory(to); }
}
async function sendNewsMail(){
  const subject = $('#newsMailSubject')?.value || '';
  const body = $('#newsMailBody')?.value || '';
  const department = $('#newsMailDepartment')?.value || '';
  const summary = $('#newsMailSummary')?.value || '';
  const r = await nui('sendMail', { to:'frontpage', targetType:'frontpage', subject, body, department, summary });

  if(!r?.ok){
    toast(r?.message || 'Kunne ikke sende nyhed.');
    return;
  }

  ['newsMailSubject','newsMailBody','newsMailDepartment','newsMailSummary'].forEach(id=>{ const el=$('#'+id); if(el) el.value=''; });

  if(r.mail) insertDashboardNewsCardRealtime(r.mail);
  await refreshMailNewsList();

  setTimeout(() => refreshDashboardFromServer(), 150);
  setTimeout(() => refreshDashboardFromServer(), 1200);

  toast('Nyhed sendt og opdateret på forsiden.');
}

async function refreshMailNewsList(){
  const list = $('#mailNewsList');
  if(list) list.innerHTML = '<div class="admin-empty">Henter nyheder...</div>';
  const r = await nui('getRecentNewsMails', { limit: 50 });
  mailNewsList = r?.news || [];
  renderMailNewsList();
}
function renderMailNewsList(){
  const list = $('#mailNewsList');
  if(!list) return;
  if(!mailNewsList.length){
    list.innerHTML = '<div class="admin-empty">Ingen nyheder sendt endnu.</div>';
    return;
  }
  list.innerHTML = mailNewsList.map(n => {
    const seen = Number(n.seen_count || 0);
    const total = Number(n.total_count || 0);
    return `<div class="mail-news-card">
      <div class="mail-news-main clickable" data-open-mail-id="${escapeHtml(n.id)}">
        <b>NYHED - ID: ${escapeHtml(n.id || '')}</b>
        <small>${escapeHtml(n.subject || n.title || 'Nyhed')}</small>
        <small>Sendt af: ${escapeHtml(n.sender || 'Ukendt')} · ${escapeHtml(n.department || 'Rigspolitiet')} · ${escapeHtml(fmtDate(n.created_at) || '')}</small>
      </div>
      <button type="button" class="mail-news-readers" data-news-readers="${escapeHtml(n.id)}" title="Se hvem der har set nyheden">👥 <span>${seen}/${total}</span></button>
    </div>`;
  }).join('');
}
async function openNewsReadersModal(id){
  const news = (mailNewsList || []).find(n => String(n.id) === String(id)) || {};
  const r = await nui('getNewsReadStatus', { id });
  const officers = r?.officers || [];
  $('#modalTitle').textContent = `Set status - NYHED ID: ${id}`;
  $('#modalFields').innerHTML = `<div class="news-readers-modal">
    <div class="news-readers-head"><b>${escapeHtml(news.subject || news.title || 'Nyhed')}</b><small>${escapeHtml(news.department || 'Rigspolitiet')}</small></div>
    <div class="news-readers-list">
      ${officers.length ? officers.map(o => `<div class="news-reader-row ${o.seen ? 'seen':''}">
        <span class="news-reader-dot">${o.seen ? '✓' : ''}</span>
        <div><b>${escapeHtml(o.name || o.identifier)}</b><small>${escapeHtml(o.badge || officerBadge(o) || o.identifier)}${o.seen_at ? ' · Set: '+escapeHtml(fmtDate(o.seen_at) || '') : ' · Ikke set'}</small></div>
      </div>`).join('') : '<div class="admin-empty">Ingen betjente fundet.</div>'}
    </div>
  </div>`;
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Luk';
  $('#modalSave').onclick = closeModal;
  const cancel=$('#modalCancel'); if(cancel) cancel.style.display='none';
  $('#modal').classList.remove('hidden');
}
async function sendMail(){ return activeMailMode === 'news' ? sendNewsMail() : sendPrivateMail(); }
async function openNewsMailModal(id){
  const m = dashboardMails.find(x=>String(x.id)===String(id));
  if(!m) return;
  openPaperMailModal(m, 'Mail / Nyhed');
  markMailSeenFast(id, m);
}
async function refreshSelfProfile(){
  const r = await nui('getSelfProfile', {});
  if(!r?.ok){ toast(r?.message || 'Kunne ikke hente profil.'); return; }
  const d = await nui('getDutyStatus', {}).catch(()=>({ok:false,onDuty:false}));
  selfDutyStatus = d || {ok:false,onDuty:false};
  selfProfile = r.profile;
  const box = $('#selfProfileBox'); if(!box) return;
  const receivedHtml = (selfProfile.mails || []).map((m) => renderSelfProfileMailCard(Object.assign({ mail_direction: 'received' }, m))).join('');
  const sentHtml = (selfProfile.sentMails || []).map((m) => renderSelfProfileMailCard(Object.assign({ mail_direction: 'sent' }, m))).join('');
  const mails = [
    receivedHtml ? `<div class="mail-section-label">Modtaget</div>${receivedHtml}` : '',
    sentHtml ? `<div class="mail-section-label">Sendt af dig</div>${sentHtml}` : ''
  ].filter(Boolean).join('') || '<div class="admin-empty">Ingen beskeder.</div>';
  const dutyHtml = `<div class="self-card duty-card"><h2>Tjenestestatus</h2><div class="self-info"><span>Status</span><b class="${selfDutyStatus.onDuty?'available':'service'}">${selfDutyStatus.onDuty?'På arbejde':'Ikke på arbejde'}</b></div><p>${selfDutyStatus.onDuty?'Du er aktiv i MDT, kan tilmelde patrulje og tage dispatch-opgaver.':'Du er ikke på arbejde. Du kan ikke gå på arbejde fra Min Profil.'}</p>${selfDutyStatus.onDuty?'<button class="primary" id="selfDutyToggle">Gå af arbejde</button>':'<div class="admin-empty">Gå-på-arbejde er fjernet herfra.</div>'}</div>`;
  box.innerHTML = `<div class="self-profile-grid"><div class="self-card"><div class="self-photo">${profileImageHtml(selfProfile.profile_image, selfProfile.name, 'self-profile-img')}</div><h2>${escapeHtml(selfProfile.name||'Ukendt')}</h2><p>${escapeHtml(selfProfile.identifier||'')}</p><div class="self-info"><span>Tjenestenummer</span><b>${escapeHtml(selfProfile.badge || formatPoliceBadge(selfProfile.pnumber, selfProfile.division) || '')}</b></div><div class="self-info"><span>Rolle</span><b>${escapeHtml(selfProfile.role||'Ukendt')}</b></div><div class="self-info"><span>Afdeling</span><b>${escapeHtml(selfProfile.division||'Patrulje')}</b></div><div class="self-info"><span>Job</span><b>${escapeHtml(selfProfile.job||'')}</b></div></div>${dutyHtml}<div class="self-mails"><h2>Emails / Meddelelser</h2>${mails}</div></div>`;
  $('#selfDutyToggle') && ($('#selfDutyToggle').onclick = async()=>{
    const goingOff = !!selfDutyStatus.onDuty;
    // FiveM CEF kan fryse/låse NUI ved native browser confirm().
    // Derfor lukker vi direkte og logger ud uden JavaScript-dialog.
    const btn = $('#selfDutyToggle');
    if(!goingOff) return;
    if(btn) { btn.disabled = true; btn.textContent = 'Logger ud...'; }
    toast('Du er gået af arbejde. MDT lukker.');
    mdtHardCloseVisual();
    nui('logoutMdt', { reason:'Gik af arbejde via Min Profil' });
    return;
  });
  $('#profileNotifyDot')?.classList.toggle('show', Number(selfProfile.unread||0)>0);
}




function openChargeViewModal(id){
  const c = (mdtCharges || []).find(x => Number(x.id) === Number(id));
  if(!c) return;
  const cat = c.category || 'blue';
  $('#modalTitle').textContent = `§ ${c.paragraph || '?'} - ${c.name || 'Sigtelse'}`;
  $('#modalFields').innerHTML = `<div class="scums-charge-view charge-${escapeHtml(cat)}"><div class="scum-charge-card charge-${escapeHtml(cat)} view"><div class="scum-charge-title">${escapeHtml(c.name || 'Sigtelse')}</div><div class="scum-charge-row"><span class="scum-input">1st Antal</span><span class="scum-main">${Number(c.jail||0)} min + ${money(c.fine)}</span>${hasChargePoints(c) ? `<span class="scum-klip">${Number(c.points||0)} klip</span>` : ''}</div></div><p>${escapeHtml(c.description || 'Ingen beskrivelse.')}</p>${chargePenaltyHtml(c)}</div>`;
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Luk';
  $('#modalSave').onclick = closeModal;
  const cancel = $('#modalCancel'); if(cancel) cancel.textContent = 'Luk';
  $('#modal').classList.remove('hidden');
}

function chargeCategoryLabel(cat){ return (chargeCategoryMeta[cat] && chargeCategoryMeta[cat].label) || cat || 'Ukendt'; }
const CHARGE_LAW_GROUPS = {
  straffelov: { label:'San Andreas Straffelov', cls:'orange' },
  vaabenlov: { label:'Grundlov Kap. 7 — Våbenloven', cls:'red' },
  narkoloven: { label:'Grundlov Kap. 8 — Narkotikaloven', cls:'green' },
  trafikloven: { label:'Grundlov Kap. 9 — Trafikloven', cls:'yellow' },
  erhvervsloven: { label:'Grundlov Kap. 11 — Virksomhed', cls:'blue' },
  luftfartoej: { label:'Grundlov Kap. 12 — Luftfartøj', cls:'yellow' },
  vagtloven: { label:'Grundlov Kap. 13 — Vagtloven', cls:'blue' }
};
const CHARGE_LAW_ORDER = ['straffelov','vaabenlov','narkoloven','trafikloven','erhvervsloven','luftfartoej','vagtloven'];
function chargeLawGroup(c){
  const key = String(c?.law_group || '').toLowerCase();
  if(CHARGE_LAW_GROUPS[key]) return { key, ...CHARGE_LAW_GROUPS[key] };
  const hay = String([c?.name,c?.description,c?.paragraph,c?.category,c?.category_label].join(' ')).toLowerCase();
  if(/^80[0-9]|^805|narko|meth|kokain|marihuana|euforiserende/.test(hay)) return { key:'narkoloven', ...CHARGE_LAW_GROUPS.narkoloven };
  if(/^70[0-9]|våben|vaaben|ammunition|kniv|pistol|rifle|skydevåben|skydevaaben/.test(hay)) return { key:'vaabenlov', ...CHARGE_LAW_GROUPS.vaabenlov };
  if(/^90[0-9]|^1235|frue-fri|kør|koer|fart|trafik|kørekort|koerekort|flugt fra politiet/.test(hay)) return { key:'trafikloven', ...CHARGE_LAW_GROUPS.trafikloven };
  if(/^110[0-9]|erhverv|udlej/.test(hay)) return { key:'erhvervsloven', ...CHARGE_LAW_GROUPS.erhvervsloven };
  if(/^12[0-9]{2}|flyv|luftfart/.test(hay)) return { key:'luftfartoej', ...CHARGE_LAW_GROUPS.luftfartoej };
  if(/^130[0-9]|vagt/.test(hay)) return { key:'vagtloven', ...CHARGE_LAW_GROUPS.vagtloven };
  return { key:'straffelov', ...CHARGE_LAW_GROUPS.straffelov };
}
function buildChargePickerRows(charges){
  return (charges || []).map((c, idx) => {
    const law = chargeLawGroup(c);
    const meta = chargeCategoryMeta[(law.cls || c.category) || 'green'] || chargeCategoryMeta.green;
    return {
      idx,
      charge: c,
      key: String(c.id || `${c.paragraph || ''}-${c.name || ''}`),
      searchHay: String([c.paragraph,c.name,c.description,c.category,c.category_label,law.label].join(' ')).toLowerCase(),
      lawKey: law.key,
      lawLabel: law.label,
      metaCls: meta.cls
    };
  });
}
function chargePickerCardHtml(row, isPicked){
  const c = row.charge;
  return `<button type="button" class="scum-charge-card charge-${escapeHtml(row.metaCls)} ${isPicked ? 'picked selected' : ''}" data-pick-charge="${row.idx}">
    <div class="scum-charge-title">${escapeHtml(c.name || 'Sigtelse')}</div>
    <p class="cs-description">${escapeHtml(c.description || 'Ingen beskrivelse.')}</p>
    <div class="scum-charge-row">
      <span class="scum-input">1st Antal</span>
      <span class="scum-main">${Number(c.jail||0)} min + ${money(c.fine)}</span>
      ${chargeExtraBadges(c)}
    </div>
  </button>`;
}
function money(n){ n = Number(n||0); return n.toLocaleString('da-DK') + ' kr.'; }
function hasChargePoints(c){ return Number(c && c.points || 0) > 0; }
function chargeRevocationText(c){ return String((c && c.revocation) || '').trim(); }
function hasChargeRevocation(c){
  const v = chargeRevocationText(c).toLowerCase();
  return !!v && !['ingen','nej','no','none','0','false','n/a','na'].includes(v);
}
function chargeExtraBadges(c){
  const badges = [];
  if(hasChargePoints(c)) badges.push(`<span class="charge-extra-badge points"><small>Klip</small><b>${Number(c.points||0)}</b></span>`);
  if(hasChargeRevocation(c)) badges.push(`<span class="charge-extra-badge revoke"><small>Frakendelse af køreret</small><b>${escapeHtml(chargeRevocationText(c))}</b></span>`);
  if(c && (c.impound || c.vehicle_impound || c.vehicleSeizure)) badges.push(`<span class="charge-extra-badge impound"><small>Beslaglæggelse af køretøj</small><b>Ja</b></span>`);
  return badges.join('');
}
function chargePenaltyHtml(c, opts={}){
  const parts = [`<span><small>Fængsel</small><b>${Number(c.jail||0)} mdr</b></span>`, `<span><small>Bøde</small><b>${money(Number(c.fine||0))}</b></span>`];
  if(hasChargePoints(c)) parts.push(`<span><small>Klip</small><b>${Number(c.points||0)}</b></span>`);
  if(hasChargeRevocation(c)) parts.push(`<span><small>Frakendelse af køreret</small><b>${escapeHtml(chargeRevocationText(c))}</b></span>`);
  if(c && (c.impound || c.vehicle_impound || c.vehicleSeizure)) parts.push(`<span><small>Beslaglæggelse af køretøj</small><b>Ja</b></span>`);
  const revokeNote = hasChargeRevocation(c)
    ? `<p class="charge-revoke-cooldown">Ved frakendelse kan borgeren tidligst få nyt kørekort igen efter <b>${Number(licenseRevocationCooldownHours || 48)} timer</b>.</p>`
    : '';
  return `<div class="charge-penalties">${parts.join('')}</div>${revokeNote}`;
}
function chargeSummaryExtraHtml(arr){
  const points = arr.reduce((a,c)=>a+Number(c.points||0),0);
  const revocations = arr.filter(hasChargeRevocation).map(c=>chargeRevocationText(c));
  const impounds = arr.filter(c=>c && (c.impound || c.vehicle_impound || c.vehicleSeizure)).length;
  const parts = [];
  if(points > 0) parts.push(`<span><small>Klip</small><b>${points}</b></span>`);
  if(revocations.length) parts.push(`<span><small>Frakendelse af køreret</small><b>${escapeHtml([...new Set(revocations)].join(', '))}</b></span>`);
  if(impounds > 0) parts.push(`<span><small>Beslaglæggelse af køretøj</small><b>${impounds}</b></span>`);
  return parts.join('');
}

function renderCharges(){
  const list = $('#chargesList'); if(!list) return;
  const search = ($('#chargeSearch')?.value || '').toLowerCase().trim();
  const filter = $('#chargeCategoryFilter')?.value || '';
  let arr = (mdtCharges || []).filter(c => {
    const law = chargeLawGroup(c);
    const hay = [c.paragraph,c.name,c.description,c.category,c.category_label,law.label].join(' ').toLowerCase();
    return (!search || hay.includes(search)) && (!filter || law.key === filter || c.category === filter);
  });

  const sel = $('#chargeCategoryFilter');
  if(sel && !sel.dataset.lawFilterReady){
    sel.innerHTML = '<option value="">Alle love</option>' + CHARGE_LAW_ORDER.map((k)=>`<option value="${k}">${CHARGE_LAW_GROUPS[k].label}</option>`).join('');
    sel.dataset.lawFilterReady = '1';
  }

  const sum = $('#chargesSummary');
  if(sum){
    const totalFine = arr.reduce((a,c)=>a+(Number(c.fine)||0),0);
    const totalJail = arr.reduce((a,c)=>a+(Number(c.jail)||0),0);
    const totalPoints = arr.reduce((a,c)=>a+(Number(c.points)||0),0);
    sum.innerHTML = `<div><b>${arr.length}</b><span>Sigtelser vist</span></div><div><b>${money(totalFine)}</b><span>Samlet bøde i listen</span></div><div><b>${totalJail} mdr</b><span>Samlet fængsel</span></div>${totalPoints > 0 ? `<div><b>${totalPoints}</b><span>Klip</span></div>` : ''}`;
  }
  if(!arr.length){
    list.innerHTML = '<div class="charge-empty">Ingen sigtelser fundet. Prøv en anden søgning.</div>';
    return;
  }

  const order = CHARGE_LAW_ORDER;
  const groups = {};
  arr.forEach(c => { const g = chargeLawGroup(c); (groups[g.key] ||= { meta:g, items:[] }).items.push(c); });

  const miniMeta = (c) => {
    const parts = [];
    if(hasChargePoints(c)) parts.push(`<span class="cs-pill cs-pill-points">Klip ${Number(c.points||0)}</span>`);
    if(hasChargeRevocation(c)) parts.push(`<span class="cs-pill cs-pill-revoke">Frakendelse</span>`);
    if(c && (c.impound || c.vehicle_impound || c.vehicleSeizure)) parts.push(`<span class="cs-pill cs-pill-impound">Beslaglæggelse</span>`);
    return parts.join('');
  };

  list.innerHTML = order.filter(k => groups[k]).map(k => {
    const group = groups[k];
    return `<section class="charges-law-section charge-${escapeHtml(group.meta.cls)}">
      <div class="charges-law-title"><h3>${escapeHtml(group.meta.label)}</h3><span>${group.items.length} sigtelser</span></div>
      <div class="charges-law-grid charges-card-grid-pro">${group.items.map(c => {
        const law = chargeLawGroup(c);
        const buttons = `<div class="charge-card-actions">${chargePermissions.edit ? `<button class="ghost small" data-edit-charge="${c.id}">Rediger</button>` : ''}${chargePermissions.delete ? `<button class="danger small" data-delete-charge="${c.id}">Slet</button>` : ''}</div>`;
        return `<article class="criminal-scums-charge-card charge-${escapeHtml(law.cls)} no-open">
          <div class="cs-card-head">
            <h3>${escapeHtml(c.name || 'Ukendt sigtelse')}</h3>
            <span class="cs-paragraph">§ ${escapeHtml(c.paragraph || '')}</span>
          </div>
          <p class="cs-law">${escapeHtml(law.label)}</p>
          <p class="cs-description">${escapeHtml(c.description || 'Ingen beskrivelse.')}</p>
          <div class="cs-card-row">
            <span class="cs-count">1st Antal</span>
            <span class="cs-main">${Number(c.jail||0)} min + ${money(c.fine)}</span>
            ${miniMeta(c)}
          </div>
          ${buttons}
        </article>`;
      }).join('')}</div>
    </section>`;
  }).join('');
  $$('.charge-admin-only').forEach(el => el.classList.toggle('hidden', !chargePermissions.add));
}
async function refreshCharges(){
  const r = await nui('getCharges', { search: $('#chargeSearch')?.value || '', category: $('#chargeCategoryFilter')?.value || '' });
  if(r && r.ok){
    mdtCharges = r.charges || [];
    chargePermissions = r.permissions || { add:false, edit:false, delete:false };
    const sel = $('#chargeCategoryFilter'); if(sel) delete sel.dataset.lawFilterReady;
    renderCharges();
  } else toast(r?.message || 'Kunne ikke hente sigtelser.');
}
function openChargeModal(id){
  const editing = id !== undefined && id !== null;
  const c = editing ? (mdtCharges || []).find(x => Number(x.id) === Number(id)) : { category:'green', law_group:'straffelov', paragraph:'', name:'', description:'', jail:0, fine:0, points:0, revocation:'' };
  if(editing && !c) return;
  const lawOptions = CHARGE_LAW_ORDER.map((k)=>`<option value="${k}">${CHARGE_LAW_GROUPS[k].label}</option>`).join('');
  $('#modalTitle').textContent = editing ? 'Rediger sigtelse' : 'Tilføj sigtelse';
  $('#modalFields').innerHTML = `<div class="charge-form">
    <label>Paragraf (§)</label><input id="chargeParagraph" value="${escapeHtml(c.paragraph||'')}" placeholder="Fx 701 eller 18">
    <label>Straffens navn</label><input id="chargeName" value="${escapeHtml(c.name||'')}" placeholder="Fx Grov vold">
    <label>Lovgrundlag</label><select id="chargeLawGroup">${lawOptions}</select>
    <label>Kategori</label><select id="chargeCategory"><option value="green">Grøn - Mindre forseelse</option><option value="yellow">Gul - Trafik / klip</option><option value="orange">Orange - Alvorlig</option><option value="red">Rød - Grov kriminalitet</option><option value="blue">Blå - Særlig / administrativ</option></select>
    <label>Beskrivelse</label><textarea id="chargeDescription" placeholder="Beskrivelse af sigtelsen...">${escapeHtml(c.description||'')}</textarea>
    <div class="charge-form-grid"><div><label>Fængsel (mdr)</label><input id="chargeJail" type="number" min="0" value="${Number(c.jail||0)}"></div><div><label>Bøde (kr)</label><input id="chargeFine" type="number" min="0" value="${Number(c.fine||0)}"></div><div><label>Klip</label><input id="chargePoints" type="number" min="0" value="${Number(c.points||0)}"></div><div><label>Frakendelse</label><input id="chargeRevocation" value="${escapeHtml(c.revocation||'')}" placeholder="Fx 30 dage / Nej"></div></div>
  </div>`;
  $('#chargeCategory').value = c.category || 'green';
  if($('#chargeLawGroup')) $('#chargeLawGroup').value = c.law_group || 'straffelov';
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = editing ? 'Gem sigtelse' : 'Tilføj sigtelse';
  $('#modal').classList.remove('hidden');
  $('#modalSave').onclick = async () => {
    const payload = { id: editing ? c.id : null, paragraph: $('#chargeParagraph').value, name: $('#chargeName').value, law_group: $('#chargeLawGroup')?.value || 'straffelov', category: $('#chargeCategory').value, description: $('#chargeDescription').value, jail: Number($('#chargeJail').value||0), fine: Number($('#chargeFine').value||0), points: Number($('#chargePoints').value||0), revocation: $('#chargeRevocation').value };
    if(!payload.paragraph || !payload.name){ toast('Udfyld paragraf og navn.'); return; }
    const r = await nui(editing ? 'updateCharge' : 'addCharge', payload);
    if(r && r.ok){ closeModal(); toast(r.message || 'Sigtelse gemt.'); refreshCharges(); } else toast(r?.message || 'Kunne ikke gemme sigtelse.');
  };
}
async function deleteCharge(id){
  const r = await nui('deleteCharge', { id });
  if(r && r.ok){ toast(r.message || 'Sigtelse slettet.'); refreshCharges(); }
  else toast(r?.message || 'Kunne ikke slette sigtelse.');
}


function renderVehiclePreview(v){
  const overlayId = 'vehiclePreviewOverlay_' + Date.now();
  const offset = Math.min(openProfilePreviewStack.length * 22, 88);
  const statusCls = vehicleStatusClass(v.status);
  const overlay = document.createElement('div');
  overlay.id = overlayId;
  overlay.className = 'profile-preview-overlay profile-full-modal-overlay';
  overlay.style.setProperty('--stack-offset', offset + 'px');
  overlay.style.zIndex = String(11100 + document.querySelectorAll('.profile-preview-overlay').length);
  overlay.innerHTML = `<div class="profile-preview-card vehicle-mini-preview-card profile-full-modal-card">
    <div class="preview-head profile-modal-head"><div class="preview-avatar">▣</div><div><h2>${escapeHtml(v.plate || 'Ukendt køretøj')}</h2><small>${escapeHtml(v.model || v.vehicleName || 'Ukendt model')}</small></div><button class="closeVehiclePreview" title="Luk">×</button></div>
    <div class="vehicle-info-list preview-vehicle-info"><div><label>Ejer</label><b>${escapeHtml(v.ownerName || v.owner || 'Ukendt')}</b></div><div><label>Type</label><b>${escapeHtml(v.type || 'Ukendt')}</b></div><div><label>Status</label><b class="vehicle-status ${statusCls}">${escapeHtml(v.status || 'Ukendt')}</b></div><div><label>Nummerplade</label><b>${escapeHtml(v.plate || 'Ukendt')}</b></div></div>
    <div class="preview-actions"><button class="save" data-open-vehicle-register>Åbn i køretøjsregister</button><button class="ghost" data-close-vehicle-preview>Luk</button></div>
  </div>`;
  document.body.appendChild(overlay);
  overlay.querySelector('.closeVehiclePreview').onclick = () => closeProfilePreview(overlayId);
  overlay.querySelector('[data-close-vehicle-preview]').onclick = () => closeProfilePreview(overlayId);
  overlay.querySelector('[data-open-vehicle-register]').onclick = () => { activeVehicleProfile = {...v}; closeProfilePreview(overlayId); setPage('vehicles'); setVehicleRegistryMode('detail'); renderVehicleProfile(); };
  overlay.addEventListener('mousedown', e => { if(e.target === overlay) closeProfilePreview(overlayId); });
  openProfilePreviewStack.push(overlayId);
}


function openIncidentPopup(incident){
  const i = normalizeIncident(incident);
  const overlayId = 'incidentPreviewOverlay_' + Date.now() + '_' + Math.floor(Math.random()*9999);
  const offset = Math.min(document.querySelectorAll('.profile-preview-overlay').length * 22, 110);
  const tags = Array.isArray(i.tags) ? i.tags : [];
  const tagHtml = tags.length ? tags.map(t => { const name = (typeof t === 'object' ? t.name : t) || 'Tag'; return `<span class="incident-tag-chip" style="${tagBadgeStyle(t)}"><b>${escapeHtml(name)}</b></span>`; }).join('') : '<span class="incident-tag-chip muted">Ingen tags</span>';
    const rmeta = currentReportTypeMeta(i);
  const overlay = document.createElement('div');
  overlay.id = overlayId;
  overlay.className = 'profile-preview-overlay profile-full-modal-overlay incident-popout-overlay';
  overlay.style.setProperty('--stack-offset', offset + 'px');
  overlay.style.zIndex = String(11100 + document.querySelectorAll('.profile-preview-overlay').length);
  overlay.innerHTML = `<div class="profile-preview-card incident-popout-card profile-full-modal-card"><div class="preview-head profile-modal-head"><div class="preview-avatar">△</div><div><h2>${escapeHtml(i.title || 'Ny hændelse')}</h2><small>ID: ${escapeHtml(i.incident_no || 'KLADDE')} · ${escapeHtml(fmtDate(i.created_at) || 'Ingen dato')}</small></div><button class="closeIncidentPreview" title="Luk">×</button></div><div class="card-tags incident-popout-tags">${tagHtml}</div><div class="incident-popout-meta"><div><label>Oprettet af</label><b>${escapeHtml(i.created_by || 'Ukendt')}</b></div><div><label>Senest redigeret</label><b>${escapeHtml(i.last_edited_by || i.created_by || 'Ingen')}</b></div></div><div class="incident-popout-text">${i.description || '<span class="muted">Ingen beskrivelse.</span>'}</div><div class="preview-actions"><button class="save" data-open-incident-main>Åbn som aktiv hændelse</button><button class="ghost" data-close-incident-preview>Luk</button></div></div>`;
  document.body.appendChild(overlay);
  overlay.querySelector('.closeIncidentPreview').onclick = () => closeProfilePreview(overlayId);
  overlay.querySelector('[data-close-incident-preview]').onclick = () => closeProfilePreview(overlayId);
  overlay.querySelector('[data-open-incident-main]').onclick = () => { closeProfilePreview(overlayId); openIncident(i); };
  overlay.addEventListener('mousedown', e => { if(e.target === overlay) closeProfilePreview(overlayId); });
  openProfilePreviewStack.push(overlayId);
}

function openIncidentVehicleInRegistry(idx){
  if(!currentIncident) return;
  const v = (currentIncident.vehicles || [])[Number(idx)];
  if(!v) return;
  renderVehiclePreview({ ...v, vehicleName: v.vehicleName || v.model, model: v.model || v.vehicleName || 'Ukendt model' });
  toast('Køretøj åbnet i popup. Hændelsen bliver åben.');
}



function profileWantedReports(profile){
  const ident = String(profile?.identifier||'').toLowerCase();
  const name = String(profile?.name||'').toLowerCase();
  return (mdtReports||[]).filter(r => {
    const people = [...(r.suspects||[]), ...(r.civilians||[])];
    return people.some(x => x && x.wanted && ((ident && String(x.identifier||'').toLowerCase()===ident) || (name && String(x.name||'').toLowerCase()===name)));
  });
}
function vehicleWantedReports(vehicle){
  const plate = String(vehicle?.plate||vehicle||'').toLowerCase();
  return (mdtReports||[]).filter(r => (r.vehicles||[]).some(v => v && v.wanted && String(v.plate||'').toLowerCase()===plate));
}
function wantedProfileBanner(profile){
  const list = profileWantedReports(profile);
  if(!list.length) return '';
  const r = list[0];
  const m = reportMeta(r);
  const reportId = r.report_no || r.id || 'Ukendt';
  const reason = r.title || m.label || m.title || 'Rapport';
  return `<div class="profile-wanted-banner profile-wanted-card">
    <h3>EFTERLYSNING</h3>
    <p>${escapeHtml(profile.name||'Personen')} er efterlyst</p>
    <div class="profile-wanted-badges">
      <span>ID: ${escapeHtml(reportId)}</span>
      <span>${escapeHtml(reason)}</span>
      <span>Aktiv</span>
    </div>
  </div>`;
}
function gangProfileBanner(profile){
  if(!profile?.can_view_gang || !profile?.gang) return '';
  const g = profile.gang;
  return `<div class="profile-gang-banner profile-gang-card" style="--gang-color:${escapeHtml(g.color || '#ff3048')}">
    <h3>BANDEREGISTRERET</h3>
    <p>${escapeHtml(profile.name || 'Personen')} er registreret i <b>${escapeHtml(g.name || 'Ukendt bande')}</b></p>
    <div class="profile-gang-badges">
      <span>${escapeHtml(g.tag || g.name || 'Bande')}</span>
      <span>${escapeHtml(g.role || 'Medlem')}</span>
      <span>${escapeHtml(g.threat_level || 'Ukendt trussel')}</span>
    </div>
  </div>`;
}
function renderProfileGangAdminHtml(p){
  if(!p.can_register_gang) return '';
  const gangs = nskOverview.gangs || [];
  const current = p.gang;
  const options = gangs.map((g) => `<option value="${Number(g.id)}" ${current && Number(current.gang_id) === Number(g.id) ? 'selected' : ''}>${escapeHtml(g.name || 'Bande')}</option>`).join('');
  if(current){
    return `<div class="profile-side-section profile-gang-admin">
      <h3>BANDEREGISTRERING</h3>
      <div class="profile-gang-current"><b>${escapeHtml(current.name || 'Bande')}</b><small>${escapeHtml(current.role || 'Medlem')}</small></div>
      <button type="button" class="tiny danger" data-profile-gang-remove>Fjern bandemarkering</button>
    </div>`;
  }
  return `<div class="profile-side-section profile-gang-admin">
    <h3>BANDEREGISTRERING</h3>
    <select id="profileGangSelect"><option value="">Vælg bande...</option>${options}</select>
    <input id="profileGangRole" placeholder="Rolle fx Medlem / Løjtnant" value="Medlem">
    <button type="button" class="save small" data-profile-gang-register>Registrer som bandemedlem</button>
  </div>`;
}

function getScopedReports(){ return reportScope === 'krim' ? krimReports : mdtReports; }
function setScopedReports(arr){ if(reportScope === 'krim') krimReports = arr; else mdtReports = arr; }
function allReportsCombined(){ return [...(mdtReports || []), ...(krimReports || [])]; }
function findCombinedReport(id){
  id = String(id || '');
  let r = (krimReports || []).find(x => String(x.id) === id || String(x.report_no) === id);
  if(r){ reportScope = 'krim'; return normalizeReport(r); }
  r = (mdtReports || []).find(x => String(x.id) === id || String(x.report_no) === id);
  if(r){ reportScope = 'politi'; return normalizeReport(r); }
  return null;
}
function reportStorageSave(){
  localStorage.setItem('san_mdt_reports_v1', JSON.stringify(mdtReports));
  localStorage.setItem('san_mdt_krim_reports_v1', JSON.stringify(krimReports));
}
function syncReportAnpgFlags(){
  const reports = allReportsCombined().map(normalizeReport);
  nui('syncAllReportsAnpg', { reports }).catch(()=>{});
}
function syncAllReportsToAnpg(){ syncReportAnpgFlags(); }
function reportNo(){ return 'RPT' + Math.floor(100000 + Math.random()*899999); }
function normalizeReport(r){ const m=reportTypeTemplates[r?.type||'report']||reportTypeTemplates.report; return Object.assign({ id:Date.now(), report_no:reportNo(), type:'report', title:m.title, body:m.body, created_by:$('#officerName')?.textContent||'Betjent', created_at:new Date().toISOString(), linked_incident_no:'', linked_vehicle:'', linked_person:'' }, r||{}); }
function reportMeta(r){ return reportTypeTemplates[(r&&r.type)||'report'] || reportTypeTemplates.report; }
function reportBadge(r){ const m=reportMeta(r); return `<span class="report-badge" style="--report-color:${escapeHtml(m.color||'#00e6b7')}">${escapeHtml(m.badge)}</span>`; }
function renderReportTypeOptions(){
  const sel=$('#reportTypeFilter'); if(sel && !sel.dataset.ready){
    Object.entries(reportTypeTemplates).filter(([k])=>k!=='incident').forEach(([k,m])=>{ const o=document.createElement('option'); o.value=k; o.textContent=m.label; sel.appendChild(o); }); sel.dataset.ready='1';
  }
}
function renderReportsPage(){
  renderReportTypeOptions();
  const box=$('#reportsList'); if(!box) return;
  const q=($('#reportSearch')?.value||'').toLowerCase().trim(); const f=$('#reportTypeFilter')?.value||'';
  const scoped = getScopedReports() || [];
  const list=scoped.map(normalizeReport).filter(r=>{ const m=reportMeta(r); const hay=[r.title,r.report_no,m.label,m.badge,r.created_by,r.linked_incident_no,r.linked_vehicle,r.linked_person,textOnly(r.body)].join(' ').toLowerCase(); return (!q||hay.includes(q)) && (!f||r.type===f); });
  const head = $('.reports-header h2'); if(head) head.textContent = reportScope === 'krim' ? 'KRIM · Rapporter' : 'Rapporter';
  const sub = $('.reports-header p'); if(sub) sub.textContent = reportScope === 'krim' ? 'Kriminaltekniske rapporter — adskilt fra almindelige politirapporter.' : 'Opret rapporter med samme professionelle layout som hændelser.';
  box.innerHTML = list.length ? list.map(r=>{ const m=reportMeta(r); const txt=textOnly(r.body); const forlob=(txt.match(/Forløb:\s*([^]*?)(Udbytte|Videre|Konklusion|Beviser|$)/i)||[])[1] || txt.slice(0,150) || 'Ingen forløb endnu'; return `<div class="report-card" style="--report-color:${escapeHtml(m.color||'#00e6b7')}" data-open-report="${escapeHtml(r.id)}" title="Venstreklik for at åbne, højreklik for at færdigbehandle"><div class="report-card-main"><div class="report-title"><b>${escapeHtml(r.title||m.title)}</b>${reportBadge(r)}</div><div class="report-meta"><span>ID: ${escapeHtml(r.report_no)}</span><span>Oprettet af: ${escapeHtml(r.created_by||'Ukendt')}</span><span>${escapeHtml(fmtDate(r.created_at)||'Ingen dato')}</span></div><div class="report-preview"><b>Forløb:</b> ${escapeHtml(forlob.trim())}</div></div><div class="report-card-actions"><button data-delete-report="${escapeHtml(r.id)}" class="red">Slet</button></div></div>` }).join('') : `<div class="report-empty"><b>Ingen rapporter endnu</b><span>Tryk “+ Opret rapport” for at lave efterlysning, skyderi, heist, tyveri eller almindelig rapport.</span></div>`;
}
function openReportModal(existingId=null){
  const existing = existingId ? mdtReports.find(r=>String(r.id)===String(existingId)) : null;
  const r = existing ? normalizeReport(existing) : normalizeReport({type:'report'});
  $('#modalTitle').textContent = existing ? 'Rediger rapport' : 'Opret rapport';
  const opts=Object.entries(reportTypeTemplates).filter(([k])=>k!=='incident').map(([k,m])=>`<option value="${escapeHtml(k)}" ${r.type===k?'selected':''}>${escapeHtml(m.label)}</option>`).join('');
  const incOpts = (incidents||[]).map(i=>`<option value="${escapeHtml(i.incident_no||i.id||'')}" ${(r.linked_incident_no||'')===(i.incident_no||i.id||'')?'selected':''}>${escapeHtml(i.incident_no||'---')} - ${escapeHtml(i.title||'Hændelse')}</option>`).join('');
  const m = reportMeta(r);
  $('#modalFields').innerHTML = `
    <div class="report-incident-editor" style="--report-color:${escapeHtml(m.color||'#00e6b7')}">
      <div class="report-topline">
        <span class="report-top-label">RAPPORT</span>
        <span id="reportModalBadge" class="report-badge" style="--report-color:${escapeHtml(m.color||'#00e6b7')}">${escapeHtml(m.badge)}</span>
        <span class="report-number">${escapeHtml(r.report_no||reportNo())}</span>
      </div>
      <div class="report-editor-grid">
        <div class="report-editor-main">
          <div class="title-row report-title-row"><input id="reportModalTitle" placeholder="Titel fx heist ved bank, skyderi, efterlysning" value="${escapeHtml(r.title||'')}"><button class="mini" type="button">✎</button></div>
          <div id="reportModalBody" contenteditable="true" spellcheck="false" class="report-modal-editor incident-style-editor">${r.body||''}</div>
          <div class="editor-foot"><span>P</span><span id="reportWords">WORDS: 0</span><span id="reportChars">CHARACTERS: 0</span></div>
        </div>
        <aside class="report-sidepanel">
          <div class="sidebox"><h3>RAPPORT TYPE</h3><select id="reportModalType" class="report-type-select">${opts}</select><div id="reportTypePreview" class="report-type-preview"><span class="report-badge" style="--report-color:${escapeHtml(m.color||'#00e6b7')}">${escapeHtml(m.badge)}</span><small>${escapeHtml(m.label)}</small></div></div>
          <div class="sidebox"><h3>EFTERLYSNING</h3><label class="report-check"><input id="reportWantedPerson" type="checkbox" ${r.wanted_person?'checked':''}> Efterlys person</label><label class="report-check"><input id="reportWantedVehicle" type="checkbox" ${r.wanted_vehicle?'checked':''}> Efterlys køretøj</label><small class="muted">Vises senere på profil/køretøjsregister og åbner rapporten.</small></div>
          <div class="sidebox"><h3>PERSON / KØRETØJ</h3><input id="reportModalPerson" placeholder="Person / CPR / navn" value="${escapeHtml(r.linked_person||'')}"><input id="reportModalVehicle" placeholder="Køretøj / nummerplade" value="${escapeHtml(r.linked_vehicle||'')}"></div>
          <div class="sidebox"><h3>LINK HÆNDELSE</h3><select id="reportModalIncident"><option value="">Ingen linket hændelse</option>${incOpts}</select><small class="muted">Når en rapport linkes, kan hændelsen bruge samme beviser/reference-flow.</small></div>
          <div class="sidebox report-mini-sections"><h3>SAGSINDHOLD</h3><button type="button" data-report-section="objects">Konfiskerede genstande</button><button type="button" data-report-section="criminals">Kriminelle involveret</button><button type="button" data-report-section="officers">Betjente involveret</button><button type="button" data-report-section="civilians">Borgere involveret</button><button type="button" data-report-section="tags">Tags</button><button type="button" data-report-section="evidence">Beviser</button></div>
        </aside>
      </div>
    </div>`;
  const typeSel=$('#reportModalType'); const title=$('#reportModalTitle'); const body=$('#reportModalBody');
  const syncStats=()=>{ const t=textOnly(body.innerHTML); const w=t.trim()?t.trim().split(/\s+/).length:0; $('#reportWords') && ($('#reportWords').textContent='WORDS: '+w); $('#reportChars') && ($('#reportChars').textContent='CHARACTERS: '+t.length); };
  const syncType=()=>{ const nm=reportTypeTemplates[typeSel.value]||reportTypeTemplates.report; $('#reportModalBadge').textContent=nm.badge; $('#reportModalBadge').style.setProperty('--report-color', nm.color); $('.report-incident-editor').style.setProperty('--report-color', nm.color); $('#reportTypePreview').innerHTML=`<span class="report-badge" style="--report-color:${escapeHtml(nm.color)}">${escapeHtml(nm.badge)}</span><small>${escapeHtml(nm.label)}</small>`; if(!title.value || title.value.startsWith('Ny ')) title.value=nm.title; body.innerHTML=nm.body; syncStats(); };
  typeSel.onchange=syncType; body.addEventListener('input', syncStats); syncStats();
  $('#modalSave').textContent = existing ? 'Gem' : 'Opret';
  $('#modalSave').onclick = ()=>{
    const nr = normalizeReport(Object.assign({}, r, { type:typeSel.value, title:title.value || (reportTypeTemplates[typeSel.value]||reportTypeTemplates.report).title, linked_incident_no:$('#reportModalIncident').value, linked_person:$('#reportModalPerson').value, linked_vehicle:$('#reportModalVehicle').value, wanted_person:$('#reportWantedPerson').checked, wanted_vehicle:$('#reportWantedVehicle').checked, body:body.innerHTML, updated_at:new Date().toISOString() }));
    if(existing){ mdtReports = mdtReports.map(x=>String(x.id)===String(existingId)?nr:x); } else { nr.id=Date.now(); nr.report_no=reportNo(); nr.created_at=new Date().toISOString(); mdtReports.unshift(nr); }
    if(nr.linked_incident_no){
      const inc=(incidents||[]).find(i=>String(i.incident_no||i.id)===String(nr.linked_incident_no));
      if(inc){ inc.references=inc.references||[]; if(!inc.references.some(x=>String(x.report_id)===String(nr.id))) inc.references.push({name:nr.title, note:'Rapport: '+nr.report_no, type:reportMeta(nr).label, report_id:nr.id}); }
    }
    reportStorageSave(); closeModal(); renderReportsPage(); toast('Rapport gemt.');
  };
  $('#modal').classList.remove('hidden');
}
function linkReportToCurrentIncident(id){
  const r=mdtReports.find(x=>String(x.id)===String(id)); if(!r){return;}
  if(!currentIncident){ toast('Åbn en hændelse først.'); return; }
  currentIncident.references=currentIncident.references||[];
  currentIncident.references.push({name:r.title, note:'Rapport: '+r.report_no, type:reportMeta(r).label, report_id:r.id});
  renderLists(); markDirty(); toast('Rapport linket til hændelsen.');
}

let mdtWiretapPhoneId = null;
let mdtWiretapPoll = null;

function wiretapFormatTime(ts) {
  const d = new Date((Number(ts) || 0) * 1000);
  if (Number.isNaN(d.getTime())) return '--:--:--';
  return `${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}:${String(d.getSeconds()).padStart(2,'0')}`;
}

function renderMdtWiretapLogs(logs) {
  const box = $('#mdtWiretapLog');
  if (!box) return;
  if (!logs || !logs.length) {
    box.innerHTML = '<p class="wiretap-empty">Ingen interceptet trafik på denne telefon endnu.</p>';
    return;
  }
  box.innerHTML = logs.map((l) => `<div class="wiretap-line"><span class="wiretap-time">[${wiretapFormatTime(l.time)}]</span>${escapeHtml(l.message || '')}</div>`).join('');
  box.scrollTop = box.scrollHeight;
}

function updateMdtWiretapOverlayMeta(session) {
  const ownerEl = $('#mdtWiretapOwner');
  const grantRow = $('#mdtWiretapGrantRow');
  if (!ownerEl) return;
  if (session && session.ownerName) {
    ownerEl.textContent = `Aflytning påbegyndt af: ${session.ownerName}`;
    ownerEl.classList.remove('hidden');
  } else {
    ownerEl.classList.add('hidden');
  }
  if (grantRow) grantRow.classList.toggle('hidden', !(session && session.owner));
}

function openMdtWiretapOverlay(phoneId, logs, session) {
  mdtWiretapPhoneId = phoneId || null;
  const overlay = $('#mdtWiretapOverlay');
  const idEl = $('#mdtWiretapPhoneId');
  if (idEl) idEl.textContent = phoneId || 'UKENDT';
  renderMdtWiretapLogs(logs || []);
  updateMdtWiretapOverlayMeta(session || null);
  overlay && overlay.classList.remove('hidden');
}

function closeMdtWiretapOverlay(clearId) {
  const overlay = $('#mdtWiretapOverlay');
  overlay && overlay.classList.add('hidden');
  updateMdtWiretapOverlayMeta(null);
  if (clearId) mdtWiretapPhoneId = null;
}

function startMdtWiretapPoll() {
  stopMdtWiretapPoll();
  if (!mdtWiretapPhoneId) return;
  mdtWiretapPoll = setInterval(async () => {
    if (!mdtWiretapPhoneId) return;
    try {
      const r = await nui('getWiretapLive', { phoneId: mdtWiretapPhoneId });
      if (r && r.ok) renderMdtWiretapLogs(r.logs || []);
    } catch (e) {}
  }, 5000);
}

function stopMdtWiretapPoll() {
  if (mdtWiretapPoll) clearInterval(mdtWiretapPoll);
  mdtWiretapPoll = null;
}

function updateWiretapProfileButtons() {
  const start = document.querySelector('#startWiretapBtn');
  const stop = document.querySelector('#stopWiretapBtn');
  if (start) start.classList.toggle('hidden', !!mdtWiretapPhoneId);
  if (stop) stop.classList.toggle('hidden', !mdtWiretapPhoneId);
}

async function refreshWiretapSession() {
  try {
    const r = await nui('getWiretapSession', {});
    if (r && r.ok && r.session) {
      mdtWiretapPhoneId = r.session.phoneId;
      openMdtWiretapOverlay(r.session.phoneId, r.logs || [], r.session);
      startMdtWiretapPoll();
    }
  } catch (e) {}
  updateWiretapProfileButtons();
}

let activeFilesFolder = 'tracks';

function setFilesFolder(folder) {
  activeFilesFolder = folder || 'tracks';
  $$('.files-folder-btn').forEach((b) => b.classList.toggle('active', b.dataset.filesFolder === activeFilesFolder));
  $$('.files-folder-panel').forEach((p) => p.classList.remove('active'));
  const map = { tracks: '#filesFolderTracks', wiretaps: '#filesFolderWiretaps', assigned: '#filesFolderAssigned' };
  $(map[activeFilesFolder] || '#filesFolderTracks')?.classList.add('active');
}

async function refreshVehicleTracks() {
  const list = $('#vehicleTrackList');
  const count = $('#vehicleTrackCount');
  if (!list) return;
  const r = await nui('getVehicleTracks', {});
  const tracks = (r && r.tracks) || [];
  if (count) count.textContent = String(tracks.length);
  if (!tracks.length) {
    list.innerHTML = '<div class="admin-empty">Ingen sporinger registreret endnu. Brug "Spor køretøj" i køretøjsregisteret.</div>';
    return;
  }
  list.innerHTML = tracks.map((t) => `
    <button class="wiretap-archive-card" data-track-plate="${escapeHtml(t.plate || '')}">
      <div class="wiretap-archive-main">
        <b>${escapeHtml(t.plate || 'Ukendt plade')}</b>
        <small>${escapeHtml(t.officer_name || 'Ukendt')} · ${escapeHtml(fmtDate(t.created_at) || '')}</small>
      </div>
      <div class="wiretap-archive-side">
        <span>${escapeHtml(t.status_note || t.garage_label || 'Sporing')}</span>
      </div>
    </button>`).join('');
}

async function refreshAssignedFiles() {
  const list = $('#assignedFilesList');
  const count = $('#assignedFilesCount');
  if (!list) return;
  const serverFiles = ((await nui('getAssignedFiles', {})) || {}).files || [];
  const officer = ($('#officerName')?.textContent || '').trim().toLowerCase();
  const localReports = (mdtReports || []).filter((rep) => (rep.officers || []).some((o) => String(o.name || '').toLowerCase() === officer)).map((rep) => ({
    kind: 'report',
    id: rep.report_no || rep.id,
    title: rep.title || 'Rapport',
    subtitle: 'Tildelt rapport',
    date: rep.created_at,
    created_by: rep.created_by || ''
  }));
  const files = [...serverFiles, ...localReports].sort((a, b) => String(b.date || '').localeCompare(String(a.date || '')));
  if (count) count.textContent = String(files.length);
  if (!files.length) {
    list.innerHTML = '<div class="admin-empty">Ingen tildelte sager. Du får filer her når du tilføjes til hændelser eller rapporter.</div>';
    return;
  }
  list.innerHTML = files.map((f) => `
    <button class="wiretap-archive-card" data-assigned-open="${escapeHtml(f.kind || '')}:${escapeHtml(f.id || '')}">
      <div class="wiretap-archive-main">
        <b>${escapeHtml(f.title || 'Ukendt sag')}</b>
        <small>${escapeHtml(f.subtitle || f.kind || '')} · ${escapeHtml(fmtDate(f.date) || '')}</small>
      </div>
      <div class="wiretap-archive-side"><span>${escapeHtml(f.id || '')}</span></div>
    </button>`).join('');
}

async function refreshFilesPage() {
  setFilesFolder(activeFilesFolder);
  await Promise.all([refreshVehicleTracks(), refreshWiretapArchives(), refreshAssignedFiles()]);
}

async function refreshWiretapArchives() {
  const list = $('#wiretapArchiveList');
  const count = $('#wiretapArchiveCount');
  if (!list) return;
  const r = await nui('getWiretapArchives', {});
  const archives = (r && r.archives) || [];
  if (count) count.textContent = String(archives.length);
  if (!archives.length) {
    list.innerHTML = '<div class="admin-empty">Ingen aflytninger gemt endnu. Stop en aktiv aflytning for at gemme udskrift her.</div>';
    return;
  }
  list.innerHTML = archives.map((a) => `
    <button class="wiretap-archive-card" data-wiretap-archive="${escapeHtml(a.id || '')}">
      <div class="wiretap-archive-main">
        <b>${escapeHtml(a.phoneId || 'Ukendt telefon')}</b>
        <small>${escapeHtml(a.officerName || 'Ukendt betjent')} · ${escapeHtml(fmtDate(a.endedAt) || 'Ukendt dato')}</small>
      </div>
      <div class="wiretap-archive-side">
        <span>${Number(a.messageCount || (a.logs && a.logs.length) || 0)} linjer</span>
        <em>${escapeHtml(a.id || '')}</em>
      </div>
    </button>`).join('');
}

async function openWiretapArchiveDetail(id) {
  const shell = document.querySelector('.files-shell');
  const detail = $('#wiretapArchiveDetail');
  if (!id || !detail) return;
  const r = await nui('getWiretapArchive', { id });
  if (!r || !r.ok || !r.archive) { toast(r?.message || 'Kunne ikke åbne arkiv.'); return; }
  const a = r.archive;
  $('#wiretapArchiveTitle').textContent = `Aflytning ${a.phoneId || ''}`;
  $('#wiretapArchiveMeta').textContent = `${a.officerName || 'Ukendt'} · ${fmtDate(a.startedAt) || '?'} → ${fmtDate(a.endedAt) || '?'} · ${a.id || ''}`;
  const logs = a.logs || [];
  const box = $('#wiretapArchiveTranscript');
  box.innerHTML = logs.length
    ? logs.map((l) => `<div class="wiretap-line"><span class="wiretap-time">[${wiretapFormatTime(l.time)}]</span>${escapeHtml(l.message || '')}</div>`).join('')
    : '<p class="wiretap-empty">Ingen beskeder fanget i denne aflytning.</p>';
  shell && shell.classList.add('hidden');
  detail.classList.remove('hidden');
}

function closeWiretapArchiveDetail() {
  const shell = document.querySelector('.files-shell');
  const detail = $('#wiretapArchiveDetail');
  shell && shell.classList.remove('hidden');
  detail && detail.classList.add('hidden');
}

function bind(){
  $$('.nav').forEach(b => {
    b.classList.remove('disabled'); b.disabled = false;
    if(b.classList.contains('nsk-main')) return;
    if(b.classList.contains('krim-main')) return;
    if(b.dataset.page === 'reports'){
      b.onclick = () => { reportScope = 'politi'; setPage('reports'); };
      return;
    }
    b.onclick = () => setPage(b.dataset.page);
  });
  $('#topPlus') && ($('#topPlus').onclick = () => setPage('dashboard'));
  $('#newReportBtn') && ($('#newReportBtn').onclick = () => openReportModal());
  $('#reportSearch') && $('#reportSearch').addEventListener('input', renderReportsPage);
  $('#reportTypeFilter') && $('#reportTypeFilter').addEventListener('change', renderReportsPage);
  $('#createReport') && ($('#createReport').onclick = () => newIncident());
  $('#createReportList') && ($('#createReportList').onclick = () => newIncident());
  $('#backToIncidentList') && ($('#backToIncidentList').onclick = () => { currentIncident = null; setIncidentListMode(true); renderIncidentList(); });
  $('#backToIncidentListTop') && ($('#backToIncidentListTop').onclick = () => { currentIncident = null; setIncidentListMode(true); renderIncidentList(); });
  $('#close') && ($('#close').onclick = () => { setLookThrough(false); showApp(false); nui('close',{}); });
  $('#searchIncidents') && ($('#searchIncidents').onclick = refreshIncidents);
  $('#incidentSearch') && $('#incidentSearch').addEventListener('keydown', e => { if(e.key === 'Enter') refreshIncidents(); });
  $('#incidentSearch') && $('#incidentSearch').addEventListener('input', () => { clearTimeout(window.__incidentSearchTimer); window.__incidentSearchTimer = setTimeout(refreshIncidents, 160); });
  $('#searchProfiles') && ($('#searchProfiles').onclick = refreshProfiles);
  $('#profileSearch') && $('#profileSearch').addEventListener('keydown', e => { if(e.key === 'Enter') refreshProfiles(); });
  $('#profileSearch') && $('#profileSearch').addEventListener('input', () => { clearTimeout(window.__profileSearchTimer); window.__profileSearchTimer = setTimeout(refreshProfiles, 160); });
  $('#saveIncident') && ($('#saveIncident').onclick = saveIncident);
  $('#deleteIncident') && ($('#deleteIncident').onclick = deleteIncident);
  $('#incidentTitle') && $('#incidentTitle').addEventListener('input', markDirty);
  $('#incidentEditor') && $('#incidentEditor').addEventListener('input', updateCounts);
  $$('[data-cmd]').forEach(b => b.onclick = () => document.execCommand(b.dataset.cmd, false, null));
  $('#formatBlock') && ($('#formatBlock').onchange = e => document.execCommand('formatBlock', false, e.target.value));
  $$('[data-add]').forEach(b => b.onclick = () => addToList(b.dataset.add));
  $('#modalCancel') && ($('#modalCancel').onclick = closeModal);
  if(!window.__reportsDelegated){ window.__reportsDelegated=true; document.addEventListener('click', e=>{ const open=e.target.closest('[data-open-report]'); if(open && !e.target.closest('button')){ openReportModal(open.dataset.openReport); return; } const del=e.target.closest('[data-delete-report]'); if(del){ let scoped=getScopedReports().filter(r=>String(r.id)!==String(del.dataset.deleteReport)); setScopedReports(scoped); reportStorageSave(); syncReportAnpgFlags(); renderReportsPage(); return; } const l=e.target.closest('[data-link-report]'); if(l){ linkReportToCurrentIncident(l.dataset.linkReport); return; } }); }
  $('#selfProfileBtn') && ($('#selfProfileBtn').onclick = () => setPage('self_profile'));
  $('#employeeSearch') && $('#employeeSearch').addEventListener('input', () => { clearTimeout(window.__empSearchTimer); window.__empSearchTimer = setTimeout(refreshEmployees, 160); });
  $('#refreshEmployees') && ($('#refreshEmployees').onclick = refreshEmployees);
  $('#hireEmployeeBtn') && ($('#hireEmployeeBtn').onclick = openHireModal);
  $('#newRoleBtn') && ($('#newRoleBtn').onclick = () => openRoleModal(-1));
  $('#sendMailBtn') && ($('#sendMailBtn').onclick = sendMail);
  $('#sendPrivateMailBtn') && ($('#sendPrivateMailBtn').onclick = sendPrivateMail);
  $('#sendNewsMailBtn') && ($('#sendNewsMailBtn').onclick = sendNewsMail);
  $$('.mail-mode-card').forEach(b => b.onclick = () => setMailMode(b.dataset.mailMode));
  $('#mailProfileSearchBtn') && ($('#mailProfileSearchBtn').onclick = refreshMailSystem);
  $('#mailProfileSearch') && ($('#mailProfileSearch').oninput = () => { clearTimeout(window.__mailSearchTimer); window.__mailSearchTimer=setTimeout(refreshMailSystem, 220); });
  $('#filesRefreshBtn') && ($('#filesRefreshBtn').onclick = refreshFilesPage);
  $$('.files-folder-btn').forEach((b) => { b.onclick = () => { setFilesFolder(b.dataset.filesFolder); }; });
  $('#wiretapArchivesRefresh') && ($('#wiretapArchivesRefresh').onclick = refreshFilesPage);
  $('#wiretapArchiveBack') && ($('#wiretapArchiveBack').onclick = closeWiretapArchiveDetail);
  $('#mdtWiretapGrantBtn') && ($('#mdtWiretapGrantBtn').onclick = async () => {
    const target = ($('#mdtWiretapGrantId')?.value || '').trim();
    if (!target) { toast('Indtast kollegas identifier (char1:...).'); return; }
    if (!mdtWiretapPhoneId) { toast('Ingen aktiv aflytning.'); return; }
    const r = await nui('grantWiretapAccess', { phoneId: mdtWiretapPhoneId, targetIdentifier: target });
    if (r && r.ok) {
      toast('Adgang givet til kollega.');
      updateMdtWiretapOverlayMeta(r.lock || null);
      $('#mdtWiretapGrantId') && ($('#mdtWiretapGrantId').value = '');
    } else toast((r && r.message) || 'Kunne ikke give adgang.');
  });
  $('#mdtWiretapStop') && ($('#mdtWiretapStop').onclick = async () => {
    const r = await nui('stopNarkoWiretap', {});
    if (r && r.ok) {
      stopMdtWiretapPoll();
      closeMdtWiretapOverlay(true);
      updateWiretapProfileButtons();
      toast(r.message || 'Aflytning stoppet og gemt.');
      if (activePage === 'files') refreshWiretapArchives();
    } else toast((r && r.message) || 'Kunne ikke stoppe aflytning.');
  });
  $('#mdtWiretapMinimize') && ($('#mdtWiretapMinimize').onclick = () => $('#mdtWiretapOverlay')?.classList.add('hidden'));
  document.addEventListener('click', (e) => {
    const card = e.target.closest('[data-wiretap-archive]');
    if (card) { e.preventDefault(); openWiretapArchiveDetail(card.dataset.wiretapArchive); return; }
    const assigned = e.target.closest('[data-assigned-open]');
    if (assigned) {
      e.preventDefault();
      const [kind, id] = String(assigned.dataset.assignedOpen || '').split(':');
      if (kind === 'incident') {
        const inc = (incidents || []).find((i) => String(i.incident_no || i.id) === String(id));
        if (inc) openIncident(inc); else toast('Hændelsen er ikke indlæst.');
      } else if (kind === 'report') {
        const rep = (mdtReports || []).find((r) => String(r.report_no || r.id) === String(id));
        if (rep) openReportPage(rep); else toast('Rapporten blev ikke fundet.');
      }
      return;
    }
    const track = e.target.closest('[data-track-plate]');
    if (track) {
      e.preventDefault();
      const plate = track.dataset.trackPlate || '';
      setPage('vehicles');
      const search = $('#vehicleRegistrySearch');
      if (search) search.value = plate;
      searchVehicleRegistry().then(() => { if (registryVehicleResults.length) openRegistryVehicle(0); });
    }
  });
  $('#mailHistoryRefresh') && ($('#mailHistoryRefresh').onclick = () => refreshMailHistory());
  $('#mailNewsRefresh') && ($('#mailNewsRefresh').onclick = () => refreshMailNewsList());
  $('#addChargeBtn') && ($('#addChargeBtn').onclick = () => openChargeModal());
  $('#chargeSearch') && $('#chargeSearch').addEventListener('input', () => { clearTimeout(chargeSearchTimer); chargeSearchTimer = setTimeout(renderCharges, 120); });
  $('#chargeCategoryFilter') && $('#chargeCategoryFilter').addEventListener('change', renderCharges);
  const adminMainBtn = $('.admin-main');
  const adminDrop = $('.admin-dropdown');
  if(adminMainBtn && adminDrop){
    refreshAdministrationAccess();
    adminMainBtn.onclick = (ev) => {
      ev.preventDefault();
      if(!mdtAdminView){
        adminDrop.classList.add('closed');
        adminMainBtn.classList.add('closed');
        toast({ type:'error', title:'Ingen adgang', message:'Du mangler administration.view eller Rigspolitiet.' });
        return;
      }
      const isClosed = adminDrop.classList.toggle('closed');
      adminMainBtn.classList.toggle('closed', isClosed);
      if(!isClosed) openAdminPage('admin_employees');
    };
  }
  $$('.admin-subnav').forEach(b => { if(!enabledPages[b.dataset.page]) b.classList.add('disabled'); b.onclick = () => openAdminPage(b.dataset.page); });
  $$('.nsk-subnav').forEach((b) => { b.onclick = (ev) => { ev.preventDefault(); openNskPage(b.dataset.page); }; });
  const krimMainBtn = $('.krim-main');
  const krimDrop = $('.krim-dropdown');
  if(krimMainBtn && krimDrop){
    krimMainBtn.onclick = (ev) => {
      ev.preventDefault();
      const isClosed = krimDrop.classList.toggle('closed');
      krimMainBtn.classList.toggle('closed', isClosed);
      if(!isClosed) openKrimPage('krim_dna');
    };
  }
  $$('.krim-subnav').forEach((b) => { b.onclick = (ev) => { ev.preventDefault(); openKrimPage(b.dataset.page); }; });
  $('#krimDnaRefresh') && ($('#krimDnaRefresh').onclick = refreshKrimDna);
  $('#krimFpRefresh') && ($('#krimFpRefresh').onclick = refreshKrimFingerprints);
  $('#krimDnaSearch') && ($('#krimDnaSearch').oninput = () => { clearTimeout(window.__krimDnaSearch); window.__krimDnaSearch = setTimeout(refreshKrimDna, 350); });
  $('#krimFpSearch') && ($('#krimFpSearch').oninput = () => { clearTimeout(window.__krimFpSearch); window.__krimFpSearch = setTimeout(refreshKrimFingerprints, 350); });
  $('#nskRefreshBtn') && ($('#nskRefreshBtn').onclick = () => refreshNskOverview());
  $('#nskAddGangBtn') && ($('#nskAddGangBtn').onclick = () => openNskGangModal());
  $('#nskAddTerritoryBtn') && ($('#nskAddTerritoryBtn').onclick = () => startNskTerritoryPlace());
  $('#nskMapPlaceBtn') && ($('#nskMapPlaceBtn').onclick = () => startNskTerritoryPlace());
  $('#nskMapCancelPlaceBtn') && ($('#nskMapCancelPlaceBtn').onclick = () => cancelNskTerritoryEdit());
  document.querySelectorAll('.nsk-tab').forEach((btn) => {
    btn.onclick = () => {
      document.querySelectorAll('.nsk-tab').forEach((b) => b.classList.toggle('active', b === btn));
      document.querySelectorAll('.nsk-panel').forEach((p) => p.classList.remove('active'));
      const panel = $(`#nskPanel${btn.dataset.nskTab.charAt(0).toUpperCase()}${btn.dataset.nskTab.slice(1)}`);
      if(panel) panel.classList.add('active');
    };
  });
  $('#nskObsRefresh') && ($('#nskObsRefresh').onclick = () => refreshNskObservations());
  $('#nskObsSaveBtn') && ($('#nskObsSaveBtn').onclick = () => saveNskObservationEditor());
  $('#nskObsNewBtn') && ($('#nskObsNewBtn').onclick = () => openNskObservationEditor(null));
  $('#nskObsDeleteBtn') && ($('#nskObsDeleteBtn').onclick = () => deleteNskObservationEditor());
  $('#nskObsSubjectEdit')?.addEventListener('input', () => { nskObsDirty = true; syncNskObsSaveState(); });
  $('#nskObsBodyEdit')?.addEventListener('input', () => { nskObsDirty = true; syncNskObsSaveState(); });
  ['#nskObsTargetTypeEdit','#nskObsGangEdit','#nskObsPersonSearchEdit','#nskObsPriorityEdit'].forEach((sel) => {
    $(sel.replace('#',''))?.addEventListener('change', () => { nskObsDirty = true; syncNskObsSaveState(); });
    $(sel.replace('#',''))?.addEventListener('input', () => { nskObsDirty = true; syncNskObsSaveState(); });
  });
  $('#nskObsSearch') && ($('#nskObsSearch').oninput = () => { clearTimeout(window.__nskObsSearch); window.__nskObsSearch = setTimeout(refreshNskObservations, 350); });
  $('#nskObsFilter') && ($('#nskObsFilter').onchange = refreshNskObservations);
  $('#nskObsGangFilter') && ($('#nskObsGangFilter').onchange = refreshNskObservations);
  $('#nskConnRefresh') && ($('#nskConnRefresh').onclick = () => refreshNskConnections());
  $('#nskConnAddBtn') && ($('#nskConnAddBtn').onclick = () => openNskConnectionModal());
  $('#nskConnGangFilter') && ($('#nskConnGangFilter').onchange = refreshNskConnections);
  $('#nskActRefresh') && ($('#nskActRefresh').onclick = () => refreshNskActivity());
  $('#nskActSearch') && ($('#nskActSearch').oninput = () => { clearTimeout(window.__nskActSearch); window.__nskActSearch = setTimeout(refreshNskActivity, 350); });
  $('#nskActOfficer') && ($('#nskActOfficer').oninput = () => { clearTimeout(window.__nskActOfficer); window.__nskActOfficer = setTimeout(refreshNskActivity, 350); });
  document.addEventListener('change', e => {
    const roleSel = e.target.closest('[data-emp-role]');
    const divSel = e.target.closest('[data-emp-division]');
    if(roleSel || divSel){
      const idx = Number((roleSel || divSel).dataset.empRole ?? (roleSel || divSel).dataset.empDivision);
      scheduleEmployeeSave(idx, 120);
    }
  });
  document.addEventListener('keydown', e => {
    const pnum = e.target.closest('[data-emp-pnum]');
    const img = e.target.closest('[data-emp-image]');
    const pass = e.target.closest('[data-emp-pass]');
    if(pass && e.key === 'Enter'){ e.preventDefault(); saveEmployee(Number(pass.dataset.empPass), true); pass.blur(); return; }
    if(img && e.key === 'Enter'){ e.preventDefault(); saveEmployee(Number(img.dataset.empImage), true); img.blur(); return; }
    if(pnum && e.key === 'Enter'){
      e.preventDefault();
      saveEmployee(Number(pnum.dataset.empPnum), true);
      pnum.blur();
    }
  });
  document.addEventListener('blur', e => {
    const pnum = e.target.closest('[data-emp-pnum]');
    const img = e.target.closest('[data-emp-image]');
    const pass = e.target.closest('[data-emp-pass]');
    if(pass) saveEmployee(Number(pass.dataset.empPass), true);
    if(img) saveEmployee(Number(img.dataset.empImage), true);
    if(pnum) saveEmployee(Number(pnum.dataset.empPnum), true);
  }, true);
  const vehicleInput = $('#vehicleRegistrySearch');
  const vehicleBtn = $('#vehicleRegistrySearchBtn');
  if(vehicleInput){
    vehicleInput.addEventListener('input', () => {
      clearTimeout(vehicleRegistrySearchTimer);
      vehicleRegistrySearchTimer = setTimeout(searchVehicleRegistry, 150);
    });
    vehicleInput.addEventListener('keydown', e => { if(e.key === 'Enter') searchVehicleRegistry(); });
  }
  if(vehicleBtn) vehicleBtn.onclick = searchVehicleRegistry;
  document.addEventListener('click', e => {
    const togglePass = e.target.closest('[data-toggle-pass]');
    if(togglePass){
      const idx = Number(togglePass.dataset.togglePass);
      const input = document.querySelector(`[data-emp-pass="${idx}"]`);
      if(input){ const show = input.type === 'password'; input.type = show ? 'text' : 'password'; togglePass.textContent = show ? 'Skjul kode' : 'Se kode'; }
      return;
    }
    const unlinkRefEarly = e.target.closest('[data-unlink-reference]');
    if(unlinkRefEarly){
      e.preventDefault();
      e.stopPropagation();
      if(e.stopImmediatePropagation) e.stopImmediatePropagation();
      const parts = String(unlinkRefEarly.dataset.unlinkReference || '').split(':');
      if(parts[0] === 'report' && typeof window.unlinkReportFromCurrentIncident === 'function') window.unlinkReportFromCurrentIncident(parts[1]);
      return false;
    }
    const addCrim = e.target.closest('[data-add-criminal]'); if(addCrim){ addCriminalToIncident(criminalSearchResults[Number(addCrim.dataset.addCriminal)]); return; }
    const addCiv = e.target.closest('[data-add-civilian]'); if(addCiv){ addCivilianToIncident(civilianSearchResults[Number(addCiv.dataset.addCivilian)]); return; }
    const addVeh = e.target.closest('[data-add-vehicle]'); if(addVeh){ addVehicleToIncident(vehicleSearchResults[Number(addVeh.dataset.addVehicle)]); return; }
    const addReportSuspect = e.target.closest('[data-add-report-suspect]'); if(addReportSuspect){ addSuspectToReport(criminalSearchResults[Number(addReportSuspect.dataset.addReportSuspect)]); return; }
    const addReportVehicle = e.target.closest('[data-add-report-vehicle]'); if(addReportVehicle){ addVehicleToReport(vehicleSearchResults[Number(addReportVehicle.dataset.addReportVehicle)]); return; }
    const addReportCivilian = e.target.closest('[data-add-report-civilian]'); if(addReportCivilian){ addCivilianToReport(civilianSearchResults[Number(addReportCivilian.dataset.addReportCivilian)]); return; }
    const addReportOfficer = e.target.closest('[data-add-report-officer]'); if(addReportOfficer){ addOfficerToReport(reportOfficerSearchResults[Number(addReportOfficer.dataset.addReportOfficer)]); return; }
    const addIncidentOfficer = e.target.closest('[data-add-incident-officer]'); if(addIncidentOfficer){ addOfficerToIncident(incidentOfficerSearchResults[Number(addIncidentOfficer.dataset.addIncidentOfficer)]); return; }
    const reportAdd = e.target.closest('[data-report-add]'); if(reportAdd){ openReportAddModal(reportAdd.dataset.reportAdd); return; }
    const reportRemove = e.target.closest('[data-report-remove]'); if(reportRemove && currentReport){ const [k,i]=reportRemove.dataset.reportRemove.split(':'); currentReport[k]?.splice(Number(i),1); renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); return; }
    const reportWanted = e.target.closest('[data-report-wanted]'); if(reportWanted && currentReport){ const [k,i]=reportWanted.dataset.reportWanted.split(':'); const obj=currentReport[k]?.[Number(i)]; if(obj){ obj.wanted=!obj.wanted; renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); toast(obj.wanted ? 'Efterlysning markeret i rapport — ANPG opdateres.' : 'Efterlysning fjernet fra rapport — ANPG opdateres.'); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); reportStorageSave(); syncReportAnpgFlags(); } return; }
    const reportSuspectProfile = e.target.closest('[data-report-suspect-profile]'); if(reportSuspectProfile && currentReport){ const idx=Number(reportSuspectProfile.dataset.reportSuspectProfile); const p=(currentReport.suspects||[])[idx] || (currentReport.civilians||[])[idx]; openProfilePreviewByIdentifier(p && p.identifier); return; }
    const reportOfficerProfile = e.target.closest('[data-report-officer-profile]'); if(reportOfficerProfile && currentReport){ const p=currentReport.officers?.[Number(reportOfficerProfile.dataset.reportOfficerProfile)]; openProfilePreviewByIdentifier(p && p.identifier); return; }
    const reportVehicleOwner = e.target.closest('[data-report-vehicle-owner]'); if(reportVehicleOwner && currentReport){ const v=currentReport.vehicles?.[Number(reportVehicleOwner.dataset.reportVehicleOwner)]; openProfilePreviewByIdentifier(v && v.owner); return; }
    const reportPickTag = e.target.closest('[data-report-pick-tag]'); if(reportPickTag && currentReport){ const t=mdtTags[Number(reportPickTag.dataset.reportPickTag)]; if(t){ currentReport.tags=currentReport.tags||[]; const idx=currentReport.tags.findIndex(x=>(x.name||x)===t.name); if(idx>=0) currentReport.tags.splice(idx,1); else currentReport.tags.push(t); renderReportSideLists(); openReportAddModal('tags'); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); } return; }
    const evLocker = e.target.closest('[data-open-evidence-locker]'); if(evLocker){ openEvidenceLocker(); return; }
    const chargeToggle = e.target.closest('[data-toggle-incident-charges]'); if(chargeToggle){ incidentChargesExpanded = !incidentChargesExpanded; renderLists(); return; }
    const crimCharges = e.target.closest('[data-criminal-charges]'); if(crimCharges && currentIncident){ activeCriminalChargesIndex = activeCriminalChargesIndex === Number(crimCharges.dataset.criminalCharges) ? null : Number(crimCharges.dataset.criminalCharges); renderLists(); return; }
    const crimOpen = e.target.closest('[data-criminal-open]'); if(crimOpen && currentIncident && !e.target.closest('button')){ activeCriminalChargesIndex = activeCriminalChargesIndex === Number(crimOpen.dataset.criminalOpen) ? null : Number(crimOpen.dataset.criminalOpen); renderLists(); return; }
    const personAddCharge = e.target.closest('[data-person-add-charge]'); if(personAddCharge && currentIncident){ openIncidentChargePicker(Number(personAddCharge.dataset.personAddCharge)); return; }
    const personIssueFine = e.target.closest('[data-person-issue-fine]'); if(personIssueFine && currentIncident){ issuePersonFine(Number(personIssueFine.dataset.personIssueFine)); return; }
    const personLicenseSanction = e.target.closest('[data-person-license-sanction]'); if(personLicenseSanction && currentIncident){ openLicenseSanctionConfirm(Number(personLicenseSanction.dataset.personLicenseSanction)); return; }
    const personChargeRemove = e.target.closest('[data-person-charge-remove]'); if(personChargeRemove && currentIncident){ const [pi,ci]=personChargeRemove.dataset.personChargeRemove.split(':').map(Number); const p=currentIncident.criminals?.[pi]; const arr=getPersonCharges(p); if(arr[ci]){ if(Number(arr[ci].count||1)>1) arr[ci].count=Number(arr[ci].count)-1; else arr.splice(ci,1); p.charges=arr.reduce((a,c)=>a+Number(c.count||1),0); renderLists(); markDirty(); } return; }
    const personChargeDetail = e.target.closest('[data-person-charge-detail]'); if(personChargeDetail && currentIncident && !e.target.closest('button')){ const [pi,ci]=personChargeDetail.dataset.personChargeDetail.split(':').map(Number); openPersonChargeDetail(pi,ci); return; }
    const flagBtn = e.target.closest('[data-person-flag]'); if(flagBtn && currentIncident){ const [pi,key]=flagBtn.dataset.personFlag.split(':'); const p=currentIncident.criminals?.[Number(pi)]; if(p){ p.chargeFlags=p.chargeFlags||{}; p.chargeFlags[key]=!p.chargeFlags[key]; if(key==='wanted' && !p.chargeFlags.wanted && currentIncident.vehicles){ currentIncident.vehicles.forEach(v=>{ if(!v) return; v.wanted=false; if(String(v.status||'').toLowerCase().includes('efterlyst')) v.status=''; }); } renderLists(); markDirty(); } return; }
    const crimProfile = e.target.closest('[data-criminal-profile]'); if(crimProfile && currentIncident){ const p = currentIncident.criminals[Number(crimProfile.dataset.criminalProfile)]; openProfilePreviewByIdentifier(p && p.identifier); return; }
    const civProfile = e.target.closest('[data-civilian-profile]'); if(civProfile && currentIncident){ const p = currentIncident.civilians[Number(civProfile.dataset.civilianProfile)]; openProfilePreviewByIdentifier(p && p.identifier); return; }
    const incidentOfficerProfile = e.target.closest('[data-incident-officer-profile]'); if(incidentOfficerProfile && currentIncident){ const p = currentIncident.officers?.[Number(incidentOfficerProfile.dataset.incidentOfficerProfile)]; openProfilePreviewByIdentifier(p && p.identifier); return; }
    const vehOwner = e.target.closest('[data-vehicle-owner-profile]'); if(vehOwner && currentIncident){ const v = currentIncident.vehicles[Number(vehOwner.dataset.vehicleOwnerProfile)]; openProfilePreviewByIdentifier(v && v.owner); return; }
    const tagInfo = e.target.closest('[data-tag-info]'); if(tagInfo && !e.target.closest('[data-remove]')){ openTagInfo(Number(tagInfo.dataset.tagInfo)); return; }
    const empAdmin = e.target.closest('[data-employee-admin]'); if(empAdmin){ openEmployeeAdminModal(Number(empAdmin.dataset.employeeAdmin)); return; }
    const empLogin = e.target.closest('[data-employee-login]'); if(empLogin){ openEmployeeLoginModal(Number(empLogin.dataset.employeeLogin)); return; }
    const fireEmp = e.target.closest('[data-fire-emp]'); if(fireEmp){ fireEmployee(Number(fireEmp.dataset.fireEmp)); return; }
    const editPerms = e.target.closest('[data-edit-perms]'); if(editPerms){ openEmployeePermsModal(Number(editPerms.dataset.editPerms)); return; }
    const adminTagNew = e.target.closest('#newTagBtn'); if(adminTagNew){ openAdminTagModal(); return; }
    const editAdminTag = e.target.closest('[data-edit-admin-tag]'); if(editAdminTag){ openAdminTagModal(Number(editAdminTag.dataset.editAdminTag)); return; }
    const delAdminTag = e.target.closest('[data-delete-admin-tag]'); if(delAdminTag){ mdtTags.splice(Number(delAdminTag.dataset.deleteAdminTag),1); saveLocalTags(); renderAdminTags(); return; }
    const pickTag = e.target.closest('[data-pick-tag]'); if(pickTag && currentIncident){ const t = mdtTags[Number(pickTag.dataset.pickTag)]; if(t){ currentIncident.tags=currentIncident.tags||[]; const pos=currentIncident.tags.findIndex(x=>(x.name||x)===t.name); if(pos>=0){ currentIncident.tags.splice(pos,1); pickTag.classList.remove('picked'); const row=pickTag.querySelector('.scum-tag-row span:last-child'); if(row) row.textContent='Vælg'; } else { currentIncident.tags.push({...t}); pickTag.classList.add('picked'); const row=pickTag.querySelector('.scum-tag-row span:last-child'); if(row) row.textContent='Valgt'; } renderLists(); markDirty(); } return; }
    const refPick = e.target.closest('[data-pick-reference]'); if(refPick && currentIncident){ const src=(incidents||[]).filter(x => !currentIncident || x.id !== currentIncident.id)[Number(refPick.dataset.pickReference)]; if(src){ currentIncident.references=currentIncident.references||[]; currentIncident.references.push({name:(src.title||'Rapport'), note:'ID: '+(src.incident_no||'---'), incident_id:src.id, type:currentReportTypeMeta(src).label}); renderLists(); markDirty(); toast('Reference tilføjet.'); } return; }
    const roleEdit = e.target.closest('[data-role-edit]'); if(roleEdit){ openRoleModal(Number(roleEdit.dataset.roleEdit)); return; }
    const roleDelete = e.target.closest('[data-role-delete]'); if(roleDelete){ const role = adminRoles[Number(roleDelete.dataset.roleDelete)]; if(role) nui('deleteRole',{name:role.name}).then(()=>refreshRoles()); return; }
    const editCharge = e.target.closest('[data-edit-charge]'); if(editCharge){ openChargeModal(Number(editCharge.dataset.editCharge)); return; }
    const chargeView = e.target.closest('[data-charge-view]'); if(chargeView && !e.target.closest('button')){ return; }
    const delCharge = e.target.closest('[data-delete-charge]'); if(delCharge){ deleteCharge(Number(delCharge.dataset.deleteCharge)); return; }
    const profileLicenseAction = e.target.closest('[data-profile-license-action]');
    if(profileLicenseAction && activeProfile){
      const [action, licenseType] = String(profileLicenseAction.dataset.profileLicenseAction || '').split(':');
      if(action && licenseType) updateProfileLicense(action, licenseType);
      return;
    }
    const pc = e.target.closest('[data-profile]'); if(pc) openProfile(Number(pc.dataset.profile));
    const rem = e.target.closest('[data-remove]'); if(rem && currentIncident){ const t=rem.dataset.remove, idx=Number(rem.dataset.idx); currentIncident[t].splice(idx,1); renderLists(); markDirty(); }
    const openVeh = e.target.closest('[data-open-registry-vehicle]'); if(openVeh){ openRegistryVehicle(Number(openVeh.dataset.openRegistryVehicle)); return; }
    const incVeh = e.target.closest('[data-incident-vehicle], .vehicle-pill'); if(incVeh && !e.target.closest('button') && currentIncident){ const idx = incVeh.dataset.incidentVehicle ?? [...incVeh.parentElement.children].indexOf(incVeh); openIncidentVehicleInRegistry(idx); return; }
    const ownerBtn = e.target.closest('[data-open-owner-profile]'); if(ownerBtn && activeVehicleProfile){ openProfilePreviewByIdentifier(activeVehicleProfile.owner); return; }
    const vehiclePlaceholder = e.target.closest('[data-vehicle-placeholder]'); if(vehiclePlaceholder){ toast(vehiclePlaceholder.dataset.vehiclePlaceholder || 'Kommer snart.'); return; }
    const ret = e.target.closest('[data-return]'); if(ret) openReturnModal(ret.dataset.return);
  });
  document.addEventListener('contextmenu', e => {
    const res = e.target.closest('[data-preview-criminal]');
    if(res){ e.preventDefault(); openProfilePreviewByIdentifier(criminalSearchResults[Number(res.dataset.previewCriminal)]?.identifier); }
    const civ = e.target.closest('[data-preview-civilian]');
    if(civ){ e.preventDefault(); openProfilePreviewByIdentifier(civilianSearchResults[Number(civ.dataset.previewCivilian)]?.identifier); }
    const veh = e.target.closest('[data-preview-vehicle-owner]');
    if(veh){ e.preventDefault(); openProfilePreviewByIdentifier(vehicleSearchResults[Number(veh.dataset.previewVehicleOwner)]?.owner); }
  });

  // CoachN: højreklik gør ikke længere MDT usynlig.
  // Look-through styres af patchen nederst: KUN hold venstreklik udenfor tablet-rammen.
  document.addEventListener('contextmenu', e => {
    if(!e.target.closest('[data-preview-criminal],[data-preview-civilian],[data-preview-vehicle-owner]')) e.preventDefault();
  }, true);
  document.addEventListener('input', e => {
    const inp = e.target.closest('[data-reduction]');
    if(inp && currentIncident){ const [pi,key]=inp.dataset.reduction.split(':'); const p=currentIncident.criminals?.[Number(pi)]; if(p){ p.chargeReduction=p.chargeReduction||{jail:0,fine:0,points:0}; p.chargeReduction[key]=Number(inp.value||0); markDirty(); } }
  });
  document.addEventListener('keydown', e => { if(e.key === 'Escape'){ if(document.getElementById('sanDispatchDetailOverlay')?.classList.contains('open')) return closeSanDispatchDetails(); if(sanDispatchPanelOpen || document.getElementById('sanDispatchPanel')?.classList.contains('open')) return closeDispatchPanel(); if($('#app')?.classList.contains('hidden')){ sanCloseDispatchUi(true); return nui('closeDispatchList',{}).catch(()=>{}); } if(document.querySelector('.profile-preview-overlay')) return closeProfilePreview(); if(!$('#modal')?.classList.contains('hidden')) return closeModal(); setLookThrough(false); showApp(false); nui('close',{}); } if(e.key === 'Tab' && !document.getElementById('mdtLoginOverlay')){ e.preventDefault(); }});
  setInterval(() => { if($('#clock')) $('#clock').textContent = new Date().toLocaleString('da-DK'); }, 1000);
}



function sanDispatchIcon(name){
  const common='viewBox="0 0 24 24" aria-hidden="true" focusable="false"';
  const paths={
    horn:'<path d="M4 10.5v3h3.2l7.8 4.2V6.3L7.2 10.5H4zm13-3.4v9.8c1.7-.9 2.8-2.7 2.8-4.9S18.7 8 17 7.1z"/>',
    globe:'<path d="M12 2a10 10 0 100 20 10 10 0 000-20zm6.8 9h-3.1a15 15 0 00-1.2-5.1A8.1 8.1 0 0118.8 11zM12 4.1c.7 1 1.5 3.1 1.7 6.9h-3.4c.2-3.8 1-5.9 1.7-6.9zM4.2 13h3.1c.2 2 .6 3.7 1.2 5.1A8.1 8.1 0 014.2 13zm3.1-2H4.2a8.1 8.1 0 014.3-5.1A15 15 0 007.3 11zM12 19.9c-.7-1-1.5-3.1-1.7-6.9h3.4c-.2 3.8-1 5.9-1.7 6.9zm3.5-1.8c.6-1.4 1-3.1 1.2-5.1h3.1a8.1 8.1 0 01-4.3 5.1z"/>',
    hash:'<path d="M9 3h2l-.7 5h4.2l.7-5h2l-.7 5H20v2h-3.8l-.6 4H19v2h-3.7l-.7 5h-2l.7-5H9.1l-.7 5h-2l.7-5H4v-2h3.4l.6-4H5V8h3.3L9 3zm.4 11h4.2l.6-4H10l-.6 4z"/>',
    clock:'<path d="M12 2a10 10 0 1010 10A10 10 0 0012 2zm1 11h5v-2h-4V6h-2v7z"/>',
    user:'<path d="M12 12a4 4 0 10-4-4 4 4 0 004 4zm0 2c-4 0-7 2-7 4.4V21h14v-2.6C19 16 16 14 12 14z"/>',
    map:'<path d="M9 18l-6 3V6l6-3 6 3 6-3v15l-6 3-6-3zm1-12.5v10.7l4 2V7.5l-4-2z"/>',
    phone:'<path d="M6.6 10.8a15.8 15.8 0 006.6 6.6l2.2-2.2c.3-.3.8-.4 1.2-.3 1.3.4 2.6.6 4 .6.7 0 1.2.5 1.2 1.2v3.5c0 .7-.5 1.2-1.2 1.2A18.6 18.6 0 012 3.4C2 2.7 2.5 2.2 3.2 2.2h3.5c.7 0 1.2.5 1.2 1.2 0 1.4.2 2.7.6 4 .1.4 0 .9-.3 1.2l-1.6 2.2z"/>'
  };
  return `<svg class="san-svg-ico san-svg-${name}" ${common}>${paths[name]||paths.horn}</svg>`;
}

function sanDispatchKind(call){
  const type=String(call?.type||call?.title||'').toLowerCase();
  if(type.includes('weapon')||type.includes('våben')) return 'weapon';
  if(type.includes('shot')||type.includes('skud')||type.includes('skyderi')) return 'shooting';
  if(type.includes('assault')||type.includes('vold')||type.includes('overfald')) return 'shooting';
  if(type.includes('vehicle')||type.includes('bil')||type.includes('køretøj')||type.includes('lockpick')) return 'vehicle';
  return 'normal';
}
function sanDispatchPriority(call){
  const p=Number(call?.priority||0);
  if(p>0) return p;
  return sanDispatchKind(call)==='shooting' ? 1 : (sanDispatchKind(call)==='vehicle' ? 2 : 3);
}
function sanDispatchLabel(call){
  const kind=sanDispatchKind(call);
  if(String(call?.type||call?.title||'').toLowerCase().includes('weapon') || String(call?.title||'').toLowerCase().includes('våben')) return 'VÅBEN';
  if(String(call?.type||call?.title||'').toLowerCase().includes('assault') || String(call?.title||'').toLowerCase().includes('overfald')) return 'VOLD';
  if(kind==='shooting') return 'SKYDERI';
  if(kind==='vehicle') return 'BIL';
  return String(call?.label||call?.type||'ALARM').toUpperCase().slice(0,12);
}
function sanDispatchTitle(call){
  const kind=sanDispatchKind(call);
  if(String(call?.type||call?.title||'').toLowerCase().includes('weapon') || String(call?.title||'').toLowerCase().includes('våben')) return 'Mistænkelig person med våben';
  if(String(call?.type||call?.title||'').toLowerCase().includes('assault') || String(call?.title||'').toLowerCase().includes('overfald')) return 'Melding om voldeligt overfald';
  if(kind==='shooting') return 'Igangværende skyderi';
  if(kind==='vehicle'){
    const t=String(call?.title||call?.type||'').toLowerCase();
    if(t.includes('lockpick')||t.includes('mistænkelig')) return 'Mistænkelig aktivitet ved bil';
    return 'Igangværende biltyveri';
  }
  return call?.title||'Nyt opkald';
}
function sanDispatchAge(call){
  const t=Number(call?.lastUpdateAt||call?.createdAt||0);
  const now=Math.floor(Date.now()/1000);
  let sec=t>1000000000 ? Math.max(0, now-t) : 0;
  if(sec<60) return `${sec||1}s ago`;
  const min=Math.floor(sec/60);
  if(min<60) return `${min}m ago`;
  return `${Math.floor(min/60)}h ago`;
}
function sanDispatchMeta(call){
  return call?.street||call?.location||'Ukendt lokation';
}
function sanDispatchCardHtml(call, compact=false){
  return `<div class="san-dispatch-card-top"><div class="san-dispatch-title">${sanDispatchIcon('horn')}<b>${escapeHtml(sanDispatchTitle(call))}</b></div><span class="san-dispatch-badge">${escapeHtml(sanDispatchLabel(call))}</span></div><div class="san-dispatch-card-meta"><span class="loc">${sanDispatchIcon('globe')} ${escapeHtml(sanDispatchMeta(call))}</span><span class="prio">${sanDispatchIcon('hash')} Priority ${sanDispatchPriority(call)}</span><span class="age">${sanDispatchIcon('clock')} ${escapeHtml(sanDispatchAge(call))}</span></div>`;
}
function showDispatchToast(call){
  call = call || {};
  let host=document.getElementById('sanDispatchToastHost');
  if(!host){ host=document.createElement('div'); host.id='sanDispatchToastHost'; document.body.appendChild(host); }
  const el=document.createElement('div');
  const kind=sanDispatchKind(call);
  el.className='san-dispatch-toast '+kind;
  el.innerHTML=sanDispatchCardHtml(call);
  if(sanDispatchPanelOpen || document.getElementById('sanDispatchPanel')?.classList.contains('open')){ el.remove(); } else { host.prepend(el); while(host.children.length>7) host.lastElementChild?.remove(); }
  setTimeout(()=>{ el.classList.add('hide'); setTimeout(()=>el.remove(),350); },15000);
  renderDispatchPanel();
}
function renderDispatchPanel(){
  let panel=document.getElementById('sanDispatchPanel');
  if(!panel) return;
  const calls=[...(fleetDispatches||[])].sort((a,b)=>Number(b.lastUpdateAt||b.createdAt||0)-Number(a.lastUpdateAt||a.createdAt||0)).slice(0,30);
  panel.innerHTML=`<div class="san-dispatch-panel-head"><b>Dispatch-opkald</b><button id="sanDispatchClose">×</button></div><div class="san-dispatch-panel-list">${calls.length?calls.map(c=>`<div class="san-dispatch-panel-call ${sanDispatchKind(c)}" data-dispatch-id="${escapeHtml(c.id||'')}">${sanDispatchCardHtml(c,true)}<div class="san-dispatch-actions"><span class="san-dispatch-callers">${sanDispatchIcon('user')} ${Number(c.witnessCount||c.count||0)||0}</span><button data-dispatch-accept="${escapeHtml(c.id||'')}">Tag opkald</button><button data-dispatch-gps="${escapeHtml(c.id||'')}">Sæt GPS</button><button data-dispatch-details="${escapeHtml(c.id||'')}">Detaljer</button></div></div>`).join(''):'<div class="san-dispatch-empty">Ingen aktive opkald.</div>'}</div>`;
  document.getElementById('sanDispatchClose')?.addEventListener('click', closeDispatchPanel);
}


function sanDispatchPhotoSrc(v){
  v=String(v||'');
  if(!v) return '';
  if(v.startsWith('data:image/')) return v.replace(/"/g,'&quot;');
  if(v.length>1000) return ('data:image/jpeg;base64,'+v).replace(/"/g,'&quot;');
  return v.replace(/"/g,'&quot;');
}

function sanDispatchFind(id){ return (fleetDispatches||[]).find(d=>String(d.id)===String(id)); }
function sanDispatchLine(label, value){
  if(value===undefined || value===null || String(value)==='') return '';
  const text=String(value);
  if(text.indexOf('\n')>=0){
    return text.split(/\n+/).filter(Boolean).map((line,idx)=>`<li><span>${idx===0?escapeHtml(label):''}${idx===0?':':''}</span> ${escapeHtml(line)}</li>`).join('');
  }
  return `<li><span>${escapeHtml(label)}:</span> ${escapeHtml(text)}</li>`;
}
async function openSanDispatchDetails(id){
  let d=sanDispatchFind(id); if(!d) return toast('Opkaldet findes ikke længere.');
  try{
    const resp=await nui('getDispatchDetails',{id});
    if(resp && resp.ok && resp.dispatch) d=resp.dispatch;
  }catch(e){}
  const md=d.metadata||{}; const suspect=d.suspect||md.suspect||{}; const veh=d.vehicle||md.vehicle||{}; const wit=d.witnesses||md.witnesses||{};
  const photo=md.witnessPhoto||md.photo||suspect.photo||veh.photo||'';
  const statements=Array.isArray(md.witnessStatements)?md.witnessStatements:(md.witnessStatement?String(md.witnessStatement).split(/\n+/):[]);
  const witnessHtml=statements.length?statements.slice(0,5).map((s,i)=>`<li><span>Vidne ${i+1}:</span> ${escapeHtml(String(s).replace(/^Vidneudsagn:\s*/,''))}</li>`).join(''):'<li>Ingen detaljerede vidneudsagn modtaget.</li>';
  let overlay=document.getElementById('sanDispatchDetailOverlay');
  if(!overlay){ overlay=document.createElement('div'); overlay.id='sanDispatchDetailOverlay'; document.body.appendChild(overlay); }
  overlay.innerHTML=`<div class="san-dispatch-detail ${sanDispatchKind(d)}">
    <div class="san-dispatch-detail-head"><div>${sanDispatchCardHtml(d,true)}</div><button data-dispatch-detail-close>×</button></div>
    <div class="san-dispatch-detail-desc">${escapeHtml(d.description||'Flere borgere har anmeldt hændelsen i området.')}</div>
    <section><h3>FOTO FRA VIDNE</h3><div class="san-dispatch-mug ${photo?'has-photo':'no-photo'}">${photo?`<img src="${sanDispatchPhotoSrc(photo)}" alt="Vidnefoto">`:'<div class="san-no-photo-box"><b>Ingen foto</b><small>Vidne sendte ikke billede</small></div>'}</div></section>
    <section><h3>SIGNALMENT</h3><ul>${sanDispatchLine('Køn',suspect.sex)}${sanDispatchLine('Alder',suspect.age)}${sanDispatchLine('Højde',suspect.height)}${sanDispatchLine('Kropsbygning',suspect.build)}${sanDispatchLine('Påklædning',suspect.clothing)}${sanDispatchLine('Maske',suspect.mask)}${sanDispatchLine('Hovedbeklædning',suspect.headwear)}${sanDispatchLine('Briller',suspect.glasses)}${sanDispatchLine('Våben',suspect.weapon)}${sanDispatchLine('Andet',suspect.note)}</ul></section>
    <section><h3>KØRETØJ</h3><ul>${veh && Object.keys(veh).length ? `${sanDispatchLine('Type',veh.type)}${sanDispatchLine('Mærke',veh.make)}${sanDispatchLine('Model',veh.model)}${sanDispatchLine('Farve',veh.color)}${sanDispatchLine('Nummerplade',veh.plate)}` : '<li>Intet køretøj observeret.</li>'}</ul></section>
    <section><h3>VIDNER</h3><ul>${witnessHtml}${sanDispatchLine('Antal vidner',d.witnessCount||wit.total)}${sanDispatchLine('Tæt på',wit.near)}${sanDispatchLine('Fri sigtelinje',wit.clear)}</ul></section>
    <section><h3>KOORDINATER</h3><p>X: ${Number(d.x||0).toFixed(2)} &nbsp; Y: ${Number(d.y||0).toFixed(2)} &nbsp; Z: ${Number(d.z||0).toFixed(2)}</p></section>
    <div class="san-dispatch-detail-actions"><button data-dispatch-gps="${escapeHtml(d.id||'')}">${sanDispatchIcon('map')} MARKÉR PÅ KORT</button><button data-dispatch-accept="${escapeHtml(d.id||'')}">${sanDispatchIcon('phone')} TAG OPKALD</button></div>
  </div>`;
  overlay.classList.add('open');
}
function closeSanDispatchDetails(){ document.getElementById('sanDispatchDetailOverlay')?.classList.remove('open'); }

document.addEventListener('click', e=>{
  const close=e.target.closest('[data-dispatch-detail-close]'); if(close){ closeSanDispatchDetails(); return; }
  const det=e.target.closest('[data-dispatch-details]'); if(det){ e.preventDefault(); e.stopPropagation(); openSanDispatchDetails(det.dataset.dispatchDetails); return; }
  const gps=e.target.closest('[data-dispatch-gps]'); if(gps){ e.preventDefault(); e.stopPropagation(); const d=sanDispatchFind(gps.dataset.dispatchGps); if(d){ nui('setDispatchGps',{x:d.x,y:d.y}).then(r=>toast((r&&r.ok)?'GPS sat.':((r&&r.message)||'Kunne ikke sætte GPS.'))).catch(()=>toast('Kunne ikke sætte GPS.')); } return; }
}, true);

function openDispatchPanel(){
  let panel=document.getElementById('sanDispatchPanel');
  if(!panel){ panel=document.createElement('div'); panel.id='sanDispatchPanel'; document.body.appendChild(panel); }
  sanDispatchPanelOpen=true; document.body.classList.add('san-dispatch-panel-open'); document.getElementById('sanDispatchToastHost')?.remove(); panel.classList.add('open'); renderDispatchPanel();
}
function closeDispatchPanel(){
  sanDispatchPanelOpen=false;
  document.body.classList.remove('san-dispatch-panel-open');
  document.getElementById('sanDispatchPanel')?.classList.remove('open');
  nui('closeDispatchList',{}).catch(()=>{});
}
function toggleDispatchPanel(){ sanDispatchPanelOpen ? closeDispatchPanel() : openDispatchPanel(); }

window.addEventListener('message', e => {
  const msg = e.data || {};
  if(msg.action === 'lookMode'){
    setLookThrough(!!msg.active, false);
  }
  if(msg.action === 'permDebug'){ permissionDebug = msg.data || permissionDebug; mdtOwnPermissions = permissionDebug?.permissions || mdtOwnPermissions || []; refreshAdministrationAccess(); refreshNskAccess(); }
  if(msg.action === 'jobUpdated'){
    loadPermissionCatalog().then(() => {
      refreshAdministrationAccess();
      refreshNskAccess();
      if(activePage === 'self_profile') refreshSelfProfile();
      const gradeNum = msg.job?.grade ?? msg.job?.grade_number ?? '';
      if($('#officerGrade') && gradeNum !== ''){
        nui('getSelfProfile', {}).then((r) => {
          if(r?.ok && r.profile && $('#officerGrade')){
            $('#officerGrade').textContent = r.profile.badge || formatPoliceBadge(r.profile.pnumber || gradeNum, r.profile.division) || $('#officerGrade').textContent;
          }
        }).catch(() => {});
      }
    });
  }
  if(msg.action === 'forceClose'){
    mdtHardCloseVisual();
  }
  if(msg.action === 'open'){
    showApp(true);
    if(!mdtLoggedIn) mdtSetAuthLocked(true);
    if(msg.licenseRevocationCooldownHours != null) licenseRevocationCooldownHours = Number(msg.licenseRevocationCooldownHours) || 48;
    $('#officerName').textContent = msg.name || msg.playerName || $('#officerName').textContent || 'Betjent';
    const gradeNum = msg.job?.grade ?? msg.job?.grade_number ?? '';
    if($('#officerGrade')) $('#officerGrade').textContent = fleetFormatPNumber(gradeNum !== '' ? gradeNum : ($('#officerGrade')?.textContent || ''), 'Patrulje') || 'B0000';
    mdtEnsureLogin().then(ok=>{
      if(!ok) return;
      syncReportAnpgFlags();
      nui('getSelfProfile',{}).then(r=>{ if(r&&r.ok&&r.profile){ $('#officerName').textContent = r.profile.name || $('#officerName').textContent; if($('#officerGrade')) $('#officerGrade').textContent = r.profile.badge || formatPoliceBadge(r.profile.pnumber || gradeNum, r.profile.division) || $('#officerGrade').textContent; }}).catch(()=>{});
      loadPermissionCatalog();
      setPage(activePage || 'dashboard');
      refreshWiretapSession();
      if(!mdtCharges.length){
        nui('getCharges',{ search:'' }).then(r=>{ if(r&&r.ok) mdtCharges=r.charges||[]; }).catch(()=>{});
      }
    });
  }
  if(msg.action === 'dispatchListToggle'){
    toggleDispatchPanel();
  }
  if(msg.action === 'dispatchNotify'){
    showDispatchToast(msg.data || {});
    const d=(msg.data||{});
    if(d.id){
      const idx=(fleetDispatches||[]).findIndex(x=>String(x.id)===String(d.id));
      if(idx>=0) fleetDispatches[idx]=Object.assign({}, fleetDispatches[idx], d);
      else fleetDispatches.unshift(d);
    }
    if(activePage==='fleet') renderFleet();
    if(sanDispatchPanelOpen) renderDispatchPanel();
  }
  if(msg.action === 'dashboard'){
    const data = msg.data || {};
    window.__dashboardDataAt = Date.now();
    $('#officerName').textContent = data.name || $('#officerName').textContent;
    permissionDebug = data.permissions?.debug || permissionDebug; mdtOwnPermissions = permissionDebug?.permissions || mdtOwnPermissions || [];
    if(typeof data.permissions?.deleteIncident === 'boolean') mdtCanDeleteIncident = data.permissions.deleteIncident;
    refreshAdministrationAccess(); refreshNskAccess(); renderDashboard(data);
  }
  if(msg.action === 'incidents'){
    incidents = (msg.data?.incidents || []).map(normalizeIncident);
    renderIncidentList();
  }
});



/* CoachN report-as-page repair 27/05
   Rapporter er nu deres egen workspace-side/tab ligesom hændelser.
   Opret/rediger rapport åbner ikke længere modal og opretter ikke hændelse. */
let currentReport = null;
let currentReportTabKey = null;
const tabReports = {};
function reportTabKey(r){ return 'report:' + (r && r.id ? r.id : ('draft-' + (r && r.__draftKey ? r.__draftKey : Date.now()))); }
const __oldTabLabel = tabLabel;
tabLabel = function(key){
  if(String(key).startsWith('report:')){
    const r = tabReports[key] || currentReport || {};
    return escapeHtml(r.title || reportMeta(r).title || 'Ny rapport');
  }
  return __oldTabLabel(key);
};
renderTabs = function(active){
  const tabs = $('#tabs');
  if(!tabs) return;
  const add = $('#topPlus');
  [...tabs.querySelectorAll('.tab:not(.add)')].forEach(t => t.remove());
  [...openTabs].forEach(key => {
    const b = document.createElement('button');
    b.className = 'tab' + (key === active ? ' active' : '');
    b.dataset.tab = key;
    b.innerHTML = `${tabLabel(key)} <span>×</span>`;
    b.onclick = (e) => {
      if(e.target && e.target.tagName === 'SPAN'){
        e.stopPropagation();
        if(openTabs.size > 1){
          openTabs.delete(key); delete tabIncidents[key]; delete tabReports[key];
          const next = [...openTabs].pop() || 'dashboard';
          if(String(next).startsWith('incident:')) openIncident(tabIncidents[next], next);
          else if(String(next).startsWith('report:')) openReportPage(tabReports[next], next);
          else setPage(next);
        }
        return;
      }
      if(String(key).startsWith('incident:')) openIncident(tabIncidents[key], key);
      else if(String(key).startsWith('report:')) openReportPage(tabReports[key], key);
      else setPage(key);
    };
    tabs.insertBefore(b, add || null);
  });
};
function reportEditorHtml(r){
  r = normalizeReport(r);
  const m = reportMeta(r);
  const opts = Object.entries(reportTypeTemplates).filter(([k])=>k!=='incident').map(([k,mt])=>`<option value="${escapeHtml(k)}" ${r.type===k?'selected':''}>${escapeHtml(mt.label)}</option>`).join('');
  return `<div class="report-page-editor" style="--report-color:${escapeHtml(m.color||'#2f8cff')}">
    <div class="incident-head report-workspace-head">
      <div><b>Rapport</b> <span id="reportPageBadge" class="report-badge" style="--report-color:${escapeHtml(m.color)}">${escapeHtml(m.badge)}</span> <span class="pill">${escapeHtml(r.report_no || 'KLADDE')}</span> <span id="reportPageCreated">${r.draft?'Ny rapport - ikke gemt endnu':'Oprettet af '+escapeHtml(r.created_by||'Ukendt')+' - '+escapeHtml(fmtDate(r.created_at))}</span> <span id="reportSaveState">${r.draft?'Kladde - ikke gemt endnu':'Ingen ændringer at gemme'}</span></div>
      <div class="head-actions"><button id="backToReportsList" class="ghost">← Tilbage</button><button id="saveReportPage" class="save">Gem Rapport</button><button id="deleteReportPage" class="danger">🗑</button></div>
    </div>
    <div class="report-workspace-layout">
      <div class="editor-panel report-workspace-main">
        <div class="title-row report-title-row"><input id="reportPageTitle" placeholder="Titel fx heist ved bank, skyderi, efterlysning" value="${escapeHtml(r.title||'')}"><select id="reportPageType" class="inline-report-type">${opts}</select><button class="mini">✎</button></div>
        <div id="reportPageBody" contenteditable="true" spellcheck="false" class="incident-style-editor" data-placeholder="Beskrivelse af rapporten...">${r.body || m.body}</div>
        <div class="editor-foot"><span>P</span><span id="reportPageWords">WORDS: 0</span><span id="reportPageChars">CHARACTERS: 0</span></div>
      </div>
      <aside class="right-panel report-workspace-side report-clean-side report-only-clean">
        <div class="sidebox" data-report-list="tags"><h3>TAGS <button type="button" data-report-add="tags">+</button></h3><div class="items tag-items" id="reportTagsItems"></div></div>
        <div class="sidebox" data-report-list="evidence"><h3>BEVISER <button type="button" data-report-add="evidence">+</button></h3><div class="items" id="reportEvidenceItems"></div></div>
        <div class="sidebox" data-report-list="officers"><h3>BETJENTE INVOLVERET <button type="button" data-report-add="officers">+</button></h3><div class="items" id="reportOfficersItems"></div></div>
        <div class="sidebox" data-report-list="civilians"><h3>BORGERE INVOLVERET <button type="button" data-report-add="civilians">+</button></h3><div class="items" id="reportCiviliansItems"></div></div>
        <div class="sidebox" data-report-list="vehicles"><h3>KØRETØJER <button type="button" data-report-add="vehicles">+</button></h3><div class="items" id="reportVehiclesItems"></div></div>
        <div class="sidebox" data-report-list="references"><h3>REFERENCER <button type="button" data-report-add="references">+</button></h3><div class="items" id="reportReferencesItems"></div></div>
      </aside>
    </div>
  </div>`;
}

function firstReportSuspectName(){ const a=(currentReport&&currentReport.suspects)||[]; return a[0]?.name || currentReport?.linked_person || ''; }
function firstReportVehiclePlate(){ const a=(currentReport&&currentReport.vehicles)||[]; return a[0]?.plate || currentReport?.linked_vehicle || ''; }
function ensureReportArrays(){
  currentReport = currentReport || {};
  currentReport.suspects = currentReport.suspects || (currentReport.linked_person ? [{name:currentReport.linked_person, dob:'', wanted:!!currentReport.wanted_person}] : []);
  currentReport.vehicles = currentReport.vehicles || (currentReport.linked_vehicle ? [{plate:currentReport.linked_vehicle, model:'', owner:'', wanted:!!currentReport.wanted_vehicle}] : []);
  currentReport.officers = currentReport.officers || [];
  currentReport.civilians = currentReport.civilians || [];
  currentReport.tags = currentReport.tags || [];
  currentReport.evidence = currentReport.evidence || [];
  currentReport.references = currentReport.references || [];
}
function reportWantedSwitch(kind, idx, wanted, label){
  return `<button type="button" class="report-status-toggle ${wanted?'is-on':''}" data-report-wanted="${kind}:${idx}" title="${escapeHtml(label)}">
    <span>${escapeHtml(label)}</span><i></i>
  </button>`;
}
function reportMiniCard(obj, kind, idx){
  if(kind==='suspects'){
    const wanted = !!obj.wanted;
    return `<div class="report-involved-card report-person-card ${wanted?'wanted-card':''}">
      <div class="report-involved-head" data-report-suspect-open="${idx}">
        <div><b>${escapeHtml(obj.name||'Ukendt person')}</b><small>${escapeHtml(obj.dob||'Ingen fødselsdato')} · Mistænkt ${wanted?'· EFTERLYST':''}</small></div>
        <div class="item-actions">${obj.identifier?`<button class="iconbtn" data-report-suspect-profile="${idx}" title="Åbn profil">▣</button>`:''}<button class="iconbtn red" data-report-remove="suspects:${idx}">🗑</button></div>
      </div>
      <div class="report-status-list">${reportWantedSwitch('suspects',idx,wanted,'Efterlyst')}</div>
    </div>`;
  }
  if(kind==='vehicles'){
    const wanted = !!obj.wanted;
    return `<div class="report-involved-card report-vehicle-card ${wanted?'wanted-card':''}">
      <div class="report-involved-head" data-report-vehicle-open="${idx}" title="Venstreklik: åbn køretøj">
        <div><b>${escapeHtml(obj.plate||'Ukendt køretøj')}</b><small><strong>${escapeHtml(obj.model||'Ukendt model')}</strong> · Ejer: ${escapeHtml(obj.ownerName||obj.owner||'Ukendt')} ${wanted?'· EFTERLYST':''}</small></div>
        <div class="item-actions">${obj.owner?`<button class="iconbtn" data-report-vehicle-owner="${idx}" title="Åbn ejerprofil">▣</button>`:''}<button class="iconbtn red" data-report-remove="vehicles:${idx}">🗑</button></div>
      </div>
      <div class="report-status-list">${reportWantedSwitch('vehicles',idx,wanted,'Efterlyst')}</div>
    </div>`;
  }
  if(kind==='civilians'){
    const wanted = !!obj.wanted;
    return `<div class="report-involved-card report-person-card ${wanted?'wanted-card':''}">
      <div class="report-involved-head">
        <div><b>${escapeHtml(obj.name||'Ukendt borger')}</b><small>${escapeHtml(obj.dob||'Ingen fødselsdato')} · Borger involveret ${wanted?'· EFTERLYST':''}</small></div>
        <div class="item-actions">${obj.identifier?`<button class="iconbtn" data-report-suspect-profile="${idx}" title="Åbn profil">▣</button>`:''}<button class="iconbtn red" data-report-remove="civilians:${idx}">🗑</button></div>
      </div>
      <div class="report-status-list">${reportWantedSwitch('civilians',idx,wanted,'Efterlyst')}</div>
    </div>`;
  }
  if(kind==='officers'){
    return `<div class="item officer-pill report-officer-pill"><div><b>${escapeHtml(obj.name||'Ukendt betjent')}</b><small>${escapeHtml(obj.rank||obj.role||obj.note||'Politi')}</small></div><div class="item-actions">${obj.identifier?`<button class="iconbtn" data-report-officer-profile="${idx}" title="Åbn profil">▣</button>`:''}<button class="iconbtn red" data-report-remove="officers:${idx}">🗑</button></div></div>`;
  }
  if(kind==='tags') return `<span class="tag-badge-modern" style="${tagBadgeStyle(obj)}">${escapeHtml(obj.name||obj)}</span>`;
  return `<div class="person-mini-card report-mini-card"><div><b>${escapeHtml(obj.name||obj.plate||obj.title||'Element')}</b><small>${escapeHtml(obj.note||obj.info||'')}</small></div><button class="danger small" data-report-remove="${kind}:${idx}">🗑</button></div>`;
}
function renderReportSideLists(){
  if(!currentReport) return; ensureReportArrays();
  const map={vehicles:'#reportVehiclesItems',officers:'#reportOfficersItems',civilians:'#reportCiviliansItems',tags:'#reportTagsItems',evidence:'#reportEvidenceItems',references:'#reportReferencesItems'};
  Object.entries(map).forEach(([k,sel])=>{
    const el=$(sel); if(!el) return;
    const arr=currentReport[k]||[];
    el.innerHTML = arr.length ? arr.map((x,i)=>reportMiniCard(x,k,i)).join('') : (k==='vehicles'?'Ingen køretøjer':k==='officers'?'Ingen betjente':k==='civilians'?'Ingen borgere':k==='tags'?'Ingen tags':k==='references'?'Ingen referencer':k==='evidence'?'Ingen beviser':'Ingen elementer');
  });
}
function addSuspectToReport(profile){
  if(!currentReport) return; ensureReportArrays();
  const obj = { name:profile.name||'Ukendt borger', dob:profile.dob||'', phone:profile.phone||'', identifier:profile.identifier||'', wanted:false };
  if(obj.identifier && currentReport.suspects.some(c=>c.identifier===obj.identifier)){ toast('Mistænkte er allerede tilføjet.'); return; }
  currentReport.suspects.push(obj); renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); toast(obj.name+' tilføjet som mistænkt.'); closeModal();
}
function addVehicleToReport(vehicle){
  if(!currentReport) return; ensureReportArrays();
  const obj = { plate:vehicle.plate||'', model:vehicle.model||vehicle.vehicleName||'', owner:vehicle.owner||'', ownerName:vehicle.ownerName||'', status:vehicle.status||'', type:vehicle.type||vehicle.vehicleType||'', wanted:false };
  if(!obj.plate){ toast('Køretøj mangler nummerplade.'); return; }
  if(currentReport.vehicles.some(v=>String(v.plate||'').toUpperCase()===String(obj.plate).toUpperCase())){ toast('Køretøjet er allerede tilføjet.'); return; }
  currentReport.vehicles.push(obj); renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); toast(obj.plate+' tilføjet til rapporten.'); closeModal();
}
function addCivilianToReport(profile){
  if(!currentReport) return; ensureReportArrays();
  const obj = { name:profile.name||'Ukendt borger', dob:profile.dob||'', phone:profile.phone||'', identifier:profile.identifier||'', wanted:false };
  if(obj.identifier && currentReport.civilians.some(c=>c.identifier===obj.identifier)){ toast('Borgeren er allerede tilføjet.'); return; }
  currentReport.civilians.push(obj); renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); toast(obj.name+' tilføjet til rapporten.'); closeModal();
}
function addOfficerToReport(emp){
  if(!currentReport) return; ensureReportArrays();
  const obj = { name:emp.name||emp.fullname||'Ukendt betjent', identifier:emp.identifier||'', rank:emp.role||emp.rank||emp.division||'Politi' };
  if(obj.identifier && currentReport.officers.some(o=>o.identifier===obj.identifier)){ toast('Betjenten er allerede tilføjet.'); return; }
  currentReport.officers.push(obj); renderReportSideLists(); if(currentReportTabKey) tabReports[currentReportTabKey]=collectReportPage(); toast(obj.name+' tilføjet som betjent.'); closeModal();
}
async function searchReportSuspects(){
  const q = $('#reportSuspectSearchInput')?.value || '';
  const r = await nui('getProfiles', { search:q });
  criminalSearchResults = (r && r.profiles) || [];
  const box=$('#reportSuspectSearchResults'); if(!box) return;
  box.innerHTML = criminalSearchResults.length ? criminalSearchResults.map((p,idx)=>`<div class="criminal-result-card" data-add-report-suspect="${idx}"><div class="result-avatar">☷</div><div class="result-main"><b>${escapeHtml(p.name||'Ukendt borger')}</b><small><span class="idpill">ID: ${escapeHtml(p.identifier||'Ukendt')}</span> Telefon: ${escapeHtml(p.phone||'Ingen data')} · Født: ${escapeHtml(p.dob||'Ukendt')}</small></div><div class="result-action">Tilføj mistænkt</div></div>`).join('') : '<div class="profile-search-empty">Ingen personer fundet.</div>';
}
async function searchReportVehicles(){
  const q = $('#reportVehicleSearchInput')?.value || '';
  const r = await nui('getVehicles', { search:q });
  vehicleSearchResults = (r && r.vehicles) || [];
  const box=$('#reportVehicleSearchResults'); if(!box) return;
  box.innerHTML = vehicleSearchResults.length ? vehicleSearchResults.map((v,idx)=>`<div class="vehicle-result-card" data-add-report-vehicle="${idx}"><div class="vehicle-thumb">${v.image?`<img src="${escapeHtml(v.image)}">`:'🚘'}</div><div class="result-main"><b>${escapeHtml(v.plate||'Ukendt nummerplade')}</b><small><span class="vehicle-model">${escapeHtml(v.model||'Ukendt model')}</span> · Type: ${escapeHtml(v.type||'Ukendt type')} · Ejer: ${escapeHtml(v.ownerName||v.owner||'Ukendt')}</small></div><div class="result-action">Tilføj køretøj</div></div>`).join('') : '<div class="profile-search-empty">Ingen køretøjer fundet.</div>';
}
async function searchReportCivilians(){
  const q = $('#reportCivilianSearchInput')?.value || '';
  const r = await nui('getProfiles', { search:q });
  civilianSearchResults = (r && r.profiles) || [];
  const box=$('#reportCivilianSearchResults'); if(!box) return;
  box.innerHTML = civilianSearchResults.length ? civilianSearchResults.map((p,idx)=>`<div class="criminal-result-card" data-add-report-civilian="${idx}"><div class="result-avatar">☷</div><div class="result-main"><b>${escapeHtml(p.name||'Ukendt borger')}</b><small><span class="idpill">ID: ${escapeHtml(p.identifier||'Ukendt')}</span> Telefon: ${escapeHtml(p.phone||'Ingen data')} · Født: ${escapeHtml(p.dob||'Ukendt')}</small></div><div class="result-action">Tilføj person</div></div>`).join('') : '<div class="profile-search-empty">Ingen personer fundet.</div>';
}
async function searchReportOfficers(){
  const q = ($('#reportOfficerSearchInput')?.value || '').toLowerCase();
  if(!employees.length){ const r = await nui('getEmployees', { search:q }); employees = (r && r.employees) || employees || []; }
  reportOfficerSearchResults = (employees||[]).filter(e=>[e.name,e.identifier,e.role,e.rank,e.division,e.pnumber,e.badge,officerBadge(e)].join(' ').toLowerCase().includes(q)).slice(0,40);
  const box=$('#reportOfficerSearchResults'); if(!box) return;
  box.innerHTML = reportOfficerSearchResults.length ? reportOfficerSearchResults.map((e,idx)=>`<div class="criminal-result-card" data-add-report-officer="${idx}"><div class="result-avatar">★</div><div class="result-main"><b>${escapeHtml(e.name||'Ukendt betjent')}</b><small>${escapeHtml(e.role||e.rank||'Politi')} · ${escapeHtml(e.division||'')} · ${escapeHtml(officerBadge(e)||e.identifier||'')}</small></div><div class="result-action">Tilføj betjent</div></div>`).join('') : '<div class="profile-search-empty">Ingen betjente fundet.</div>';
}
function openReportAddModal(kind){
  if(!currentReport) return; ensureReportArrays();
  const titles={suspects:'Tilføj mistænkt',vehicles:'Tilføj køretøj',officers:'Tilføj betjent',civilians:'Tilføj person/borger',evidence:'Tilføj bevis',tags:'Vælg tag',references:'Tilføj reference'};
  $('#modalTitle').textContent=titles[kind]||'Tilføj';
  if(kind==='suspects'){
    $('#modalFields').innerHTML=`<div class="criminal-search-ui"><input id="reportSuspectSearchInput" placeholder="Søg navn, telefon, fødselsdato eller identifier..." autofocus><div class="search-help">Venstreklik: tilføj mistænkt til rapporten. Efterlysning vælges bagefter på kortet.</div><div id="reportSuspectSearchResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div></div>`;
    $('#modalSave').style.display='none'; $('#modalCancel').style.display=''; $('#modal').classList.remove('hidden'); setTimeout(()=>$('#reportSuspectSearchInput')?.focus(),50); $('#reportSuspectSearchInput').addEventListener('input',()=>{clearTimeout(criminalSearchTimer); criminalSearchTimer=setTimeout(searchReportSuspects,120);}); return;
  }
  if(kind==='vehicles'){
    $('#modalFields').innerHTML=`<div class="criminal-search-ui"><input id="reportVehicleSearchInput" placeholder="Søg nummerplade, registreringsnummer, model eller ejer..." autofocus><div class="search-help">Venstreklik: tilføj køretøj til rapporten. Efterlysning vælges bagefter på kortet.</div><div id="reportVehicleSearchResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div></div>`;
    $('#modalSave').style.display='none'; $('#modalCancel').style.display=''; $('#modal').classList.remove('hidden'); setTimeout(()=>$('#reportVehicleSearchInput')?.focus(),50); $('#reportVehicleSearchInput').addEventListener('input',()=>{clearTimeout(vehicleSearchTimer); vehicleSearchTimer=setTimeout(searchReportVehicles,120);}); return;
  }
  if(kind==='civilians'){
    $('#modalFields').innerHTML=`<div class="criminal-search-ui"><input id="reportCivilianSearchInput" placeholder="Søg navn, telefon, fødselsdato eller identifier..." autofocus><div class="search-help">Venstreklik: tilføj person. Efterlysning kan vælges bagefter på kortet.</div><div id="reportCivilianSearchResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div></div>`;
    $('#modalSave').style.display='none'; $('#modalCancel').style.display=''; $('#modal').classList.remove('hidden'); setTimeout(()=>$('#reportCivilianSearchInput')?.focus(),50); $('#reportCivilianSearchInput').addEventListener('input',()=>{clearTimeout(civilianSearchTimer); civilianSearchTimer=setTimeout(searchReportCivilians,120);}); return;
  }
  if(kind==='officers'){
    $('#modalFields').innerHTML=`<div class="criminal-search-ui"><input id="reportOfficerSearchInput" placeholder="Søg betjent, rang, tjenestenummer eller afdeling..." autofocus><div class="search-help">Kun betjente/ansatte kan vælges her.</div><div id="reportOfficerSearchResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div></div>`;
    $('#modalSave').style.display='none'; $('#modalCancel').style.display=''; $('#modal').classList.remove('hidden'); setTimeout(()=>$('#reportOfficerSearchInput')?.focus(),50); $('#reportOfficerSearchInput').addEventListener('input',()=>{clearTimeout(civilianSearchTimer); civilianSearchTimer=setTimeout(searchReportOfficers,120);}); searchReportOfficers(); return;
  }
  if(kind==='tags'){
    const selected=new Set((currentReport.tags||[]).map(t=>t.name||t));
    $('#modalFields').innerHTML=(mdtTags||[]).length?`<div class="tag-picker-grid scums-tag-grid">${mdtTags.map((t,i)=>`<button class="tag-pick-card scum-tag-card ${selected.has(t.name)?'picked':''}" data-report-pick-tag="${i}" style="${tagBadgeStyle(t)}"><div class="scum-tag-title">${escapeHtml(t.name)}</div><div class="scum-tag-row"><span>Tag</span><span>${escapeHtml(t.info||'Ingen information')}</span><span>${selected.has(t.name)?'Valgt':'Vælg'}</span></div></button>`).join('')}</div>`:'<div class="admin-empty">Ingen tags oprettet.</div>';
    $('#modalSave').textContent='Luk'; $('#modalSave').onclick=closeModal; $('#modalCancel').style.display='none'; $('#modal').classList.remove('hidden'); return;
  }
  $('#modalFields').innerHTML='<input id="reportAddName" placeholder="Navn"><input id="reportAddNote" placeholder="Note / ekstra info">';
  $('#modalCancel').style.display=''; $('#modalSave').style.display=''; $('#modalSave').textContent='Tilføj'; $('#modal').classList.remove('hidden');
  $('#modalSave').onclick=()=>{ const name=($('#reportAddName')?.value||'').trim(); if(!name){toast('Skriv en værdi.');return;} const note=$('#reportAddNote')?.value||''; currentReport[kind]=currentReport[kind]||[]; currentReport[kind].push({name,note}); renderReportSideLists(); if(currentReportTabKey){tabReports[currentReportTabKey]=collectReportPage();} closeModal(); };
}

function bindReportPageEditor(){
  const typeSel = $('#reportPageType'), title = $('#reportPageTitle'), body = $('#reportPageBody');
  if(!typeSel || !title || !body) return;
  const mark = ()=>{ if($('#reportSaveState')) $('#reportSaveState').textContent='Ikke gemte ændringer'; if(currentReportTabKey){ currentReport = collectReportPage(); tabReports[currentReportTabKey]=currentReport; renderTabs(currentReportTabKey); } };
  const stats = ()=>{ const t=textOnly(body.innerHTML); $('#reportPageWords') && ($('#reportPageWords').textContent='WORDS: '+(t.trim()?t.trim().split(/\s+/).length:0)); $('#reportPageChars') && ($('#reportPageChars').textContent='CHARACTERS: '+t.length); };
  const syncType = ()=>{
    const mt = reportTypeTemplates[typeSel.value] || reportTypeTemplates.report;
    $('.report-page-editor')?.style.setProperty('--report-color', mt.color);
    const b = $('#reportPageBadge'); if(b){ b.textContent=mt.badge; b.style.setProperty('--report-color', mt.color); }
    $('#reportPageTypePreview') && ($('#reportPageTypePreview').innerHTML=`<span class="report-badge" style="--report-color:${escapeHtml(mt.color)}">${escapeHtml(mt.badge)}</span><small>${escapeHtml(mt.label)}</small>`);
    if(!title.value || title.value.startsWith('Ny ')) title.value = mt.title;
    if(!textOnly(body.innerHTML).trim() || /^(RAPPORT|HEIST|SKYDERI|EFTERLYSNING|TYVERI|ANMELDELSE|FÆRDSEL|VÅBEN|NARKO|BANDE)/i.test(textOnly(body.innerHTML).trim().slice(0,35))) body.innerHTML = mt.body;
    mark(); stats();
  };
  typeSel.onchange = syncType;
  title.oninput = mark;
  body.oninput = ()=>{ stats(); mark(); };
  $('#backToReportsList') && ($('#backToReportsList').onclick = () => { currentReport=null; currentReportTabKey=null; setPage('reports'); });
  $('#saveReportPage') && ($('#saveReportPage').onclick = saveReportPage);
  $('#deleteReportPage') && ($('#deleteReportPage').onclick = () => { if(currentReport && currentReport.id){ let scoped=getScopedReports().filter(x=>String(x.id)!==String(currentReport.id)); setScopedReports(scoped); reportStorageSave(); syncReportAnpgFlags(); } if(currentReportTabKey){ openTabs.delete(currentReportTabKey); delete tabReports[currentReportTabKey]; } currentReport=null; currentReportTabKey=null; setPage('reports'); toast('Rapport slettet.'); });
  stats();
}
function collectReportPage(){
  const mt = reportTypeTemplates[$('#reportPageType')?.value || currentReport?.type || 'report'] || reportTypeTemplates.report;
  return normalizeReport(Object.assign({}, currentReport || {}, {
    type: $('#reportPageType')?.value || 'report',
    title: $('#reportPageTitle')?.value || mt.title,
    body: $('#reportPageBody')?.innerHTML || mt.body,
    linked_person: firstReportSuspectName(),
    linked_vehicle: firstReportVehiclePlate(),
    wanted_person: !!([...(currentReport?.suspects||[]), ...(currentReport?.civilians||[])].some(x=>x.wanted)),
    wanted_vehicle: !!(currentReport?.vehicles||[]).some(x=>x.wanted),
    linked_incident_no: '',
    suspects: currentReport?.suspects || [],
    vehicles: currentReport?.vehicles || [],
    officers: currentReport?.officers || [],
    civilians: currentReport?.civilians || [],
    tags: currentReport?.tags || [],
    evidence: currentReport?.evidence || [],
    references: currentReport?.references || [],
    updated_at: new Date().toISOString()
  }));
}
function newReportPage(){
  const officer = $('#officerName')?.textContent || 'Betjent';
  const r = normalizeReport({ id:null, draft:true, __draftKey:Date.now(), type:'report', title:reportTypeTemplates.report.title, body:reportTypeTemplates.report.body, report_no:reportNo(), created_by:officer, created_at:new Date().toISOString() });
  openReportPage(r, reportTabKey(r));
}
function openReportPage(r, key=null){
  currentReport = normalizeReport(r || {type:'report'});
  currentReportTabKey = key || reportTabKey(currentReport);
  tabReports[currentReportTabKey] = currentReport;
  openTabs.add(currentReportTabKey); activeTabKey=currentReportTabKey; activePage='reports';
  $$('.page').forEach(p=>p.classList.toggle('active', p.id==='reports'));
  $$('.nav').forEach(n=>n.classList.toggle('active', n.dataset.page==='reports'));
  const sec=$('#reports'); if(sec){ sec.innerHTML=reportEditorHtml(currentReport); }
  renderTabs(currentReportTabKey);
  bindReportPageEditor();
  renderReportSideLists();
}
function saveReportPage(){
  let r = collectReportPage();
  const wasDraft = !r.id || r.draft;
  if(wasDraft){ r.id = Date.now(); r.report_no = r.report_no || reportNo(); r.created_at = r.created_at || new Date().toISOString(); }
  r.draft = false;
  let scoped = getScopedReports() || [];
  const exists = scoped.some(x=>String(x.id)===String(r.id));
  scoped = exists ? scoped.map(x=>String(x.id)===String(r.id)?r:x) : [r, ...scoped];
  setScopedReports(scoped);
  reportStorageSave();
  syncReportAnpgFlags();
  if(currentReportTabKey){ openTabs.delete(currentReportTabKey); delete tabReports[currentReportTabKey]; }
  currentReport = r;
  currentReportTabKey = reportTabKey(r);
  tabReports[currentReportTabKey]=r; openTabs.add(currentReportTabKey);
  openReportPage(r, currentReportTabKey);
  toast('Rapport gemt.');
}
renderReportsPage = function(){
  renderReportTypeOptions();
  const sec=$('#reports'); if(!sec) return;
  sec.innerHTML = `<div class="reports-shell"><div class="reports-header"><div><h2>Rapporter</h2><p>Opret rapporter med samme professionelle layout som hændelser.</p></div><div class="reports-actions"><input id="reportSearch" placeholder="Søg rapport, type, ID, titel..."><select id="reportTypeFilter"><option value="">Alle typer</option></select><button id="newReportBtn" class="save">+ Opret rapport</button></div></div><div id="reportsList" class="reports-list"></div></div>`;
  const sel=$('#reportTypeFilter'); Object.entries(reportTypeTemplates).filter(([k])=>k!=='incident').forEach(([k,m])=>{ const o=document.createElement('option'); o.value=k; o.textContent=m.label; sel.appendChild(o); });
  const draw=()=>{
    const box=$('#reportsList'); if(!box) return;
    const q=($('#reportSearch')?.value||'').toLowerCase().trim(); const f=$('#reportTypeFilter')?.value||'';
    const list=(mdtReports||[]).map(normalizeReport).filter(r=>{ const m=reportMeta(r); const hay=[r.title,r.report_no,m.label,m.badge,r.created_by,r.linked_vehicle,r.linked_person,textOnly(r.body)].join(' ').toLowerCase(); return (!q||hay.includes(q)) && (!f||r.type===f); });
    box.innerHTML = list.length ? list.map(r=>{ const m=reportMeta(r); const txt=textOnly(r.body); const forlob=(txt.match(/Forløb:\s*([^]*?)(Udbytte|Videre|Konklusion|Beviser|$)/i)||[])[1] || txt.slice(0,170) || 'Ingen forløb endnu'; return `<div class="report-card" style="--report-color:${escapeHtml(m.color||'#00e6b7')}" data-open-report="${escapeHtml(r.id)}"><div class="report-card-main"><div class="report-title"><b>${escapeHtml(r.title||m.title)}</b>${reportBadge(r)}</div><div class="report-meta"><span>ID: ${escapeHtml(r.report_no)}</span><span>Oprettet af: ${escapeHtml(r.created_by||'Ukendt')}</span><span>${escapeHtml(fmtDate(r.created_at)||'Ingen dato')}</span></div><div class="report-preview"><b>Forløb:</b> ${escapeHtml(forlob.trim())}</div></div><div class="report-card-actions"><button data-delete-report="${escapeHtml(r.id)}" class="red">Slet</button></div></div>` }).join('') : `<div class="report-empty"><b>Ingen rapporter endnu</b><span>Tryk “+ Opret rapport” for at lave efterlysning, skyderi, heist, tyveri eller almindelig rapport.</span></div>`;
  };
  $('#newReportBtn').onclick = newReportPage;
  $('#reportSearch').addEventListener('input', draw); $('#reportTypeFilter').addEventListener('change', draw);
  draw();
};
openReportModal = function(existingId=null){ const r = existingId ? findCombinedReport(existingId) : null; if(r) openReportPage(r); else newReportPage(); };
openReferencePickerModal = function(){
  if(!currentIncident){ toast('Opret eller vælg en hændelse først.'); return; }
  $('#modalTitle').textContent = 'Tilføj rapport til hændelse';
  const drawCards = (q='') => (mdtReports||[]).map(normalizeReport).filter(r=>[r.title,r.report_no,reportMeta(r).label,textOnly(r.body)].join(' ').toLowerCase().includes(q.toLowerCase())).slice(0,40).map(r=>{ const m=reportMeta(r); return `<button class="reference-report-card report-ref-card" data-link-report="${escapeHtml(r.id)}" style="--report-color:${escapeHtml(m.color)}"><div><b>${escapeHtml(r.title||m.title)}</b><span class="report-badge" style="--report-color:${escapeHtml(m.color)}">${escapeHtml(m.badge)}</span></div><small>ID: ${escapeHtml(r.report_no)} · ${escapeHtml(r.created_by||'Ukendt')}</small><em>Vælg</em></button>`; }).join('') || '<div class="admin-empty">Ingen rapporter fundet. Opret rapporten under Rapporter først.</div>';
  $('#modalFields').innerHTML = `<div class="reference-picker-ui"><input id="reportReferenceSearch" placeholder="Søg rapport, type, ID eller titel..."><div id="reportReferenceCards" class="reference-card-grid">${drawCards('')}</div></div>`;
  $('#modalSave').style.display=''; $('#modalSave').textContent='Luk'; $('#modalSave').onclick=closeModal; $('#modalCancel').style.display='none'; $('#modal').classList.remove('hidden');
  $('#reportReferenceSearch')?.addEventListener('input', e=>{ $('#reportReferenceCards').innerHTML = drawCards(e.target.value||''); });
};
linkReportToCurrentIncident = function(id){
  const r=findCombinedReport(id); if(!r || !currentIncident) return;
  currentIncident.references=currentIncident.references||[];
  if(!currentIncident.references.some(x=>String(x.report_id)===String(r.id))){ currentIncident.references.push({name:r.title, note:'Rapport: '+r.report_no, type:reportMeta(r).label, report_id:r.id}); }
  // sync rapportens sagsindhold ind i hændelsen
  (r.suspects||[]).forEach(p=>{ currentIncident.criminals=currentIncident.criminals||[]; if(!currentIncident.criminals.some(x=>(x.identifier&&p.identifier&&x.identifier===p.identifier)||x.name===p.name)) currentIncident.criminals.push({name:p.name, dob:p.dob||'', phone:p.phone||'', identifier:p.identifier||'', charges:0, mdtCharges:[], chargeReduction:{jail:0,fine:0,points:0}, chargeFlags:{wanted:!!p.wanted, handled:false, indictment:false}}); });
  (r.vehicles||[]).forEach(v=>{ currentIncident.vehicles=currentIncident.vehicles||[]; if(!currentIncident.vehicles.some(x=>String(x.plate||'').toUpperCase()===String(v.plate||'').toUpperCase())) currentIncident.vehicles.push({plate:v.plate, model:v.model||'', owner:v.owner||'', ownerName:v.ownerName||'', wanted:!!v.wanted, status:v.wanted?'EFTERLYST':(v.status||''), type:v.type||''}); });
  (r.tags||[]).forEach(t=>{ currentIncident.tags=currentIncident.tags||[]; if(!currentIncident.tags.some(x=>(x.name||x)===(t.name||t))) currentIncident.tags.push(t); });
  (r.evidence||[]).forEach(v=>{ currentIncident.evidence=currentIncident.evidence||[]; if(!currentIncident.evidence.some(x=>(x.name||x.title)===(v.name||v.title))) currentIncident.evidence.push(v); });
  renderLists(); markDirty(); closeModal(); toast('Rapport tilføjet til hændelsen.');
};

document.addEventListener('DOMContentLoaded', () => {
  bind();
  $$('.nav').forEach(n => { if(!enabledPages[n.dataset.page]) n.classList.add('disabled'); });
  setPage('dashboard');
});

/* === COACHN V27 ADVANCED WINDOW SYSTEM ===
   - Start altid med ét Forside-vindue
   - Venstre menu navigerer KUN i aktivt vindue, opretter ikke nye tabs
   - Plus opretter nyt vindue fra seneste position, maks 5 vinduer
   - Tabs gemmer egen sidste side/state og logger navigation til localStorage/server callback hvis findes
*/
(function(){
  const MAX_WINDOWS = 5;
  const storageKey = 'san_mdt_window_nav_logs_v1';
  const short = (s, n=18) => { s = String(s||'Forside'); return s.length > n ? s.slice(0, Math.max(1,n-3)) + '...' : s; };
  const pageTitle = (page) => (window.pageLabels && pageLabels[page]) || page || 'Forside';
  function now(){ try { return new Date().toISOString(); } catch(_){ return String(Date.now()); } }
  function logNav(action, from, to, tabKey){
    const entry = { time: now(), officer: ($('#officerName')&&$('#officerName').textContent)||'Ukendt', action, from: from||'', to: to||'', tab: tabKey||window.activeTabKey||activeTabKey||'dashboard' };
    try { const arr = JSON.parse(localStorage.getItem(storageKey)||'[]'); arr.push(entry); localStorage.setItem(storageKey, JSON.stringify(arr.slice(-500))); } catch(_){ }
    try { if(typeof nui === 'function') nui('logWindowNavigation', entry).catch(()=>{}); } catch(_){ }
    try { console.log('[SAN MDT WINDOW LOG]', entry); } catch(_){ }
  }

  // Bevar eksisterende Set, men brug metadata pr. tab til labels og page-state.
  window.__mdtWindowState = window.__mdtWindowState || { seq: 1, tabs: { dashboard:{ page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() } } };
  const state = window.__mdtWindowState;
  function ensureDashboard(){
    try { openTabs.clear(); openTabs.add('dashboard'); } catch(_){ }
    state.tabs.dashboard = state.tabs.dashboard || { page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() };
    activeTabKey = activeTabKey || 'dashboard';
  }
  ensureDashboard();

  function dynamicLabelFor(page){
    if(page === 'profiles' && activeProfile){ return 'Profil/' + (activeProfile.name || activeProfile.firstname || activeProfile.identifier || 'Borger'); }
    if(page === 'vehicles' && activeVehicleProfile){ return 'Køretøj/' + (activeVehicleProfile.plate || activeVehicleProfile.registration || 'Ukendt'); }
    if(page === 'incidents' && currentIncident){ return 'Hændelse/' + (currentIncident.incident_no || currentIncident.id || 'Ny'); }
    if(page === 'reports' && window.currentReport){ return 'Rapport/' + (currentReport.report_no || currentReport.id || currentReport.title || 'Ny'); }
    return pageTitle(page);
  }

  function getTabMeta(key){ return state.tabs[key] || (state.tabs[key] = { page:key, label:pageTitle(key), createdAt:now(), lastAt:now() }); }
  function setTabMeta(key, page, label){
    const m = getTabMeta(key);
    const old = m.page;
    m.page = page || m.page || 'dashboard';
    m.label = label || dynamicLabelFor(m.page);
    m.lastAt = now();
    if(old !== m.page) logNav('navigate', old, m.page, key);
    return m;
  }

  const oldTabLabel = window.tabLabel || tabLabel;
  window.tabLabel = tabLabel = function(key){
    if(String(key).startsWith('incident:') && typeof oldTabLabel === 'function') return oldTabLabel(key);
    if(String(key).startsWith('report:') && typeof oldTabLabel === 'function') return oldTabLabel(key);
    const m = getTabMeta(key);
    return escapeHtml(short(m.label || pageTitle(m.page || key), 22));
  };

  window.renderTabs = renderTabs = function(active){
    const tabs = $('#tabs'); if(!tabs) return;
    const add = $('#topPlus');
    [...tabs.querySelectorAll('.tab:not(.add)')].forEach(t => t.remove());
    [...openTabs].slice(0, MAX_WINDOWS).forEach(key => {
      const b = document.createElement('button');
      b.className = 'tab' + (key === active ? ' active' : '');
      b.dataset.tab = key;
      b.title = (getTabMeta(key).label || pageTitle(getTabMeta(key).page));
      b.innerHTML = `${tabLabel(key)} <span>×</span>`;
      b.onclick = (e) => {
        if(e.target && e.target.tagName === 'SPAN'){
          e.stopPropagation();
          if(key === 'dashboard' && openTabs.size === 1){ toast('Forside skal være åben.'); return; }
          if(openTabs.size > 1){
            logNav('close', getTabMeta(key).page, '', key);
            openTabs.delete(key); delete tabIncidents[key]; if(window.tabReports) delete tabReports[key]; delete state.tabs[key];
            const next = [...openTabs].includes(activeTabKey) ? activeTabKey : ([...openTabs].pop() || 'dashboard');
            switchToTab(next);
          }
          return;
        }
        switchToTab(key);
      };
      tabs.insertBefore(b, add || null);
    });
  };

  function switchToTab(key){
    if(!openTabs.has(key)) openTabs.add(key);
    activeTabKey = key;
    const m = getTabMeta(key);
    logNav('switch', '', m.page, key);
    if(String(key).startsWith('incident:') && typeof openIncident === 'function') return openIncident(tabIncidents[key], key);
    if(String(key).startsWith('report:') && typeof openReportPage === 'function' && window.tabReports) return openReportPage(tabReports[key], key);
    internalSetPage(m.page || 'dashboard', true);
  }

  const originalSetPage = window.setPage || setPage;
  function internalSetPage(page, fromTabSwitch){
    if(!enabledPages[page]) { toast('Dette modul er ikke tilgængeligt endnu.'); return; }
    const key = activeTabKey || 'dashboard';
    if(!fromTabSwitch) setTabMeta(key, page, dynamicLabelFor(page));
    // Kør original visning uden at lade den lave permanent ny tab-label bagefter; vi re-renderer selv.
    try { originalSetPage(page); } catch(e){ console.error('[SAN MDT V27 setPage]', e); }
    // TABFIX: legacy setPage kunne tilføje siden som ny tab-key. Fjern den igen.
    if(page !== key && openTabs.has(page) && !String(key).startsWith('incident:') && !String(key).startsWith('report:')){
      openTabs.delete(page);
      if(state.tabs && state.tabs[page]) delete state.tabs[page];
    }
    activeTabKey = key;
    setTabMeta(key, page, dynamicLabelFor(page));
    renderTabs(key);
  }
  window.setPage = setPage = function(page){ internalSetPage(page, false); };

  function createWindowFromCurrent(){
    if(openTabs.size >= MAX_WINDOWS){ toast('Maks 5 vinduer åbne. Luk et vindue først.'); return; }
    const from = getTabMeta(activeTabKey || 'dashboard');
    const key = 'win:' + (++state.seq) + ':' + Date.now();
    state.tabs[key] = { page: from.page || activePage || 'dashboard', label: from.label || dynamicLabelFor(from.page), createdAt:now(), lastAt:now() };
    openTabs.add(key); activeTabKey = key;
    logNav('open', '', state.tabs[key].page, key);
    internalSetPage(state.tabs[key].page, true);
  }

  function bindV27(){
    const plus = $('#topPlus');
    if(plus){ plus.onclick = (e) => { e.preventDefault(); e.stopPropagation(); createWindowFromCurrent(); }; plus.title = 'Åbn nyt vindue (maks 5)'; }
    // Venstre menu må kun navigere aktivt vindue. Stop alle gamle click handlers ved capture og kør vores egen.
    document.querySelectorAll('.nav, .admin-subnav, .nsk-subnav').forEach(btn => {
      if(btn.__v27Bound) return; btn.__v27Bound = true;
      btn.addEventListener('click', function(ev){
        const page = this.dataset && this.dataset.page;
        if(!page || this.disabled || this.classList.contains('disabled')) return;
        ev.preventDefault(); ev.stopPropagation(); ev.stopImmediatePropagation();

        // NSK hovedknap: toggle dropdown. Første åbning navigerer til bandeoverblik.
        if(this.classList.contains('nsk-main')){
          const wasClosed = $('.nsk-dropdown')?.classList.contains('closed');
          const opened = toggleNskDropdown();
          if(opened && wasClosed) setPage('nsk_gangs');
          return;
        }
        if(this.classList.contains('nsk-subnav')){
          openNskPage(page);
          return;
        }

        // ADMIN hovedknap: toggle kun dropdown, naviger/opret aldrig vindue.
        if(this.classList.contains('admin-main')){
          refreshAdministrationAccess();
          const adminDrop = $('.admin-dropdown');
          const adminMainBtn = $('.admin-main');
          if(!mdtAdminView){
            if(adminDrop) adminDrop.classList.add('closed');
            if(adminMainBtn) adminMainBtn.classList.add('closed', 'admin-locked');
            toast({ type:'error', title:'Ingen adgang', message:'Du mangler administration.view eller Rigspolitiet.' });
            return;
          }
          const isClosed = adminDrop ? adminDrop.classList.toggle('closed') : false;
          if(adminMainBtn) adminMainBtn.classList.toggle('closed', isClosed);
          return;
        }

        // ADMIN undermenu: kræver permission, navigerer kun i aktivt vindue.
        if(this.classList.contains('admin-subnav')){
          refreshAdministrationAccess();
          if(!mdtAdminView){
            const adminDrop = $('.admin-dropdown');
            const adminMainBtn = $('.admin-main');
            if(adminDrop) adminDrop.classList.add('closed');
            if(adminMainBtn) adminMainBtn.classList.add('closed', 'admin-locked');
            toast({ type:'error', title:'Ingen adgang', message:'Du mangler administration.view eller Rigspolitiet.' });
            return;
          }
        }

        // Venstre menu ændrer kun aktivt vindue. Kun plus-knappen må oprette nyt vindue.
        setPage(page);
      }, true);
    });
    renderTabs(activeTabKey || 'dashboard');
  }
  window.addEventListener('message', function(e){ if((e.data||{}).action === 'open') setTimeout(bindV27, 100); });
  document.addEventListener('DOMContentLoaded', bindV27);
  setTimeout(bindV27, 250);
})();

/* === COACHN V28 PROPER SINGLE-WINDOW NAVIGATION SYSTEM ===
   - Forside er altid start-tab
   - Venstre menu skifter KUN siden i aktivt vindue
   - Opret/åbn hændelse eller rapport bruger samme aktive vindue
   - Tab-label opdateres: Hændelser -> Hændelse/NyHændelse -> Hændelse/ID
   - Kun plus-knappen opretter et nyt vindue
*/
(function(){
  function now(){ try { return new Date().toISOString(); } catch(_){ return String(Date.now()); } }
  function shortLabel(s, n=24){ s=String(s||'Forside'); return s.length>n ? s.slice(0,n-3)+'...' : s; }
  function stateObj(){
    window.__mdtWindowState = window.__mdtWindowState || { seq:1, tabs:{ dashboard:{ page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() } } };
    window.__mdtWindowState.tabs = window.__mdtWindowState.tabs || {};
    window.__mdtWindowState.tabs.dashboard = window.__mdtWindowState.tabs.dashboard || { page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() };
    return window.__mdtWindowState;
  }
  function activeWindowKey(){
    let key = activeTabKey || 'dashboard';
    // Gamle incident:/report: tabs må ikke længere bruges som vinduer.
    if(String(key).startsWith('incident:') || String(key).startsWith('report:')){
      try { openTabs.delete(key); } catch(_){ }
      key = [...openTabs].find(k => !String(k).startsWith('incident:') && !String(k).startsWith('report:')) || 'dashboard';
      try { openTabs.add(key); } catch(_){ }
      activeTabKey = key;
    }
    return key;
  }
  function setWindowMeta(page, label){
    const state = stateObj();
    const key = activeWindowKey();
    try { openTabs.add(key); } catch(_){ }
    const meta = state.tabs[key] || { createdAt:now() };
    meta.page = page || meta.page || 'dashboard';
    meta.label = label || meta.label || ((window.pageLabels && pageLabels[page]) || page || 'Forside');
    meta.lastAt = now();
    state.tabs[key] = meta;
    activeTabKey = key;
    return key;
  }
  function renderActiveTabs(){ try { renderTabs(activeTabKey || 'dashboard'); } catch(_){ } }

  // Tab labels skal altid komme fra vinduets egen meta-state, ikke fra sidenøgler.
  window.tabLabel = tabLabel = function(key){
    const meta = stateObj().tabs[key];
    const label = (meta && meta.label) || ((window.pageLabels && pageLabels[key]) || key || 'Forside');
    return escapeHtml(shortLabel(label));
  };

  // Patch setPage igen: aktivt vindue skifter side; ingen nye tabs.
  const baseSetPageV28 = setPage;
  window.setPage = setPage = function(page){
    const key = setWindowMeta(page, (window.pageLabels && pageLabels[page]) || page || 'Forside');
    try { baseSetPageV28(page); } catch(e){ console.error('[SAN MDT V28 setPage]', e); }
    // Legacy cleanup: hvis gamle handlers tilføjede page/incident/report som tab, fjern dem igen.
    try {
      [...openTabs].forEach(k => {
        if(k !== key && (k === page || String(k).startsWith('incident:') || String(k).startsWith('report:'))){
          openTabs.delete(k);
          delete stateObj().tabs[k];
        }
      });
    } catch(_){ }
    activeTabKey = key;
    renderActiveTabs();
  };

  function incidentLabel(i){
    i = i || currentIncident || {};
    if(i.draft || !i.id) return 'Hændelse/NyHændelse';
    return 'Hændelse/' + (i.incident_no || i.id);
  }

  window.openIncident = openIncident = function(i){
    const key = activeWindowKey();
    currentIncident = normalizeIncident(i);
    currentIncidentTabKey = key;
    tabIncidents[key] = currentIncident;
    setWindowMeta('incidents', incidentLabel(currentIncident));
    activePage = 'incidents';

    $$('.page').forEach(p => p.classList.toggle('active', p.id === 'incidents'));
    $$('.nav').forEach(n => n.classList.toggle('active', n.dataset.page === 'incidents'));
    setIncidentListMode(false);

    $('#incidentNumber').textContent = currentIncident.draft ? 'KLADDE' : (currentIncident.incident_no || '---');
    $('#incidentCreated').textContent = currentIncident.draft ? 'Ny kladde - ikke gemt endnu' : `Oprettet af ${currentIncident.created_by || 'Ukendt'} - ${fmtDate(currentIncident.created_at)} · Senest redigeret af ${currentIncident.last_edited_by || currentIncident.created_by || 'Ingen'} - ${fmtDate(currentIncident.last_edited_at || currentIncident.updated_at) || 'Aldrig'}`;
    $('#incidentOfficer').textContent = currentIncident.officers?.[0]?.name ? `Betjente i hændelsen: ${currentIncident.officers[0].name}` : '';
    $('#saveState').textContent = currentIncident.draft ? 'Kladde - ikke gemt endnu' : 'Ingen ændringer at gemme';
    $('#incidentTitle').value = currentIncident.title || '';
    $('#incidentEditor').innerHTML = currentIncident.description || '';
    syncIncidentDeleteButton();

    renderLists();
    renderIncidentList();
    updateCountsNoDirty();
    renderActiveTabs();
  };

  window.newIncident = newIncident = function(){
    const officer = $('#officerName')?.textContent || 'Betjent';
    const draft = normalizeIncident({
      id:null, draft:true, __draftKey:Date.now(), incident_no:'KLADDE', report_type:'incident', title:'Ny hændelse', description:reportTypeTemplates.incident.body, status:'Aktiv', location:'',
      objects:[], criminals:[], tags:[], evidence:[], officers:[{name:officer}], civilians:[], vehicles:[], references:[],
      created_by:officer, created_at:null, updated_at:null, last_edited_by:'', last_edited_at:null, locked:false
    });
    setWindowMeta('incidents', 'Hændelse/NyHændelse');
    openIncident(draft);
  };

  window.saveIncident = saveIncident = async function(){
    const inc = collectIncident();
    if(!inc){ toast('Ingen hændelse valgt.'); return; }
    const btn = $('#saveIncident'); const old = btn ? btn.textContent : '';
    if(btn){ btn.disabled = true; btn.textContent = 'Gemmer...'; }
    try{
      const r = await nui('saveIncident', { incident: inc });
      if(r && r.ok){
        currentIncident = normalizeIncident(r.incident || inc);
        currentIncident.draft = false;
        const key = activeWindowKey();
        currentIncidentTabKey = key;
        tabIncidents[key] = currentIncident;
        setWindowMeta('incidents', incidentLabel(currentIncident));
        $('#saveState').textContent = 'Ingen ændringer at gemme';
        await refreshIncidents();
        openIncident(currentIncident);
        toast(r.message || 'Hændelse gemt.');
      } else toast(r?.message || 'Kunne ikke gemme.');
    } finally { if(btn){ btn.disabled = false; btn.textContent = old; } }
  };

  // Rapport-editor følger samme vinduesprincip.
  function reportLabel(r){
    r = r || window.currentReport || currentReport || {};
    if(r.draft || !r.id) return 'Rapport/NyRapport';
    return 'Rapport/' + (r.report_no || r.id);
  }
  if(typeof openReportPage === 'function'){
    window.openReportPage = openReportPage = function(r){
      const key = activeWindowKey();
      currentReport = normalizeReport(r || {type:'report'});
      currentReportTabKey = key;
      tabReports[key] = currentReport;
      setWindowMeta('reports', reportLabel(currentReport));
      activePage='reports';
      $$('.page').forEach(p=>p.classList.toggle('active', p.id==='reports'));
      $$('.nav').forEach(n=>n.classList.toggle('active', n.dataset.page==='reports'));
      const sec=$('#reports'); if(sec){ sec.innerHTML=reportEditorHtml(currentReport); }
      bindReportPageEditor();
      renderReportSideLists();
      renderActiveTabs();
    };
    window.newReportPage = newReportPage = function(){
      const officer = $('#officerName')?.textContent || 'Betjent';
      const r = normalizeReport({ id:null, draft:true, __draftKey:Date.now(), type:'report', title:reportTypeTemplates.report.title, body:reportTypeTemplates.report.body, report_no:reportNo(), created_by:officer, created_at:new Date().toISOString() });
      setWindowMeta('reports', 'Rapport/NyRapport');
      openReportPage(r);
    };
    window.saveReportPage = saveReportPage = function(){
      let r = collectReportPage();
      const wasDraft = !r.id || r.draft;
      if(wasDraft){ r.id = Date.now(); r.report_no = r.report_no || reportNo(); r.created_at = r.created_at || new Date().toISOString(); }
      r.draft = false;
      const exists = mdtReports.some(x=>String(x.id)===String(r.id));
      mdtReports = exists ? mdtReports.map(x=>String(x.id)===String(r.id)?r:x) : [r, ...mdtReports];
      reportStorageSave();
      syncReportAnpgFlags();
      currentReport = r;
      const key = activeWindowKey();
      currentReportTabKey = key;
      tabReports[key]=r;
      setWindowMeta('reports', reportLabel(r));
      openReportPage(r);
      toast('Rapport gemt.');
    };
  }

  // Plus-knappen er ENESTE måde at lave nyt vindue. Nyt vindue starter altid på Forside.
  function bindV28Plus(){
    const plus = $('#topPlus');
    if(!plus || plus.__v28Bound) return;
    plus.__v28Bound = true;
    plus.onclick = function(e){
      e.preventDefault(); e.stopPropagation();
      if(openTabs.size >= 5){ toast('Maks 5 vinduer åbne. Luk et vindue først.'); return; }
      const st = stateObj();
      const key = 'win:' + (++st.seq) + ':' + Date.now();
      st.tabs[key] = { page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() };
      openTabs.add(key);
      activeTabKey = key;
      setPage('dashboard');
    };
    plus.title = 'Åbn nyt vindue';
  }

  // Ryd gamle special-tabs ved load og bind plus.
  try {
    [...openTabs].forEach(k => { if(String(k).startsWith('incident:') || String(k).startsWith('report:')){ openTabs.delete(k); delete stateObj().tabs[k]; } });
    if(!openTabs.size) openTabs.add('dashboard');
    activeTabKey = [...openTabs][0] || 'dashboard';
  } catch(_){ }
  bindV28Plus();
  document.addEventListener('DOMContentLoaded', bindV28Plus);
  window.addEventListener('message', function(e){ if((e.data||{}).action === 'open') setTimeout(bindV28Plus, 100); });
  renderActiveTabs();
})();

/* === COACHN V29 WINDOW CONTEXT FIX ===
   - + opretter altid nyt vindue på Forside
   - Venstre navigation skifter kun aktivt vindue
   - Hændelser-listen viser tab-label "Hændelser"
   - Åbnet/ny hændelse viser "Hændelse/NyHændelse" eller "Hændelse/ID"
   - Når man går tilbage fra en hændelse, opdateres samme vindue tilbage til "Hændelser"
*/
(function(){
  function now(){ try { return new Date().toISOString(); } catch(_){ return String(Date.now()); } }
  function getState(){
    window.__mdtWindowState = window.__mdtWindowState || { seq:1, tabs:{ dashboard:{ page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() } } };
    window.__mdtWindowState.tabs = window.__mdtWindowState.tabs || {};
    return window.__mdtWindowState;
  }
  function realWindowKey(){
    let key = activeTabKey || 'dashboard';
    if(String(key).startsWith('incident:') || String(key).startsWith('report:')){
      try { openTabs.delete(key); } catch(_){ }
      key = [...openTabs].find(k => !String(k).startsWith('incident:') && !String(k).startsWith('report:')) || 'dashboard';
      activeTabKey = key;
    }
    try { openTabs.add(key); } catch(_){ }
    return key;
  }
  function setMeta(page, label){
    const st = getState();
    const key = realWindowKey();
    const meta = st.tabs[key] || { createdAt:now() };
    meta.page = page || 'dashboard';
    meta.label = label || ((window.pageLabels && pageLabels[page]) || page || 'Forside');
    meta.lastAt = now();
    st.tabs[key] = meta;
    activeTabKey = key;
    try { renderTabs(key); } catch(_){ }
    return key;
  }
  function incidentWindowLabel(i){
    i = i || currentIncident || {};
    if(i.draft || !i.id) return 'Hændelse/NyHændelse';
    return 'Hændelse/' + (i.incident_no || i.id);
  }
  function showIncidentList(){
    currentIncident = null;
    currentIncidentTabKey = null;
    setMeta('incidents', 'Hændelser');
    try { activePage = 'incidents'; } catch(_){ }
    try { setIncidentListMode(true); } catch(_){ }
    try { renderIncidentList(); } catch(_){ }
    try { refreshIncidents(); } catch(_){ }
  }

  const previousSetPage = setPage;
  window.setPage = setPage = function(page){
    if(page === 'incidents'){
      try { previousSetPage(page); } catch(e){ console.error('[SAN MDT V29 incidents setPage]', e); }
      showIncidentList();
      return;
    }
    const label = (window.pageLabels && pageLabels[page]) || page || 'Forside';
    try { previousSetPage(page); } catch(e){ console.error('[SAN MDT V29 setPage]', e); }
    setMeta(page, label);
  };

  const previousOpenIncident = openIncident;
  window.openIncident = openIncident = function(i){
    const inc = normalizeIncident(i);
    const key = setMeta('incidents', incidentWindowLabel(inc));
    currentIncidentTabKey = key;
    try { tabIncidents[key] = inc; } catch(_){ }
    try { previousOpenIncident(inc, key); } catch(e){ console.error('[SAN MDT V29 openIncident]', e); }
    setMeta('incidents', incidentWindowLabel(inc));
  };

  window.newIncident = newIncident = function(){
    const officer = $('#officerName')?.textContent || 'Betjent';
    const draft = normalizeIncident({
      id:null, draft:true, __draftKey:Date.now(), incident_no:'KLADDE', report_type:'incident', title:'Ny hændelse', description:reportTypeTemplates.incident.body, status:'Aktiv', location:'',
      objects:[], criminals:[], tags:[], evidence:[], officers:[{name:officer}], civilians:[], vehicles:[], references:[],
      created_by:officer, created_at:null, updated_at:null, last_edited_by:'', last_edited_at:null, locked:false
    });
    openIncident(draft);
  };

  const previousSaveIncident = saveIncident;
  window.saveIncident = saveIncident = async function(){
    try { await previousSaveIncident(); }
    finally { setMeta('incidents', incidentWindowLabel(currentIncident)); }
  };

  function bindV29(){
    const plus = $('#topPlus');
    if(plus){
      plus.onclick = function(e){
        e.preventDefault(); e.stopPropagation();
        if(openTabs.size >= 5){ toast('Maks 5 vinduer åbne. Luk et vindue først.'); return; }
        const st = getState();
        const key = 'win:' + (++st.seq) + ':' + Date.now();
        st.tabs[key] = { page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() };
        openTabs.add(key);
        activeTabKey = key;
        try { previousSetPage('dashboard'); } catch(_){ }
        setMeta('dashboard', 'Forside');
      };
      plus.title = 'Åbn nyt vindue på Forside';
    }

    ['backToIncidentList','backToIncidentListTop'].forEach(id => {
      const btn = document.getElementById(id);
      if(!btn || btn.__v29Bound) return;
      btn.__v29Bound = true;
      btn.onclick = function(e){
        e.preventDefault(); e.stopPropagation();
        showIncidentList();
      };
    });

    document.querySelectorAll('.nav[data-page="incidents"]').forEach(btn => {
      if(btn.__v29IncidentNav) return;
      btn.__v29IncidentNav = true;
      btn.addEventListener('click', function(e){
        e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
        setPage('incidents');
      }, true);
    });
  }

  bindV29();
  document.addEventListener('DOMContentLoaded', bindV29);
  window.addEventListener('message', function(e){ if((e.data||{}).action === 'open') setTimeout(bindV29, 100); });
  try { setMeta('dashboard','Forside'); } catch(_){ }
})();

/* === CHATGPT V32 PLUS WINDOW FIX ===
   Fix: + må aldrig ændre det eksisterende aktive vindue til Forside.
   + opretter altid et NYT vindue på Forside og bevarer gamle vinduers page/label.
*/
(function(){
  function now(){ try { return new Date().toISOString(); } catch(_){ return String(Date.now()); } }
  function state(){
    window.__mdtWindowState = window.__mdtWindowState || { seq:1, tabs:{ dashboard:{ page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() } } };
    window.__mdtWindowState.tabs = window.__mdtWindowState.tabs || {};
    return window.__mdtWindowState;
  }
  function currentMetaSnapshot(key){
    try {
      const st = state();
      const m = st.tabs[key] || {};
      return { page:m.page, label:m.label, createdAt:m.createdAt, lastAt:m.lastAt };
    } catch(_){ return null; }
  }
  function restoreMeta(key, snap){
    if(!key || !snap) return;
    try {
      const st = state();
      st.tabs[key] = Object.assign(st.tabs[key] || {}, snap);
    } catch(_){ }
  }
  function createFreshDashboardWindow(){
    try {
      const st = state();
      if(openTabs.size >= 5){ toast('Maks 5 vinduer åbne. Luk et vindue først.'); return; }

      const previousKey = activeTabKey || 'dashboard';
      const previousSnap = currentMetaSnapshot(previousKey);
      const key = 'win:' + (++st.seq) + ':' + Date.now();

      st.tabs[key] = { page:'dashboard', label:'Forside', createdAt:now(), lastAt:now() };
      openTabs.add(key);
      activeTabKey = key;

      // Kør side-render på det NYE vindue, men gendan gammel vinduesmetadata bagefter.
      try { setPage('dashboard'); } catch(e){ console.error('[SAN MDT V32 plus setPage]', e); }

      restoreMeta(previousKey, previousSnap);
      st.tabs[key] = Object.assign(st.tabs[key] || {}, { page:'dashboard', label:'Forside', lastAt:now() });
      activeTabKey = key;
      try { renderTabs(key); } catch(_){ }
    } catch(e){ console.error('[SAN MDT V32 plus window fix]', e); }
  }
  function bindPlusV32(){
    const plus = document.getElementById('topPlus');
    if(!plus) return;
    plus.title = 'Åbn nyt vindue på Forside';
    plus.onclick = function(e){ e.preventDefault(); e.stopPropagation(); createFreshDashboardWindow(); };
  }

  // Capture stopper gamle + handlers, så de ikke ændrer det aktive vindue.
  document.addEventListener('click', function(e){
    const plus = e.target && e.target.closest && e.target.closest('#topPlus');
    if(!plus) return;
    e.preventDefault();
    e.stopPropagation();
    e.stopImmediatePropagation();
    createFreshDashboardWindow();
  }, true);

  bindPlusV32();
  document.addEventListener('DOMContentLoaded', bindPlusV32);
  window.addEventListener('message', function(e){ if((e.data||{}).action === 'open') setTimeout(bindPlusV32, 100); });
})();


/* CHATGPT_V34_FORSIDE_LABEL_CLEANUP */
(function(){
  try {
    window.pageLabels = window.pageLabels || pageLabels || {};
    window.pageLabels.dashboard = 'Forside';
    document.querySelectorAll('[data-page="dashboard"], [data-tab="dashboard"]').forEach(el => {
      if(el && /Dashboard/i.test(el.textContent || '')) el.textContent = (el.classList.contains('tab') ? 'Forside ×' : '⌂ Forside');
      if(el && el.title && /Dashboard/i.test(el.title)) el.title = 'Forside';
    });
  } catch(e) {}
})();


/* === SAN MDT V74 CLEAN RUNTIME REPAIR ===
   Clean single runtime. Central links. Incident owns unlink. Report references read-only.
   Dedupe references/officers/entities. Simple templates. No navigation on unlink.
*/
(function(){
  var SIMPLE_TEMPLATE = 'Lokation/Tidspunkt:<br><br>Hændelsesforløb:<br>Beskriv hændelsesforløbet detaljeret.';
  function safe(fn){ try { return fn(); } catch(e){ console.error('[SAN MDT V74]', e); } }
  function esc(v){ try { return escapeHtml(String(v == null ? '' : v)); } catch(_){ return String(v == null ? '' : v); } }
  function norm(v){ return String(v == null ? '' : v).trim(); }
  function low(v){ return norm(v).toLowerCase(); }
  function validId(v){ var s=norm(v); return !!s && !/^KLADDE$/i.test(s) && s!=='---' && s!=='null' && s!=='undefined'; }
  function uniq(arr, keyFn){ var out=[], seen={}; (arr||[]).forEach(function(x){ var k=keyFn(x); if(!k || seen[k]) return; seen[k]=true; out.push(x); }); return out; }
  function officerKey(o){ return low((o&& (o.identifier||o.citizenid||o.charid||o.name)) || ''); }
  function personKey(o){ return low((o&& (o.identifier||o.citizenid||o.charid||o.name)) || ''); }
  function vehicleKey(v){ return norm((v&&(v.plate||v.name))||'').toUpperCase(); }
  function tagKey(t){ return low((typeof t==='object'?(t.name||t.label):t)||''); }
  function evidenceKey(e){ return low((e&&(e.id||e.name||e.title))||e||''); }
  function incidentNo(i){ return norm(i && (i.incident_no||i.id)); }
  function reportNo(r){ return norm(r && (r.report_no||r.id)); }
  function realReportId(r){ return norm(r && r.id); }
  function findIncident(id){ id=norm(id); return (incidents||[]).map(function(x){return normalizeIncident(x);}).find(function(i){ return norm(i.id)===id || norm(i.incident_no)===id; }); }
  function findReport(id){ id=norm(id); return (mdtReports||[]).map(function(x){return normalizeReport(x);}).find(function(r){ return norm(r.id)===id || norm(r.report_no)===id; }); }

  function setTemplates(){
    safe(function(){ Object.keys(reportTypeTemplates||{}).forEach(function(k){ reportTypeTemplates[k].body = SIMPLE_TEMPLATE; }); });
  }
  function cleanIncidentObject(inc){
    if(!inc) return inc;
    inc.references = uniq((inc.references||[]).filter(function(r){ return r && (validId(r.report_id)||validId(r.incident_id)||validId(r.note)||validId(r.name)); }), function(r){
      if(validId(r.report_id)) return 'report:'+norm(r.report_id);
      if(validId(r.incident_id)) return 'incident:'+norm(r.incident_id);
      return 'manual:'+low(r.name)+':'+low(r.note);
    });
    inc.officers=uniq(inc.officers||[], officerKey); inc.civilians=uniq(inc.civilians||[], personKey); inc.criminals=uniq(inc.criminals||[], personKey); inc.vehicles=uniq(inc.vehicles||[], vehicleKey); inc.tags=uniq(inc.tags||[], tagKey); inc.evidence=uniq(inc.evidence||[], evidenceKey);
    return inc;
  }
  function cleanReportObject(r){
    if(!r) return r;
    if(!validId(r.linked_incident_no)) r.linked_incident_no='';
    r.references = uniq((r.references||[]).filter(function(x){ return x && (validId(x.incident_id)||validId(x.report_id)||validId(x.note)||validId(x.name)); }), function(x){
      if(validId(x.incident_id)) return 'incident:'+norm(x.incident_id);
      if(validId(x.report_id)) return 'report:'+norm(x.report_id);
      return 'manual:'+low(x.name)+':'+low(x.note);
    });
    r.officers=uniq(r.officers||[], officerKey); r.civilians=uniq(r.civilians||[], personKey); r.suspects=uniq(r.suspects||[], personKey); r.vehicles=uniq(r.vehicles||[], vehicleKey); r.tags=uniq(r.tags||[], tagKey); r.evidence=uniq(r.evidence||[], evidenceKey);
    return r;
  }
  function cleanAllState(){
    safe(function(){ incidents=(incidents||[]).map(function(x){ return cleanIncidentObject(normalizeIncident(x)); }); });
    safe(function(){ mdtReports=(mdtReports||[]).map(function(x){ return cleanReportObject(normalizeReport(x)); }); reportStorageSave(); });
    safe(function(){ if(currentIncident) currentIncident=cleanIncidentObject(currentIncident); });
    safe(function(){ if(currentReport) currentReport=cleanReportObject(currentReport); });
  }
  function linkedReportsForIncident(inc){
    if(!inc) return [];
    var id=incidentNo(inc), arr=[];
    (inc.references||[]).forEach(function(ref){ if(validId(ref.report_id)){ var r=findReport(ref.report_id); if(r) arr.push(r); }});
    (mdtReports||[]).map(function(x){return normalizeReport(x);}).forEach(function(r){ if(validId(r.linked_incident_no) && norm(r.linked_incident_no)===id) arr.push(r); });
    return uniq(arr, function(r){return 'report:'+(realReportId(r)||reportNo(r));});
  }
  function linkedIncidentForReport(rep){
    if(!rep) return null;
    if(validId(rep.linked_incident_no)) return findIncident(rep.linked_incident_no) || {id:rep.linked_incident_no, incident_no:rep.linked_incident_no};
    var ref=(rep.references||[]).find(function(x){ return validId(x.incident_id); });
    return ref ? (findIncident(ref.incident_id)||{id:ref.incident_id, incident_no:ref.incident_id}) : null;
  }
  function linkedBadge(kind,id){
    if(kind==='report') return '<div class="linked-ref-badge linked-report-badge"><b>KOBLET RAPPORT</b><small>KOBLET TIL ID: '+esc(id)+'</small></div>';
    return '<div class="linked-ref-badge linked-incident-badge"><b>KOBLET HÆNDELSE</b><small>KOBLET TIL ID: '+esc(id)+'</small></div>';
  }
  function incidentReferenceCard(reportKey, idx, displayId){
    var key = norm(reportKey);
    var label = norm(displayId || reportKey);
    return '<div class="reference-link-card report-ref" data-open-linked-report="'+esc(key)+'"><div>'+linkedBadge('report',label)+'</div><button type="button" class="iconbtn red unlink-reference-btn" title="Fjern link" data-unlink-reference="report:'+esc(key)+':'+(idx||0)+'">×</button></div>';
  }
  function reportReferenceCard(incidentId){
    return '<div class="reference-link-card incident-ref readonly" data-open-linked-incident="'+esc(incidentId)+'"><div>'+linkedBadge('incident',incidentId)+'</div></div>';
  }
  function ensureLinked(inc, rep){
    if(!inc || !rep || !validId(incidentNo(inc))) return;
    inc.references=inc.references||[]; rep.references=rep.references||[];
    if(!inc.references.some(function(x){return norm(x.report_id)===norm(rep.id);})){ inc.references.push({name:rep.title||'Rapport', type:(reportMeta(rep)||{}).label||'Rapport', report_id:rep.id}); }
    rep.linked_incident_no=incidentNo(inc);
    if(!rep.references.some(function(x){return norm(x.incident_id)===incidentNo(inc);})){ rep.references.push({name:inc.title||'Hændelse', type:'Hændelse', incident_id:incidentNo(inc)}); }
    cleanIncidentObject(inc); cleanReportObject(rep);
  }
  function syncEntities(inc, rep){
    if(!inc || !rep) return;
    function pushUnique(dst, src, key){ (src||[]).forEach(function(x){ if(!dst.some(function(y){return key(y)===key(x);})){ dst.push(x); } }); }
    inc.officers=inc.officers||[]; rep.officers=rep.officers||[]; pushUnique(inc.officers,rep.officers,officerKey); pushUnique(rep.officers,inc.officers,officerKey);
    inc.civilians=inc.civilians||[]; rep.civilians=rep.civilians||[]; pushUnique(inc.civilians,rep.civilians,personKey); pushUnique(rep.civilians,inc.civilians,personKey);
    inc.vehicles=inc.vehicles||[]; rep.vehicles=rep.vehicles||[]; pushUnique(inc.vehicles,rep.vehicles,vehicleKey); pushUnique(rep.vehicles,inc.vehicles,vehicleKey);
    inc.tags=inc.tags||[]; rep.tags=rep.tags||[]; pushUnique(inc.tags,rep.tags,tagKey); pushUnique(rep.tags,inc.tags,tagKey);
    inc.evidence=inc.evidence||[]; rep.evidence=rep.evidence||[]; pushUnique(inc.evidence,rep.evidence,evidenceKey); pushUnique(rep.evidence,inc.evidence,evidenceKey);
    cleanIncidentObject(inc); cleanReportObject(rep);
  }
  function rerenderAllLight(){
    safe(function(){ if(currentIncident) renderLists(); });
    safe(function(){ if(currentReport) renderReportSideLists(); });
    safe(function(){ renderIncidentList(); });
    safe(function(){ if(activePage==='reports') renderReportsPage(); });
  }
  function unlinkReportFromCurrentIncident(reportId){
    if(!currentIncident) return;
    var rawId = norm(reportId);
    var rep = findReport(rawId);
    var repDbId = rep ? norm(rep.id) : rawId;
    var repNoId = rep ? norm(rep.report_no) : rawId;
    currentIncident.references=(currentIncident.references||[]).filter(function(x){
      var xid = norm(x && x.report_id);
      return xid !== rawId && xid !== repDbId && xid !== repNoId;
    });
    if(rep){
      rep.linked_incident_no='';
      rep.references=(rep.references||[]).filter(function(x){
        var iid = norm(x && x.incident_id);
        return iid !== incidentNo(currentIncident) && iid !== norm(currentIncident.id);
      });
      cleanReportObject(rep);
      mdtReports=(mdtReports||[]).map(function(r){return norm(r.id)===norm(rep.id)?rep:r;});
      reportStorageSave();
    }
    cleanIncidentObject(currentIncident);
    safe(function(){ markDirty(); });
    safe(function(){ if(!currentIncident.draft && currentIncident.id) nui('saveIncident',{incident:(typeof collectIncident==='function'?collectIncident():currentIncident)}); });
    rerenderAllLight();
    toast({type:'success', title:'Reference fjernet', message:'Linket er fjernet fra hændelsen og rapporten.'});
  }
  window.unlinkReportFromCurrentIncident = unlinkReportFromCurrentIncident;

  var oldNormalizeReport = normalizeReport;
  window.normalizeReport = normalizeReport = function(r){ return cleanReportObject(oldNormalizeReport(r)); };
  var oldNormalizeIncident = normalizeIncident;
  window.normalizeIncident = normalizeIncident = function(i){ return cleanIncidentObject(oldNormalizeIncident(i)); };

  var oldItemHtml = itemHtml;
  window.itemHtml = itemHtml = function(type,item,idx){
    if(type==='references'){
      if(item && item.report_id){ var r=findReport(item.report_id); return incidentReferenceCard(r?realReportId(r):item.report_id, idx, r?reportNo(r):item.report_id); }
      if(item && item.incident_id){ var inc=findIncident(item.incident_id); return reportReferenceCard(inc?incidentNo(inc):item.incident_id); }
      return '<div class="reference-link-card manual-ref"><div><b>'+esc((item&&item.name)||'Reference')+'</b>'+((item&&item.note)?'<small>'+esc(item.note)+'</small>':'')+'</div><button type="button" class="iconbtn red" data-remove="references" data-idx="'+idx+'">×</button></div>';
    }
    return oldItemHtml(type,item,idx);
  };
  var oldReportMiniCard = reportMiniCard;
  window.reportMiniCard = reportMiniCard = function(obj,kind,idx){
    if(kind==='references'){
      if(obj && obj.incident_id){ var inc=findIncident(obj.incident_id); return reportReferenceCard(inc?incidentNo(inc):obj.incident_id); }
      if(obj && obj.report_id){ var r=findReport(obj.report_id); return '<div class="reference-link-card report-ref readonly"><div>'+linkedBadge('report', r?reportNo(r):obj.report_id)+'</div></div>'; }
      return '<div class="reference-link-card manual-ref"><div><b>'+esc((obj&&obj.name)||'Reference')+'</b>'+((obj&&obj.note)?'<small>'+esc(obj.note)+'</small>':'')+'</div></div>';
    }
    return oldReportMiniCard(obj,kind,idx);
  };

  var oldRenderLists = renderLists;
  window.renderLists = renderLists = function(){
    if(currentIncident){
      cleanIncidentObject(currentIncident);
      var linked=linkedReportsForIncident(currentIncident);
      currentIncident.references=(currentIncident.references||[]).filter(function(x){return !x.report_id || linked.some(function(r){return norm(r.id)===norm(x.report_id);});});
      linked.forEach(function(r){ if(!currentIncident.references.some(function(x){return norm(x.report_id)===norm(r.id);})){ currentIncident.references.push({name:r.title||'Rapport',type:(reportMeta(r)||{}).label||'Rapport',report_id:r.id}); }});
      currentIncident.officers=uniq(currentIncident.officers||[],officerKey);
    }
    oldRenderLists();
  };
  var oldRenderReportSideLists = renderReportSideLists;
  window.renderReportSideLists = renderReportSideLists = function(){
    if(currentReport){
      var inc=linkedIncidentForReport(currentReport);
      currentReport.references=[];
      if(inc && validId(incidentNo(inc))) currentReport.references.push({name:'Hændelse',type:'Hændelse',incident_id:incidentNo(inc)});
      cleanReportObject(currentReport);
    }
    oldRenderReportSideLists();
  };

  window.renderIncidentList = function(){
    var box=$('#recentIncidents'); if(!box) return;
    var list=(incidents||[]).map(function(x){return normalizeIncident(x);}).filter(function(i){return !i.draft && validId(i.incident_no||i.id);});
    var q=($('#incidentSearch')&&$('#incidentSearch').value||'').toLowerCase().trim();
    if(q) list=list.filter(function(i){return [i.title,i.incident_no,i.created_by,textOnly(i.description||'')].join(' ').toLowerCase().includes(q);});
    box.innerHTML='';
    if(!list.length){ box.innerHTML='<div class="incident-wide-card empty-card no-click"><b>Ingen hændelser fundet</b><small>Ingen hændelser matcher din søgning.</small></div>'; return; }
    list.forEach(function(i){
      var el=document.createElement('div'); el.className='incident-wide-card'+(currentIncident&&norm(currentIncident.id)===norm(i.id)?' active':'');
      var tags=Array.isArray(i.tags)?i.tags.slice(0,4):[];
      var tagHtml=tags.length?tags.map(function(t){var name=(typeof t==='object'?t.name:t)||'Tag'; return '<span class="incident-tag-chip" style="'+tagBadgeStyle(t)+'"><b>'+esc(name)+'</b></span>';}).join(''):'<span class="incident-tag-chip muted">Ingen tags</span>';
      var meta=currentReportTypeMeta(i); var linked=linkedReportsForIncident(i); var linkHtml=linked.map(function(r){return linkedBadge('report',reportNo(r));}).join('');
      el.innerHTML='<div class="card-main"><div class="card-title"><b>'+esc(i.title||'Ny hændelse')+'</b><span>'+esc(meta.badge)+'</span></div><div class="card-meta"><span class="idpill">ID: '+esc(i.incident_no||i.id)+'</span><span>Oprettet af: '+esc(i.created_by||'Ukendt')+'</span><span>'+esc(fmtDate(i.created_at)||'Ingen dato')+'</span></div><div class="card-meta edited-meta"><span>Senest redigeret af: '+esc(i.last_edited_by||i.created_by||'Ingen')+'</span><span>'+esc(fmtDate(i.last_edited_at||i.updated_at)||'Aldrig')+'</span></div>'+linkHtml+'</div><div class="card-tags">'+tagHtml+'</div>';
      el.onclick=function(ev){ if(ev.shiftKey||ev.ctrlKey){ openIncidentPopup(i); return; } openIncident(i); };
      el.onauxclick=function(ev){ if(ev.button===1){ ev.preventDefault(); openIncidentPopup(i); } };
      box.appendChild(el);
    });
  };

  window.renderReportsPage = function(){
    renderReportTypeOptions(); var sec=$('#reports'); if(!sec) return;
    sec.innerHTML='<div class="reports-shell"><div class="reports-header"><div><h2>Rapporter</h2><p>Opret rapporter med samme professionelle layout som hændelser.</p></div><div class="reports-actions"><input id="reportSearch" placeholder="Søg rapport, type, ID, titel..."><select id="reportTypeFilter"><option value="">Alle typer</option></select><button id="newReportBtn" class="save">+ Opret rapport</button></div></div><div id="reportsList" class="reports-list"></div></div>';
    var sel=$('#reportTypeFilter'); Object.entries(reportTypeTemplates).filter(function(kv){return kv[0]!=='incident';}).forEach(function(kv){var o=document.createElement('option'); o.value=kv[0]; o.textContent=kv[1].label; sel.appendChild(o);});
    function draw(){
      var box=$('#reportsList'); if(!box) return; var q=($('#reportSearch')&&$('#reportSearch').value||'').toLowerCase().trim(); var f=$('#reportTypeFilter')&&$('#reportTypeFilter').value||'';
      var list=(mdtReports||[]).map(function(x){return normalizeReport(x);}).filter(function(r){var m=reportMeta(r); var hay=[r.title,r.report_no,m.label,m.badge,r.created_by,r.linked_vehicle,r.linked_person,r.linked_incident_no,textOnly(r.body||'')].join(' ').toLowerCase(); return (!q||hay.includes(q)) && (!f||r.type===f);});
      box.innerHTML=list.length?list.map(function(r){var m=reportMeta(r); var txt=textOnly(r.body||''); var forlob=(txt.match(/Hændelsesforløb:\s*([^]*?)(Konklusion|Beviser|$)/i)||[])[1] || txt.slice(0,170) || 'Ingen forløb endnu'; var inc=linkedIncidentForReport(r); var linkHtml=inc?linkedBadge('incident',incidentNo(inc)):''; return '<div class="report-card" style="--report-color:'+esc(m.color||'#00e6b7')+'" data-open-report="'+esc(r.id)+'"><div class="report-card-main"><div class="report-title"><b>'+esc(r.title||m.title)+'</b>'+reportBadge(r)+'</div><div class="report-meta"><span>ID: '+esc(r.report_no)+'</span><span>Oprettet af: '+esc(r.created_by||'Ukendt')+'</span><span>'+esc(fmtDate(r.created_at)||'Ingen dato')+'</span></div><div class="report-preview"><b>Hændelsesforløb:</b> '+esc(forlob.trim())+'</div>'+linkHtml+'</div><div class="report-card-actions"><button data-delete-report="'+esc(r.id)+'" class="red">Slet</button></div></div>';}).join(''):'<div class="report-empty"><b>Ingen rapporter endnu</b><span>Tryk “+ Opret rapport” for at lave en rapport.</span></div>';
    }
    $('#newReportBtn').onclick=newReportPage; $('#reportSearch').addEventListener('input',draw); $('#reportTypeFilter').addEventListener('change',draw); draw();
  };

  var oldSaveIncident = saveIncident;
  window.saveIncident = saveIncident = async function(){
    if(currentIncident) currentIncident=cleanIncidentObject(currentIncident);
    await oldSaveIncident(); cleanAllState(); rerenderAllLight();
  };
  var oldSaveReportPage = saveReportPage;
  window.saveReportPage = saveReportPage = function(){
    if(currentReport) currentReport=cleanReportObject(currentReport);
    oldSaveReportPage();
    if(currentReport) syncReportAnpgFlags();
    if(currentReport){ var inc=linkedIncidentForReport(currentReport); if(inc && findIncident(incidentNo(inc))){ var real=findIncident(incidentNo(inc)); ensureLinked(real,currentReport); syncEntities(real,currentReport); } }
    cleanAllState(); rerenderAllLight();
  };
  window.linkReportToCurrentIncident = function(id){
    var rep=findReport(id); if(!rep||!currentIncident) return;
    if(currentIncident.draft || !validId(currentIncident.incident_no||currentIncident.id)){ toast({type:'error', title:'Gem hændelsen først', message:'Hændelsen skal gemmes før den kan linkes til en rapport.'}); return; }
    ensureLinked(currentIncident,rep); syncEntities(currentIncident,rep); mdtReports=(mdtReports||[]).map(function(r){return norm(r.id)===norm(rep.id)?rep:r;}); reportStorageSave(); renderLists(); markDirty(); closeModal(); safe(function(){nui('saveIncident',{incident:(typeof collectIncident==='function'?collectIncident():currentIncident)});}); toast({type:'success', title:'Rapport linket', message:'Rapporten er koblet til hændelsen.'});
  };

  document.addEventListener('click', function(e){
    var unlink=e.target.closest('[data-unlink-reference]');
    if(unlink){ e.preventDefault(); e.stopPropagation(); if(e.stopImmediatePropagation) e.stopImmediatePropagation(); var parts=String(unlink.dataset.unlinkReference||'').split(':'); if(parts[0]==='report') unlinkReportFromCurrentIncident(parts[1]); return false; }
    var openR=e.target.closest('[data-open-linked-report]');
    if(openR && !e.target.closest('button')){ e.preventDefault(); e.stopPropagation(); var r=findReport(openR.dataset.openLinkedReport); if(r) openReportPage(r); return false; }
    var openI=e.target.closest('[data-open-linked-incident]');
    if(openI && !e.target.closest('button')){ e.preventDefault(); e.stopPropagation(); var i=findIncident(openI.dataset.openLinkedIncident); if(i) openIncident(i); return false; }
  }, true);

  safe(function(){ setTemplates(); cleanAllState(); rerenderAllLight(); });
  document.addEventListener('DOMContentLoaded', function(){ safe(function(){ setTemplates(); cleanAllState(); rerenderAllLight(); }); });
  window.addEventListener('message', function(e){ if((e.data||{}).action==='open') setTimeout(function(){ safe(function(){ setTemplates(); cleanAllState(); rerenderAllLight(); }); },150); });
})();

/* SAN MDT - Flådestyring CLEAN V84 - real single map/render/vehicle/sync stack */
let fleetUnits = [];
let fleetOfficers = [];
let fleetDispatches = [];
let selfDutyStatus = { ok:false, onDuty:false };
let fleetSelectedId = localStorage.getItem('san_mdt_fleet_selected_live') || '';
let fleetViewerService = localStorage.getItem('san_mdt_fleet_viewer_service') || 'police';
let fleetSelfOnDuty = false;
let fleetSelfOfficer = null;
let fleetShowOtherService = localStorage.getItem('san_mdt_show_other_service') === '1';
let fleetShowCalls = localStorage.getItem('san_mdt_show_calls') !== '0';
let fleetShowGangTerritories = localStorage.getItem('san_mdt_fleet_gang_territories') === '1';
let fleetGangTerritories = [];
let fleetTerritoriesLoading = false;
let fleetDispatchLastSeen = Number(localStorage.getItem('san_mdt_dispatch_seen_count') || 0);
var sanDispatchPanelOpen = false;
const fleetDispatchPending = new Set();
let fleetTimer = null;
let fleetRefreshInFlight = false;
const FLEET_POLL_MS = 4000;

function stopFleetPolling(){
  if(fleetTimer){ clearInterval(fleetTimer); fleetTimer = null; }
}

function startFleetPolling(){
  if(fleetTimer || activePage !== 'fleet') return;
  fleetTimer = setInterval(() => { if(activePage === 'fleet') refreshFleet(); }, FLEET_POLL_MS);
}
let fleetMapBuilt = false;
let fleetMapView = { x:0, y:0, zoom:1 };
const FLEET_MAP_VERSION = 'v10-ox-crs-simple-leaflet-style';
try {
  if(localStorage.getItem('san_mdt_fleet_map_version') !== FLEET_MAP_VERSION){
    localStorage.setItem('san_mdt_fleet_map_version', FLEET_MAP_VERSION);
    localStorage.removeItem('san_mdt_fleet_map_x');
    localStorage.removeItem('san_mdt_fleet_map_y');
    localStorage.removeItem('san_mdt_fleet_map_zoom');
    // Keep old calibration out of the new system, but do not delete v40 anchor sync points.
    localStorage.removeItem('san_mdt_fleet_cal_x');
    localStorage.removeItem('san_mdt_fleet_cal_y');
  } else {
    fleetMapView = {
      x:Number(localStorage.getItem('san_mdt_fleet_map_x') || 0),
      y:Number(localStorage.getItem('san_mdt_fleet_map_y') || 0),
      zoom:Number(localStorage.getItem('san_mdt_fleet_map_zoom') || 1)
    };
  }
} catch(e) {}

/*
  SAN MDT Map V4
  The DLK/minimap resource remains untouched and is still used by FiveM for minimap/ESC.
  MDT uses the same satellite image as a raw image and projects GTA world coords onto it.

  Why V4 exists:
  The old code tried to find one magic set of world bounds. That can be close, but DLK maps
  are often cropped/padded differently from Rockstar's coordinate rectangle. V4 therefore
  supports LIVE ANCHOR SYNC: select a live unit, hold ALT and click the exact place on the
  MDT satellite image. Those anchors are saved in localStorage and used by every vehicle and
  dispatch blip.
*/
const FLEET_MAP_IMAGE = 'img/dlk-satellite-map.jpg';
const FLEET_MAP_TILE_PATH = 'img/dlk_tiles/minimap_{row}_{col}.png';
const FLEET_MAP_IMAGE_SIZE = { w:4096, h:6144 };

// SAN MDT V10: ox_mdt-style CRS.Simple projection.
// This is the same idea ox_mdt uses with Leaflet CRS.Simple:
//   mapCenter = [-119.43, 58.84]
//   latPr100 = 1.421
//   gameToMap(x,y) = [centerLat + latPr100/100*y, centerLng + latPr100/100*x]
// We convert that CRS point into percentages for the existing vanilla MDT map.
const FLEET_OX_CRS = {
  centerLat: -119.43,
  centerLng: 58.84,
  scale: 1.421 / 100,
  minLat: -192.0,
  maxLat: 0.0,
  minLng: 0.0,
  maxLng: 128.0
};
const FLEET_BASE_BOUNDS = { minX:-4000, maxX:4000, minY:-4000, maxY:8000 }; // kept only for fallback/debug
let FLEET_MAP_CAL = { x:0, y:0 };
let FLEET_SYNC_POINTS = [];

function fleetSaveCalibration(){
  try { localStorage.setItem('san_mdt_v40_sync_points', JSON.stringify(FLEET_SYNC_POINTS.slice(-24))); } catch(e){}
}
function fleetResetSync(){
  FLEET_SYNC_POINTS = [];
  fleetSaveCalibration();
  renderFleet();
  try{ toast({type:'success', title:'Map sync nulstillet', message:'Alle V4 sync-punkter er slettet.'}); }catch(e){ try{ toast('Map sync nulstillet.'); }catch(_){} }
}
function fleetBasePointXY(x,y){
  // ox_mdt / Leaflet CRS.Simple projection converted to percent coords.
  x = Number(x); y = Number(y);
  const lat = FLEET_OX_CRS.centerLat + FLEET_OX_CRS.scale * y;
  const lng = FLEET_OX_CRS.centerLng + FLEET_OX_CRS.scale * x;
  const px = ((lng - FLEET_OX_CRS.minLng) / (FLEET_OX_CRS.maxLng - FLEET_OX_CRS.minLng)) * 100;
  const py = ((FLEET_OX_CRS.maxLat - lat) / (FLEET_OX_CRS.maxLat - FLEET_OX_CRS.minLat)) * 100;
  return { x:px, y:py, lat:lat, lng:lng };
}
function fleetSolveAffine(points){
  if(!points || points.length < 3) return null;
  // Least squares solve for percent coords:
  // px = a*x + b*y + c, py = d*x + e*y + f
  const A = [[0,0,0],[0,0,0],[0,0,0]], bx=[0,0,0], by=[0,0,0];
  points.forEach(p=>{
    const X=Number(p.worldX), Y=Number(p.worldY), U=Number(p.mapX), V=Number(p.mapY);
    if(!isFinite(X)||!isFinite(Y)||!isFinite(U)||!isFinite(V)) return;
    const r=[X,Y,1];
    for(let i=0;i<3;i++){ for(let j=0;j<3;j++) A[i][j]+=r[i]*r[j]; bx[i]+=r[i]*U; by[i]+=r[i]*V; }
  });
  function solve(M,B){
    M=M.map(row=>row.slice()); B=B.slice();
    for(let i=0;i<3;i++){
      let pivot=i; for(let r=i+1;r<3;r++) if(Math.abs(M[r][i])>Math.abs(M[pivot][i])) pivot=r;
      if(Math.abs(M[pivot][i]) < 1e-9) return null;
      if(pivot!==i){ const t=M[i]; M[i]=M[pivot]; M[pivot]=t; const tb=B[i]; B[i]=B[pivot]; B[pivot]=tb; }
      const div=M[i][i]; for(let c=i;c<3;c++) M[i][c]/=div; B[i]/=div;
      for(let r=0;r<3;r++) if(r!==i){ const f=M[r][i]; for(let c=i;c<3;c++) M[r][c]-=f*M[i][c]; B[r]-=f*B[i]; }
    }
    return B;
  }
  const sx=solve(A,bx), sy=solve(A,by);
  if(!sx || !sy) return null;
  return { sx, sy };
}
function fleetApplyAffine(x,y){
  const aff=fleetSolveAffine(FLEET_SYNC_POINTS);
  if(!aff) return null;
  return { x:aff.sx[0]*x + aff.sx[1]*y + aff.sx[2], y:aff.sy[0]*x + aff.sy[1]*y + aff.sy[2] };
}
function fleetApplyLocalResidual(x,y,p){
  // Affine gets the global crop/rotation/scale correct. This residual layer removes remaining
  // DLK crop/warp drift near each clicked anchor without breaking the rest of the map.
  if(!FLEET_SYNC_POINTS || FLEET_SYNC_POINTS.length < 4) return p;
  let sum=0, dx=0, dy=0;
  FLEET_SYNC_POINTS.forEach(sp=>{
    const pred = fleetApplyAffine(sp.worldX, sp.worldY) || fleetBasePointXY(sp.worldX, sp.worldY);
    const rx = Number(sp.mapX) - Number(pred.x), ry = Number(sp.mapY) - Number(pred.y);
    const dist = Math.hypot((x-Number(sp.worldX))/80, (y-Number(sp.worldY))/80);
    const w = 1 / Math.pow(Math.max(dist, 0.08), 2.1);
    if(isFinite(w) && isFinite(rx) && isFinite(ry)){ sum += w; dx += rx*w; dy += ry*w; }
  });
  if(sum > 0){ p = { x:p.x + dx/sum, y:p.y + dy/sum }; }
  return p;
}


function fleetSaveView(){
  try{
    localStorage.setItem('san_mdt_fleet_selected_live', fleetSelectedId || '');
    localStorage.setItem('san_mdt_fleet_map_x', String(fleetMapView.x || 0));
    localStorage.setItem('san_mdt_fleet_map_y', String(fleetMapView.y || 0));
    localStorage.setItem('san_mdt_fleet_map_zoom', String(fleetMapView.zoom || 1));
  }catch(e){}
}
function fleetUnitId(u){ return String(u && (u.id || u.plate || u.source) || ''); }
function fleetUnitService(u){ return String((u && (u.service || u.kind)) || 'police').toLowerCase()==='ems'?'ems':'police'; }
function fleetAllUnits(){
  return (fleetUnits || []).filter(u => {
    if(!u || !fleetUnitId(u)) return false;
    const s=fleetUnitService(u);
    return fleetShowOtherService ? s !== fleetViewerService : s === fleetViewerService;
  });
}
function fleetAllRawUnits(){ return (fleetUnits || []).filter(u => u && fleetUnitId(u)); }
function fleetOtherServiceLabel(){ return fleetViewerService==='ems' ? 'Politi' : 'EMS'; }
function fleetSelectedUnit(){ const all=fleetAllUnits(); return all.find(u => fleetUnitId(u) === fleetSelectedId) || all[0] || null; }
function fleetStatusClass(u){ const st=String((u&&u.status)||'online').toLowerCase(); if(st.includes('service')) return 'service'; if(st.includes('opgave') || st.includes('busy')) return 'busy'; return 'available'; }
function fleetMapPoint(u){
  const x=Number(u&&u.x), y=Number(u&&u.y);
  if(!isFinite(x) || !isFinite(y)) return null;
  const p = fleetBasePointXY(x,y);
  const px = Math.max(-5, Math.min(105, Number(p.x)));
  const py = Math.max(-5, Math.min(105, Number(p.y)));
  return { x:px, y:py, rawX:x, rawY:y, lat:p.lat, lng:p.lng, syncPoints:0 };
}
function fleetNudgeCalibration(dx,dy){
  try{ toast({type:'info', title:'Brug ALT+klik sync', message:'V4 bruger ikke længere manuel nudge. Vælg en bil, hold ALT og klik bilens præcise sted på mappet.'}); }catch(e){}
}
function fleetJoinedArray(u){ const joined=(u&&u.joined)||{}; return Object.keys(joined).map(k=>joined[k]).filter(Boolean); }
function fleetOfficerBadgeRaw(v, division){
  if(v && typeof v === 'object') return formatPoliceBadge(v.badge || v.pnumber, v.division || division) || '?';
  const badge = formatPoliceBadge(v, division);
  return badge || '?';
}
function fleetOfficerDisplayName(j){
  const name = String((j&&(j.name || j.fullname || j.characterName || j.officerName || ((j.firstName||j.firstname||'')+' '+(j.lastName||j.lastname||'')))) || '').trim().replace(/\s+/g,' ');
  const badge = fleetOfficerBadgeRaw(j, j && j.division);
  return (name && name !== 'undefined') ? `${name} (${badge})` : `Betjent (${badge})`;
}
function fleetCrewListHtml(u){
  const arr=fleetJoinedArray(u);
  if(!arr.length) return '<div class="fleet-crew-empty">Ingen aktive betjente tilmeldt</div>';
  return `<div class="fleet-crew-scroll">${arr.map(j=>`<div class="fleet-crew-person"><span>${escapeHtml(fleetOfficerDisplayName(j))}</span></div>`).join('')}</div>`;
}

function fleetOfficerKey(o){ return String(o && (o.identifier || o.id || o.source || o.badge || o.name) || ''); }
function fleetSelfJoined(u){
  const joined=(u&&u.joined)||{};
  if(fleetSelfIdentifier && joined[fleetSelfIdentifier]) return true;
  return Object.keys(joined).some(k=>{ const j=joined[k]||{}; return String(j.source||'') && fleetOfficers.some(o=>String(o.source||'')===String(j.source||'') && String(o.identifier||'')===fleetSelfIdentifier); });
}
function fleetDutyOfficersHtml(){
  const officers=(fleetOfficers||[]).filter(Boolean);
  const dutyButton = !fleetSelfOnDuty ? `<button class="fleet-duty-join" id="fleetGoOnDutyBtn">Gå på arbejde</button><div class="fleet-duty-hint">Du skal gå på arbejde før du kan tilmelde dig en patrulje.</div>` : '';
  if(!officers.length) return `<div class="fleet-duty-empty">Ingen betjente er på arbejde.</div>${dutyButton}`;
  const assigned={};
  (fleetUnits||[]).forEach(u=>Object.values((u&&u.joined)||{}).forEach(j=>{ if(j&&j.source) assigned[String(j.source)]=u.callsign||u.plate||'Patrulje'; }));
  return `${dutyButton}<div class="fleet-duty-list">${officers.map(o=>{
    const badge=fleetOfficerBadgeRaw(o, o.division);
    const name=escapeHtml(String(o.name||o.fullname||o.characterName||'Betjent'));
    const unit=assigned[String(o.source||'')];
    const st=unit?`I ${escapeHtml(unit)}`:'Ikke tilmeldt patrulje';
    return `<div class="fleet-duty-person ${unit?'assigned':'unassigned'}"><b>${name} <em>(${escapeHtml(badge)})</em></b><span>${st}</span></div>`;
  }).join('')}</div>`;
}
function fleetDispatchResponders(d){
  return d && d.responders ? Object.values(d.responders).filter(Boolean) : [];
}
function fleetCurrentUnitResponding(d){
  const u=fleetSelectedUnit();
  if(!u || !d) return false;
  const uid=String(fleetUnitId(u));
  const cs=String(u.callsign||'');
  const plate=String(u.plate||'');
  const responders=fleetDispatchResponders(d);
  return responders.some(r=>{
    const rid=String(r.unitId||r.id||r.plate||'');
    const rcs=String(r.callsign||'');
    return (rid && (rid===uid || rid===plate)) || (rcs && cs && rcs===cs);
  }) || (d.assignedUnit && String(d.assignedUnit)===uid) || (d.assignedCallsign && cs && String(d.assignedCallsign)===cs);
}
function fleetFormatPNumber(v, division){
  if(!String(v || '').trim()) return '';
  return formatPoliceBadge(v, division);
}
function fleetFormatPlate(v){
  const raw=String(v||'').trim().toUpperCase().replace(/\s+/g,' ');
  return raw || 'UKENDT';
}
function fleetBadgeRow(u){
  const arr=fleetJoinedArray(u);
  const plate = fleetFormatPlate(u && (u.plate || u.id));
  const names = arr.length ? arr.map(j=>`<span class="fleet-joined-pill">${escapeHtml(fleetOfficerDisplayName(j))}</span>`).join('') : '<span class="fleet-not-joined">Ingen tilmeldt</span>';
  return `${names}<span class="fleet-plate-pill">${escapeHtml(plate)}</span>`;
}
function fleetJoinedText(u){
  const arr=fleetJoinedArray(u);
  if(!arr.length) return '<span class="fleet-not-joined">Klik på cardet for at tilmelde dig</span>';
  return arr.map(j=>`<span class="fleet-joined-pill">${escapeHtml(fleetOfficerDisplayName(j))}</span>`).join('<span class="fleet-plus">+</span>');
}

const MDT_MAP_SOURCES = ['img/dlk-satellite-map.jpg', 'img/dlk-master-4096x6144.png', 'img/satellite-map.png'];
function loadMapImageIntoLayer(layer, statusEl, readyLabel){
  if(!layer || layer.dataset.ready === '1') return;
  layer.dataset.ready = '1';
  layer.innerHTML = '';
  const img = document.createElement('img');
  img.className = 'fleet-dlk-fullmap allow-fleet-img';
  img.alt = 'Satellitkort';
  img.draggable = false;
  let idx = 0;
  const tryNext = () => {
    if(idx >= MDT_MAP_SOURCES.length){
      if(statusEl) statusEl.textContent = 'Kort mangler — læg dlk-satellite-map.jpg i nui/img/';
      layer.innerHTML = '<div class="nsk-map-fallback">Satellitkort kunne ikke indlæses</div>';
      return;
    }
    img.src = MDT_MAP_SOURCES[idx++];
  };
  img.onload = () => { if(statusEl) statusEl.textContent = readyLabel || 'Satellitkort indlæst'; };
  img.onerror = tryNext;
  tryNext();
  layer.appendChild(img);
}
function buildFleetTiles(){
  loadMapImageIntoLayer($('#fleetTileLayer'), $('#fleetMapTileStatus'), 'DLK full map loaded · V10 OX CRS projection');
}
function applyFleetMapView(){
  const map=$('#fleetMap'), canvas=$('#fleetMapCanvas'); if(!map || !canvas) return;
  fleetMapView.zoom=Math.max(1,Math.min(5,Number(fleetMapView.zoom)||1));
  fleetMapView.x=Number(fleetMapView.x)||0; fleetMapView.y=Number(fleetMapView.y)||0;
  const r=map.getBoundingClientRect();
  const cw=canvas.offsetWidth || r.width;
  const ch=canvas.offsetHeight || r.height;
  const sw=cw*fleetMapView.zoom;
  const sh=ch*fleetMapView.zoom;
  if(sw <= r.width){ fleetMapView.x=(r.width-sw)/2; }
  else { fleetMapView.x=Math.min(0,Math.max(r.width-sw,fleetMapView.x)); }
  if(sh <= r.height){ fleetMapView.y=(r.height-sh)/2; }
  else { fleetMapView.y=Math.min(0,Math.max(r.height-sh,fleetMapView.y)); }
  canvas.style.transform=`translate3d(${fleetMapView.x}px,${fleetMapView.y}px,0) scale(${fleetMapView.zoom})`;
}
function ensureFleetMap(){
  const map=$('#fleetMap'); if(!map) return;
  if(fleetMapBuilt && map.querySelector('#fleetTileLayer') && map.querySelector('#fleetMapPins')) return;
  map.querySelectorAll('.fleet-map-img,.fleet-overlay,.fleet-old-overlay,.fleet-static-map,.fleet-hardcoded-blips,.fleet-map-render,img,[class*="dummy"],[class*="old"]').forEach(el=>el.remove());
  map.innerHTML = `
    <div id="fleetMapWorld" class="fleet-map-world" data-stack="v10-ox-crs-simple">
      <div id="fleetMapCanvas" class="fleet-map-canvas" data-map-aspect="4096x6144-v10-ox">
        <div id="fleetTileLayer" class="fleet-tile-layer" data-render-layer="dlk-tile-map"></div>
        <svg id="fleetTerritoryLayer" class="fleet-territory-layer nsk-territory-layer" viewBox="0 0 100 100" preserveAspectRatio="none"></svg>
        <div class="fleet-map-grid"></div>
        <div id="fleetMapPins" data-vehicle-layer="legacy-hidden"></div>
        <div id="fleetSyncAnchors" class="fleet-sync-anchor-layer"></div>
        <div id="mdtCleanBlips" class="mdt-clean-blip-layer" data-clean-blips="v10-ox"></div>
      </div>
    </div>
    <div class="fleet-map-stats"><span><b id="fleetStatTotal">0</b> Enheder</span><span class="online"><b id="fleetStatOnline">0</b> Online</span><span class="busy"><b id="fleetStatBusy">0</b> I opgave</span><span class="offline"><b id="fleetStatService">0</b> Service</span></div>
    <div class="fleet-map-controls"><button data-fleet-zoom="in">+</button><button data-fleet-zoom="out">−</button><button data-fleet-center="1">⌖</button></div>
    <div class="fleet-map-layers"><button>Kort</button><button class="active">Satellit</button><button>Hybrid</button><button>Terrain</button></div>
    <div id="fleetMapTileStatus" class="fleet-map-tile-status">DLK minimap loader...</div>
    <div class="fleet-map-hint">V10 OX CRS: GTA coords → CRS.Simple → MDT blips · Klik ➤ for at centrere</div>
    <div class="fleet-map-powered">San MDT · V10 OX CRS Map</div>`;
  fleetMapBuilt=true;
  buildFleetTiles();
  applyFleetMapView();
}
function fleetAutoFitUnits(units){
  const map=$('#fleetMap'), canvas=$('#fleetMapCanvas'); if(!map || !canvas || !units || !units.length) return;
  const pts=units.map(fleetMapPoint).filter(Boolean); if(!pts.length) return;
  const minX=Math.min(...pts.map(p=>p.x)), maxX=Math.max(...pts.map(p=>p.x));
  const minY=Math.min(...pts.map(p=>p.y)), maxY=Math.max(...pts.map(p=>p.y));
  const rect=map.getBoundingClientRect(); const cw=canvas.offsetWidth || rect.width; const ch=canvas.offsetHeight || rect.height;
  const pad=12;
  const spanX=Math.max(4,maxX-minX), spanY=Math.max(4,maxY-minY);
  const zoom=Math.max(1,Math.min(4, Math.min((100/spanX)*(1-pad/100), (100/spanY)*(1-pad/100))));
  const cx=(minX+maxX)/2, cy=(minY+maxY)/2;
  fleetMapView.zoom=zoom;
  fleetMapView.x=(rect.width/2)-(cw*(cx/100)*fleetMapView.zoom);
  fleetMapView.y=(rect.height/2)-(ch*(cy/100)*fleetMapView.zoom);
  applyFleetMapView();
}
function centerFleetOnUnit(u){
  const map=$('#fleetMap'), canvas=$('#fleetMapCanvas'); if(!map || !canvas || !u) return;
  const p=fleetMapPoint(u); if(!p) return;
  const rect=map.getBoundingClientRect();
  const cw=canvas.offsetWidth || rect.width;
  const ch=canvas.offsetHeight || rect.height;
  fleetMapView.x=(rect.width/2)-(cw*(p.x/100)*fleetMapView.zoom);
  fleetMapView.y=(rect.height/2)-(ch*(p.y/100)*fleetMapView.zoom);
  fleetSaveView(); applyFleetMapView();
}

function fleetMapClientToPercent(clientX, clientY){
  const canvas = document.querySelector('#fleetMapCanvas');
  if(!canvas) return null;
  const rect = canvas.getBoundingClientRect();
  const x = ((clientX - rect.left) / rect.width) * 100;
  const y = ((clientY - rect.top) / rect.height) * 100;
  if(!isFinite(x)||!isFinite(y)) return null;
  return { x:Math.max(0,Math.min(100,x)), y:Math.max(0,Math.min(100,y)) };
}
function fleetAddSyncPointFromEvent(e){
  const selected = fleetSelectedUnit();
  if(!selected || !isFinite(Number(selected.x)) || !isFinite(Number(selected.y))){
    try{ toast({type:'error', title:'Ingen valgt live-bil', message:'Vælg bilen i MDT-listen først, og klik derefter ALT+klik på dens korrekte position.'}); }catch(_){ }
    return false;
  }
  const mp = fleetMapClientToPercent(e.clientX, e.clientY);
  if(!mp) return false;
  FLEET_SYNC_POINTS.push({
    worldX:Number(selected.x), worldY:Number(selected.y), mapX:mp.x, mapY:mp.y,
    label:String(selected.callsign || selected.plate || selected.id || 'unit'),
    t:Date.now()
  });
  if(FLEET_SYNC_POINTS.length > 24) FLEET_SYNC_POINTS = FLEET_SYNC_POINTS.slice(-24);
  fleetSaveCalibration();
  renderFleet();
  try{ toast({type:'success', title:'Map sync punkt gemt', message:`${FLEET_SYNC_POINTS.length} punkt(er). Brug mindst 4, gerne 6-8 fordelt rundt på øen.`}); }catch(_){ }
  return true;
}
function fleetRenderSyncAnchors(){
  const layer = document.querySelector('#fleetSyncAnchors');
  const status = document.querySelector('#fleetMapTileStatus');
  if(status) status.textContent = `DLK full map · V4 anchor sync · ${FLEET_SYNC_POINTS.length} punkt(er)`;
  if(!layer) return;
  layer.innerHTML = (FLEET_SYNC_POINTS||[]).map((p,i)=>`<div class="fleet-sync-anchor" style="left:${Number(p.mapX).toFixed(5)}%;top:${Number(p.mapY).toFixed(5)}%" title="Sync ${i+1}: ${escapeHtml(p.label||'punkt')}\nX ${Math.round(Number(p.worldX)||0)} Y ${Math.round(Number(p.worldY)||0)}">${i+1}</div>`).join('');
}
function ensureFleetTerritoryLayer(){
  const canvas = $('#fleetMapCanvas');
  if(!canvas) return;
  if(canvas.querySelector('#fleetTerritoryLayer')) return;
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.id = 'fleetTerritoryLayer';
  svg.setAttribute('class', 'fleet-territory-layer nsk-territory-layer');
  svg.setAttribute('viewBox', '0 0 100 100');
  svg.setAttribute('preserveAspectRatio', 'none');
  const blips = $('#mdtCleanBlips');
  if(blips) canvas.insertBefore(svg, blips);
  else canvas.appendChild(svg);
}
async function loadFleetGangTerritories(){
  if(fleetTerritoriesLoading) return fleetGangTerritories;
  fleetTerritoriesLoading = true;
  try{
    const r = await nui('getFleetGangTerritories', {});
    if(r && r.ok) fleetGangTerritories = r.territories || [];
    else if(r?.message) toast(r.message);
  } catch(e){
    console.error('[SAN MDT] fleet gang territories failed', e);
  } finally {
    fleetTerritoriesLoading = false;
  }
  return fleetGangTerritories;
}
function renderFleetTerritoryOverlay(){
  ensureFleetTerritoryLayer();
  const map = $('#fleetMap');
  const svg = $('#fleetTerritoryLayer');
  if(!svg) return;
  if(map) map.classList.toggle('fleet-territories-on', !!fleetShowGangTerritories);
  if(!fleetShowGangTerritories){
    svg.innerHTML = '';
    svg.style.display = 'none';
    return;
  }
  svg.style.display = '';
  const territories = fleetGangTerritories || [];
  svg.innerHTML = territories.length ? territories.map((t) => {
    const verts = nskTerritoryResolveVertices(t);
    if(verts.length < 3) return '';
    const color = t.color || t.gang_color || '#00e6b7';
    const points = nskTerritoryPolyPoints(verts);
    const c = nskTerritoryCentroid(verts);
    const label = escapeHtml((t.gang_name || t.name || 'Zone').slice(0, 14));
    return `<g class="fleet-territory-group">
      <polygon class="fleet-territory-poly" points="${points}" fill="${escapeHtml(color)}" fill-opacity="0.14" stroke="${escapeHtml(color)}" stroke-width="0.34"></polygon>
      <text x="${c.px}" y="${c.py}" text-anchor="middle" dominant-baseline="middle" fill="#fff" font-size="0.9" font-weight="700" stroke="rgba(0,0,0,.65)" stroke-width="0.1" paint-order="stroke">${label}</text>
    </g>`;
  }).join('') : '';
}
async function setFleetGangTerritoriesEnabled(enabled){
  fleetShowGangTerritories = !!enabled;
  localStorage.setItem('san_mdt_fleet_gang_territories', fleetShowGangTerritories ? '1' : '0');
  const toggle = $('#fleetGangTerritoriesToggle');
  if(toggle) toggle.checked = fleetShowGangTerritories;
  if(fleetShowGangTerritories){
    await loadFleetGangTerritories();
    if(!fleetGangTerritories.length) toast('Ingen registrerede bande territorier endnu.');
  }
  renderFleetTerritoryOverlay();
}
function renderFleet(){
  ensureFleetMap();
  const all=fleetAllUnits();
  const rawAll=fleetAllRawUnits();
  const otherCount=rawAll.filter(u=>fleetUnitService(u)!==fleetViewerService).length;
  const ownCount=rawAll.filter(u=>fleetUnitService(u)===fleetViewerService).length;
  const head=document.querySelector('.fleet-right .fleet-live-panel-head, .fleet-live-side .fleet-live-panel-head');
  if(head && !document.getElementById('fleetServiceToggleBtn')){
    const btn=document.createElement('button');
    btn.id='fleetServiceToggleBtn';
    btn.className='fleet-live-ghost fleet-service-toggle';
    btn.onclick=()=>{ fleetShowOtherService=!fleetShowOtherService; localStorage.setItem('san_mdt_show_other_service', fleetShowOtherService?'1':'0'); fleetSelectedId=''; renderFleet(); };
    head.appendChild(btn);
  }
  const serviceBtn=document.getElementById('fleetServiceToggleBtn');
  if(serviceBtn) serviceBtn.textContent = fleetShowOtherService ? ('Se '+(fleetViewerService==='ems'?'EMS':'Politi')+' ('+ownCount+')') : ('Se '+fleetOtherServiceLabel()+' ('+otherCount+')');
  if(!all.some(u=>fleetUnitId(u)===fleetSelectedId)) fleetSelectedId=all[0]?fleetUnitId(all[0]):'';
  const q=($('#fleetSearch')?.value||'').toLowerCase();
  const filtered=all.filter(u=>!q || [u.plate,u.model,u.driver,u.callsign,u.status].join(' ').toLowerCase().includes(q));
  if($('#fleetVehicleCount')) $('#fleetVehicleCount').textContent=all.length;
  if($('#fleetLastUpdate')) $('#fleetLastUpdate').textContent='Live · '+new Date().toLocaleTimeString('da-DK');
  const online=all.filter(u=>fleetStatusClass(u)==='available').length;
  const busy=all.filter(u=>fleetStatusClass(u)==='busy').length;
  const service=all.filter(u=>fleetStatusClass(u)==='service').length;
  if($('#fleetStatTotal')) $('#fleetStatTotal').textContent=all.length;
  if($('#fleetStatOnline')) $('#fleetStatOnline').textContent=online;
  if($('#fleetStatBusy')) $('#fleetStatBusy').textContent=busy;
  if($('#fleetStatService')) $('#fleetStatService').textContent=service;
  const calReadout=$('#fleetCalReadout');
  if(calReadout){
    const sel=fleetSelectedUnit();
    const p=sel?fleetMapPoint(sel):null;
    calReadout.textContent = `${sel&&p?`OX CRS · ${Math.round(Number(sel.x)||0)},${Math.round(Number(sel.y)||0)} → ${p.x.toFixed(2)}%,${p.y.toFixed(2)}%`: 'OX CRS · ingen valgt enhed'}`;
  }

  const list=$('#fleetUnits');
  const unitsPanelHead=document.querySelector('.fleet-live-units-panel .fleet-live-panel-head span');
  const fleetSearchInput=$('#fleetSearch');
  if(unitsPanelHead) unitsPanelHead.innerHTML = fleetShowCalls ? `OPKALD (<b id="fleetVehicleCount">${(fleetDispatches||[]).length}</b>)` : `KØRETØJER (<b id="fleetVehicleCount">${all.length}</b>)`;
  if(fleetSearchInput) fleetSearchInput.placeholder = fleetShowCalls ? 'Søg opkald, type eller lokation...' : 'Søg køretøj, call sign eller tjenestenummer...';
  if(list){
    if(fleetShowCalls){
      const dq=($('#fleetSearch')?.value||'').toLowerCase();
      const calls=(fleetDispatches||[]).filter(d=>!dq || [d.title,d.type,d.description,d.street,d.status,d.assignedCallsign].join(' ').toLowerCase().includes(dq));
      list.innerHTML = calls.length ? calls.map(d=>{
        const responders = fleetDispatchResponders(d);
        const responderText = responders.length ? responders.map(r=>r.callsign||r.unitId||'Patrulje').join(', ') : (d.assignedCallsign || 'Ledig');
        const assigned = responders.length ? `${responders.length} patrulje(r): ${escapeHtml(responderText)}` : 'Ledig';
        const status = String(d.status||'Ny');
        const takenByUs = fleetCurrentUnitResponding(d);
        const cls = responders.length || d.assignedUnit ? 'busy' : 'available';
        const age = d.createdAt ? Math.max(0, Math.floor((Date.now()/1000 - Number(d.createdAt))/60)) : 0;
        const count = Number(d.count||1);
        const pending = fleetDispatchPending.has(String(d.id));
        return `<article class="fleet-unit-card fleet-call-card ${cls} ${takenByUs?'taken-by-us':''}" data-dispatch-card="${escapeHtml(d.id)}">
          <div class="fleet-unit-top"><b>🔴 ${escapeHtml(d.title||'Opkald')}${count>1?` <em class="fleet-call-count">x${count}</em>`:''}</b><div class="fleet-unit-actions"><button class="fleet-track-btn" data-dispatch-center="${escapeHtml(d.id)}" title="Find på kort">⌖</button></div></div>
          <div class="fleet-tags"><span class="${cls}">${escapeHtml(status)}</span><span>${assigned}</span><span>${age} min</span></div>
          <div class="fleet-driver">${escapeHtml(d.street||d.description||'Ukendt lokation')}</div>
          <div class="fleet-meta"><span>X ${Math.round(Number(d.x)||0)} · Y ${Math.round(Number(d.y)||0)}</span><span>${escapeHtml(d.id||'')}</span></div>
          <div class="fleet-call-actions"><button class="${takenByUs?'accepted':''}" ${pending?'disabled':''} data-dispatch-accept="${escapeHtml(d.id)}">${pending?'Sender...':(takenByUs?'Opgave taget':'Tag opgave')}</button><button data-dispatch-gps="${escapeHtml(d.id)}">Sæt GPS</button><button data-dispatch-details="${escapeHtml(d.id)}">Detaljer</button>${(responders.length||d.assignedUnit)?`<button ${pending?'disabled':''} data-dispatch-finish="${escapeHtml(d.id)}">Afslut</button>`:''}</div>
        </article>`;
      }).join('') : '<div class="fleet-empty">Ingen aktive opkald.<br><small>Skud og køretøjstyveri opretter automatisk røde opkald her. Flere hændelser tæt på hinanden kobles sammen til samme opkald.</small></div>';
    } else {
      list.innerHTML = filtered.length ? filtered.map(u=>{
        const id=fleetUnitId(u), active=id===fleetSelectedId?' active':'', cls=fleetStatusClass(u), speed=Math.round(Number(u.speed)||0), joined=fleetJoinedArray(u).length;
        const taskCount=Number(u.taskCount||0);
        const taskText=taskCount===1?'1 opgave':`${taskCount} opgaver`;
        const selfIn=fleetSelfJoined(u);
        return `<article class="fleet-unit-card${active} ${selfIn?'joined-by-me':''}" data-fleet-select="${escapeHtml(id)}">
          <div class="fleet-unit-top"><b>${escapeHtml(u.callsign || 'Patrulje')}</b><div class="fleet-unit-actions"><button class="fleet-settings-btn" data-fleet-settings="${escapeHtml(id)}" title="Indstil patrulje">⚙</button><button class="fleet-track-btn" data-fleet-center-unit="${escapeHtml(id)}" title="Følg GPS">➤</button></div></div>
          <div class="fleet-tags"><span class="${cls}">${cls==='busy'?'PÅ OPGAVE':cls==='service'?'Service':'Online'}</span><span>${escapeHtml(taskText)}</span></div>
          <div class="fleet-meta"><span>${speed} km/t</span><span>X ${Math.round(Number(u.x)||0)} · Y ${Math.round(Number(u.y)||0)}</span></div>
          <button class="fleet-join-btn ${selfIn?'leave':''}" data-fleet-join="${escapeHtml(id)}">${selfIn?'Forlad patrulje':'Tilmeld patrulje'}</button>
          <div class="fleet-crew-title">Aktive betjente i patruljen</div>
          ${fleetCrewListHtml(u)}
        </article>`;
      }).join('') : '<div class="fleet-empty">Ingen aktive køretøjer i denne visning.<br><small>Brug Se EMS/Se Politi for at skifte mellem egen tjeneste og den anden tjeneste. Kun egen tjeneste kan tilgås/tilmeldes.</small></div>';
      list.innerHTML += `<div class="fleet-duty-box"><div class="fleet-duty-title">Betjente på arbejde</div>${fleetDutyOfficersHtml()}</div>`;
    }
  }

  const pins=$('#mdtCleanBlips');
  if(pins){
    // V30 CLEAN MAP: one dedicated overlay layer. No Leaflet pins, no old span/CSS marker stack.
    // GTA/FiveM world coords -> DLK minimap percent coords. X is horizontal, Y is vertical inverted.
    const wanted = new Set();
    const upsertCleanBlip = (kind, id, p, cls, title, data)=>{
      if(!p) return;
      const key = kind + ':' + id;
      wanted.add(key);
      let el = null;
      const nodes = pins.querySelectorAll('[data-clean-key]');
      for(let i=0;i<nodes.length;i++){ if(nodes[i].dataset.cleanKey === key){ el = nodes[i]; break; } }
      if(!el){
        el = document.createElement('button');
        el.type = 'button';
        el.className = 'mdt-clean-blip';
        el.dataset.cleanKey = key;
        pins.appendChild(el);
      }
      el.className = 'mdt-clean-blip ' + cls;
      el.style.left = p.x.toFixed(6) + '%';
      el.style.top = p.y.toFixed(6) + '%';
      el.style.setProperty('--heading', (Number(data&&data.heading)||0) + 'deg');
      el.title = title || '';
      if(kind === 'dispatch'){
        el.innerHTML = '<span class="mdt-clean-dispatch">!</span>';
        el.dataset.dispatchAccept = id; delete el.dataset.fleetSelect;
      } else {
        const ems = (cls || '').indexOf('ems') !== -1;
        el.innerHTML = ems ?
          `<svg class="mdt-clean-car-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M5.1 15.9h13.8c1.25 0 2.25-1 2.25-2.25v-2.2c0-.98-.62-1.85-1.55-2.14l-1.5-.47-1.55-2.65A3.05 3.05 0 0 0 13.92 4.7H8.08c-1.08 0-2.08.57-2.63 1.49L3.9 8.84l-1.5.47A2.25 2.25 0 0 0 .85 11.45v2.2c0 1.25 1 2.25 2.25 2.25h2Z" fill="#ffd331" stroke="#2b2100" stroke-width="1.05" stroke-linejoin="round"/><path d="M7.3 7.05h9.4l1.13 2.08H6.17L7.3 7.05Z" fill="#fff3a8" opacity=".95"/><circle cx="5.7" cy="16" r="1.9" fill="#2b2100"/><circle cx="18.3" cy="16" r="1.9" fill="#2b2100"/><circle cx="5.7" cy="16" r=".75" fill="#fffbe5" opacity=".9"/><circle cx="18.3" cy="16" r=".75" fill="#fffbe5" opacity=".9"/></svg>` :
          `<svg class="mdt-clean-car-svg" viewBox="0 0 24 24" aria-hidden="true"><path d="M5.1 15.9h13.8c1.25 0 2.25-1 2.25-2.25v-2.2c0-.98-.62-1.85-1.55-2.14l-1.5-.47-1.55-2.65A3.05 3.05 0 0 0 13.92 4.7H8.08c-1.08 0-2.08.57-2.63 1.49L3.9 8.84l-1.5.47A2.25 2.25 0 0 0 .85 11.45v2.2c0 1.25 1 2.25 2.25 2.25h2Z" fill="#1e9bff" stroke="#082033" stroke-width="1.05" stroke-linejoin="round"/><path d="M7.3 7.05h9.4l1.13 2.08H6.17L7.3 7.05Z" fill="#b7e8ff" opacity=".95"/><circle cx="5.7" cy="16" r="1.9" fill="#082033"/><circle cx="18.3" cy="16" r="1.9" fill="#082033"/><circle cx="5.7" cy="16" r=".75" fill="#e7fbff" opacity=".9"/><circle cx="18.3" cy="16" r=".75" fill="#e7fbff" opacity=".9"/></svg>`;
        el.dataset.fleetSelect = id; delete el.dataset.dispatchAccept;
      }
    };
    all.forEach(u=>{
      const p=fleetMapPoint(u); if(!p) return;
      const id=fleetUnitId(u), active=id===fleetSelectedId?' active':'', service=(String(u.service||u.kind||'police').toLowerCase()==='ems'?' ems':' police'), emergency=(u.siren===true||u.siren==='true'||u.emergency===true?' emergency':'');
      const cls='vehicle'+active+service+emergency;
      const speed=Math.round(Number(u.speed)||0);
      upsertCleanBlip('vehicle', id, p, cls, `${u.plate||''} · ${speed} km/t · ${u.driver||''}`, {heading:u.heading});
    });
    if(fleetShowCalls){
      (fleetDispatches||[]).forEach(d=>{
        const p=fleetMapPoint(d); if(!p) return;
        upsertCleanBlip('dispatch', String(d.id||''), p, 'dispatch', `${d.title||'Opkald'} · ${d.status||'Ny'}`, {heading:0});
      });
    }
    pins.querySelectorAll('[data-clean-key]').forEach(el=>{ if(!wanted.has(el.dataset.cleanKey)) el.remove(); });
  }

  if(all.length && (!fleetSelectedId || !localStorage.getItem('san_mdt_fleet_map_x'))) { try{ fleetAutoFitUnits(all); }catch(e){} }

  const box=$('#fleetInfoBox');
  if(box){
    // V100: bottom overview panels removed. Active officers now live inside each vehicle card.
    box.className='fleet-alerts-row fleet-alerts-row-hidden';
    box.innerHTML='';
  }
  renderFleetTerritoryOverlay();
  fleetSaveView();
}
async function refreshFleet(){
  if(fleetRefreshInFlight) return;
  fleetRefreshInFlight = true;
  try{
    const r=await nui('getFleetData',{});
    fleetUnits=(r&&r.units)||[];
    fleetOfficers=(r&&r.officers)||[];
    fleetDispatches=(r&&r.dispatches)||[]; if(sanDispatchPanelOpen) renderDispatchPanel();
    fleetViewerService=(r&&r.viewerService)||fleetViewerService||'police';
    fleetSelfIdentifier=String((r&&(r.selfIdentifier||r.identifier))||'');
    fleetSelfOnDuty=!!(r&&r.selfOnDuty);
    fleetSelfOfficer=(r&&r.selfOfficer)||null;
    try{localStorage.setItem('san_mdt_fleet_viewer_service', fleetViewerService)}catch(e){};
    if(fleetShowGangTerritories) await loadFleetGangTerritories();
    renderFleet();
  }
  catch(e){ console.error('[SAN MDT] fleet refresh failed', e); renderFleet(); }
  finally { fleetRefreshInFlight = false; }
  if(activePage === 'fleet') startFleetPolling();
  else stopFleetPolling();
}
async function fleetGoOnDuty(){
  const btn=$('#fleetGoOnDutyBtn');
  if(btn){ btn.disabled=true; btn.textContent='Tilmeldes...'; }
  const r=await nui('setDutyStatus', { onDuty:true }).catch(()=>null);
  if(!r || !r.ok){ if(btn){ btn.disabled=false; btn.textContent='Gå på arbejde'; } return toast((r&&r.message)||'Kunne ikke gå på arbejde.'); }
  toast('Du er nu på arbejde.');
  await refreshFleet();
  return true;
}
async function toggleFleetUnit(unitId){
  const selected=unitId?fleetAllUnits().find(u=>fleetUnitId(u)===unitId):fleetSelectedUnit();
  if(!selected) return toast('Vælg et aktivt køretøj først.');
  if(!fleetSelfOnDuty){
    const ok = await fleetGoOnDuty();
    if(!ok) return;
  }
  const r=await nui('toggleFleetUnit',{unitId:fleetUnitId(selected)});
  if(!r || !r.ok) return toast((r&&r.message)||'Kunne ikke opdatere enhed.');
  await refreshFleet();
}

async function updateFleetUnitSettings(unitId){
  const selected=fleetAllUnits().find(u=>fleetUnitId(u)===unitId) || fleetSelectedUnit();
  if(!selected) return toast('Vælg et aktivt køretøj først.');
  const currentCategory=String(selected.category||'patrulje').toLowerCase();
  const category=(prompt('Kategori: patrulje, motorcykel eller civil', currentCategory) || currentCategory).toLowerCase().trim();
  if(category === '') return;
  const callsign=prompt('Patrulje titel / callsign', selected.callsign || '') || '';
  const r=await nui('updateFleetUnitSettings',{unitId:fleetUnitId(selected), category, callsign});
  if(!r || !r.ok) return toast((r&&r.message)||'Kunne ikke gemme patrulje-info.');
  await refreshFleet();
}



// SAN MDT Audit Logs UI V1
let auditLogs = [];
let auditCategories = ['Alle','Aflytning','Administration','Hændelser','Køretøjer'];
const auditActionLabels = {
  WIRETAP_STARTED:'Startede aflytning', WIRETAP_STOPPED:'Stoppede aflytning', WIRETAP_ACCESS_GRANTED:'Gav aflytningsadgang',
  INCIDENT_DELETED:'Slettede hændelse',
  INCIDENT_FINE_ISSUED:'Udstedte bøde fra hændelse',
  EMPLOYEE_UPDATED:'Opdaterede ansat', EMPLOYEE_FIRED:'Afskedigede ansat', EMPLOYEE_PERMISSIONS_SAVED:'Gemte ansat-permissions',
  ROLE_SAVED:'Gemte rolle', ROLE_DELETED:'Slettede rolle',
  VEHICLE_RELEASED:'Frigav køretøj fra impound'
};
function auditIcon(cat){ return ({Aflytning:'📡', Hændelser:'△', Køretøjer:'▣', Administration:'⚙', Ansatte:'⚙', Roller:'⚙'})[cat] || '●'; }
function auditLabel(a){ return auditActionLabels[a] || String(a||'Handling').replaceAll('_',' '); }
function auditMetaLine(log){
  const parts=[];
  if(log.target_label) parts.push(log.target_label); else if(log.target_id) parts.push(log.target_id);
  if(log.officer_badge) parts.push(log.officer_badge);
  return parts.map(escapeHtml).join(' · ');
}
function renderAuditCategoryCards(){
  const box=$('#auditCategoryCards'); if(!box) return;
  const counts={}; auditLogs.forEach(l=>counts[l.category]=(counts[l.category]||0)+1);
  const active=$('#auditCategory')?.value || 'Alle';
  box.innerHTML=auditCategories.map(c=>`<button class="mdt-log-cat ${active===c?'active':''}" data-audit-cat="${escapeHtml(c)}"><span>${auditIcon(c)}</span><b>${escapeHtml(c)}</b><small>${c==='Alle'?auditLogs.length:(counts[c]||0)}</small></button>`).join('');
}
function renderAuditTimeline(){
  const box=$('#auditTimeline'); if(!box) return;
  renderAuditCategoryCards();
  if(!auditLogs.length){ box.innerHTML='<div class="admin-empty">Ingen logs fundet.</div>'; return; }
  box.innerHTML=auditLogs.map(log=>{
    const meta=auditMetaLine(log);
    const msg=log.message || auditLabel(log.action);
    const data=log.metadata && Object.keys(log.metadata||{}).length ? `<details><summary>Metadata</summary><pre>${escapeHtml(JSON.stringify(log.metadata,null,2))}</pre></details>` : '';
    return `<article class="mdt-log-item" data-officer-id="${escapeHtml(log.officer_identifier||'')}">
      <div class="mdt-log-dot">${auditIcon(log.category)}</div>
      <div class="mdt-log-body"><div class="mdt-log-top"><b>${escapeHtml(auditLabel(log.action))}</b><span>${escapeHtml(fmtDate(log.created_at))}</span></div>
      <div class="mdt-log-officer">${escapeHtml(log.officer_name||'Ukendt')} ${log.officer_badge?`<em>${escapeHtml(log.officer_badge)}</em>`:''}</div>
      <p>${escapeHtml(msg)}</p>${meta?`<small>${meta}</small>`:''}${data}</div>
      <button class="ghost small" data-audit-officer="${escapeHtml(log.officer_identifier||'')}">Tidslinje</button>
    </article>`;
  }).join('');
}
async function refreshAuditLogs(){
  const cat=$('#auditCategory')?.value || 'Alle';
  const r=await nui('getAuditLogs',{ category:cat, officer:$('#auditOfficer')?.value||'', search:$('#auditSearch')?.value||'', limit:200 });
  if(r && r.ok){ auditLogs=r.logs||[]; auditCategories=r.categories||auditCategories; const sel=$('#auditCategory'); if(sel && !sel.dataset.ready){ sel.innerHTML=auditCategories.map(c=>`<option>${escapeHtml(c)}</option>`).join(''); sel.dataset.ready='1'; sel.value=cat; } renderAuditTimeline(); }
  else toast(r?.message || 'Kunne ikke hente MDT-Logs.');
}
async function openFleetUnitLogs(unitId){
  const u=fleetAllUnits().find(x=>fleetUnitId(x)===unitId) || {};
  const r=await nui('getFleetUnitLogs',{unitId});
  const logs=(r&&r.logs)||[];
  $('#modalTitle').textContent='Patrulje historik';
  $('#modalFields').innerHTML=`<div class="fleet-history-head"><b>${escapeHtml(u.callsign||u.plate||unitId)}</b><span>${escapeHtml(u.plate||'')}</span></div>`+(logs.length?logs.map(l=>`<div class="fleet-history-row"><b>${escapeHtml(auditLabel(l.action))}</b><small>${escapeHtml(fmtDate(l.created_at))} · ${escapeHtml(l.officer_name||'Ukendt')} ${l.officer_badge?escapeHtml(l.officer_badge):''}</small><p>${escapeHtml(l.message||'')}</p></div>`).join(''):'<div class="admin-empty">Ingen patrulje/dispatch logs endnu.</div>');
  $('#modalSave').textContent='Luk'; $('#modalSave').onclick=closeModal; $('#modal').classList.remove('hidden');
}
function initAuditLogs(){
  $('#auditRefresh') && ($('#auditRefresh').onclick=refreshAuditLogs);
  $('#auditSearch') && ($('#auditSearch').oninput=()=>{ clearTimeout(window.__auditSearch); window.__auditSearch=setTimeout(refreshAuditLogs,350); });
  $('#auditOfficer') && ($('#auditOfficer').oninput=()=>{ clearTimeout(window.__auditOfficer); window.__auditOfficer=setTimeout(refreshAuditLogs,350); });
  $('#auditCategory') && ($('#auditCategory').onchange=refreshAuditLogs);
  document.addEventListener('click', async e=>{
    const cat=e.target.closest('[data-audit-cat]'); if(cat){ const sel=$('#auditCategory'); if(sel){ sel.value=cat.dataset.auditCat; refreshAuditLogs(); } }
    const officer=e.target.closest('[data-audit-officer]'); if(officer && officer.dataset.auditOfficer){ const inp=$('#auditOfficer'); if(inp){ inp.value=officer.dataset.auditOfficer; refreshAuditLogs(); } }
    const news=e.target.closest('[data-open-newsmail]'); if(news){ openNewsMailModal(news.dataset.openNewsmail); }
    const openMail=e.target.closest('[data-open-mail-id]'); if(openMail){ openMailModalById(openMail.dataset.openMailId); }
    const mailProf=e.target.closest('[data-mail-profile]'); if(mailProf){ selectMailProfile(mailProf.dataset.mailProfile); }
    const newsReaders=e.target.closest('[data-news-readers]'); if(newsReaders){ openNewsReadersModal(newsReaders.dataset.newsReaders); }
  });
}
if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',initAuditLogs); else initAuditLogs();

function initFleet(){
  const joinBtn=$('#fleetNewTaskBtn'); if(joinBtn){ joinBtn.style.display='none'; joinBtn.onclick=null; }
  $('#fleetRefreshBtn') && ($('#fleetRefreshBtn').onclick=refreshFleet);
  $('#fleetAddServiceBtn') && ($('#fleetAddServiceBtn').style.display='none');
  $('#fleetAlertBtn') && ($('#fleetAlertBtn').style.display='none');
  $('#fleetAddVehicleBtn') && ($('#fleetAddVehicleBtn').style.display='none');
  $('#fleetSearch') && ($('#fleetSearch').oninput=()=>{ clearTimeout(window.__fleetSearchTimer); window.__fleetSearchTimer=setTimeout(renderFleet, 200); });
  $('#fleetMapToggle') && ($('#fleetMapToggle').onchange=(e)=>{ const p=$('.fleet-live-map-panel'); if(p) p.classList.toggle('hidden-map', !e.target.checked); });
  $('#fleetCallsToggle') && ($('#fleetCallsToggle').checked=fleetShowCalls, $('#fleetCallsToggle').onchange=(e)=>{ fleetShowCalls=!!e.target.checked; localStorage.setItem('san_mdt_show_calls', fleetShowCalls?'1':'0'); renderFleet(); });
  $('#fleetGangTerritoriesToggle') && ($('#fleetGangTerritoriesToggle').checked=fleetShowGangTerritories, $('#fleetGangTerritoriesToggle').onchange=(e)=>{ setFleetGangTerritoriesEnabled(e.target.checked); });
  if(fleetShowGangTerritories) loadFleetGangTerritories().then(()=>renderFleetTerritoryOverlay());
  document.addEventListener('click',(e)=>{
    const cal=e.target.closest('[data-fleet-cal]');
    if(cal){
      e.preventDefault(); e.stopPropagation();
      const step=e.shiftKey ? 1.0 : 0.2;
      const v=cal.dataset.fleetCal;
      if(v==='left') fleetNudgeCalibration(-step,0);
      else if(v==='right') fleetNudgeCalibration(step,0);
      else if(v==='up') fleetNudgeCalibration(0,-step);
      else if(v==='down') fleetNudgeCalibration(0,step);
      else if(v==='reset'){ renderFleet(); }
      return;
    }
    const z=e.target.closest('[data-fleet-zoom]'); if(z){ fleetMapView.zoom=Math.max(1,Math.min(5,fleetMapView.zoom*(z.dataset.fleetZoom==='in'?1.18:.85))); fleetSaveView(); applyFleetMapView(); return; }
    if(e.target.closest('[data-fleet-center]')){ fleetMapView={x:0,y:0,zoom:1}; fleetSaveView(); applyFleetMapView(); return; }
    const nz=e.target.closest('[data-nsk-zoom]'); if(nz){ nskMapView.zoom=Math.max(1,Math.min(5,nskMapView.zoom*(nz.dataset.nskZoom==='in'?1.18:.85))); applyNskMapView(); return; }
    if(e.target.closest('[data-nsk-center]')){ nskMapView={x:0,y:0,zoom:1}; applyNskMapView(); return; }
    if(e.target.closest('[data-nsk-cancel-edit]')){ cancelNskTerritoryEdit(); return; }
    if(e.target.closest('[data-nsk-view-edit]')){ const id=Number(nskSelectedTerritoryId||0); if(id) selectNskTerritory(id, true); return; }
    const set=e.target.closest('[data-fleet-settings]'); if(set){ e.preventDefault(); e.stopPropagation(); openFleetUnitLogs(set.dataset.fleetSettings); return; }
    const cu=e.target.closest('[data-fleet-center-unit]'); if(cu){ e.preventDefault(); e.stopPropagation(); const u=fleetAllUnits().find(x=>fleetUnitId(x)===cu.dataset.fleetCenterUnit); if(u){ fleetSelectedId=fleetUnitId(u); centerFleetOnUnit(u); renderFleet(); } return; }
    const dutyBtn=e.target.closest('#fleetGoOnDutyBtn'); if(dutyBtn){ e.preventDefault(); e.stopPropagation(); fleetGoOnDuty(); return; }
    const join=e.target.closest('[data-fleet-join]'); if(join){ e.preventDefault(); e.stopPropagation(); fleetSelectedId=join.dataset.fleetJoin; fleetSaveView(); toggleFleetUnit(join.dataset.fleetJoin); return; }
    const da=e.target.closest('[data-dispatch-accept]'); if(da){ const id=String(da.dataset.dispatchAccept||''); if(fleetDispatchPending.has(id)) return; const u=fleetSelectedUnit(); if(u){ fleetDispatches=(fleetDispatches||[]).map(d=>{ if(String(d.id)!==id) return d; const responders=Object.assign({}, d.responders||{}); const uid=fleetUnitId(u); responders[uid]={unitId:uid,callsign:u.callsign||u.plate||'Patrulje'}; return Object.assign({}, d, {responders, status:'Tildelt'}); }); } fleetDispatchPending.add(id); renderFleet(); nui('acceptDispatchJob',{id}).then(r=>{ fleetDispatchPending.delete(id); if(!r||!r.ok) toast((r&&r.message)||'Kunne ikke tage opgaven.'); else { toast(r.message||'Opgave taget.'); if(r.job){ fleetDispatches=(fleetDispatches||[]).map(d=>String(d.id)===String(r.job.id)?r.job:d); renderFleet(); } refreshFleet(); } }).catch(()=>{ fleetDispatchPending.delete(id); renderFleet(); toast('Kunne ikke tage opgaven.'); }); return; }
    const df=e.target.closest('[data-dispatch-finish]'); if(df){ const id=String(df.dataset.dispatchFinish||''); if(fleetDispatchPending.has(id)) return; fleetDispatchPending.add(id); renderFleet(); nui('finishDispatchJob',{id}).then(r=>{ fleetDispatchPending.delete(id); if(!r||!r.ok) toast((r&&r.message)||'Kunne ikke afslutte opgaven.'); else { toast(r.message||'Opgave afsluttet.'); fleetDispatches=(fleetDispatches||[]).filter(d=>String(d.id)!==id); renderFleet(); refreshFleet(); } }).catch(()=>{ fleetDispatchPending.delete(id); renderFleet(); toast('Kunne ikke afslutte opgaven.'); }); return; }
    const sel=e.target.closest('[data-fleet-select]'); if(sel){ fleetSelectedId=sel.dataset.fleetSelect; fleetSaveView(); renderFleet(); }
  });
  document.addEventListener('dblclick',(e)=>{ const sel=e.target.closest('[data-fleet-select]'); if(sel){ e.preventDefault(); } });
  document.addEventListener('mousedown',(e)=>{
    const fleetMap=e.target.closest('#fleetMap');
    const nskMap=e.target.closest('#nskMap');
    const map=fleetMap||nskMap;
    if(!map || e.button!==0) return;
    if(nskMap && (e.target.closest('[data-territory-id]') || e.target.closest('.nsk-vertex-handle') || e.target.closest('.nsk-vertex-delete'))) return;
    if(fleetMap && e.altKey){ e.preventDefault(); e.stopPropagation(); fleetAddSyncPointFromEvent(e); return; }
    if(e.target.closest('.fleet-map-controls') || e.target.closest('.fleet-map-layers') || e.target.closest('.fleet-map-pin') || e.target.closest('.mdt-clean-blip') || e.target.closest('.nsk-map-controls') || e.target.closest('.nsk-map-edit-dock') || e.target.closest('.nsk-map-view-dock') || e.target.closest('#nskTerritoryMapPopup') || e.target.closest('.nsk-territory-side-panel') || e.target.closest('.nsk-side-panel') || e.target.closest('.nsk-vertex-handle')) return;
    e.preventDefault();
    const view=fleetMap?fleetMapView:nskMapView;
    const apply=fleetMap?applyFleetMapView:applyNskMapView;
    const save=fleetMap?fleetSaveView:()=>{};
    const sx=e.clientX, sy=e.clientY, ox=view.x, oy=view.y;
    let dragged=false;
    map.classList.add('dragging');
    const move=(ev)=>{
      if(Math.abs(ev.clientX-sx)>4 || Math.abs(ev.clientY-sy)>4) dragged=true;
      view.x=ox+(ev.clientX-sx); view.y=oy+(ev.clientY-sy); apply();
    };
    const up=()=>{
      map.classList.remove('dragging');
      map.dataset.wasDragged=dragged?'1':'0';
      save();
      document.removeEventListener('mousemove',move);
      document.removeEventListener('mouseup',up);
    };
    document.addEventListener('mousemove',move); document.addEventListener('mouseup',up);
  });
  document.addEventListener('wheel',(e)=>{
    const fleetMap=e.target.closest('#fleetMap');
    const nskMap=e.target.closest('#nskMap');
    const map=fleetMap||nskMap;
    if(!map) return;
    e.preventDefault();
    const view=fleetMap?fleetMapView:nskMapView;
    const apply=fleetMap?applyFleetMapView:applyNskMapView;
    const save=fleetMap?fleetSaveView:()=>{};
    const rect=map.getBoundingClientRect(), old=view.zoom, next=Math.max(1,Math.min(5,old*(e.deltaY<0?1.12:.90))), mx=e.clientX-rect.left, my=e.clientY-rect.top;
    view.x=mx-(mx-view.x)*(next/old); view.y=my-(my-view.y)*(next/old); view.zoom=next; save(); apply();
  },{passive:false});
  document.addEventListener('keydown',(e)=>{
    if(activePage === 'fleet' && e.ctrlKey && e.altKey && String(e.key).toLowerCase()==='c'){ e.preventDefault(); fleetResetSync(); return; }
    if(activePage !== 'fleet' || !e.altKey) return;
    const step=e.shiftKey ? 1.0 : 0.3;
    if(e.key==='ArrowLeft'){ e.preventDefault(); fleetNudgeCalibration(-step,0); }
    if(e.key==='ArrowRight'){ e.preventDefault(); fleetNudgeCalibration(step,0); }
    if(e.key==='ArrowUp'){ e.preventDefault(); fleetNudgeCalibration(0,-step); }
    if(e.key==='ArrowDown'){ e.preventDefault(); fleetNudgeCalibration(0,step); }
    if(String(e.key).toLowerCase()==='r'){ e.preventDefault(); renderFleet(); }
  });
  window.addEventListener('message',(ev)=>{ if(ev.data&&ev.data.action==='fleetData'){ fleetUnits=(ev.data.data&&ev.data.data.units)||[]; fleetOfficers=(ev.data.data&&ev.data.data.officers)||[]; fleetDispatches=(ev.data.data&&ev.data.data.dispatches)||[]; if(ev.data.data&&ev.data.data.viewerService) fleetViewerService=ev.data.data.viewerService; if(activePage==='fleet') renderFleet(); } if(ev.data&&ev.data.action==='fleetDebug'){ console.log('[SAN MDT fleet debug]', ev.data.data); } });
  renderFleet();
}
if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',initFleet); else initFleet();

/* === CoachN v13: Forside rolleoversigt + betjent-profil === */
(function(){
  const safe = (fn)=>{ try { return fn(); } catch(e){ console.error('[SAN MDT v13]', e); } };
  document.addEventListener('click', function(e){
    const wr = e.target.closest('[data-open-wanted-report]');
    if(wr){
      const id = wr.dataset.openWantedReport;
      const r = (mdtReports || []).map(normalizeReport).find(x => String(x.id) === String(id) || String(x.report_no) === String(id));
      if(r && typeof openReportPage === 'function') openReportPage(r);
      else toast('Rapporten blev ikke fundet.');
      return;
    }
    const op = e.target.closest('[data-officer-profile]');
    if(op && typeof window.openOfficerProfile === 'function'){
      window.openOfficerProfile(op.dataset.officerProfile, op.dataset.officerName);
    }
  }, true);
  const search = document.getElementById('officerDirectorySearch');
  if(search){
    search.addEventListener('input', ()=>{
      dashboardOfficerSearch = search.value || '';
      safe(()=> renderDashboard(dashboardOfficerData));
    });
  }
  const refreshBtn = document.getElementById('officerDirectoryRefresh');
  if(refreshBtn){
    refreshBtn.addEventListener('click', ()=> safe(()=> refreshDashboardFromServer()));
  }
  window.openOfficerProfile = openOfficerProfile;
  const oldReportStorageSave = (typeof reportStorageSave === 'function') ? reportStorageSave : null;
  if(oldReportStorageSave){
    reportStorageSave = function(){
      oldReportStorageSave();
      safe(() => {
        if(activePage === 'dashboard' && dashboardCachedPayload) renderDashboard(dashboardCachedPayload);
      });
    };
  }
  const oldSaveReportPage = (typeof saveReportPage === 'function') ? saveReportPage : null;
  if(oldSaveReportPage){
    saveReportPage = function(){
      const res = oldSaveReportPage.apply(this, arguments);
      safe(() => {
        if(activePage === 'dashboard' && dashboardCachedPayload) renderDashboard(dashboardCachedPayload);
      });
      return res;
    };
  }
})();

// === COACHN V16 UI containment + scroll repair ===
(function(){
  function keepUiInsideMdt(){
    const app = document.getElementById('app');
    const modal = document.getElementById('modal');
    if(app && modal && modal.parentElement !== app){
      app.appendChild(modal);
    }
  }
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', keepUiInsideMdt);
  else keepUiInsideMdt();
})();

/* === COACHN V19: dashboard safety refresh === */
(function(){
  function refresh(){ try{ if(!mdtLoggedIn) return; if(typeof refreshDashboardFromServer === 'function' && (activePage === 'dashboard' || document.getElementById('dashboard')?.classList.contains('active'))) refreshDashboardFromServer(); }catch(e){ console.warn('[MDT] dashboard refresh failed', e); } }
  window.addEventListener('message', function(e){
    const msg=e.data||{};
    if(msg.action==='open'){
      clearTimeout(window.__mdtOpenDashRefresh);
      if(mdtLoggedIn) window.__mdtOpenDashRefresh = setTimeout(refresh, 400);
    }
  });
})();




/* removed duplicate transparency manager */




/* removed duplicate transparency manager */


/* === COACHN V31: CLEAN LOOK-THROUGH RESTORE MANAGER ===
   Fix: when cursor returns to MDT, transparency is removed immediately and focus is restored.
   Outside hover/click can make the whole MDT transparent, but inside hover/click always returns normal mode.
*/
(function(){
  if(window.__sanMdtLookThroughV31) return;
  window.__sanMdtLookThroughV31 = true;

  const state = { open:false, outside:false, focusReleased:false, raf:false, notifyLock:false };
  const app = () => document.getElementById('app');
  const isOpen = () => { const a = app(); return !!a && !a.classList.contains('hidden'); };

  function clearOldTransparencyClasses(){
    const a = app();
    if(a) a.classList.remove('look-through','tap-transparent','mdt-mouse-outside');
    document.documentElement.classList.remove('look-through-root','tap-transparent');
    document.body.classList.remove('look-through-root','tap-transparent');
  }

  function setVisual(active){
    const a = app();
    if(!a) return;
    clearOldTransparencyClasses();
    a.classList.toggle('mdt-lookthrough-active', !!active);
    document.documentElement.classList.toggle('mdt-lookthrough-root', !!active);
    document.body.classList.toggle('mdt-lookthrough-root', !!active);
  }

  function notifyClient(active){
    if(state.notifyLock) return;
    state.notifyLock = true;
    nui(active ? 'mdtLookThrough' : 'mdtRestoreFocus', {}).finally(()=>{
      setTimeout(()=>{ state.notifyLock = false; }, 80);
    });
  }

  function apply(notify){
    const visual = state.open && (state.outside || state.focusReleased);
    setVisual(visual);
    if(notify) notifyClient(state.focusReleased);
  }

  function scheduleApply(notify){
    if(notify){ apply(true); return; }
    if(state.raf) return;
    state.raf = true;
    requestAnimationFrame(()=>{ state.raf = false; apply(false); });
  }

  function rectInside(x, y){
    const a = app();
    if(!a || a.classList.contains('hidden')) return false;
    const r = a.getBoundingClientRect();
    return x >= r.left && x <= r.right && y >= r.top && y <= r.bottom;
  }

  function eventInsideMdt(e){
    const a = app();
    if(!a || a.classList.contains('hidden')) return false;
    if(e && e.target && e.target.closest && e.target.closest('#app')) return true;
    if(typeof e?.clientX === 'number') return rectInside(e.clientX, e.clientY);
    return false;
  }

  function restoreInside(notify=true){
    if(!isOpen()) return;
    state.open = true;
    state.outside = false;
    state.focusReleased = false;
    // Remove transparency instantly so it never gets stuck while waiting for Lua callback.
    setVisual(false);
    if(notify) notifyClient(false);
  }

  function hoverOutside(){
    if(!isOpen() || state.focusReleased) return;
    state.open = true;
    state.outside = true;
    scheduleApply(false);
  }

  function clickOutside(){
    if(!isOpen()) return;
    state.open = true;
    state.outside = true;
    state.focusReleased = true;
    // The MDT must stay transparent and the character must be usable.
    scheduleApply(true);
  }

  window.addEventListener('mousemove', (e)=>{
    if(!isOpen()) return;
    if(eventInsideMdt(e)) restoreInside(state.focusReleased);
    else hoverOutside();
  }, {passive:true, capture:true});

  window.addEventListener('mouseover', (e)=>{
    if(isOpen() && eventInsideMdt(e)) restoreInside(state.focusReleased);
  }, true);

  window.addEventListener('mousedown', (e)=>{
    if(!isOpen() || e.button !== 0) return;
    if(eventInsideMdt(e)) restoreInside(state.focusReleased);
    else clickOutside();
  }, true);

  window.addEventListener('focus', ()=>{
    // If focus returns because cursor/tablet is active again, do not leave visual state stuck.
    if(isOpen() && !state.outside) restoreInside(false);
  });

  window.addEventListener('message', (e)=>{
    const msg = e.data || {};
    if(msg.action === 'open'){
      state.open = true;
      state.outside = false;
      state.focusReleased = false;
      setVisual(false);
    }
    if(msg.action === 'lookMode'){
      state.open = isOpen();
      state.focusReleased = !!msg.active;
      if(!state.focusReleased && !state.outside) setVisual(false);
      else scheduleApply(false);
    }
    if(msg.action === 'forceClose' || msg.action === 'close'){
      state.open = false;
      state.outside = false;
      state.focusReleased = false;
      setVisual(false);
    }
  }, true);
})();

/* === NSK / Bandeintelligens === */
let nskMapBuilt = false;
let nskMapClick = { x: 0, y: 0 };
let nskMapView = { x: 0, y: 0, zoom: 1 };
const NSK_COLOR_PRESETS = ['#ff3048', '#00e6b7', '#2d8cff', '#ffd23f', '#b46cff', '#ff8a2a', '#35c2ff', '#7bd88f', '#c03cff', '#f4f4f4', '#6b7280', '#8b4513'];
function nskColorSwatchHtml(inputId, selected){
  const sel = selected || NSK_COLOR_PRESETS[0];
  return `<div class="nsk-color-swatches" data-color-input="${escapeHtml(inputId)}">
    ${NSK_COLOR_PRESETS.map((c) => `<button type="button" class="nsk-color-swatch ${c === sel ? 'active' : ''}" data-color="${escapeHtml(c)}" style="background:${escapeHtml(c)}" title="${escapeHtml(c)}"></button>`).join('')}
    <input type="hidden" id="${escapeHtml(inputId)}" value="${escapeHtml(sel)}">
  </div>`;
}
function bindNskColorSwatches(root){
  (root || document).querySelectorAll('.nsk-color-swatches').forEach((wrap) => {
    const input = $('#' + wrap.dataset.colorInput);
    wrap.querySelectorAll('.nsk-color-swatch').forEach((btn) => {
      btn.onclick = () => {
        wrap.querySelectorAll('.nsk-color-swatch').forEach((b) => b.classList.remove('active'));
        btn.classList.add('active');
        if(input) input.value = btn.dataset.color || NSK_COLOR_PRESETS[0];
      };
    });
  });
}
let nskTerritoryMode = 'view';
let nskSelectedTerritoryId = null;
let nskTerritoryDraft = null;

function nskTerritoryDraftColor(){
  const d = nskTerritoryDraft;
  if(!d) return '#ff3048';
  return d.color || nskGangColor(d.gang_id) || '#ff3048';
}
function nskTerritoryAreaBadgeHtml(area){
  return `<div class="nsk-area-badge-top"><b>${area} m²</b><span>Areal</span></div>`;
}
function updateNskTerritoryAreaBadge(){
  const badge = $('#nskTerritoryAreaBadge');
  if(!badge) return;
  const showEdit = (nskTerritoryMode === 'place' || nskTerritoryMode === 'edit') && nskTerritoryDraft;
  const showView = nskTerritoryMode === 'view' && nskSelectedTerritoryId;
  if(!showEdit && !showView){
    badge.classList.add('hidden');
    return;
  }
  let area = 0;
  let color = '#00e6b7';
  if(showEdit){
    area = nskTerritoryAreaSqM(nskTerritoryVertsForDraft(nskTerritoryDraft));
    color = nskTerritoryDraftColor();
  } else {
    const t = nskFindTerritory(nskSelectedTerritoryId);
    if(!t){ badge.classList.add('hidden'); return; }
    area = nskTerritoryAreaSqM(nskTerritoryResolveVertices(t));
    color = t.color || t.gang_color || '#00e6b7';
  }
  badge.classList.remove('hidden');
  badge.classList.remove('over-limit');
  badge.style.setProperty('--area-accent', color);
  badge.innerHTML = nskTerritoryAreaBadgeHtml(area);
}
function updateNskMapEditDock(){
  const map = $('#nskMap');
  const editDock = $('#nskMapEditDock');
  const viewDock = $('#nskMapViewDock');
  const controls = map?.querySelector('.nsk-map-controls');
  const editing = nskTerritoryMode === 'place' || nskTerritoryMode === 'edit';
  const viewing = nskTerritoryMode === 'view' && !!nskSelectedTerritoryId;
  if(editDock) editDock.classList.toggle('hidden', !editing);
  if(viewDock) viewDock.classList.toggle('hidden', !viewing);
  if(controls) controls.classList.toggle('hidden', editing || viewing);
}
function nskTerritoryRadiusToSvg(r){
  return Math.max(1.4, Math.min(14, (Number(r || 120) / 120) * 2.8));
}
function nskTerritoryResolveVertices(t){
  const raw = t?.vertices;
  if(Array.isArray(raw) && raw.length >= 3){
    const verts = raw.map((v) => {
      if(v && v.px != null && v.py != null) return { px: Number(v.px), py: Number(v.py) };
      if(v && v.x != null && v.y != null){
        const p = fleetMapPoint({ x: v.x, y: v.y });
        if(p) return { px: p.x, py: p.y };
      }
      return null;
    }).filter(Boolean);
    if(verts.length >= 3) return verts;
  }
  const p = fleetMapPoint({ x: t?.center_x, y: t?.center_y });
  if(!p) return [];
  const half = nskTerritoryRadiusToSvg(t?.radius || 120) * 0.92;
  return [
    { px: p.x - half, py: p.y - half },
    { px: p.x + half, py: p.y - half },
    { px: p.x + half, py: p.y + half },
    { px: p.x - half, py: p.y + half },
  ];
}
function nskTerritoryVertsForDraft(d){
  if(!d) return [];
  if(Array.isArray(d.vertices) && d.vertices.length >= 3) return d.vertices.map((v) => ({ px: Number(v.px), py: Number(v.py) }));
  return nskTerritoryResolveVertices(d);
}
function nskTerritoryDefaultVertsAtGame(coords, radius){
  return nskTerritoryResolveVertices({ center_x: coords.x, center_y: coords.y, radius: radius || 120, vertices: null });
}
function nskTerritoryCentroid(verts){
  if(!verts?.length) return { px: 50, py: 50 };
  let sx = 0, sy = 0;
  verts.forEach((v) => { sx += v.px; sy += v.py; });
  return { px: sx / verts.length, py: sy / verts.length };
}
function nskTerritoryAreaSqM(verts){
  if(!verts || verts.length < 3) return 0;
  let area = 0;
  for(let i = 0; i < verts.length; i++){
    const j = (i + 1) % verts.length;
    area += verts[i].px * verts[j].py - verts[j].px * verts[i].py;
  }
  area = Math.abs(area) / 2;
  return Math.max(1, Math.round(area * 72));
}
function nskTerritoryUpdateCenterFromVerts(d){
  const verts = nskTerritoryVertsForDraft(d);
  if(verts.length < 3) return;
  const c = nskTerritoryCentroid(verts);
  const game = fleetPercentToGame(c.px, c.py);
  d.center_x = game.x;
  d.center_y = game.y;
  d.vertices = verts;
}
function nskTerritoryPolyPoints(verts){
  return verts.map((v) => `${v.px},${v.py}`).join(' ');
}
function nskTerritoryPolySvg(t, opts){
  opts = opts || {};
  const verts = opts.verts || nskTerritoryResolveVertices(t);
  if(verts.length < 3) return '';
  const color = opts.color || t.color || t.gang_color || '#00e6b7';
  const isSel = !!opts.selected;
  const isDraft = !!opts.draft;
  const id = t.id || 'draft';
  const points = nskTerritoryPolyPoints(verts);
  const editColor = color || '#ff3048';
  const fillOp = isDraft ? 0.28 : (isSel ? 0.14 : 0.1);
  const strokeW = isDraft ? 0.44 : (isSel ? 0.36 : 0.28);
  return `<g class="nsk-territory-group ${isSel ? 'selected' : ''} ${isDraft ? 'draft editing' : ''}" data-territory-id="${id}">
    <polygon class="nsk-territory-poly nsk-territory-hit" points="${points}" fill="${escapeHtml(editColor)}" fill-opacity="${fillOp}" stroke="${escapeHtml(editColor)}" stroke-width="${strokeW}" stroke-linejoin="round" vector-effect="non-scaling-stroke" data-territory-id="${id}"></polygon>
  </g>`;
}
function nskTerritoryRemoveVertex(index){
  if(!nskTerritoryDraft) return;
  const verts = nskTerritoryVertsForDraft(nskTerritoryDraft);
  if(verts.length <= 3) return;
  verts.splice(index, 1);
  nskTerritoryDraft.vertices = verts;
  nskTerritoryUpdateCenterFromVerts(nskTerritoryDraft);
  nskTerritoryDraft._placed = true;
  renderNskTerritoryMap(true);
  renderNskTerritorySidePanel();
}
function nskTerritoryInsertVertexOnEdge(edgeIndex){
  const verts = nskTerritoryVertsForDraft(nskTerritoryDraft);
  const a = verts[edgeIndex];
  const b = verts[(edgeIndex + 1) % verts.length];
  const mid = { px: (a.px + b.px) / 2, py: (a.py + b.py) / 2 };
  const next = verts.map((v) => ({ px: v.px, py: v.py }));
  next.splice(edgeIndex + 1, 0, mid);
  nskTerritoryDraft.vertices = next;
  return edgeIndex + 1;
}
function renderNskTerritoryHandles(){
  const layer = $('#nskTerritoryHandles');
  const map = $('#nskMap');
  if(!layer) return;
  const show = mdtNskManage && nskTerritoryDraft && (nskTerritoryMode === 'place' || nskTerritoryMode === 'edit');
  if(map) map.classList.toggle('nsk-editing-territory', !!show);
  if(!show){
    layer.innerHTML = '';
    return;
  }
  const verts = nskTerritoryVertsForDraft(nskTerritoryDraft);
  let html = verts.map((v, i) =>
    `<button type="button" class="nsk-vertex-handle nsk-vertex-corner" style="left:${v.px}%;top:${v.py}%" data-vertex-index="${i}" data-handle-kind="corner" title="Træk hjørne">
      <span class="nsk-vertex-hit"></span><span class="nsk-vertex-dot"></span>
    </button>`
  ).join('');
  for(let i = 0; i < verts.length; i++){
    const a = verts[i];
    const b = verts[(i + 1) % verts.length];
    const mx = (a.px + b.px) / 2;
    const my = (a.py + b.py) / 2;
    html += `<button type="button" class="nsk-vertex-handle nsk-vertex-mid" style="left:${mx}%;top:${my}%" data-edge-index="${i}" data-handle-kind="mid" title="Træk for at udvide kanten">
      <span class="nsk-vertex-hit"></span><span class="nsk-vertex-dot"></span>
    </button>`;
  }
  layer.innerHTML = html;
  bindNskTerritoryVertexDrag();
}
function nskMapPanelHost(){
  return $('#nskMap')?.closest('.nsk-map-panel') || $('#nskMap');
}
function ensureNskTerritoryAreaBadge(){
  const map = $('#nskMap');
  if(!map) return;
  nskMapPanelHost()?.querySelector('#nskTerritoryAreaBadge')?.remove();
  if(!map.querySelector('#nskTerritoryAreaBadge')){
    const badge = document.createElement('div');
    badge.id = 'nskTerritoryAreaBadge';
    badge.className = 'nsk-territory-area-badge hidden';
    map.appendChild(badge);
  }
}
function ensureNskTerritoryMapPopup(){
  const map = $('#nskMap');
  if(!map || map.querySelector('#nskTerritoryMapPopup')) return;
  const pop = document.createElement('div');
  pop.id = 'nskTerritoryMapPopup';
  pop.className = 'nsk-territory-popup hidden';
  pop.innerHTML = `
    <button type="button" class="nsk-tpop-close" data-nsk-map-pop-close aria-label="Luk">×</button>
    <b class="nsk-tpop-name">Territorium</b>
    <small class="nsk-tpop-meta">—</small>
    <div class="nsk-tpop-actions">
      <button type="button" data-nsk-map-pop-gang>Åbn bande</button>
      <button type="button" data-nsk-map-pop-edit>Rediger</button>
      <button type="button" data-nsk-map-pop-rename>Omdøb</button>
      <button type="button" class="danger" data-nsk-map-pop-delete>Slet</button>
    </div>
    <span class="nsk-tpop-arrow" aria-hidden="true"></span>`;
  map.appendChild(pop);
}
function repositionNskTerritoryMapPopup(){
  const pop = $('#nskTerritoryMapPopup');
  const map = $('#nskMap');
  const canvas = $('#nskMapCanvas');
  if(!pop || pop.classList.contains('hidden') || !map || !canvas) return;
  const t = nskFindTerritory(Number(pop.dataset.territoryId || 0));
  if(!t) return;
  const c = nskTerritoryCentroid(nskTerritoryResolveVertices(t));
  const mapRect = map.getBoundingClientRect();
  const canvasRect = canvas.getBoundingClientRect();
  const left = canvasRect.left - mapRect.left + (c.px / 100) * canvasRect.width;
  const top = canvasRect.top - mapRect.top + (c.py / 100) * canvasRect.height;
  pop.style.left = `${left}px`;
  pop.style.top = `${top}px`;
  const flipBelow = c.py < 22;
  pop.classList.toggle('flip-below', flipBelow);
  pop.style.transform = flipBelow ? 'translate(-50%, 18px)' : 'translate(-50%, calc(-100% - 18px))';
}
function hideNskTerritoryMapPopup(){
  const pop = $('#nskTerritoryMapPopup');
  if(pop) pop.classList.add('hidden');
}
function showNskTerritoryMapPopup(t){
  const pop = $('#nskTerritoryMapPopup');
  if(!pop || !t) return;
  const area = nskTerritoryAreaSqM(nskTerritoryResolveVertices(t));
  pop.dataset.territoryId = String(t.id || '');
  pop.classList.remove('hidden');
  const nameEl = pop.querySelector('.nsk-tpop-name');
  const metaEl = pop.querySelector('.nsk-tpop-meta');
  if(nameEl) nameEl.textContent = t.name || 'Territorium';
  if(metaEl) metaEl.textContent = `${area} m²`;
  pop.querySelectorAll('[data-nsk-map-pop-edit],[data-nsk-map-pop-rename],[data-nsk-map-pop-delete]').forEach((b) => {
    b.style.display = mdtNskManage ? '' : 'none';
  });
  repositionNskTerritoryMapPopup();
  updateNskTerritoryAreaBadge();
}
function bindNskTerritoryMapPopup(){
  const map = $('#nskMap');
  if(!map || map.dataset.nskMapPopBound === '1') return;
  map.dataset.nskMapPopBound = '1';
  map.addEventListener('mousedown', (e) => {
    if(e.target.closest('#nskTerritoryMapPopup')) e.stopPropagation();
  });
  map.addEventListener('click', async (e) => {
    const pop = e.target.closest('#nskTerritoryMapPopup');
    if(!pop || pop.classList.contains('hidden')) return;
    e.stopPropagation();
    const id = Number(pop.dataset.territoryId || 0);
    if(e.target.closest('[data-nsk-map-pop-close]')){
      closeNskTerritoryView();
      return;
    }
    if(e.target.closest('[data-nsk-map-pop-gang]')){
      if(id) selectNskTerritory(id, false);
      return;
    }
    if(e.target.closest('[data-nsk-map-pop-edit]')){
      if(id) selectNskTerritory(id, true);
      return;
    }
    if(e.target.closest('[data-nsk-map-pop-rename]')){
      if(id) await renameNskTerritoryById(id);
      return;
    }
    if(e.target.closest('[data-nsk-map-pop-delete]')){
      if(id) await deleteNskTerritoryById(id);
    }
  });
}
function ensureNskMapViewDock(){
  const map = $('#nskMap');
  if(!map || map.querySelector('#nskMapViewDock')) return;
  const dock = document.createElement('div');
  dock.id = 'nskMapViewDock';
  dock.className = 'nsk-map-edit-dock nsk-map-view-dock hidden';
  dock.innerHTML = `
    <button type="button" data-nsk-center="1" title="Centrer kort"><span class="nsk-dock-icon">🗺</span></button>
    <button type="button" data-nsk-view-edit title="Rediger territorium"><span class="nsk-dock-pencil">✎</span></button>`;
  map.appendChild(dock);
}
function ensureNskMapEditDock(){
  const map = $('#nskMap');
  if(!map || map.querySelector('#nskMapEditDock')) return;
  const dock = document.createElement('div');
  dock.id = 'nskMapEditDock';
  dock.className = 'nsk-map-edit-dock hidden';
  dock.innerHTML = `
    <button type="button" data-nsk-center="1" title="Centrer kort"><span class="nsk-dock-icon">🗺</span></button>
    <button type="button" data-nsk-cancel-edit title="Annuller redigering"><span class="nsk-dock-stop"></span></button>`;
  map.appendChild(dock);
}
function hideNskTerritorySidePanel(){
  const panel = $('#nskTerritorySidePanel');
  if(panel){ panel.classList.add('hidden'); panel.innerHTML = ''; }
}
function closeNskTerritoryView(){
  nskSelectedTerritoryId = null;
  hideNskTerritoryMapPopup();
  hideNskTerritorySidePanel();
  updateNskTerritoryAreaBadge();
  updateNskMapEditDock();
  renderNskTerritoryMap(true);
  renderNskPanels();
}
async function renameNskTerritoryById(id){
  const t = nskFindTerritory(id);
  if(!t || !mdtNskManage) return;
  const name = window.prompt('Nyt navn på territorium:', t.name || '');
  if(name == null || !String(name).trim()) return;
  const verts = nskTerritoryResolveVertices(t);
  const resp = await nui('saveNskTerritory', {
    id: t.id,
    gang_id: Number(t.gang_id),
    name: String(name).trim(),
    center_x: Number(t.center_x),
    center_y: Number(t.center_y),
    radius: Number(t.radius || 120),
    vertices: verts.map((v) => ({ px: v.px, py: v.py })),
    notes: t.notes || '',
    color: t.color || t.gang_color,
  });
  if(resp && resp.ok){
    toast('Territorium omdøbt.');
    const keepId = nskSelectedTerritoryId;
    await refreshNskOverview();
    if(keepId){
      nskSelectedTerritoryId = Number(keepId);
      const nt = nskFindTerritory(keepId);
      if(nt) showNskTerritoryMapPopup(nt);
      renderNskPanels();
    }
  } else toast(resp?.message || 'Kunne ikke omdøbe.');
}
async function deleteNskTerritoryById(id){
  if(!id || !mdtNskManage) return;
  const resp = await nui('deleteNskTerritory', { id });
  if(resp && resp.ok){
    toast('Territorium slettet.');
    cancelNskTerritoryEdit();
    refreshNskOverview();
  } else toast(resp?.message || 'Kunne ikke slette.');
}
function renderNskTerritorySidePanel(){
  const panel = $('#nskTerritorySidePanel');
  if(!panel) return;
  if(nskTerritoryDraft && (nskTerritoryMode === 'place' || nskTerritoryMode === 'edit')){
    const d = nskTerritoryDraft;
    const gangs = nskOverview.gangs || [];
    const opts = gangs.map((g) => `<option value="${g.id}" ${Number(d.gang_id) === Number(g.id) ? 'selected' : ''}>${escapeHtml(g.name || 'Bande')}</option>`).join('');
    const isEdit = nskTerritoryMode === 'edit' && d.id;
    const area = nskTerritoryAreaSqM(nskTerritoryVertsForDraft(d));
    panel.classList.remove('hidden');
    panel.innerHTML = `
      <div class="nsk-tpanel nsk-tpanel-edit">
        <div class="nsk-tpanel-head">
          <div><span class="nsk-tpanel-kicker">${isEdit ? 'REDIGER TERRITORIUM' : 'NYT TERRITORIUM'}</span><b>${escapeHtml(d.name || 'Uden navn')}</b></div>
          <button type="button" class="nsk-tpanel-close" data-nsk-tpanel-close aria-label="Luk">×</button>
        </div>
        <div class="nsk-tpanel-body nsk-form-pro">
          <label>Bande</label>
          <select id="nskSideGang">${opts}</select>
          <label>Navn på område</label>
          <input id="nskSideName" value="${escapeHtml(d.name || '')}" placeholder="Fx Grove Street / Havnen">
          <p class="nsk-modal-lead">Hold venstreklik og træk for at flytte kortet · træk i hjørnerne for at forme territoriet.</p>
          <div class="nsk-tpanel-stats">
            <div><span>Areal</span><b id="nskSideArea">${area} m²</b></div>
            <div><span>X</span><b id="nskSideX">${Math.round(d.center_x || 0)}</b></div>
            <div><span>Y</span><b id="nskSideY">${Math.round(d.center_y || 0)}</b></div>
          </div>
          <label>Noter</label>
          <textarea id="nskSideNotes" placeholder="Observationer, aktivitet, kontakter...">${escapeHtml(d.notes || '')}</textarea>
        </div>
        <div class="nsk-tpanel-actions">
          ${isEdit ? '<button type="button" class="nsk-btn danger sm" data-nsk-side-delete>Slet</button>' : ''}
          <button type="button" class="nsk-btn ghost sm" data-nsk-tpanel-close>Annuller</button>
          <button type="button" class="nsk-btn accent sm" data-nsk-side-save>${isEdit ? 'Gem ændringer' : 'Opret territorium'}</button>
        </div>
      </div>`;
    $('#nskSideGang')?.addEventListener('change', (e) => {
      d.gang_id = Number(e.target.value);
      d.color = nskGangColor(d.gang_id);
      renderNskTerritoryMap(true);
      updateNskTerritoryAreaBadge();
    });
    $('#nskSideName')?.addEventListener('input', (e) => {
      d.name = e.target.value;
      const title = panel.querySelector('.nsk-tpanel-head b');
      if(title) title.textContent = d.name || 'Uden navn';
    });
    $('#nskSideNotes')?.addEventListener('input', (e) => { d.notes = e.target.value; });
    panel.querySelectorAll('[data-nsk-tpanel-close]').forEach((b) => {
      b.onclick = (ev) => { ev.stopPropagation(); cancelNskTerritoryEdit(); };
    });
    panel.querySelector('[data-nsk-side-save]')?.addEventListener('click', saveNskTerritoryFromDrawer);
    panel.querySelector('[data-nsk-side-delete]')?.addEventListener('click', deleteNskTerritoryFromDrawer);
    panel.onmousedown = (ev) => { ev.stopPropagation(); };
    nskSwitchSideTab('territories');
    return;
  }
  const t = nskSelectedTerritoryId ? nskFindTerritory(nskSelectedTerritoryId) : null;
  panel.classList.add('hidden');
  panel.innerHTML = '';
  if(t){
    showNskTerritoryMapPopup(t);
    updateNskMapEditDock();
    nskSwitchSideTab('territories');
  } else {
    hideNskTerritoryMapPopup();
  }
}
function nskTerritorySyncAfterVertexChange(){
  renderNskTerritorySidePanel();
  const d = nskTerritoryDraft;
  if(!d) return;
  const area = nskTerritoryAreaSqM(nskTerritoryVertsForDraft(d));
  const xEl = $('#nskSideX'); if(xEl) xEl.textContent = String(Math.round(d.center_x || 0));
  const yEl = $('#nskSideY'); if(yEl) yEl.textContent = String(Math.round(d.center_y || 0));
  const aEl = $('#nskSideArea'); if(aEl) aEl.textContent = `${area} m²`;
  updateNskTerritoryAreaBadge();
}
function bindNskTerritoryVertexDrag(){
  const layer = $('#nskTerritoryHandles');
  if(!layer) return;
  layer.querySelectorAll('[data-vertex-delete]').forEach((btn) => {
    btn.onmousedown = (e) => { e.stopPropagation(); e.preventDefault(); };
    btn.onclick = (e) => {
      e.stopPropagation();
      e.preventDefault();
      if(!mdtNskManage || !nskTerritoryDraft) return;
      nskTerritoryRemoveVertex(Number(btn.dataset.vertexDelete));
      nskTerritorySyncAfterVertexChange();
    };
  });
  layer.querySelectorAll('.nsk-vertex-handle').forEach((handle) => {
    handle.onmousedown = (e) => {
      if(e.target.closest('[data-vertex-delete]')) return;
      e.stopPropagation();
      e.preventDefault();
      if(!mdtNskManage || !nskTerritoryDraft) return;
      let idx = Number(handle.dataset.vertexIndex);
      if(handle.dataset.handleKind === 'mid'){
        idx = nskTerritoryInsertVertexOnEdge(Number(handle.dataset.edgeIndex));
        renderNskTerritoryMap(true);
      }
      if(!nskTerritoryDraft.vertices || nskTerritoryDraft.vertices.length < 3){
        nskTerritoryDraft.vertices = nskTerritoryVertsForDraft(nskTerritoryDraft);
      }
      const onMove = (ev) => {
        const mp = nskMapClientToPercent(ev.clientX, ev.clientY);
        if(!mp || !nskTerritoryDraft) return;
        nskTerritoryDraft.vertices[idx] = { px: mp.x, py: mp.y };
        nskTerritoryUpdateCenterFromVerts(nskTerritoryDraft);
        nskTerritoryDraft._placed = true;
        const verts = nskTerritoryVertsForDraft(nskTerritoryDraft);
        const poly = $('#nskTerritoryLayer')?.querySelector('.nsk-territory-group.editing .nsk-territory-poly');
        if(poly && verts.length >= 3) poly.setAttribute('points', nskTerritoryPolyPoints(verts));
        layer.querySelectorAll('.nsk-vertex-handle').forEach((h) => {
          const vi = h.dataset.vertexIndex;
          const ei = h.dataset.edgeIndex;
          if(vi != null && vi !== ''){
            const v = verts[Number(vi)];
            if(v){ h.style.left = `${v.px}%`; h.style.top = `${v.py}%`; }
          } else if(ei != null && ei !== ''){
            const a = verts[Number(ei)];
            const b = verts[(Number(ei) + 1) % verts.length];
            if(a && b){ h.style.left = `${(a.px + b.px) / 2}%`; h.style.top = `${(a.py + b.py) / 2}%`; }
          }
        });
        updateNskTerritoryAreaBadge();
        const aEl = $('#nskSideArea'); if(aEl) aEl.textContent = `${nskTerritoryAreaSqM(verts)} m²`;
      };
      const onUp = () => {
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
        renderNskTerritoryHandles();
        nskTerritorySyncAfterVertexChange();
      };
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
    };
  });
}
function nskFindTerritory(id){
  return (nskOverview.territories || []).find((t) => Number(t.id) === Number(id)) || null;
}
function nskGangColor(gangId){
  const g = (nskOverview.gangs || []).find((x) => Number(x.id) === Number(gangId));
  return g?.color || '#ff3048';
}
function updateNskMapHint(){
  const hint = $('#nskMapHint');
  if(!hint) return;
  if(nskTerritoryMode === 'place') hint.textContent = 'Træk hvide hjørner · midtpunkter udvider · rød knap annullerer';
  else if(nskTerritoryMode === 'edit') hint.textContent = 'Træk hjørner/midtpunkter · gem til højre · rød knap annullerer';
  else hint.textContent = 'Klik territorium → åbner bande i listen · venstreklik+træk flytter kortet';
}
function setNskTerritoryMode(mode, territoryId){
  nskTerritoryMode = mode || 'view';
  nskSelectedTerritoryId = territoryId ? Number(territoryId) : null;
  if(nskTerritoryMode === 'place' || nskTerritoryMode === 'edit') hideNskTerritoryMapPopup();
  const map = $('#nskMap');
  if(map) map.classList.toggle('nsk-place-mode', nskTerritoryMode === 'place' || nskTerritoryMode === 'edit');
  $('#nskMapPlaceBtn')?.classList.toggle('hidden', nskTerritoryMode !== 'view');
  $('#nskMapCancelPlaceBtn')?.classList.toggle('hidden', nskTerritoryMode === 'view');
  updateNskMapHint();
  updateNskMapEditDock();
  renderNskTerritorySidePanel();
  renderNskTerritoryMap(true);
  updateNskTerritoryAreaBadge();
}
function nskSwitchSideTab(tab){
  document.querySelectorAll('.nsk-tab').forEach((b) => b.classList.toggle('active', b.dataset.nskTab === tab));
  document.querySelectorAll('.nsk-panel').forEach((p) => p.classList.remove('active'));
  const panel = $(`#nskPanel${tab.charAt(0).toUpperCase()}${tab.slice(1)}`);
  if(panel) panel.classList.add('active');
}
function selectNskTerritory(id, openEdit){
  const t = nskFindTerritory(id);
  if(!t) return;
  const verts = nskTerritoryResolveVertices(t);
  nskMapClick = { x: Number(t.center_x || 0), y: Number(t.center_y || 0) };
  if(openEdit){
    nskSwitchSideTab('territories');
    nskTerritoryDraft = {
      id: t.id,
      gang_id: t.gang_id,
      name: t.name || '',
      center_x: Number(t.center_x || 0),
      center_y: Number(t.center_y || 0),
      radius: Number(t.radius || 120),
      vertices: verts.map((v) => ({ px: v.px, py: v.py })),
      notes: t.notes || '',
      color: t.color || t.gang_color || nskGangColor(t.gang_id),
      _placed: true,
    };
    setNskTerritoryMode('edit', t.id);
  } else {
    nskTerritoryDraft = null;
    nskSelectedTerritoryId = Number(t.id);
    nskTerritoryMode = 'view';
    const map = $('#nskMap');
    if(map) map.classList.remove('nsk-place-mode');
    hideNskTerritoryMapPopup();
    hideNskTerritorySidePanel();
    renderNskTerritoryMap(true);
    updateNskTerritoryAreaBadge();
    updateNskMapEditDock();
    if(t.gang_id){
      nskSwitchSideTab('gangs');
      openNskGangBoard(Number(t.gang_id));
      toast(`Åbner ${t.gang_name || 'bande'} · ${t.name || 'zone'}`);
    } else {
      nskSwitchSideTab('gangs');
      renderNskPanels();
      toast('Territoriet har ingen tilknyttet bande.');
    }
  }
}
function startNskTerritoryPlace(){
  if(!mdtNskManage){ toast('Ingen adgang til at oprette territorier.'); return; }
  const gangs = nskOverview.gangs || [];
  if(!gangs.length){ toast('Opret en bande først.'); return; }
  const cx = Number(nskMapClick.x || 0);
  const cy = Number(nskMapClick.y || 0);
  const verts = (cx || cy) ? nskTerritoryDefaultVertsAtGame({ x: cx, y: cy }, 120) : [];
  nskTerritoryDraft = {
    id: null,
    gang_id: Number(gangs[0].id),
    name: '',
    center_x: cx,
    center_y: cy,
    radius: 120,
    vertices: verts.map((v) => ({ px: v.px, py: v.py })),
    notes: '',
    color: gangs[0].color || '#ff3048',
    _placed: !!(cx || cy),
  };
  nskSwitchSideTab('territories');
  setNskTerritoryMode('place', null);
  toast({ type:'info', title:'Placeringsmode', message:'Klik på kortet og træk i hjørnerne for at forme territoriet.' });
}
function cancelNskTerritoryEdit(){
  nskTerritoryDraft = null;
  nskSelectedTerritoryId = null;
  hideNskTerritoryMapPopup();
  const badge = $('#nskTerritoryAreaBadge');
  if(badge) badge.classList.add('hidden');
  hideNskTerritorySidePanel();
  renderNskTerritoryHandles();
  setNskTerritoryMode('view', null);
  renderNskPanels();
}
function renderNskTerritoryDrawer(){
  renderNskTerritorySidePanel();
}
async function saveNskTerritoryFromDrawer(){
  const d = nskTerritoryDraft;
  if(!d) return;
  if(!d.name?.trim()){ toast('Giv territoriet et navn.'); return; }
  if(!d.gang_id){ toast('Vælg en bande.'); return; }
  if(!d._placed){ toast('Klik på kortet for at placere territoriet.'); return; }
  const verts = nskTerritoryVertsForDraft(d);
  if(verts.length < 3){ toast('Territoriet skal have mindst 3 hjørner.'); return; }
  const resp = await nui('saveNskTerritory', {
    id: d.id || undefined,
    gang_id: Number(d.gang_id),
    name: d.name.trim(),
    center_x: Number(d.center_x),
    center_y: Number(d.center_y),
    radius: Number(d.radius || 120),
    vertices: verts.map((v) => ({ px: v.px, py: v.py })),
    notes: d.notes || '',
    color: d.color || nskGangColor(d.gang_id),
  });
  if(resp && resp.ok){
    toast(resp.message || 'Territorium gemt.');
    cancelNskTerritoryEdit();
    refreshNskOverview();
  } else toast(resp?.message || 'Kunne ikke gemme territorium.');
}
async function deleteNskTerritoryFromDrawer(){
  const d = nskTerritoryDraft;
  if(!d?.id) return;
  const resp = await nui('deleteNskTerritory', { id: Number(d.id) });
  if(resp && resp.ok){
    toast(resp.message || 'Territorium slettet.');
    cancelNskTerritoryEdit();
    refreshNskOverview();
  } else toast(resp?.message || 'Kunne ikke slette territorium.');
}
function nskApplyMapClick(coords){
  if(!coords || (nskTerritoryMode !== 'place' && nskTerritoryMode !== 'edit')) return;
  if(!nskTerritoryDraft) return;
  nskTerritoryDraft.center_x = coords.x;
  nskTerritoryDraft.center_y = coords.y;
  nskTerritoryDraft.vertices = nskTerritoryDefaultVertsAtGame(coords, nskTerritoryDraft.radius || 120).map((v) => ({ px: v.px, py: v.py }));
  nskTerritoryDraft._placed = true;
  nskMapClick = { x: coords.x, y: coords.y };
  const xEl = $('#nskSideX') || $('#nskDrawerX'); if(xEl) xEl.textContent = String(Math.round(coords.x));
  const yEl = $('#nskSideY') || $('#nskDrawerY'); if(yEl) yEl.textContent = String(Math.round(coords.y));
  const aEl = $('#nskSideArea') || $('#nskDrawerArea'); if(aEl) aEl.textContent = `${nskTerritoryAreaSqM(nskTerritoryDraft.vertices)} m²`;
  renderNskTerritoryMap(true);
  updateNskTerritoryAreaBadge();
}

function applyNskMapView(){
  const map = $('#nskMap');
  const canvas = $('#nskMapCanvas');
  if(!map || !canvas) return;
  nskMapView.zoom = Math.max(1, Math.min(5, Number(nskMapView.zoom) || 1));
  nskMapView.x = Number(nskMapView.x) || 0;
  nskMapView.y = Number(nskMapView.y) || 0;
  const r = map.getBoundingClientRect();
  const cw = canvas.offsetWidth || r.width;
  const ch = canvas.offsetHeight || r.height;
  const sw = cw * nskMapView.zoom;
  const sh = ch * nskMapView.zoom;
  if(sw <= r.width) nskMapView.x = (r.width - sw) / 2;
  else nskMapView.x = Math.min(0, Math.max(r.width - sw, nskMapView.x));
  if(sh <= r.height) nskMapView.y = (r.height - sh) / 2;
  else nskMapView.y = Math.min(0, Math.max(r.height - sh, nskMapView.y));
  canvas.style.transform = `translate3d(${nskMapView.x}px,${nskMapView.y}px,0) scale(${nskMapView.zoom})`;
  repositionNskTerritoryMapPopup();
}
function buildNskMapTiles(){
  loadMapImageIntoLayer($('#nskTileLayer'), $('#nskMapStatus'), 'Bandekort indlæst · klik for koordinater');
}
function nskMapClientToPercent(clientX, clientY){
  const canvas = $('#nskMapCanvas');
  if(!canvas) return null;
  const rect = canvas.getBoundingClientRect();
  const x = ((clientX - rect.left) / rect.width) * 100;
  const y = ((clientY - rect.top) / rect.height) * 100;
  if(!isFinite(x) || !isFinite(y)) return null;
  return { x: Math.max(0, Math.min(100, x)), y: Math.max(0, Math.min(100, y)) };
}
function bindNskMapInteractions(){
  const map = $('#nskMap');
  if(!map || map.dataset.bound === '1') return;
  map.dataset.bound = '1';
  map.addEventListener('click', (e) => {
    if(map.dataset.wasDragged === '1'){ map.dataset.wasDragged = '0'; return; }
    if(e.target.closest('.nsk-map-controls') || e.target.closest('.nsk-map-edit-dock') || e.target.closest('.nsk-map-view-dock') || e.target.closest('#nskTerritoryMapPopup') || e.target.closest('.nsk-territory-side-panel') || e.target.closest('.nsk-territory-area-badge')) return;
    if(e.target.closest('.nsk-vertex-handle') || e.target.closest('.nsk-vertex-delete')) return;
    const hit = e.target.closest('[data-territory-id]');
    if(hit){
      e.stopPropagation();
      const id = Number(hit.dataset.territoryId);
      if(id && nskTerritoryMode !== 'place'){
        if(nskTerritoryMode === 'edit' && nskTerritoryDraft?.id === id) return;
        selectNskTerritory(id, false);
      }
      return;
    }
    if(nskTerritoryMode === 'view' && nskSelectedTerritoryId){
      closeNskTerritoryView();
      return;
    }
    if(!mdtNskManage) return;
    const mp = nskMapClientToPercent(e.clientX, e.clientY);
    if(!mp) return;
    const coords = fleetPercentToGame(mp.x, mp.y);
    nskMapClick = coords;
    if(nskTerritoryMode === 'place' || nskTerritoryMode === 'edit'){
      nskApplyMapClick(coords);
      return;
    }
    const hint = $('#nskMapHint');
    if(hint) hint.textContent = `Valgt punkt: ${Math.round(coords.x)}, ${Math.round(coords.y)}`;
  });
}
function ensureNskMapExtras(){
  const map = $('#nskMap');
  if(!map) return;
  const canvas = $('#nskMapCanvas');
  if(canvas && !canvas.querySelector('#nskTerritoryHandles')){
    const handles = document.createElement('div');
    handles.id = 'nskTerritoryHandles';
    handles.className = 'nsk-territory-handles-layer';
    canvas.appendChild(handles);
  }
  ensureNskTerritoryAreaBadge();
  ensureNskTerritoryMapPopup();
  ensureNskMapEditDock();
  ensureNskMapViewDock();
  bindNskTerritoryMapPopup();
  updateNskMapEditDock();
}
function ensureNskMap(){
  const map = $('#nskMap');
  if(!map) return;
  if(nskMapBuilt && map.querySelector('#nskTileLayer')){
    ensureNskMapExtras();
    return;
  }
  if(!nskMapBuilt || !map.querySelector('#nskTileLayer')){
    map.innerHTML = `
      <div id="nskMapWorld" class="fleet-map-world" data-stack="nsk-v10-ox-crs">
        <div id="nskMapCanvas" class="fleet-map-canvas" data-map-aspect="4096x6144-v10-ox">
          <div id="nskTileLayer" class="fleet-tile-layer" data-render-layer="dlk-tile-map"></div>
          <svg id="nskTerritoryLayer" class="nsk-territory-layer" viewBox="0 0 100 100" preserveAspectRatio="none"></svg>
          <div id="nskTerritoryHandles" class="nsk-territory-handles-layer"></div>
        </div>
      </div>
      <div class="fleet-map-controls nsk-map-controls">
        <button type="button" data-nsk-zoom="in" title="Zoom ind">+</button>
        <button type="button" data-nsk-zoom="out" title="Zoom ud">−</button>
        <button type="button" data-nsk-center="1" title="Centrer kort">⌖</button>
      </div>
      <div id="nskMapEditDock" class="nsk-map-edit-dock hidden">
        <button type="button" data-nsk-center="1" title="Centrer kort"><span class="nsk-dock-icon">🗺</span></button>
        <button type="button" data-nsk-cancel-edit title="Annuller redigering"><span class="nsk-dock-stop"></span></button>
      </div>
      <div id="nskMapViewDock" class="nsk-map-edit-dock nsk-map-view-dock hidden">
        <button type="button" data-nsk-center="1" title="Centrer kort"><span class="nsk-dock-icon">🗺</span></button>
        <button type="button" data-nsk-view-edit title="Rediger territorium"><span class="nsk-dock-pencil">✎</span></button>
      </div>
      <div id="nskMapStatus" class="fleet-map-tile-status">Indlæser bandekort...</div>`;
    nskMapBuilt = true;
    bindNskMapInteractions();
  }
  ensureNskMapExtras();
  buildNskMapTiles();
  requestAnimationFrame(() => {
    applyNskMapView();
    renderNskTerritoryMap(true);
  });
}

function fleetPercentToGame(px, py){
  const lng = FLEET_OX_CRS.minLng + (Number(px) / 100) * (FLEET_OX_CRS.maxLng - FLEET_OX_CRS.minLng);
  const lat = FLEET_OX_CRS.maxLat - (Number(py) / 100) * (FLEET_OX_CRS.maxLat - FLEET_OX_CRS.minLat);
  return {
    x: (lng - FLEET_OX_CRS.centerLng) / FLEET_OX_CRS.scale,
    y: (lat - FLEET_OX_CRS.centerLat) / FLEET_OX_CRS.scale,
  };
}

function renderNskTerritoryMap(skipEnsure){
  if(!skipEnsure) ensureNskMap();
  const svg = $('#nskTerritoryLayer');
  if(!svg) return;
  const territories = nskOverview.territories || [];
  const selectedId = nskSelectedTerritoryId;
  const editingId = nskTerritoryMode === 'edit' ? nskTerritoryDraft?.id : null;
  let shapes = territories.map((t) => {
    if(editingId && Number(t.id) === Number(editingId)) return '';
    return nskTerritoryPolySvg(t, {
      selected: Number(t.id) === Number(selectedId),
      showHandles: false,
      color: t.color || t.gang_color || '#00e6b7',
    });
  }).join('');
  const d = nskTerritoryDraft;
  if(d && (nskTerritoryMode === 'place' || nskTerritoryMode === 'edit')){
    const verts = nskTerritoryVertsForDraft(d);
    if(verts.length >= 3){
      shapes += nskTerritoryPolySvg(d, {
        selected: true,
        draft: true,
        showHandles: mdtNskManage,
        verts,
        color: d.color || nskGangColor(d.gang_id) || '#00e6b7',
      });
    }
  }
  svg.innerHTML = shapes;
  const editingShape = nskTerritoryMode === 'place' || nskTerritoryMode === 'edit';
  svg.style.pointerEvents = editingShape ? 'none' : ((nskTerritoryMode === 'view' || mdtNskManage) ? 'auto' : 'none');
  renderNskTerritoryHandles();
}

async function refreshNskOverview(){
  if(!mdtNskView){
    refreshNskAccess();
    if(!mdtNskView) return;
  }
  const r = await nui('getNskOverview', {});
  if(!r || !r.ok){ toast(r?.message || 'Kunne ikke hente NSK-data.'); return; }
  nskOverview = r;
  mdtNskManage = !!r.can_manage;
  refreshNskAccess();
  if(nskSelectedGangId){
    const br = await nui('getNskGangBoard', { gang_id: nskSelectedGangId });
    if(br?.ok){ nskGangBoard = br; renderNskGangBoardPanel(); }
    else closeNskGangBoard();
  } else {
    renderNskPanels();
  }
  renderNskTerritoryMap();
  const gangs = (r.gangs || []).length;
  const members = (r.members || []).length;
  const territories = (r.territories || []).length;
  const gEl = $('#nskStatGangs'); if(gEl) gEl.textContent = String(gangs);
  const mEl = $('#nskStatMembers'); if(mEl) mEl.textContent = String(members);
  const tEl = $('#nskStatTerritories'); if(tEl) tEl.textContent = String(territories);
}

function nskResolveBoardTier(member){
  const tier = String(member?.board_tier || '').trim().toLowerCase();
  if(tier && NSK_GANG_BOARD_TIERS.some((t) => t.key === tier)) return tier;
  const role = String(member?.role || '').toLowerCase();
  if(/leder|boss|president|king|godfather/.test(role)) return 'boss';
  if(/næst|underboss|vice|second/.test(role)) return 'underboss';
  if(/capo|sergeant|sergent|lieutenant/.test(role)) return 'capo';
  if(/prospect|hangaround|aspirant/.test(role)) return 'prospect';
  if(/soldat|soldier|medlem|member/.test(role)) return 'soldier';
  return 'unknown';
}
function nskBoardMembersByTier(members){
  const grouped = {};
  NSK_GANG_BOARD_TIERS.forEach((t) => { grouped[t.key] = []; });
  (members || []).forEach((m) => {
    const tier = nskResolveBoardTier(m);
    grouped[tier] = grouped[tier] || [];
    grouped[tier].push(Object.assign({}, m, { board_tier: tier }));
  });
  Object.keys(grouped).forEach((key) => {
    grouped[key].sort((a, b) => Number(a.board_rank || 0) - Number(b.board_rank || 0) || String(a.person_name || '').localeCompare(String(b.person_name || ''), 'da'));
  });
  return grouped;
}
function nskShowGangBoardShell(show){
  const board = $('#nskGangBoardPanel');
  const tabs = document.querySelector('.nsk-side-panel .nsk-tabs');
  const panels = ['#nskPanelGangs', '#nskPanelMembers', '#nskPanelTerritories'].map((sel) => $(sel));
  if(show){
    if(tabs) tabs.classList.add('hidden');
    panels.forEach((p) => p && p.classList.remove('active'));
    board?.classList.remove('hidden');
  } else {
    board?.classList.add('hidden');
    if(tabs) tabs.classList.remove('hidden');
    const activeTab = document.querySelector('.nsk-tab.active')?.dataset.nskTab || 'gangs';
    const panel = $(`#nskPanel${activeTab.charAt(0).toUpperCase()}${activeTab.slice(1)}`);
    if(panel) panel.classList.add('active');
  }
}
function nskBoardMemberChip(m, editable){
  const drag = editable ? ' draggable="true"' : '';
  return `<div class="nsk-board-member${editable ? ' editable' : ''}"${drag}
    data-board-member-id="${escapeHtml(m.id)}"
    data-board-member-ident="${escapeHtml(m.identifier || '')}"
    data-board-tier="${escapeHtml(nskResolveBoardTier(m))}">
    <span class="nsk-board-member-avatar">${escapeHtml(nskInitials(m.person_name))}</span>
    <div class="nsk-board-member-main">
      <b>${escapeHtml(m.person_name || 'Ukendt')}</b>
      <small>${escapeHtml(m.role || 'Medlem')}</small>
    </div>
    <button type="button" class="nsk-board-member-profile" data-board-open-profile="${escapeHtml(m.identifier || '')}" title="Åbn profil">▣</button>
  </div>`;
}
function renderNskGangBoardPanel(){
  const panel = $('#nskGangBoardPanel');
  const data = nskGangBoard;
  if(!panel || !data?.gang) return;
  const g = data.gang;
  const grouped = nskBoardMembersByTier(data.members || []);
  const editable = !!data.can_manage && !!mdtNskManage;
  const color = g.color || '#ff3048';
  const tiersHtml = NSK_GANG_BOARD_TIERS.map((tier) => {
    const list = grouped[tier.key] || [];
    return `<div class="nsk-board-tier" data-board-tier="${escapeHtml(tier.key)}">
      <div class="nsk-board-tier-head"><span class="nsk-board-tier-rank">${tier.icon}</span><div class="nsk-board-tier-copy"><b>${escapeHtml(tier.label)}</b><small>${list.length} medlem${list.length === 1 ? '' : 'mer'}</small></div></div>
      <div class="nsk-board-tier-drop" data-board-drop-tier="${escapeHtml(tier.key)}">
        ${list.length ? list.map((m) => nskBoardMemberChip(m, editable)).join('') : `<div class="nsk-board-tier-empty"><span class="nsk-board-tier-empty-icon">◎</span><span>${editable ? 'Træk medlem hertil' : 'Ingen placeret'}</span></div>`}
      </div>
    </div>`;
  }).join('');
  const zones = (data.territories || []).map((t) => `<span class="nsk-board-zone-pill">${escapeHtml(t.name || 'Zone')}</span>`).join('') || '<span class="nsk-board-zone-pill muted">Ingen zoner</span>';
  panel.innerHTML = `
    <div class="nsk-board-shell" style="--gang-color:${escapeHtml(color)}">
      <div class="nsk-board-top">
        <button type="button" class="nsk-btn ghost sm" id="nskBoardBackBtn">← Tilbage</button>
        ${editable ? '<button type="button" class="nsk-btn accent sm" id="nskBoardAddMemberBtn">+ Medlem</button>' : ''}
      </div>
      <div class="nsk-board-hero">
        <div class="nsk-board-hero-accent"></div>
        <div>
          <span class="nsk-board-tag">${escapeHtml(g.tag || 'BANDE')}</span>
          <h3>${escapeHtml(g.name || 'Bande')}</h3>
          <p>${Number(g.member_count || (data.members || []).length)} medlemmer · ${Number(g.territory_count || (data.territories || []).length)} zoner</p>
        </div>
        <span class="nsk-threat-pill ${escapeHtml(g.threat_level || 'medium')}">${escapeHtml((g.threat_level || 'medium').toUpperCase())}</span>
      </div>
      ${g.notes ? `<div class="nsk-board-notes"><label>Noter</label><p>${escapeHtml(g.notes)}</p></div>` : ''}
      <div class="nsk-board-zones"><label>Territorier</label><div class="nsk-board-zone-list">${zones}</div></div>
      <div class="nsk-board-head"><div><b>Rangliste / Board</b><small>${editable ? 'Træk medlemmer mellem rækker for at placere dem' : 'Overblik over kendt hierarki'}</small></div><span class="nsk-board-head-pill">${Number((data.members || []).length)} medlemmer</span></div>
      <div class="nsk-board-tiers">${tiersHtml}</div>
    </div>`;
  $('#nskBoardBackBtn')?.addEventListener('click', closeNskGangBoard);
  $('#nskBoardAddMemberBtn')?.addEventListener('click', () => openNskAddMemberModal(g.id));
  panel.querySelectorAll('[data-board-open-profile]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const ident = btn.dataset.boardOpenProfile;
      if(!ident) return;
      if(typeof openProfilePreviewByIdentifier === 'function') openProfilePreviewByIdentifier(ident);
    });
  });
  if(editable) bindNskGangBoardDrag(panel, g.id);
}
async function saveNskGangBoardLayout(gangId){
  const panel = $('#nskGangBoardPanel');
  if(!panel || !gangId) return;
  const members = [];
  panel.querySelectorAll('[data-board-drop-tier]').forEach((drop) => {
    const tier = drop.dataset.boardDropTier;
    drop.querySelectorAll('[data-board-member-id]').forEach((el, idx) => {
      members.push({ id: Number(el.dataset.boardMemberId), board_tier: tier, board_rank: idx });
    });
  });
  const resp = await nui('saveNskGangBoardLayout', { gang_id: gangId, members });
  if(!resp?.ok) toast(resp?.message || 'Kunne ikke gemme rangliste.');
}
function bindNskGangBoardDrag(panel, gangId){
  let dragId = null;
  panel.querySelectorAll('[data-board-member-id].editable').forEach((el) => {
    el.addEventListener('dragstart', (e) => {
      dragId = el.dataset.boardMemberId;
      el.classList.add('dragging');
      e.dataTransfer?.setData('text/plain', dragId || '');
      e.dataTransfer.effectAllowed = 'move';
    });
    el.addEventListener('dragend', () => {
      el.classList.remove('dragging');
      dragId = null;
      panel.querySelectorAll('.nsk-board-tier-drop').forEach((d) => d.classList.remove('drag-over'));
    });
  });
  panel.querySelectorAll('[data-board-drop-tier]').forEach((drop) => {
    drop.addEventListener('dragover', (e) => {
      e.preventDefault();
      drop.classList.add('drag-over');
      e.dataTransfer.dropEffect = 'move';
    });
    drop.addEventListener('dragleave', () => drop.classList.remove('drag-over'));
    drop.addEventListener('drop', async (e) => {
      e.preventDefault();
      drop.classList.remove('drag-over');
      const id = dragId || e.dataTransfer?.getData('text/plain');
      const chip = panel.querySelector(`[data-board-member-id="${CSS.escape(String(id))}"]`);
      if(!chip || !drop) return;
      const empty = drop.querySelector('.nsk-board-tier-empty');
      if(empty) empty.remove();
      drop.appendChild(chip);
      await saveNskGangBoardLayout(gangId);
      const r = await nui('getNskGangBoard', { gang_id: gangId });
      if(r?.ok){
        nskGangBoard = r;
        renderNskGangBoardPanel();
      }
    });
  });
}
async function openNskGangBoard(gangId){
  if(!gangId) return;
  nskSelectedGangId = gangId;
  const r = await nui('getNskGangBoard', { gang_id: gangId });
  if(!r?.ok || !r.gang){ toast(r?.message || 'Kunne ikke åbne bande-board.'); return; }
  nskGangBoard = r;
  nskShowGangBoardShell(true);
  renderNskGangBoardPanel();
}
function closeNskGangBoard(){
  nskSelectedGangId = null;
  nskGangBoard = null;
  nskShowGangBoardShell(false);
  renderNskPanels();
}
function renderNskPanels(){
  if(nskSelectedGangId) return;
  const gangsBox = $('#nskPanelGangs');
  const membersBox = $('#nskPanelMembers');
  const terrBox = $('#nskPanelTerritories');
  const gangs = nskOverview.gangs || [];
  const members = nskOverview.members || [];
  const territories = nskOverview.territories || [];
  if(gangsBox){
    gangsBox.innerHTML = gangs.length ? gangs.map((g) => `<div class="nsk-pro-card nsk-gang-card clickable" data-open-gang-board="${g.id}" style="--gang-color:${escapeHtml(g.color || '#ff3048')}">
      <div class="nsk-pro-card-accent"></div>
      <div class="nsk-pro-card-body"><b>${escapeHtml(g.name || 'Bande')}</b><small>${escapeHtml(g.tag || '—')} · ${Number(g.member_count||0)} medlemmer · ${Number(g.territory_count||0)} zoner</small></div>
      <span class="nsk-threat-pill ${escapeHtml(g.threat_level || 'medium')}">${escapeHtml((g.threat_level || 'medium').toUpperCase())}</span>
    </div>`).join('') : '<div class="nsk-empty-state"><b>Ingen bander endnu</b><small>Opret den første bande med + Bande</small></div>';
    gangsBox.querySelectorAll('[data-open-gang-board]').forEach((el) => {
      el.onclick = () => openNskGangBoard(Number(el.dataset.openGangBoard));
    });
  }
  if(membersBox){
    const addBtn = mdtNskManage ? '<div class="nsk-panel-toolbar"><button type="button" class="nsk-btn accent sm" id="nskAddMemberBtn">+ Medlem</button></div>' : '';
    membersBox.innerHTML = addBtn + (members.length ? members.map((m) => `<div class="nsk-pro-card nsk-member-card clickable" data-open-profile-ident="${escapeHtml(m.identifier || '')}" style="--gang-color:${escapeHtml(m.gang_color || '#ff3048')}">
      <div class="nsk-pro-card-accent"></div>
      <span class="nsk-member-avatar">${escapeHtml(nskInitials(m.person_name))}</span>
      <div class="nsk-pro-card-body"><b>${escapeHtml(m.person_name || 'Ukendt')}</b><small>${escapeHtml(m.gang_name || 'Bande')} · ${escapeHtml((m.identifier || '').slice(0, 22))}</small></div>
      <span class="nsk-member-role">${escapeHtml(m.role || 'Medlem')}</span>
    </div>`).join('') : '<div class="nsk-empty-state"><b>Ingen medlemmer</b><small>Tryk + Medlem for at registrere</small></div>');
    $('#nskAddMemberBtn') && ($('#nskAddMemberBtn').onclick = () => openNskAddMemberModal());
    membersBox.querySelectorAll('[data-open-profile-ident]').forEach((el) => {
      el.onclick = () => {
        const ident = el.dataset.openProfileIdent;
        if(!ident) return;
        setPage('profiles');
        $('#profileSearch').value = ident;
        refreshProfiles().then(() => {
          const idx = profiles.findIndex((p) => p.identifier === ident);
          if(idx >= 0) openProfile(idx);
        });
      };
    });
  }
  if(terrBox){
    terrBox.innerHTML = territories.length ? territories.map((t) => {
      const isSel = Number(t.id) === Number(nskSelectedTerritoryId);
      return `<div class="nsk-pro-card nsk-territory-card clickable ${isSel ? 'active' : ''}" data-select-territory="${t.id}" style="--gang-color:${escapeHtml(t.color || t.gang_color || '#ff3048')}">
        <div class="nsk-pro-card-accent"></div>
        <div class="nsk-pro-card-body"><b>${escapeHtml(t.name || 'Territorium')}</b><small>${escapeHtml(t.gang_name || 'Bande')} · ${nskTerritoryAreaSqM(nskTerritoryResolveVertices(t))} m²</small><em>${Math.round(t.center_x||0)}, ${Math.round(t.center_y||0)}</em></div>
        <span class="nsk-zone-pill">ZONE</span>
      </div>`;
    }).join('') : '<div class="nsk-empty-state"><b>Ingen territorier</b><small>Tryk ◎ Markér territorium · klik kortet · træk hjørner</small></div>';
    terrBox.querySelectorAll('[data-select-territory]').forEach((el) => {
      el.onclick = () => selectNskTerritory(Number(el.dataset.selectTerritory), false);
    });
  }
}

function openNskGangModal(){
  if(!mdtNskManage){ toast('Ingen adgang til at oprette bander.'); return; }
  $('#modalTitle').textContent = 'Opret bande';
  $('#modalFields').innerHTML = `<div class="nsk-form-pro nsk-modal-pro">
    <p class="nsk-modal-lead">Registrer en ny bande i NSK-registeret. Farven bruges på kortet og profiler.</p>
    <label>Bandenavn</label><input id="nskGangName" placeholder="Fx Vagos">
    <label>Tag / kort navn</label><input id="nskGangTag" placeholder="VAG">
    <label>Farve</label>${nskColorSwatchHtml('nskGangColor', '#ff3048')}
    <label>Trusselsniveau</label><select id="nskGangThreat"><option value="low">Lav</option><option value="medium" selected>Medium</option><option value="high">Høj</option><option value="critical">Kritisk</option></select>
    <label>Noter</label><textarea id="nskGangNotes" placeholder="Kendt aktivitet, ledelse, relationer..."></textarea>
  </div>`;
  bindNskColorSwatches($('#modalFields'));
  nskApplyModalTheme();
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Opret bande';
  $('#modalSave').onclick = async () => {
    const resp = await nui('saveNskGang', {
      name: $('#nskGangName')?.value || '',
      tag: $('#nskGangTag')?.value || '',
      color: $('#nskGangColor')?.value || '#ff3048',
      threat_level: $('#nskGangThreat')?.value || 'medium',
      notes: $('#nskGangNotes')?.value || '',
    });
    closeModal();
    if(resp && resp.ok){ toast(resp.message || 'Bande oprettet.'); refreshNskOverview(); }
    else toast(resp?.message || 'Kunne ikke oprette bande.');
    $('#modalSave').onclick = null;
  };
}

function openNskTerritoryModal(){
  startNskTerritoryPlace();
}

let nskMemberPick = null;
function openNskAddMemberModal(preselectGangId){
  if(!mdtNskManage){ toast('Ingen adgang.'); return; }
  const gangs = nskOverview.gangs || [];
  if(!gangs.length){ toast('Opret en bande først.'); return; }
  nskMemberPick = null;
  const gangOpts = gangs.map((g) => `<option value="${g.id}" ${Number(preselectGangId) === Number(g.id) ? 'selected' : ''}>${escapeHtml(g.name || 'Bande')}</option>`).join('');
  $('#modalTitle').textContent = 'Tilføj bandemedlem';
  $('#modalFields').innerHTML = `<div class="nsk-form-pro nsk-modal-pro">
    <p class="nsk-modal-lead">Søg efter person og vælg bande. Farven følger banden på kortet.</p>
    <label>Søg person</label>
    <input id="nskMemberSearch" placeholder="Navn, telefon, identifier..." autofocus>
    <div id="nskMemberResults" class="criminal-results"><div class="profile-search-empty">Skriv for at søge.</div></div>
    <div id="nskMemberPickBox" class="nsk-member-pick hidden"></div>
    <label>Bande</label>
    <select id="nskMemberGang">${gangOpts}</select>
    <label>Rolle</label>
    <input id="nskMemberRole" value="Medlem" placeholder="Fx Medlem / Løjtnant">
  </div>`;
  nskApplyModalTheme();
  $('#modal').classList.remove('hidden');
  $('#modalSave').style.display = '';
  $('#modalSave').textContent = 'Registrer medlem';
  const runSearch = async () => {
    const q = $('#nskMemberSearch')?.value || '';
    const box = $('#nskMemberResults');
    if(!box) return;
    if(!q.trim()){ box.innerHTML = '<div class="profile-search-empty">Skriv for at søge.</div>'; return; }
    const r = await nui('getProfiles', { search: q });
    const list = (r && r.profiles) || [];
    if(!list.length){ box.innerHTML = '<div class="profile-search-empty">Ingen personer fundet.</div>'; return; }
    box.innerHTML = list.slice(0, 20).map((p, idx) => `<div class="criminal-result-card" data-nsk-pick-member="${idx}">
      <div class="result-avatar">${escapeHtml(nskInitials(p.name))}</div>
      <div class="result-main"><b>${escapeHtml(p.name || 'Ukendt')}</b><small>${escapeHtml((p.identifier || '').slice(0, 28))}</small></div>
      <div class="result-action">Vælg</div>
    </div>`).join('');
    box._nskList = list;
    box.querySelectorAll('[data-nsk-pick-member]').forEach((el) => {
      el.onclick = () => {
        const pick = box._nskList[Number(el.dataset.nskPickMember)];
        if(!pick) return;
        nskMemberPick = pick;
        const pickBox = $('#nskMemberPickBox');
        if(pickBox){
          pickBox.classList.remove('hidden');
          pickBox.innerHTML = `<b>Valgt:</b> ${escapeHtml(pick.name || 'Ukendt')}`;
        }
      };
    });
  };
  let timer;
  $('#nskMemberSearch')?.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(runSearch, 140); });
  $('#modalSave').onclick = async () => {
    if(!nskMemberPick?.identifier){ toast('Vælg en person først.'); return; }
    const gangId = Number($('#nskMemberGang')?.value || 0);
    if(!gangId){ toast('Vælg en bande.'); return; }
    const resp = await nui('registerNskGangMember', {
      identifier: nskMemberPick.identifier,
      person_name: nskMemberPick.name,
      gang_id: gangId,
      role: ($('#nskMemberRole')?.value || 'Medlem').trim(),
    });
    closeModal();
    if(resp && resp.ok){
      toast(resp.message || 'Medlem registreret.');
      await refreshNskOverview();
      if(nskSelectedGangId) openNskGangBoard(nskSelectedGangId);
    }
    else toast(resp?.message || 'Kunne ikke registrere medlem.');
    $('#modalSave').onclick = null;
    nskMemberPick = null;
  };
}

let nskObservations = [];
let currentNskObservation = null;
let nskObsDirty = false;
let nskObsPersonPick = null;
let nskObsOfficerMeta = null;
let nskConnections = [];
let nskActivityLogs = [];

const nskRelationLabels = {
  ally: 'Allieret',
  rival: 'Rival',
  neutral: 'Neutral',
  unknown: 'Ukendt',
  supplier: 'Leverandør',
  conflict: 'Konflikt',
};

function nskPriorityClass(p){
  const v = String(p || 'normal').toLowerCase();
  if(v === 'high' || v === 'critical') return 'priority-high';
  if(v === 'low') return 'priority-low';
  return 'priority-normal';
}
function nskApplyModalTheme(){ $('#modal')?.classList.add('nsk-modal'); }
function nskInitials(name){
  const parts = String(name || '?').trim().split(/\s+/).filter(Boolean);
  if(parts.length >= 2) return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  return String(parts[0] || '?').slice(0, 2).toUpperCase();
}
function nskEmptyState(title, sub){
  return `<div class="nsk-ultra-empty"><div class="nsk-ultra-empty-icon">◌</div><b>${escapeHtml(title)}</b><small>${escapeHtml(sub)}</small></div>`;
}

function fillNskGangSelect(sel, gangs, includeAll){
  if(!sel) return;
  const current = sel.value;
  const head = includeAll ? '<option value="">Alle bander</option>' : '';
  sel.innerHTML = head + (gangs || []).map((g) => `<option value="${g.id}">${escapeHtml(g.name || 'Bande')}</option>`).join('');
  if(current && [...sel.options].some((o) => o.value === current)) sel.value = current;
}

async function refreshNskObservations(){
  if(!mdtNskView){ refreshNskAccess(); if(!mdtNskView) return; }
  const r = await nui('getNskObservations', {
    search: $('#nskObsSearch')?.value || '',
    target_type: $('#nskObsFilter')?.value || '',
    gang_id: Number($('#nskObsGangFilter')?.value || 0) || undefined,
  });
  if(!r || !r.ok){ toast(r?.message || 'Kunne ikke hente observationer.'); return; }
  nskObservations = r.observations || [];
  fillNskGangSelect($('#nskObsGangFilter'), r.gangs || [], true);
  fillNskObsGangSelectEdit(r.gangs || nskOverview.gangs || []);
  refreshNskAccess();
  await loadNskObsOfficerMeta();
  renderNskObservations();
  if(!currentNskObservation && mdtNskManage) openNskObservationEditor(null);
  else if(currentNskObservation?.id){
    const again = nskObservations.find((x) => Number(x.id) === Number(currentNskObservation.id));
    if(again) openNskObservationEditor(again);
  }
  const typeEdit = $('#nskObsTargetTypeEdit');
  if(typeEdit && !typeEdit.dataset.bound){
    typeEdit.dataset.bound = '1';
    typeEdit.onchange = () => { syncNskObsTargetTypeEdit(); nskObsDirty = true; syncNskObsSaveState(); };
  }
}

function syncNskObsSaveState(){
  const el = $('#nskObsSaveState');
  if(el) el.textContent = nskObsDirty ? 'Ændringer ikke gemt' : 'Ingen ændringer at gemme';
}
async function loadNskObsOfficerMeta(){
  const r = await nui('getSelfProfile', {}).catch(() => null);
  if(r?.ok && r.profile){
    nskObsOfficerMeta = r.profile;
    const nameEl = $('#nskObsOfficerName');
    const badgeEl = $('#nskObsOfficerBadge');
    const metaEl = $('#nskObsOfficerMeta');
    if(nameEl) nameEl.textContent = r.profile.name || 'Ukendt betjent';
    if(badgeEl) badgeEl.textContent = r.profile.badge || formatPoliceBadge(r.profile.pnumber, r.profile.division);
    if(metaEl) metaEl.textContent = `${r.profile.division || 'Patrulje'} · ${r.profile.role || 'Betjent'}`;
    if($('#officerGrade')) $('#officerGrade').textContent = r.profile.badge || formatPoliceBadge(r.profile.pnumber, r.profile.division);
  }
}
function fillNskObsGangSelectEdit(gangs){
  const sel = $('#nskObsGangEdit');
  if(!sel) return;
  const cur = sel.value;
  sel.innerHTML = `<option value="">Vælg bande...</option>${(gangs || []).map((g) => `<option value="${g.id}">${escapeHtml(g.name || 'Bande')}</option>`).join('')}`;
  if(cur) sel.value = cur;
}
function renderNskObsPersonPickBox(){
  const pickBox = $('#nskObsPersonPickBoxEdit');
  if(!pickBox) return;
  if(!nskObsPersonPick?.identifier){
    pickBox.classList.add('hidden');
    pickBox.innerHTML = '';
    return;
  }
  pickBox.classList.remove('hidden');
  pickBox.innerHTML = `<b>Valgt:</b> ${escapeHtml(nskObsPersonPick.name || 'Ukendt')}`;
}
function bindNskObsPersonSearch(){
  const input = $('#nskObsPersonSearchEdit');
  if(!input || input.dataset.bound) return;
  input.dataset.bound = '1';
  const runSearch = async () => {
    const box = $('#nskObsPersonResultsEdit');
    if(!box) return;
    const q = (input.value || '').trim();
    if(!q){
      box.innerHTML = '<div class="profile-search-empty">Søg og vælg en person.</div>';
      return;
    }
    const r = await nui('getProfiles', { search: q });
    const list = (r && r.profiles) || [];
    if(!list.length){
      box.innerHTML = '<div class="profile-search-empty">Ingen personer fundet.</div>';
      return;
    }
    box.innerHTML = list.slice(0, 12).map((p, idx) => `<div class="criminal-result-card" data-nsk-obs-pick-person="${idx}">
      <div class="result-avatar">${escapeHtml(nskInitials(p.name))}</div>
      <div class="result-main"><b>${escapeHtml(p.name || 'Ukendt borger')}</b><small>${escapeHtml(p.phone || 'Ingen telefon')} · ${escapeHtml(p.dob || 'Ukendt fødselsdato')}</small></div>
      <div class="result-action">Vælg</div>
    </div>`).join('');
    box._nskObsList = list;
    box.querySelectorAll('[data-nsk-obs-pick-person]').forEach((el) => {
      el.onclick = () => {
        const pick = box._nskObsList[Number(el.dataset.nskObsPickPerson)];
        if(!pick?.identifier) return;
        nskObsPersonPick = { identifier: pick.identifier, name: pick.name || 'Ukendt' };
        input.value = '';
        box.innerHTML = '<div class="profile-search-empty">Person valgt.</div>';
        renderNskObsPersonPickBox();
        nskObsDirty = true;
        syncNskObsSaveState();
      };
    });
  };
  let timer;
  input.addEventListener('input', () => { clearTimeout(timer); timer = setTimeout(runSearch, 140); });
}
function syncNskObsTargetTypeEdit(){
  const isPerson = $('#nskObsTargetTypeEdit')?.value === 'person';
  $('#nskObsGangWrapEdit')?.classList.toggle('hidden', isPerson);
  $('#nskObsPersonWrapEdit')?.classList.toggle('hidden', !isPerson);
  if(isPerson) bindNskObsPersonSearch();
}
function renderNskObservations(){
  const box = $('#nskObsList');
  if(!box) return;
  if(!nskObservations.length){
    box.innerHTML = '<div class="nsk-obs-empty">Ingen observationer endnu</div>';
    return;
  }
  box.innerHTML = nskObservations.map((o) => {
    const active = currentNskObservation && Number(currentNskObservation.id) === Number(o.id);
    const pri = String(o.priority || 'normal').toLowerCase();
    const target = o.target_type === 'person' ? (o.person_name || 'Person') : (o.gang_name || 'Bande');
    return `<button type="button" class="nsk-obs-list-card ${active ? 'active' : ''} ${nskPriorityClass(o.priority)}" data-open-obs="${o.id}">
      <div class="nsk-obs-list-top"><b>${escapeHtml(o.subject || 'Observation')}</b><span class="nsk-intel-priority ${escapeHtml(pri)}">${escapeHtml(pri.toUpperCase())}</span></div>
      <small>${escapeHtml(target)}</small>
      <em>${escapeHtml(fmtDate(o.created_at) || '')} · ${escapeHtml(o.created_by_name || 'Ukendt')}</em>
    </button>`;
  }).join('');
  box.querySelectorAll('[data-open-obs]').forEach((btn) => {
    btn.onclick = () => {
      const obs = nskObservations.find((x) => Number(x.id) === Number(btn.dataset.openObs));
      if(obs) openNskObservationEditor(obs);
    };
  });
}
function openNskObservationEditor(obs){
  if(obs && !mdtNskManage && !mdtNskView){ toast('Ingen adgang.'); return; }
  if(!obs && !mdtNskManage){ toast('Ingen adgang til at oprette observationer.'); return; }
  currentNskObservation = obs ? Object.assign({}, obs) : {
    draft: true, target_type: 'gang', priority: 'normal', body: '', subject: ''
  };
  nskObsDirty = !!currentNskObservation.draft;
  const gangs = nskOverview.gangs?.length ? nskOverview.gangs : [];
  fillNskObsGangSelectEdit(gangs);
  $('#nskObsNumber').textContent = currentNskObservation.id ? `ID ${currentNskObservation.id}` : 'NY';
  $('#nskObsCreated').textContent = currentNskObservation.id
    ? `Oprettet af ${currentNskObservation.created_by_name || 'Ukendt'} · ${fmtDate(currentNskObservation.created_at) || ''}`
    : 'Ny observation - ikke gemt endnu';
  $('#nskObsSubjectEdit').value = currentNskObservation.subject || '';
  $('#nskObsBodyEdit').innerHTML = (currentNskObservation.body || '').replace(/\n/g, '<br>');
  $('#nskObsTargetTypeEdit').value = currentNskObservation.target_type === 'person' ? 'person' : 'gang';
  $('#nskObsGangEdit').value = currentNskObservation.gang_id ? String(currentNskObservation.gang_id) : '';
  if(currentNskObservation.target_type === 'person' && currentNskObservation.identifier){
    nskObsPersonPick = {
      identifier: currentNskObservation.identifier,
      name: currentNskObservation.person_name || 'Ukendt',
    };
  } else {
    nskObsPersonPick = null;
  }
  const personSearch = $('#nskObsPersonSearchEdit');
  if(personSearch) personSearch.value = '';
  const personResults = $('#nskObsPersonResultsEdit');
  if(personResults){
    personResults.innerHTML = nskObsPersonPick
      ? '<div class="profile-search-empty">Person valgt.</div>'
      : '<div class="profile-search-empty">Søg og vælg en person.</div>';
  }
  renderNskObsPersonPickBox();
  $('#nskObsPriorityEdit').value = currentNskObservation.priority || 'normal';
  $('#nskObsDeleteBtn')?.classList.toggle('hidden', !currentNskObservation.id || !mdtNskManage);
  syncNskObsTargetTypeEdit();
  syncNskObsSaveState();
  renderNskObservations();
}
async function saveNskObservationEditor(){
  if(!mdtNskManage){ toast('Ingen adgang.'); return; }
  const subject = ($('#nskObsSubjectEdit')?.value || '').trim();
  const body = textOnly($('#nskObsBodyEdit')?.innerHTML || '');
  if(!subject){ toast('Skriv et emne.'); return; }
  const targetType = $('#nskObsTargetTypeEdit')?.value || 'gang';
  if(targetType === 'person' && !nskObsPersonPick?.identifier){
    toast('Vælg en person fra søgningen.');
    return;
  }
  const resp = await nui('saveNskObservation', {
    id: currentNskObservation?.id || undefined,
    target_type: targetType,
    gang_id: Number($('#nskObsGangEdit')?.value || 0) || undefined,
    identifier: targetType === 'person' ? (nskObsPersonPick?.identifier || '') : '',
    person_name: targetType === 'person' ? (nskObsPersonPick?.name || '') : '',
    subject,
    priority: $('#nskObsPriorityEdit')?.value || 'normal',
    body,
  });
  if(resp?.ok){
    toast(resp.message || 'Observation gemt.');
    nskObsDirty = false;
    await refreshNskObservations();
    const savedId = resp.id || currentNskObservation?.id;
    const saved = nskObservations.find((x) => Number(x.id) === Number(savedId)) || nskObservations[0];
    if(saved) openNskObservationEditor(saved);
    else openNskObservationEditor(null);
  } else toast(resp?.message || 'Kunne ikke gemme observation.');
}
async function deleteNskObservationEditor(){
  if(!mdtNskManage || !currentNskObservation?.id) return;
  const resp = await nui('deleteNskObservation', { id: Number(currentNskObservation.id) });
  if(resp?.ok){
    toast(resp.message || 'Observation slettet.');
    currentNskObservation = null;
    nskObsDirty = false;
    await refreshNskObservations();
    openNskObservationEditor(null);
  } else toast(resp?.message || 'Kunne ikke slette observation.');
}

async function refreshNskConnections(){
  if(!mdtNskView){ refreshNskAccess(); if(!mdtNskView) return; }
  const r = await nui('getNskConnections', { gang_id: Number($('#nskConnGangFilter')?.value || 0) || undefined });
  if(!r || !r.ok){ toast(r?.message || 'Kunne ikke hente forbindelser.'); return; }
  nskConnections = r.connections || [];
  fillNskGangSelect($('#nskConnGangFilter'), r.gangs || [], true);
  refreshNskAccess();
  renderNskConnections();
}

function renderNskConnections(){
  const box = $('#nskConnGrid');
  if(!box) return;
  if(!nskConnections.length){
    box.innerHTML = nskEmptyState('Intet netværk kortlagt', 'Tilføj allierede, rivaler, leverandører eller konflikter mellem bander.');
    return;
  }
  box.innerHTML = nskConnections.map((c) => {
    const rel = nskRelationLabels[c.relation_type] || c.relation_type || 'Ukendt';
    const colorA = c.gang_a_color || '#ff3048';
    const colorB = c.gang_b_color || '#4a9eff';
    const type = escapeHtml(c.relation_type || 'unknown');
    return `<article class="nsk-net-card type-${type}">
      <div class="nsk-net-glow"></div>
      <div class="nsk-net-nodes">
        <span class="nsk-net-node" style="--gang-color:${escapeHtml(colorA)}">${escapeHtml(c.gang_a_name || 'Bande A')}</span>
        <span class="nsk-net-link"><em>${escapeHtml(rel.toUpperCase())}</em><i>↔</i></span>
        <span class="nsk-net-node" style="--gang-color:${escapeHtml(colorB)}">${escapeHtml(c.gang_b_name || 'Bande B')}</span>
      </div>
      ${c.notes ? `<p class="nsk-net-notes">${escapeHtml(c.notes)}</p>` : ''}
      <footer class="nsk-net-foot">
        <small>${escapeHtml(fmtDate(c.updated_at || c.created_at))}</small>
        <span>${escapeHtml(c.created_by_name || 'Ukendt')}</span>
        ${mdtNskManage ? `<button type="button" class="nsk-btn danger sm" data-delete-conn="${c.id}">Slet</button>` : ''}
      </footer>
    </article>`;
  }).join('');
  box.querySelectorAll('[data-delete-conn]').forEach((btn) => {
    btn.onclick = async () => {
      const resp = await nui('deleteNskConnection', { id: Number(btn.dataset.deleteConn) });
      if(resp && resp.ok){ toast(resp.message || 'Forbindelse slettet.'); refreshNskConnections(); }
      else toast(resp?.message || 'Kunne ikke slette forbindelse.');
    };
  });
}

function openNskConnectionModal(){
  if(!mdtNskManage){ toast('Ingen adgang til at oprette forbindelser.'); return; }
  const loadGangs = async () => {
    if((nskOverview.gangs || []).length) return nskOverview.gangs;
    const r = await nui('getNskConnections', {});
    return (r && r.gangs) || [];
  };
  loadGangs().then((gangList) => {
    const opts = (gangList || []).map((g) => `<option value="${g.id}">${escapeHtml(g.name || 'Bande')}</option>`).join('');
    $('#modalTitle').textContent = 'Ny bandeforbindelse';
    $('#modalFields').innerHTML = `<div class="nsk-form-pro nsk-modal-pro">
      <p class="nsk-modal-lead">Kortlæg relationer mellem bander — allierede, rivaler, leverandører og konflikter.</p>
      <label>Bande A</label><select id="nskConnA"><option value="">Vælg...</option>${opts}</select>
      <label>Bande B</label><select id="nskConnB"><option value="">Vælg...</option>${opts}</select>
      <label>Relation</label>
      <select id="nskConnRelation">
        <option value="ally">Allieret</option>
        <option value="rival">Rival</option>
        <option value="conflict">Konflikt</option>
        <option value="supplier">Leverandør</option>
        <option value="neutral">Neutral</option>
        <option value="unknown" selected>Ukendt</option>
      </select>
      <label>Noter</label><textarea id="nskConnNotes" placeholder="Kontekst, observationer, kilder..."></textarea>
    </div>`;
    nskApplyModalTheme();
    $('#modal').classList.remove('hidden');
    $('#modalSave').style.display = '';
    $('#modalSave').textContent = 'Gem forbindelse';
    $('#modalSave').onclick = async () => {
      const resp = await nui('saveNskConnection', {
        gang_a_id: Number($('#nskConnA')?.value || 0),
        gang_b_id: Number($('#nskConnB')?.value || 0),
        relation_type: $('#nskConnRelation')?.value || 'unknown',
        notes: $('#nskConnNotes')?.value || '',
      });
      closeModal();
      if(resp && resp.ok){ toast(resp.message || 'Forbindelse gemt.'); refreshNskConnections(); }
      else toast(resp?.message || 'Kunne ikke gemme forbindelse.');
      $('#modalSave').onclick = null;
    };
  });
}

async function refreshNskActivity(){
  if(!mdtNskView){ refreshNskAccess(); if(!mdtNskView) return; }
  const r = await nui('getNskActivityLog', {
    search: $('#nskActSearch')?.value || '',
    officer: $('#nskActOfficer')?.value || '',
    limit: 200,
  });
  if(!r || !r.ok){ toast(r?.message || 'Kunne ikke hente NSK-aktivitet.'); return; }
  nskActivityLogs = r.logs || [];
  renderNskActivity();
}

function renderNskActivity(){
  const box = $('#nskActTimeline');
  if(!box) return;
  if(!nskActivityLogs.length){
    box.innerHTML = nskEmptyState('Ingen aktivitet endnu', 'NSK-handlinger logges automatisk når bander, zoner og medlemmer ændres.');
    return;
  }
  box.innerHTML = nskActivityLogs.map((log) => {
    const msg = log.message || auditLabel(log.action);
    const meta = auditMetaLine(log);
    return `<article class="nsk-audit-item">
      <div class="nsk-audit-rail"><span class="nsk-audit-dot"></span></div>
      <div class="nsk-audit-body">
        <header><b>${escapeHtml(auditLabel(log.action))}</b><time>${escapeHtml(fmtDate(log.created_at))}</time></header>
        <div class="nsk-audit-officer">${escapeHtml(log.officer_name || 'Ukendt')}${log.officer_badge ? ` <em>${escapeHtml(log.officer_badge)}</em>` : ''}</div>
        <p>${escapeHtml(msg)}</p>${meta ? `<small>${meta}</small>` : ''}
      </div>
    </article>`;
  }).join('');
}


