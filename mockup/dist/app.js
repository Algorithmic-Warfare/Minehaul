const $ = (selector) => document.querySelector(selector);
const icon = (name) => `<svg class="icon" aria-hidden="true"><use href="#i-${name}"/></svg>`;
const format = (number) => new Intl.NumberFormat('en-US').format(number);
const jobs = [
  { id: 'MH-0248', from: 'Aster Prime', to: 'Meridian Outpost', source: 'SSU-01', destination: 'SSU-04', network: 'Aster Collective', cargo: 'Refined ore', units: 2400, reward: 19000, collateral: 10000, hours: 8 },
  { id: 'MH-0247', from: 'Halcyon Depot', to: 'Aster Prime', source: 'SSU-02', destination: 'SSU-01', network: 'Aster Collective', cargo: 'Fuel cells', units: 800, reward: 11400, collateral: 6500, hours: 6 },
  { id: 'MH-0246', from: 'Meridian Outpost', to: 'Kepler Station', source: 'SSU-04', destination: 'SSU-05', network: 'Meridian Union', cargo: 'Structural alloy', units: 1600, reward: 23750, collateral: 13000, hours: 12 },
  { id: 'MH-0245', from: 'Echo Anchorage', to: 'Vesper Terminal', source: 'SSU-06', destination: 'SSU-07', network: 'Outer Rim Guild', cargo: 'Electronic parts', units: 320, reward: 8550, collateral: 5000, hours: 4 },
  { id: 'MH-0244', from: 'Kepler Station', to: 'Meridian Outpost', source: 'SSU-05', destination: 'SSU-04', network: 'Meridian Union', cargo: 'Industrial tools', units: 640, reward: 14250, collateral: 8000, hours: 10 },
  { id: 'MH-0243', from: 'Aster Prime', to: 'Halcyon Depot', source: 'SSU-01', destination: 'SSU-02', network: 'Aster Collective', cargo: 'Carbon materials', units: 3200, reward: 9500, collateral: 5000, hours: 6 },
  { id: 'MH-0242', from: 'Vesper Terminal', to: 'Drift Exchange', source: 'SSU-07', destination: 'SSU-08', network: 'Outer Rim Guild', cargo: 'Refined ore', units: 1900, reward: 17100, collateral: 9500, hours: 8 },
  { id: 'MH-0241', from: 'Cinder Relay', to: 'Aster Prime', source: 'SSU-03', destination: 'SSU-01', network: 'Aster Collective', cargo: 'Fuel cells', units: 450, reward: 6650, collateral: 3500, hours: 4 },
];
const networks = [
  { name: 'Aster Collective', tag: 'AST', description: 'Keeping the industrial heart of the frontier supplied.', endpoints: ['Aster Prime', 'Halcyon Depot', 'Cinder Relay'], ids: ['SSU-01', 'SSU-02', 'SSU-03'] },
  { name: 'Meridian Union', tag: 'MRD', description: 'Connecting independent manufacturing and storage.', endpoints: ['Meridian Outpost', 'Kepler Station'], ids: ['SSU-04', 'SSU-05'] },
  { name: 'Outer Rim Guild', tag: 'ORG', description: 'Essential cargo for communities on the outer edge.', endpoints: ['Echo Anchorage', 'Vesper Terminal', 'Drift Exchange'], ids: ['SSU-06', 'SSU-07', 'SSU-08'] },
];
const storageKey = 'minehaul-mockup-v1';
const states = ['claimed', 'collected', 'delivered', 'settled'];
let session = { connected: false, hauls: {} };
let storageAvailable = true;
try {
  const saved = JSON.parse(localStorage.getItem(storageKey));
  if (saved && typeof saved.connected === 'boolean' && saved.hauls && typeof saved.hauls === 'object') {
    session.connected = saved.connected;
    for (const job of jobs) if (states.includes(saved.hauls[job.id])) session.hauls[job.id] = saved.hauls[job.id];
  }
} catch { storageAvailable = false; }
let selectedJob = null;
let view = 'board';
let toastTimer;
let previousFocus;
const networkClass = (network) => network === 'Meridian Union' ? 'meridian' : network === 'Outer Rim Guild' ? 'outer' : '';
const statusText = { claimed: 'Awaiting collection', collected: 'In transit', delivered: 'Dispute window', settled: 'Settled' };
const balance = () => 100000 - jobs.reduce((sum, job) => sum + (session.hauls[job.id] && session.hauls[job.id] !== 'settled' ? job.collateral : 0), 0) + jobs.reduce((sum, job) => sum + (session.hauls[job.id] === 'settled' ? job.reward : 0), 0);

