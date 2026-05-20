const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const fetch = global.fetch || require('node-fetch');

const app = express();
app.use(cors());
app.use(express.json());

const root = path.resolve(__dirname);
const configPath = path.join(root, 'config.json');
const exampleConfigPath = path.join(root, 'config.example.json');
let lastStatus = { state: 'idle', updated: new Date().toISOString() };

function loadConfig() {
  try {
    const cfg = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    return cfg;
  } catch (e) {
    try {
      return JSON.parse(fs.readFileSync(exampleConfigPath, 'utf8'));
    } catch (e2) {
      return {};
    }
  }
}

async function pollStatus() {
  try {
    const config = loadConfig();
    const POLL_MS = config.pollIntervalMs || 3000;
    if (!config.statusSource) return;
    if (config.statusSource.type === 'url') {
      const res = await fetch(config.statusSource.url, { method: 'GET' });
      if (res.ok) {
        const data = await res.json();
        lastStatus = { ...data, updated: new Date().toISOString() };
      } else {
        lastStatus = { error: `HTTP ${res.status}`, updated: new Date().toISOString() };
      }
    } else if (config.statusSource.type === 'file') {
      const p = path.isAbsolute(config.statusSource.path)
        ? config.statusSource.path
        : path.join(root, config.statusSource.path);
      if (fs.existsSync(p)) {
        try {
          const data = JSON.parse(fs.readFileSync(p, 'utf8'));
          lastStatus = { ...data, updated: new Date().toISOString() };
        } catch (e) {
          lastStatus = { error: `Invalid JSON in status file: ${p}`, updated: new Date().toISOString() };
        }
      } else {
        lastStatus = { error: `File not found: ${p}`, updated: new Date().toISOString() };
      }
    }
    // schedule next poll according to config
    setTimeout(pollStatus, POLL_MS);
  } catch (err) {
    lastStatus = { error: String(err), updated: new Date().toISOString() };
    setTimeout(pollStatus, 3000);
  }
}

// start polling loop
pollStatus();

app.get('/api/status', (req, res) => {
  res.json(lastStatus);
});

// Read status history from jsonl file (newest first).
app.get('/api/history', (req, res) => {
  const config = loadConfig();
  const historyPathCfg = config.historyFile || './status-history.jsonl';
  const historyPath = path.isAbsolute(historyPathCfg)
    ? historyPathCfg
    : path.join(root, historyPathCfg);

  if (!fs.existsSync(historyPath)) {
    return res.json({ items: [] });
  }

  const limitRaw = Number(req.query.limit || 200);
  const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 2000) : 200;
  const runId = req.query.run_id ? String(req.query.run_id) : '';

  try {
    const lines = fs.readFileSync(historyPath, 'utf8').split(/\r?\n/).filter(Boolean);
    const items = [];
    for (let i = lines.length - 1; i >= 0 && items.length < limit; i -= 1) {
      try {
        const obj = JSON.parse(lines[i]);
        if (!runId || obj.run_id === runId) {
          items.push(obj);
        }
      } catch (e) {
        // ignore invalid line
      }
    }
    res.json({ items });
  } catch (err) {
    res.status(500).json({ items: [], error: String(err) });
  }
});

// Serve frontend static
app.use('/', express.static(path.join(root, 'public')));

const cfg = loadConfig();
const port = (cfg && cfg.port) || 5173;
app.listen(port, () => {
  console.log(`Skill Visualizer running on http://localhost:${port}`);
});
