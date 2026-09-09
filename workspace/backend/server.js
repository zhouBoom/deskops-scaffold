'use strict';
/**
 * server.js – Harbor Benchmark Express entry point
 */

const express = require('express');
const cors    = require('cors');
const { ensureAppDb } = require('./db');

const PORT = 3000;

// Initialise DB (creates / migrates app.db if needed)
const db  = ensureAppDb();
const app = express();

// ── Middleware ───────────────────────────────────────────────────
app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type'],
}));
app.use(express.json());

// ── Health probe ─────────────────────────────────────────────────
app.get('/api/health', (_req, res) => {
  res.json({ status: 'ok', ts: new Date().toISOString() });
});

// ── Inventory routes ─────────────────────────────────────────────
const inventoryRouter = require('./routes/inventory')(db);
app.use('/api/inventory', inventoryRouter);

// ── 404 catch-all ────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// ── Start ────────────────────────────────────────────────────────
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[backend] Express listening on http://0.0.0.0:${PORT}`);
});
