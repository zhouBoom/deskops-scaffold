<template>
  <div class="workbench">
    <!-- ── Page Header ──────────────────────────────────────── -->
    <div class="page-header">
      <div class="page-title-area">
        <h1 class="page-title">
          <el-icon class="title-icon"><PriceTag /></el-icon>
          库存调价工作台
        </h1>
        <p class="page-subtitle">实时价格管理 · 所有变更即时落库 · Enter 保存 / Esc 撤销 / Tab 流转</p>
      </div>
      <div class="page-actions">
        <el-button
          :icon="RefreshRight"
          :loading="loading"
          @click="fetchList"
          plain
          size="small"
        >刷新</el-button>
        <el-tag type="info" effect="plain" size="small">共 {{ rows.length }} 条记录</el-tag>
      </div>
    </div>

    <!-- ── Stats Bar ────────────────────────────────────────── -->
    <div class="stats-bar">
      <div class="stat-card">
        <span class="stat-label">在售 SKU</span>
        <span class="stat-value accent-green">{{ stats.active }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">库存紧张</span>
        <span class="stat-value accent-yellow">{{ stats.lowStock }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">缺货</span>
        <span class="stat-value accent-red">{{ stats.outOfStock }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">库存总量</span>
        <span class="stat-value accent-blue">{{ stats.totalStock.toLocaleString() }}</span>
      </div>
      <div class="stat-card">
        <span class="stat-label">库存总值（元）</span>
        <span class="stat-value accent-purple">{{ stats.totalValueYuan }}</span>
      </div>
    </div>

    <!-- ── Table ─────────────────────────────────────────────── -->
    <div class="table-wrapper" v-loading="loading" element-loading-background="rgba(11,17,32,0.8)">
      <el-table
        :data="rows"
        class="inventory-table"
        stripe
        border
        height="100%"
        :row-class-name="rowClassName"
        @cell-dbl-click="onCellDblClick"
      >
        <!-- ID -->
        <el-table-column prop="id" label="ID" width="56" align="center" fixed="left">
          <template #default="{ row }">
            <span class="cell-id">#{{ row.id }}</span>
          </template>
        </el-table-column>

        <!-- SKU Code -->
        <el-table-column prop="sku_code" label="SKU 编号" width="120" fixed="left">
          <template #default="{ row }">
            <code class="sku-code">{{ row.sku_code }}</code>
          </template>
        </el-table-column>

        <!-- Name -->
        <el-table-column prop="name" label="商品名称" min-width="220">
          <template #default="{ row }">
            <span class="product-name">{{ row.name }}</span>
          </template>
        </el-table-column>

        <!-- Category -->
        <el-table-column prop="category" label="分类" width="120">
          <template #default="{ row }">
            <el-tag size="small" :type="categoryTagType(row.category)" effect="plain">
              {{ row.category }}
            </el-tag>
          </template>
        </el-table-column>

        <!-- Stock -->
        <el-table-column prop="stock" label="库存" width="80" align="right">
          <template #default="{ row }">
            <span :class="['cell-stock', { 'stock-zero': row.stock === 0, 'stock-low': row.stock > 0 && row.stock < 30 }]">
              {{ row.stock }}
            </span>
          </template>
        </el-table-column>

        <!-- Status -->
        <el-table-column prop="status" label="状态" width="100" align="center">
          <template #default="{ row }">
            <el-tag :type="statusTagType(row.status)" size="small" effect="dark">
              {{ statusLabel(row.status) }}
            </el-tag>
          </template>
        </el-table-column>

        <!-- Current Price (yuan, read-only display) -->
        <el-table-column label="现价（元）" width="120" align="right">
          <template #default="{ row }">
            <span class="cell-price">¥ {{ centsToYuan(row.price) }}</span>
          </template>
        </el-table-column>

        <!-- Edit Price Input -->
        <el-table-column label="修改价格（元）" width="160" align="center">
          <template #header>
            <span>修改价格（元）</span>
            <el-tooltip content="双击单元格可快速聚焦" placement="top">
              <el-icon class="col-tip"><QuestionFilled /></el-icon>
            </el-tooltip>
          </template>
          <template #default="{ row, $index }">
            <el-input
              :ref="el => setInputRef(el, $index)"
              v-model="editValues[$index]"
              :data-row-index="$index"
              :data-testid="`price-input-${$index}`"
              :id="`price-input-${$index}`"
              class="price-input"
              size="small"
              placeholder="输入新价格"
              @keydown="onKeyDown($event, $index)"
              @focus="onFocus($index)"
              @blur="onBlur($index)"
            />
          </template>
        </el-table-column>

        <!-- Version -->
        <el-table-column prop="version" label="版本" width="70" align="center">
          <template #default="{ row }">
            <span class="cell-version">v{{ row.version }}</span>
          </template>
        </el-table-column>

        <!-- Updated At -->
        <el-table-column prop="updated_at" label="最后更新" width="170">
          <template #default="{ row }">
            <span class="cell-time">{{ row.updated_at }}</span>
          </template>
        </el-table-column>

        <!-- Actions -->
        <el-table-column label="操作" width="100" align="center" fixed="right">
          <template #default="{ row, $index }">
            <el-button
              type="primary"
              size="small"
              plain
              :loading="savingIndex === $index"
              @click="saveRow($index)"
            >保存</el-button>
          </template>
        </el-table-column>
      </el-table>
    </div>

    <!-- ── Keyboard Hint Footer ──────────────────────────────── -->
    <div class="kb-footer">
      <span class="kb-hint"><kbd>Enter</kbd> 保存当前行</span>
      <span class="kb-hint"><kbd>Tab</kbd> 跳至下一行同列</span>
      <span class="kb-hint"><kbd>Esc</kbd> 撤销编辑</span>
      <span class="kb-hint"><kbd>双击单元格</kbd> 快速聚焦输入框</span>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, computed, onMounted, nextTick } from 'vue'
import axios from 'axios'
import { ElMessage } from 'element-plus'
import { RefreshRight, QuestionFilled } from '@element-plus/icons-vue'

// ── State ────────────────────────────────────────────────────────
const rows        = ref([])
const loading     = ref(false)
const savingIndex = ref(-1)

// editValues[i] = string value in yuan (e.g. "14999.00") being edited
const editValues  = reactive([])
// originalValues[i] = original yuan string, for Esc reset
const originalValues = reactive([])

// Refs to el-input components indexed by row
const inputRefs = reactive([])

function setInputRef(el, index) {
  inputRefs[index] = el
}

// ── Computed stats ───────────────────────────────────────────────
const stats = computed(() => {
  const active      = rows.value.filter(r => r.status === 'active').length
  const lowStock    = rows.value.filter(r => r.status === 'low_stock').length
  const outOfStock  = rows.value.filter(r => r.status === 'out_of_stock').length
  const totalStock  = rows.value.reduce((s, r) => s + r.stock, 0)
  const totalCents  = rows.value.reduce((s, r) => s + r.price * r.stock, 0)
  const totalValueYuan = '¥ ' + (totalCents / 100).toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
  return { active, lowStock, outOfStock, totalStock, totalValueYuan }
})

// ── Helpers ──────────────────────────────────────────────────────
function centsToYuan(cents) {
  return (cents / 100).toFixed(2)
}
function yuanToCents(yuan) {
  // Round to nearest cent to avoid float errors
  return Math.round(parseFloat(yuan) * 100)
}

function categoryTagType(cat) {
  const map = {
    '笔记本电脑': '',
    '智能手机': 'success',
    '平板电脑': 'warning',
    '音频设备': 'info',
    '智能手表': 'danger',
    '显示器': '',
    '外设': 'success',
    '充电设备': 'warning',
    '存储设备': 'info',
    '显卡': 'danger',
    'CPU': '',
  }
  return map[cat] ?? ''
}
function statusTagType(s) {
  return { active: 'success', low_stock: 'warning', out_of_stock: 'danger' }[s] ?? 'info'
}
function statusLabel(s) {
  return { active: '在售', low_stock: '库存紧张', out_of_stock: '已缺货' }[s] ?? s
}
function rowClassName({ row }) {
  if (row.status === 'out_of_stock') return 'row-out-of-stock'
  if (row.status === 'low_stock')    return 'row-low-stock'
  return ''
}

// ── Data fetch ───────────────────────────────────────────────────
async function fetchList() {
  loading.value = true
  try {
    const { data } = await axios.get('/api/inventory/list')
    rows.value = data.data ?? []
    // Populate edit values from live data
    rows.value.forEach((row, i) => {
      editValues[i]    = centsToYuan(row.price)
      originalValues[i] = centsToYuan(row.price)
    })
  } catch (e) {
    ElMessage.error('加载数据失败：' + (e.message ?? '未知错误'))
  } finally {
    loading.value = false
  }
}

onMounted(fetchList)

// ── Focus helpers ────────────────────────────────────────────────
function focusInput(index) {
  nextTick(() => {
    const ref = inputRefs[index]
    if (!ref) return
    // el-input exposes input element via .input or .$el.querySelector
    const el = ref.input ?? ref.$el?.querySelector('input')
    if (el) {
      el.focus()
      el.select()
    }
  })
}

function onFocus(index) {
  // Sync originalValue so Esc can revert
  originalValues[index] = editValues[index]
}

function onBlur(_index) {
  // intentionally empty – no auto-save on blur
}

// ── Double-click cell to focus ───────────────────────────────────
function onCellDblClick(_row, column, _cell, _event) {
  // column.label identifies the price input column
  if (column.label === '修改价格（元）') {
    const rowIndex = rows.value.indexOf(_row)
    if (rowIndex !== -1) focusInput(rowIndex)
  }
}

// ── Keyboard handler ─────────────────────────────────────────────
function onKeyDown(event, index) {
  const key = event.key

  if (key === 'Enter') {
    event.preventDefault()
    saveRow(index)
    return
  }

  if (key === 'Tab') {
    // Prevent browser's default tab-out behaviour
    event.preventDefault()
    event.stopPropagation()

    const nextIndex = index + 1
    if (nextIndex < rows.value.length) {
      focusInput(nextIndex)
    }
    return
  }

  if (key === 'Escape') {
    event.preventDefault()
    // Revert to original value
    editValues[index] = originalValues[index]
    // Blur the input
    const ref = inputRefs[index]
    const el  = ref?.input ?? ref?.$el?.querySelector('input')
    el?.blur()
    return
  }
}

// ── Save row ─────────────────────────────────────────────────────
async function saveRow(index) {
  const row = rows.value[index]
  if (!row) return

  const raw = editValues[index]
  if (!raw || raw.trim() === '') {
    ElMessage.warning('价格不能为空')
    return
  }

  const parsed = parseFloat(raw)
  if (isNaN(parsed) || parsed < 0) {
    ElMessage.error('请输入有效的非负数价格')
    return
  }

  const cents = yuanToCents(parsed)

  savingIndex.value = index
  try {
    const { data } = await axios.post('/api/inventory/update-price', {
      id: row.id,
      price: cents,
    })

    // Update local state from server response
    const updated = data.data
    rows.value[index] = updated
    editValues[index]    = centsToYuan(updated.price)
    originalValues[index] = centsToYuan(updated.price)

    ElMessage({
      type: 'success',
      message: `✓ ${row.name} 价格已更新为 ¥${centsToYuan(updated.price)}`,
      duration: 2500,
      showClose: true,
    })
  } catch (e) {
    const msg = e.response?.data?.error ?? e.message ?? '未知错误'
    ElMessage.error('保存失败：' + msg)
    // Revert on error
    editValues[index] = originalValues[index]
  } finally {
    savingIndex.value = -1
  }
}
</script>

<style scoped>
/* ── Layout ─────────────────────────────────────────────────── */
.workbench {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px 20px 0;
  gap: 12px;
  overflow: hidden;
}

/* ── Page Header ────────────────────────────────────────────── */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  flex-shrink: 0;
}
.page-title-area { display: flex; flex-direction: column; gap: 4px; }
.page-title {
  font-size: 20px;
  font-weight: 700;
  color: #f1f5f9;
  display: flex;
  align-items: center;
  gap: 8px;
}
.title-icon { color: #38bdf8; font-size: 22px; }
.page-subtitle { font-size: 12px; color: #475569; }
.page-actions { display: flex; align-items: center; gap: 10px; }

/* ── Stats Bar ──────────────────────────────────────────────── */
.stats-bar {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
}
.stat-card {
  background: #1e293b;
  border: 1px solid #2d3f56;
  border-radius: 8px;
  padding: 10px 18px;
  display: flex;
  flex-direction: column;
  gap: 4px;
  min-width: 110px;
}
.stat-label { font-size: 11px; color: #64748b; letter-spacing: 0.5px; }
.stat-value { font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; }
.accent-green  { color: #4ade80; }
.accent-yellow { color: #fbbf24; }
.accent-red    { color: #f87171; }
.accent-blue   { color: #60a5fa; }
.accent-purple { color: #c084fc; }

/* ── Table Wrapper ──────────────────────────────────────────── */
.table-wrapper {
  flex: 1;
  overflow: hidden;
  border-radius: 8px;
  border: 1px solid #1e3a5f;
}

/* ── Table Cell Styles ──────────────────────────────────────── */
.cell-id      { color: #475569; font-size: 12px; }
.sku-code     {
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 12px;
  color: #38bdf8;
  background: rgba(56,189,248,0.08);
  padding: 2px 6px;
  border-radius: 4px;
}
.product-name { color: #e2e8f0; font-weight: 500; }
.cell-price   { color: #4ade80; font-weight: 600; font-variant-numeric: tabular-nums; }
.cell-stock   { color: #94a3b8; font-variant-numeric: tabular-nums; }
.stock-zero   { color: #f87171; font-weight: 700; }
.stock-low    { color: #fbbf24; font-weight: 600; }
.cell-version { color: #475569; font-size: 11px; }
.cell-time    { color: #475569; font-size: 12px; font-variant-numeric: tabular-nums; }
.col-tip      { margin-left: 4px; color: #475569; cursor: help; }

/* ── Price Input ────────────────────────────────────────────── */
.price-input :deep(.el-input__wrapper) {
  background: rgba(56,189,248,0.05);
  border: 1px solid #2d4a6b;
  box-shadow: none !important;
  transition: border-color 0.2s;
}
.price-input :deep(.el-input__wrapper:hover),
.price-input :deep(.el-input__wrapper.is-focus) {
  border-color: #38bdf8 !important;
  background: rgba(56,189,248,0.1);
}
.price-input :deep(input) {
  color: #facc15;
  font-weight: 600;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

/* ── Keyboard Footer ────────────────────────────────────────── */
.kb-footer {
  flex-shrink: 0;
  display: flex;
  gap: 20px;
  padding: 8px 0 10px;
  border-top: 1px solid #1e293b;
}
.kb-hint { font-size: 12px; color: #475569; display: flex; align-items: center; gap: 5px; }
kbd {
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 4px;
  padding: 2px 7px;
  font-size: 11px;
  color: #94a3b8;
  font-family: inherit;
}
</style>

<!-- Global (unscoped) Element Plus table dark theme overrides -->
<style>
.inventory-table {
  --el-table-bg-color: #0f172a;
  --el-table-tr-bg-color: #0f172a;
  --el-table-row-hover-bg-color: #1a2744;
  --el-table-header-bg-color: #0b1829;
  --el-table-border-color: #1e3a5f;
  --el-table-text-color: #94a3b8;
  --el-table-header-text-color: #64748b;
  --el-fill-color-lighter: #0f172a;
  background: #0f172a;
}
.inventory-table .el-table__body tr.row-out-of-stock td {
  background: rgba(248, 113, 113, 0.04) !important;
}
.inventory-table .el-table__body tr.row-low-stock td {
  background: rgba(251, 191, 36, 0.04) !important;
}
.inventory-table .el-table__stripe .el-table__body tr.el-table__row--striped td {
  background: rgba(255,255,255,0.02) !important;
}
.inventory-table th.el-table__cell {
  background: #0b1829 !important;
  color: #475569 !important;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.5px;
}
</style>
