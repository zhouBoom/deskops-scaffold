'use strict';
/**
 * routes/inventory.js – Inventory CRUD routes
 *
 * GET  /api/inventory/list         → returns all 15 rows
 * POST /api/inventory/update-price → transactional price update (price in 分)
 */

const express = require('express');

module.exports = function inventoryRoutes(db) {
  const router = express.Router();

  // ── GET /api/inventory/list ──────────────────────────────────
  router.get('/list', (_req, res) => {
    try {
      const rows = db
        .prepare('SELECT * FROM inventory ORDER BY id ASC')
        .all();
      res.json({ code: 0, data: rows });
    } catch (err) {
      console.error('[inventory/list] Error:', err.message);
      res.status(500).json({ code: 500, error: err.message });
    }
  });

  // ── POST /api/inventory/update-price ────────────────────────
  router.post('/update-price', (req, res) => {
    const { id, price } = req.body;

    // ── Validation ───────────────────────────────────────────
    if (id === undefined || id === null) {
      return res.status(400).json({ code: 400, error: '缺少参数: id' });
    }
    if (price === undefined || price === null) {
      return res.status(400).json({ code: 400, error: '缺少参数: price' });
    }

    const parsedId    = parseInt(id, 10);
    const parsedPrice = parseInt(price, 10);

    if (!Number.isInteger(parsedId) || parsedId <= 0) {
      return res.status(400).json({ code: 400, error: 'id 必须是正整数' });
    }
    if (!Number.isInteger(parsedPrice) || parsedPrice < 0) {
      return res.status(400).json({ code: 400, error: 'price 必须是非负整数（单位：分）' });
    }

    // ── Transactional update ────────────────────────────────
    const doUpdate = db.transaction(() => {
      // Verify row exists first
      const existing = db
        .prepare('SELECT id FROM inventory WHERE id = ?')
        .get(parsedId);

      if (!existing) {
        throw new Error(`记录不存在: id=${parsedId}`);
      }

      const info = db.prepare(`
        UPDATE inventory
        SET
          price      = ?,
          version    = version + 1,
          updated_at = datetime('now', 'localtime')
        WHERE id = ?
      `).run(parsedPrice, parsedId);

      if (info.changes === 0) {
        throw new Error('更新影响行数为 0，回滚');
      }

      return db
        .prepare('SELECT * FROM inventory WHERE id = ?')
        .get(parsedId);
    });

    try {
      const updated = doUpdate();
      res.json({ code: 0, message: '价格更新成功', data: updated });
    } catch (err) {
      console.error('[inventory/update-price] Error:', err.message);
      res.status(400).json({ code: 400, error: err.message });
    }
  });

  return router;
};
