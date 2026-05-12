const $ = sel => document.querySelector(sel);

const staticSteps = [
  { id: '00', label: '环境预检' },
  { id: '01', label: '范围界定' },
  { id: '02', label: '查询扩展' },
  { id: '03', label: '多源检索' },
  { id: '04', label: '去重与分拣' },
  { id: '05', label: 'BibTeX 与验证' },
  { id: '06', label: 'Zotero 导入' },
  { id: '07', label: '覆盖性检查' },
  { id: '08', label: '交付物生成' }
];

let liveStatus = null;
let liveStepLabel = '';
let selectedStepLabel = '';
const stepSnapshots = {};

async function fetchStatus() {
  try {
    const r = await fetch('/api/status');
    return await r.json();
  } catch (e) {
    return { error: String(e) };
  }
}

async function fetchHistory() {
  try {
    const r = await fetch('/api/history?limit=50');
    return await r.json();
  } catch (e) {
    return { items: [] };
  }
}



function deepCopy(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function normalizeStepLabel(mainStep) {
  const text = String(mainStep || '');
  for (const step of staticSteps) {
    if (text.indexOf(step.label) !== -1 || text.indexOf(step.id) !== -1) return step.label;
  }
  return '';
}

function stateText(state) {
  const s = String(state || '').toLowerCase();
  if (/error|fail|failed/.test(s)) return '失败';
  if (/done|ok|success|completed/.test(s)) return '已完成';
  if (/running|processing|in_progress/.test(s)) return '进行中';
  if (!s) return '';
  return state;
}

function calcProgress(data) {
  const sub = (data && (data.sub_steps || data.substeps)) || [];
  if (sub.length === 0) return (data && data.progress) || 0;
  const done = sub.filter(s => /done|success|ok|completed/.test(String(s.status || '').toLowerCase())).length;
  return Math.round((done / sub.length) * 100);
}

function getDisplayData() {
  if (!selectedStepLabel) return liveStatus;
  if (selectedStepLabel === liveStepLabel && liveStatus) return liveStatus;
  if (stepSnapshots[selectedStepLabel]) return stepSnapshots[selectedStepLabel];
  return {
    main_step: selectedStepLabel,
    state: 'no-data',
    sub_steps: [{ name: selectedStepLabel, status: 'pending', message: '该步骤尚未归档（切换到下一步骤后会保存）' }],
    updated: ''
  };
}

function renderSteps() {
  const container = $('#steps-list');
  container.innerHTML = '';
  staticSteps.forEach(step => {
    const div = document.createElement('div');
    const isActive = selectedStepLabel
      ? selectedStepLabel === step.label
      : liveStepLabel === step.label;
    div.className = 'step-item' + (isActive ? ' active' : '');
    div.onclick = () => {
      selectedStepLabel = step.label;
      renderAll();
    };

    const icon = document.createElement('div');
    icon.className = 'step-icon';
    icon.textContent = (step.label || '')[0];

    const title = document.createElement('div');
    title.className = 'step-title';
    title.textContent = step.label;

    const status = document.createElement('div');
    status.className = 'step-status';
    if (step.label === liveStepLabel && liveStatus) {
      status.textContent = stateText(liveStatus.state || 'running');
    } else if (stepSnapshots[step.label]) {
      status.textContent = stateText(stepSnapshots[step.label].state || '');
    } else {
      status.textContent = '';
    }

    div.appendChild(icon);
    div.appendChild(title);
    div.appendChild(status);
    container.appendChild(div);
  });
}

function renderDetail(data) {
  const title = $('#detail-title');
  const statusEl = $('#detail-status');
  const subContainer = $('#detail-substeps');
  const raw = $('#raw-json');

  if (!data) {
    title.textContent = '-';
    statusEl.textContent = '';
    subContainer.innerHTML = '';
    raw.textContent = '';
    return;
  }

  if (data.error) {
    title.textContent = '错误';
    statusEl.textContent = data.error;
    subContainer.innerHTML = '';
    raw.textContent = JSON.stringify(data, null, 2);
    return;
  }

  title.textContent = data.main_step || '-';
  statusEl.textContent = data.state || '';

  const sub = data.sub_steps || data.substeps || [];
  subContainer.innerHTML = '';
  sub.forEach(s => {
    const row = document.createElement('div');
    row.className = 'substep';

    const n = document.createElement('div');
    n.className = 'name';
    n.textContent = s.name || s.title || s.task || '-';

    const st = document.createElement('div');
    st.className = 'status';
    st.textContent = s.status || '';
    if (/done|success|ok|completed/.test(String(s.status || '').toLowerCase())) st.style.color = 'var(--good)';
    else if (/error|fail|failed/.test(String(s.status || '').toLowerCase())) st.style.color = 'var(--bad)';
    else st.style.color = 'var(--accent)';

    row.appendChild(n);
    row.appendChild(st);

    if (s.message) {
      const msg = document.createElement('div');
      msg.style.fontSize = '12px';
      msg.style.color = 'var(--muted)';
      msg.textContent = s.message;
      msg.style.marginTop = '6px';
      row.appendChild(msg);
    }

    subContainer.appendChild(row);
  });

  raw.textContent = JSON.stringify(data, null, 2);
}



function renderSidebarSnapshots() {
  const container = $('#sidebar-history-list');
  container.innerHTML = '';

  const items = staticSteps
    .map(step => {
      if (step.label === liveStepLabel && liveStatus) {
        return { ...step, status: liveStatus.state, updated: liveStatus.updated || '', isLive: true };
      }
      if (stepSnapshots[step.label]) {
        return { ...step, status: stepSnapshots[step.label].state, updated: stepSnapshots[step.label].updated || '', isLive: false };
      }
      return null;
    })
    .filter(Boolean);

  if (items.length === 0) {
    container.textContent = '暂无步骤快照';
    return;
  }

  items.forEach(item => {
    const row = document.createElement('div');
    row.className = 'sidebar-history-item' + (selectedStepLabel === item.label ? ' active' : '');
    row.onclick = () => {
      selectedStepLabel = item.label;
      renderAll();
    };

    const main = document.createElement('div');
    main.className = 'sidebar-history-main';
    main.textContent = item.isLive ? `${item.label}（当前）` : item.label;

    const meta = document.createElement('div');
    meta.className = 'sidebar-history-meta';

    const state = document.createElement('div');
    state.textContent = stateText(item.status || '');

    const time = document.createElement('div');
    time.textContent = String(item.updated || '').replace('T', ' ').slice(0, 19);

    meta.appendChild(state);
    meta.appendChild(time);
    row.appendChild(main);
    row.appendChild(meta);
    container.appendChild(row);
  });
}

function renderAll() {
  const data = getDisplayData();
  const p = calcProgress(data || {});
  $('#global-progress').style.width = `${p}%`;
  $('#progress-percent').textContent = `${p}%`;

  renderSteps();
  renderSidebarSnapshots();
  renderDetail(data);
}

function handleStepTransition(nextStatus) {
  if (!nextStatus || nextStatus.error) return;
  const nextLabel = normalizeStepLabel(nextStatus.main_step || '');

  if (liveStatus && liveStepLabel && nextLabel && liveStepLabel !== nextLabel) {
    stepSnapshots[liveStepLabel] = deepCopy(liveStatus);
  }

  liveStatus = nextStatus;
  if (nextLabel) liveStepLabel = nextLabel;
}

async function loadHistory() {
  const history = await fetchHistory();
  const items = history.items || [];

  // Group by step label and keep the latest state for each step
  const stepLatest = {};
  for (const item of items) {
    const label = normalizeStepLabel(item.main_step || '');
    if (label) {
      // Keep the most recent state for each step
      if (!stepLatest[label] || new Date(item.updated) > new Date(stepLatest[label].updated)) {
        stepLatest[label] = item;
      }
    }
  }

  // Populate stepSnapshots
  for (const label in stepLatest) {
    if (label !== liveStepLabel) {
      stepSnapshots[label] = deepCopy(stepLatest[label]);
    }
  }
}

async function tick() {
  const status = await fetchStatus();
  handleStepTransition(status);
  renderAll();
}

// Initialize: load history first, then start live updates
async function init() {
  await loadHistory();
  await tick();
}

init();

const liveBtn = $('#history-live-btn');
if (liveBtn) {
  liveBtn.addEventListener('click', () => {
    selectedStepLabel = '';
    renderAll();
  });
}
