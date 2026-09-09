// @ts-check
/**
 * workbench.spec.js – Harbor Benchmark E2E Test Suite
 *
 * Assertions covered:
 *   1. Table renders exactly 15 rows (DOM state)
 *   2. Tab key moves activeElement to the NEXT row's price input
 *   3. Enter key saves → success toast appears
 *   4. F5 (page.reload) → saved price persists in DOM
 *   5. Direct SQLite query → price (分) and version updated correctly
 */

const { test, expect } = require('@playwright/test')
const path             = require('path')
const Database         = require('better-sqlite3')

// Path to the live database used by the running backend
// __dirname = tests/e2e/specs  →  ../../../ = pc root
const DB_PATH = path.resolve(__dirname, '../../../workspace/backend/app.db')

// ── Helpers ──────────────────────────────────────────────────────

/** Open a read-only connection to app.db and return the row by id */
function queryDbRow(id) {
  const db  = new Database(DB_PATH, { readonly: true })
  const row = db.prepare('SELECT * FROM inventory WHERE id = ?').get(id)
  db.close()
  return row
}

/** Format cents → yuan string the same way the UI does (toFixed(2)) */
function centsToYuan(cents) {
  return (cents / 100).toFixed(2)
}

// ── Test Suite ───────────────────────────────────────────────────

test.describe('Harbor Benchmark – Inventory Workbench', () => {

  // Navigate to the workbench before each test
  test.beforeEach(async ({ page }) => {
    await page.goto('/')
    // Wait for table to fully render (at least one row visible)
    await page.waitForSelector('[data-testid="price-input-0"]', { timeout: 20_000 })
  })

  // ── Test 1: Table renders 15 rows ──────────────────────────────
  test('T1 – DOM: table renders exactly 15 data rows', async ({ page }) => {
    // el-table renders rows inside .el-table__body tbody tr (excluding header)
    const rows = page.locator('.el-table__body tbody tr')
    await expect(rows).toHaveCount(15)
  })

  // ── Test 2: Tab key moves focus to next row's input ────────────
  test('T2 – Keyboard: Tab moves activeElement to row-1 price input', async ({ page }) => {
    const firstInput = page.locator('#price-input-0')
    await firstInput.click()
    await firstInput.selectText()

    // Press Tab – our handler prevents default and focuses row[1]
    await page.keyboard.press('Tab')

    // Verify activeElement is the second row's price input
    const activeId = await page.evaluate(() => document.activeElement?.id ?? '')
    expect(activeId).toBe('price-input-1')
  })

  // ── Test 3 + 4 + 5: Enter saves, reload persists, DB updated ───
  test('T3/T4/T5 – Enter saves price; reload persists; SQLite updated', async ({ page }) => {
    // ── 3a. Target row 0 (id=1 in DB) ──────────────────────────
    const TARGET_ROW_ID = 1        // DB primary key
    const TARGET_INDEX  = 0        // 0-based table row index
    const NEW_PRICE_YUAN  = '888.88'
    const NEW_PRICE_CENTS = Math.round(parseFloat(NEW_PRICE_YUAN) * 100) // 88888

    // Read current version before update
    const before = queryDbRow(TARGET_ROW_ID)
    const versionBefore = before.version

    // ── 3b. Focus and type new price ───────────────────────────
    const priceInput = page.locator(`#price-input-${TARGET_INDEX}`)
    await priceInput.click()
    await priceInput.selectText()
    await priceInput.fill(NEW_PRICE_YUAN)

    // ── 3c. Press Enter → save request ─────────────────────────
    await priceInput.press('Enter')

    // ── 3d. Assert success toast ────────────────────────────────
    // Element Plus ElMessage renders with .el-message class
    const toast = page.locator('.el-message--success').first()
    await expect(toast).toBeVisible({ timeout: 8_000 })

    // Optionally assert toast text contains the new price
    const toastText = await toast.innerText()
    expect(toastText).toContain(NEW_PRICE_YUAN)

    // ── 4. F5 Reload – verify price persists in DOM ─────────────
    await page.reload()
    await page.waitForSelector('[data-testid="price-input-0"]', { timeout: 15_000 })

    // The el-input value for row 0 should reflect new price
    const inputAfterReload = page.locator(`#price-input-${TARGET_INDEX}`)
    await expect(inputAfterReload).toHaveValue(centsToYuan(NEW_PRICE_CENTS))

    // Also verify the display "现价" cell (read-only column)
    // Target the cell text in column 7 (index 6, 0-based) of row 0
    const priceDisplayCell = page
      .locator('.el-table__body tbody tr')
      .nth(TARGET_INDEX)
      .locator('.cell-price')
    await expect(priceDisplayCell).toContainText(centsToYuan(NEW_PRICE_CENTS))

    // ── 5. Direct SQLite assertion ──────────────────────────────
    // Give the backend a tiny moment to commit (it's synchronous, so
    // the HTTP 200 means it's done – but OS file flush takes ~0ms)
    const dbRow = queryDbRow(TARGET_ROW_ID)

    // price stored as INTEGER cents
    expect(dbRow.price).toBe(NEW_PRICE_CENTS)

    // version must have incremented by exactly 1
    expect(dbRow.version).toBe(versionBefore + 1)
  })

  // ── Test 6: Esc reverts price ───────────────────────────────────
  test('T6 – Keyboard: Esc reverts unsaved price change', async ({ page }) => {
    const priceInput = page.locator('#price-input-0')

    // Get original value
    const originalValue = await priceInput.inputValue()

    await priceInput.click()
    await priceInput.selectText()
    await priceInput.fill('9999.99')

    // Press Escape
    await page.keyboard.press('Escape')

    // Value should revert
    await expect(priceInput).toHaveValue(originalValue)
  })

  // ── Test 7: Persistence across cold reload (control test) ──────
  test('T7 – DOM: activeElement is correctly tracked via data-testid', async ({ page }) => {
    // Click input on row 3 and confirm focus
    const input3 = page.locator('#price-input-3')
    await input3.click()

    const activeId = await page.evaluate(() => document.activeElement?.id ?? '')
    expect(activeId).toBe('price-input-3')
  })

})
