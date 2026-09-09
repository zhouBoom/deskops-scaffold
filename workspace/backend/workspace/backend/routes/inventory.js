const express = require('express');
const router = express.Router();
const db = require('../db');

// 获取全量列表
router.get('/list', (req, res) => {
  try {
    const rows = db.prepare('SELECT * FROM inventory ORDER BY id ASC').all();
    res.json({ success: true, data: rows });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 更新价格（分级单位存储，事务与版本自增）
router.post('/update-price', (req, res) => {
  const { id, price } = req.body;

  if (!id || price === undefined || !Number.isInteger(price) || price < 0) {
    return res.status(400).json({ success: false, message: 'Invalid id or price' });
  }

  try {
    const updateStmt = db.prepare(`
      UPDATE inventory 
      SET price = ?, version = version + 1, updated_at = CURRENT_TIMESTAMP 
      WHERE id = ?
    `);

    const result = updateStmt.run(price, id);

    if (result.changes === 0) {
      return res.status(404).json({ success: false, message: 'Item not found' });
    }

    const updatedRow = db.prepare('SELECT * FROM inventory WHERE id = ?').get(id);
    res.json({ success: true, data: updatedRow });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