function notify(message) {
  clearTimeout(toastTimer);
  $('#toast').textContent = message;
  $('#toast').hidden = false;
  toastTimer = setTimeout(() => { $('#toast').hidden = true; }, 5000);
}
function saveSession() {
  try { localStorage.setItem(storageKey, JSON.stringify(session)); }
  catch { storageAvailable = false; }
  if (!storageAvailable) notify('Progress is available for this visit only; browser storage is unavailable.');
}
function updateWallet() {
  $('#wallet span').textContent = session.connected ? `Demo wallet · ${format(balance())} CR` : 'Connect demo wallet';
  $('#wallet').setAttribute('aria-label', session.connected ? `Demo wallet connected, ${format(balance())} demo credits available. View demo guide.` : 'Connect demo wallet');
}
function connect() {
  session.connected = true;
  saveSession();
  updateWallet();
  notify('Demo wallet connected. 100,000 demo CR available.');
}
function saveUrl(push = false) {
  const params = new URLSearchParams();
  params.set('view', view);
  if ($('#search').value) params.set('q', $('#search').value);
  if ($('#network-filter').value !== 'all') params.set('network', $('#network-filter').value);
  if ($('#sort').value !== 'newest') params.set('sort', $('#sort').value);
  history[push ? 'pushState' : 'replaceState'](null, '', `${location.pathname}?${params}`);
}
function readUrl() {
  const params = new URLSearchParams(location.search);
  view = ['board', 'hauls', 'networks'].includes(params.get('view')) ? params.get('view') : 'board';
  $('#search').value = params.get('q') || '';
  $('#network-filter').value = networks.some(n => n.name === params.get('network')) ? params.get('network') : 'all';
  $('#sort').value = ['newest', 'reward', 'collateral'].includes(params.get('sort')) ? params.get('sort') : 'newest';
}
function navigate(nextView) {
  view = nextView;
  saveUrl(true);
  render();
}
function render() {
  const available = jobs.filter(job => !session.hauls[job.id]);
  const myJobs = jobs.filter(job => session.hauls[job.id]);
  $('#board-count').textContent = available.length;
  $('#haul-count').textContent = myJobs.length;
  $('#available-stat').textContent = String(available.length).padStart(2, '0');
  $('#rewards-stat').innerHTML = `${format(available.reduce((sum, job) => sum + job.reward, 0))} <small>CR</small>`;
  const headings = {
    board: ['Job board', 'Keep the frontier moving.', 'Find your next haul. Deliver what matters. Get rewarded.'],
    hauls: ['My hauls', 'Every haul has a destination.', 'Track your cargo from collection to settlement.'],
    networks: ['Networks', 'An independent frontier. Connected.', 'Explore the communities and storage units behind every haul.'],
  };
  const [label, title, subtitle] = headings[view];
  document.title = `${label} · Minehaul`;
  $('#breadcrumb').textContent = label;
  $('#page-title').textContent = title;
  $('#page-subtitle').textContent = subtitle;
  document.querySelectorAll('[data-view]').forEach(link => {
    link.classList.toggle('active', link.dataset.view === view);
    if (link.dataset.view === view) link.setAttribute('aria-current', 'page'); else link.removeAttribute('aria-current');
  });
  $('#jobs-section').hidden = view === 'networks';
  $('#networks-section').hidden = view !== 'networks';
  if (view === 'networks') renderNetworks();
  const query = $('#search').value.trim().toLowerCase();
  let list = (view === 'hauls' ? myJobs : available).filter(job =>
    ($('#network-filter').value === 'all' || job.network === $('#network-filter').value) &&
    [job.from, job.to, job.cargo, job.id, job.network, job.source, job.destination].some(value => value.toLowerCase().includes(query))
  );
  if ($('#sort').value === 'reward') list.sort((a, b) => b.reward - a.reward);
  if ($('#sort').value === 'collateral') list.sort((a, b) => a.collateral - b.collateral);
  $('#jobs-title').innerHTML = `${view === 'hauls' ? 'My haul contracts' : 'Available jobs'} <span>${list.length}</span>`;
  $('.section-note').innerHTML = view === 'hauls' ? 'Your demo activity' : '<span class="live-dot"></span> Funded & ready for pickup';
  $('#clear-search').hidden = !$('#search').value;
  $('#job-rows').innerHTML = list.map(job => `<tr>
    <td><div class="route-main">${job.from} ${icon('arrow')} ${job.to}</div><div class="route-meta"><span class="network-dot ${networkClass(job.network)}"></span>${job.network}<span class="separator">/</span><span class="job-id">${job.id}</span></div></td>
    <td><div class="cargo-cell">${icon('box')}<div>${job.cargo}<div class="subtext">${format(job.units)} units</div></div></div></td>
    <td><span class="money reward">${format(job.reward)} <small>CR</small></span></td>
    <td><span class="money">${format(job.collateral)} <small>CR</small></span></td>
    <td><div class="time-cell">${icon('clock')}${job.hours} hours</div>${session.hauls[job.id] ? `<span class="status-label ${session.hauls[job.id] === 'delivered' ? 'pending' : ''}">${statusText[session.hauls[job.id]]}</span>` : ''}</td>
    <td><button class="row-button" data-job="${job.id}" aria-label="View job ${job.id}, ${job.from} to ${job.to}">View job ${icon('arrow')}</button></td>
  </tr>`).join('');
  $('#empty-state').hidden = list.length !== 0;
  $('table').hidden = list.length === 0;
  const unclaimed = view === 'hauls' && myJobs.length === 0;
  $('#empty-state h3').textContent = unclaimed ? 'Your next haul is waiting' : 'No matching jobs';
  $('#empty-state p').textContent = unclaimed ? 'Claim a transfer from the job board to get started.' : 'Try a different endpoint, cargo, or network.';
  $('#reset-filters').textContent = unclaimed ? 'Browse available jobs' : 'Clear filters';
  $('#results-count').textContent = `Showing ${list.length} of ${view === 'hauls' ? myJobs.length : available.length} jobs`;
  updateWallet();
}
function renderNetworks() {
  $('#network-cards').innerHTML = networks.map(network => `<article class="network-card"><span class="small-caps"><span class="network-dot ${networkClass(network.name)}" style="display:inline-block"></span> ${network.tag} / DEMO NETWORK</span><h3>${network.name}</h3><p>${network.description}</p><ul>${network.endpoints.map((endpoint, i) => `<li>${endpoint}<span>${network.ids[i]}</span></li>`).join('')}</ul><button class="button outline" data-network="${network.name}">View available jobs ${icon('arrow')}</button></article>`).join('');
}
function openDialog(dialog) {
  previousFocus = document.activeElement;
  dialog.showModal();
  dialog.querySelector('.close-dialog').focus();
}
function openDetails(id) {
  selectedJob = jobs.find(job => job.id === id);
  if (!selectedJob) return;
  renderDetails();
  openDialog($('#detail-dialog'));
}
function renderDetails() {
  const job = selectedJob;
  const state = session.hauls[job.id];
  const insufficient = !state && session.connected && balance() < job.collateral;
  const actionText = !session.connected ? 'Connect demo wallet' : !state ? 'Claim demo job' : {
    claimed: 'Simulate collection', collected: 'Simulate verified delivery', delivered: 'Skip demo window & settle', settled: 'View my hauls'
  }[state];
  const notes = {
    claimed: 'Collateral is reserved. Collect the full cargo manifest from the source storage unit. This button simulates collection confirmation.',
    collected: 'Deliver the full manifest to the destination. This demo simulates the trusted adapter’s verification; no game cargo moves.',
    delivered: 'Delivery recorded. A simulated 24-hour dispute window is open. Reward and collateral remain escrowed. Continue to skip demo time and settle; no actual dispute process runs.',
    settled: 'Settlement complete. The demo hauler reward was credited and collateral returned. Delivery and settlement are separate events.',
  };
  $('#detail-content').innerHTML = `<h2 id="detail-title">${job.cargo} transfer</h2><p class="dialog-intro">${job.id} <span class="separator">/</span> ${job.network}</p>
    <div class="dialog-route"><div><small>COLLECT FROM · ${job.source}</small><strong>${job.from}</strong></div>${icon('arrow')}<div><small>DELIVER TO · ${job.destination}</small><strong>${job.to}</strong></div></div>
    <dl class="detail-grid"><div><dt>Hauler reward</dt><dd class="money reward">${format(job.reward)} <small>CR</small></dd></div><div><dt>Required collateral</dt><dd class="money">${format(job.collateral)} <small>CR</small></dd></div><div><dt>Cargo manifest</dt><dd>${format(job.units)} units · ${job.cargo}</dd></div><div><dt>Time allowed after claim</dt><dd>${job.hours} hours</dd></div><div><dt>Total funded reward</dt><dd>${format(job.reward / .95)} CR</dd></div><div><dt>Fixed payout split</dt><dd>95% hauler · 5% treasury</dd></div></dl>
    ${state ? `<ol class="progress-steps" aria-label="Haul progress">${states.map((step, i) => `<li class="${states.indexOf(state) >= i ? 'done' : ''}" ${step === state ? 'aria-current="step"' : ''}>${['Claimed', 'Collected', 'Delivered', 'Settled'][i]}</li>`).join('')}</ol>` : ''}
    <div class="info-note">${state ? notes[state] : `Claiming reserves ${format(job.collateral)} demo CR until settlement or dispute resolution. The hauler reward shown is after the treasury split. No real funds move.`}</div>
    ${insufficient ? '<p class="inline-error" role="alert">Not enough demo CR for this collateral. Settle an existing haul or choose a smaller job.</p>' : ''}
    <div class="dialog-actions"><button class="button outline close-dialog">Close</button><button class="button primary" id="job-action" ${insufficient ? 'disabled' : ''}>${actionText} ${icon('arrow')}</button></div>`;
}
function actOnJob() {
  if (!session.connected) { connect(); renderDetails(); $('#job-action').focus(); return; }
  const job = selectedJob;
  const current = session.hauls[job.id];
  if (current === 'settled') { $('#detail-dialog').close(); navigate('hauls'); return; }
  if (!current && balance() < job.collateral) return;
  const next = current ? states[states.indexOf(current) + 1] : 'claimed';
  session.hauls[job.id] = next;
  saveSession();
  render();
  renderDetails();
  $('#job-action').focus();
  notify({ claimed: `${job.id} claimed. Track it in My hauls.`, collected: `${job.id}: demo cargo collection confirmed.`, delivered: `${job.id}: demo delivery recorded. Settlement is pending.`, settled: `${job.id} settled. Reward credited and collateral returned.` }[next]);
}
function clearFilters() {
  $('#search').value = '';
  $('#network-filter').value = 'all';
  $('#sort').value = 'newest';
  if (view === 'hauls' && !Object.keys(session.hauls).length) view = 'board';
  saveUrl(); render();
}
document.addEventListener('click', event => {
  const nav = event.target.closest('[data-view]');
  if (nav) { event.preventDefault(); navigate(nav.dataset.view); }
  const jobButton = event.target.closest('[data-job]');
  if (jobButton) openDetails(jobButton.dataset.job);
  const networkButton = event.target.closest('[data-network]');
  if (networkButton) { $('#search').value = ''; $('#network-filter').value = networkButton.dataset.network; navigate('board'); $('#jobs-section').scrollIntoView({ block: 'start' }); }
  if (event.target.closest('.close-dialog')) event.target.closest('dialog').close();
  if (event.target.closest('#job-action')) actOnJob();
});
$('#wallet').addEventListener('click', () => { if (session.connected) openDialog($('#guide-dialog')); else connect(); });
['#guide', '#how-it-works'].forEach(selector => $(selector).addEventListener('click', () => openDialog($('#guide-dialog'))));
$('#explore-networks').addEventListener('click', () => { navigate('networks'); $('#networks-section').scrollIntoView({ block: 'start' }); });
$('#search').addEventListener('input', event => { if (!event.isComposing) { saveUrl(); render(); } });
$('#search').addEventListener('compositionend', () => { saveUrl(); render(); });
$('#clear-search').addEventListener('click', () => { $('#search').value = ''; saveUrl(); render(); $('#search').focus(); });
['#network-filter', '#sort'].forEach(selector => $(selector).addEventListener('change', () => { saveUrl(); render(); }));
$('#reset-filters').addEventListener('click', clearFilters);
$('#reset-demo').addEventListener('click', () => {
  const prior = session;
  session = { connected: false, hauls: {} };
  saveSession(); clearFilters(); navigate('board'); $('#guide-dialog').close();
  notify('Demo progress reset.');
  const undo = document.createElement('button');
  undo.className = 'button outline'; undo.textContent = 'Undo'; undo.style.marginLeft = '16px';
  undo.addEventListener('click', () => { session = prior; saveSession(); render(); notify('Demo progress restored.'); });
  $('#toast').append(undo);
});
document.querySelectorAll('dialog').forEach(dialog => dialog.addEventListener('close', () => {
  if (previousFocus?.isConnected) previousFocus.focus();
  else { $('#jobs-title').tabIndex = -1; $('#jobs-title').focus({ preventScroll: true }); }
}));
window.addEventListener('popstate', () => { readUrl(); render(); });
readUrl(); render();
