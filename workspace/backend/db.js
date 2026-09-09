'use strict';
/**
 * db.js – Database initialisation for Harbor Benchmark Backend
 *
 * Responsibilities:
 *   1. Resolve the path of app.db (sibling to this file).
 *   2. If app.db is missing, copy seed.db → app.db so the schema + seed data
 *      are always present on first boot without a separate migration step.
 *   3. Run CREATE TABLE IF NOT EXISTS to guarantee schema regardless of source.
 *   4. When called with `node db.js --seed`, write seed.db for Docker build.
 *
 * Price is stored as INTEGER (分 / cents) to avoid IEEE-754 float traps.
 */

const path    = require('path');
const fs      = require('fs');
const Database = require('better-sqlite3');

const DIR      = __dirname;
const APP_DB   = path.join(DIR, 'app.db');
const SEED_DB  = path.join(DIR, 'seed.db');

// ── Helper: open a database file ────────────────────────────────
function openDb(filePath) {
  return new Database(filePath, { verbose: null });
}

// ── DDL ─────────────────────────────────────────────────────────
const DDL = `
  CREATE TABLE IF NOT EXISTS inventory (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    sku_code   TEXT    NOT NULL UNIQUE,
    name       TEXT    NOT NULL,
    category   TEXT    NOT NULL,
    price      INTEGER NOT NULL DEFAULT 0,   -- stored in 分 (cents)
    stock      INTEGER NOT NULL DEFAULT 0,
    status     TEXT    NOT NULL DEFAULT 'active',
    version    INTEGER NOT NULL DEFAULT 1,
    updated_at TEXT    NOT NULL DEFAULT (datetime('now','localtime'))
  );
`;

// ── Seed rows (price in 分) ──────────────────────────────────────
const SEED_ROWS = [
  { sku_code: 'SKU-1001', name: 'MacBook Pro 14"',          category: '笔记本电脑', price: 1499900, stock: 42,  status: 'active'      },
  { sku_code: 'SKU-1002', name: 'iPhone 15 Pro Max',         category: '智能手机',   price:  899900, stock: 128, status: 'active'      },
  { sku_code: 'SKU-1003', name: 'iPad Air M2',               category: '平板电脑',   price:  599900, stock: 75,  status: 'active'      },
  { sku_code: 'SKU-1004', name: 'AirPods Pro 2',             category: '音频设备',   price:  179900, stock: 200, status: 'active'      },
  { sku_code: 'SKU-1005', name: 'Apple Watch Series 9',      category: '智能手表',   price:  299900, stock: 90,  status: 'active'      },
  { sku_code: 'SKU-1006', name: 'Sony WH-1000XM5',           category: '音频设备',   price:  249900, stock: 65,  status: 'active'      },
  { sku_code: 'SKU-1007', name: 'Dell XPS 15',               category: '笔记本电脑', price: 1299900, stock: 30,  status: 'active'      },
  { sku_code: 'SKU-1008', name: 'Samsung Galaxy S24 Ultra',  category: '智能手机',   price:  949900, stock: 110, status: 'active'      },
  { sku_code: 'SKU-1009', name: 'LG 27" 4K Monitor',         category: '显示器',     price:  349900, stock: 55,  status: 'active'      },
  { sku_code: 'SKU-1010', name: 'Logitech MX Master 3S',     category: '外设',       price:   79900, stock: 300, status: 'active'      },
  { sku_code: 'SKU-1011', name: 'Keychron Q3 Pro',           category: '外设',       price:  119900, stock: 180, status: 'active'      },
  { sku_code: 'SKU-1012', name: 'Anker 140W USB-C Charger',  category: '充电设备',   price:   39900, stock: 500, status: 'active'      },
  { sku_code: 'SKU-1013', name: 'WD My Passport 2TB',        category: '存储设备',   price:   49900, stock: 220, status: 'active'      },
  { sku_code: 'SKU-1014', name: 'Nvidia RTX 4070 Ti Super',  category: '显卡',       price:  599900, stock: 18,  status: 'low_stock'   },
  { sku_code: 'SKU-1015', name: 'AMD Ryzen 9 7950X',         category: 'CPU',        price:  389900, stock: 0,   status: 'out_of_stock'},
];

// ── Core initialiser ────────────────────────────────────────────
function initDb(db) {
  db.exec(DDL);

  const insert = db.prepare(`
    INSERT OR IGNORE INTO inventory
      (sku_code, name, category, price, stock, status)
    VALUES
      (@sku_code, @name, @category, @price, @stock, @status)
  `);

  const insertMany = db.transaction((rows) => {
    for (const row of rows) insert.run(row);
  });

  insertMany(SEED_ROWS);
}

// ── Ensure app.db exists (copy from seed.db if available) ───────
function ensureAppDb() {
  if (!fs.existsSync(APP_DB)) {
    if (fs.existsSync(SEED_DB)) {
      fs.copyFileSync(SEED_DB, APP_DB);
    }
  }
  const db = openDb(APP_DB);
  initDb(db);
  return db;
}

// ── CLI: node db.js --seed  →  produce seed.db ──────────────────
if (require.main === module) {
  const isSeedMode = process.argv.includes('--seed');
  const targetPath = isSeedMode ? SEED_DB : APP_DB;

  if (isSeedMode && fs.existsSync(SEED_DB)) fs.unlinkSync(SEED_DB);

  const db = openDb(targetPath);
  initDb(db);
  db.close();

  // If seeding, also make sure app.db gets copied from seed.db
  if (isSeedMode) {
    fs.copyFileSync(SEED_DB, APP_DB);
    console.log(`[db] seed.db created at ${SEED_DB}`);
    console.log(`[db] app.db  created at ${APP_DB}`);
  }
  process.exit(0);
}

module.exports = { ensureAppDb };
