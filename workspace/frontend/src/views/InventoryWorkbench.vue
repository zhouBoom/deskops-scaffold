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
  color: #0f172a;
  display: flex;
  align-items: center;
  gap: 8px;
}
.title-icon    { color: #0284c7; font-size: 22px; }
.page-subtitle { font-size: 12px; color: #94a3b8; }
.page-actions  { display: flex; align-items: center; gap: 10px; }

/* ── Stats Bar ──────────────────────────────────────────────── */
.stats-bar {
  display: flex;
  gap: 12px;
  flex-shrink: 0;
}
.stat-card {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  border-top: 2px solid #e2e8f0;   /* thicker top — overridden per accent below */
  border-radius: 10px;
  padding: 11px 20px 12px;
  display: flex;
  flex-direction: column;
  gap: 5px;
  min-width: 120px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.06);
  transition: box-shadow 0.2s, border-color 0.2s;
}
.stat-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.10);
  border-color: #bae6fd;
}
.stat-label {
  font-size: 11px;
  color: #94a3b8;
  letter-spacing: 0.6px;
  font-weight: 500;
  text-transform: uppercase;
}
.stat-value {
  font-size: 26px;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  line-height: 1.1;
  letter-spacing: -0.5px;
}
.accent-green  { color: #16a34a; }
.accent-yellow { color: #d97706; }
.accent-red    { color: #dc2626; }
.accent-blue   { color: #0284c7; }
.accent-purple { color: #7c3aed; }

/* ── Table Wrapper ──────────────────────────────────────────── */
.table-wrapper {
  flex: 1;
  overflow: hidden;
  border-radius: 8px;
  border: 1px solid #e2e8f0;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

/* ── Table Cell Styles ──────────────────────────────────────── */
.cell-id { color: #94a3b8; font-size: 12px; }
.sku-code {
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 12px;
  color: #0284c7;
  background: #eff6ff;
  padding: 2px 6px;
  border-radius: 4px;
}
.product-name { color: #1e293b; font-weight: 500; }

/* Price: deep green, monospace */
.cell-price {
  color: #15803d;
  font-weight: 700;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 13px;
  letter-spacing: 0.3px;
}
/* Stock: monospace for column alignment */
.cell-stock {
  color: #475569;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 13px;
}
.stock-zero { color: #dc2626; font-weight: 700; }
.stock-low  { color: #d97706; font-weight: 600; }

/* Version + time: muted monospace */
.cell-version {
  color: #94a3b8;
  font-size: 11px;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
}
.cell-time {
  color: #94a3b8;
  font-size: 12px;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
}
.col-tip { margin-left: 4px; color: #94a3b8; cursor: help; }

/* ── Price Input ────────────────────────────────────────────── */
/* Idle: white bg, light border */
.price-input :deep(.el-input__wrapper) {
  background: #ffffff;
  border: 1px solid #e2e8f0;
  box-shadow: none !important;
  transition: border-color 0.18s, box-shadow 0.18s;
}
/* Hover */
.price-input :deep(.el-input__wrapper:hover) {
  border-color: #7dd3fc !important;
}
/* Focus: sky-blue border + subtle glow */
.price-input :deep(.el-input__wrapper.is-focus) {
  border-color: #0284c7 !important;
  box-shadow: 0 0 0 3px rgba(2, 132, 199, 0.12) !important;
}
/* Input text: indigo, monospace, right-aligned */
.price-input :deep(input) {
  color: #1d4ed8;
  font-weight: 600;
  text-align: right;
  font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
  font-size: 13px;
  letter-spacing: 0.3px;
}

/* ── Keyboard Footer ────────────────────────────────────────── */
.kb-footer {
  flex-shrink: 0;
  display: flex;
  gap: 20px;
  padding: 8px 0 10px;
  border-top: 1px solid #e2e8f0;
}
.kb-hint { font-size: 12px; color: #94a3b8; display: flex; align-items: center; gap: 5px; }
kbd {
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-bottom: 2px solid #cbd5e1;
  border-radius: 4px;
  padding: 2px 7px;
  font-size: 11px;
  color: #475569;
  font-family: inherit;
}
</style>

<!-- Global: Element Plus table light-theme overrides -->
<style>
.inventory-table {
  --el-table-bg-color:           #ffffff;
  --el-table-tr-bg-color:        #ffffff;
  --el-table-row-hover-bg-color: #f8fafc;
  --el-table-header-bg-color:    #f8fafc;
  --el-table-border-color:       #e2e8f0;
  --el-table-text-color:         #374151;
  --el-table-header-text-color:  #6b7280;
  --el-fill-color-lighter:       #f8fafc;
  background: #ffffff;
}
/* Tighter row height */
.inventory-table .el-table__cell {
  padding: 5px 0 !important;
}
/* Row status tints */
.inventory-table .el-table__body tr.row-out-of-stock td {
  background: #fef2f2 !important;
}
.inventory-table .el-table__body tr.row-low-stock td {
  background: #fffbeb !important;
}
/* Stripe */
.inventory-table .el-table__stripe .el-table__body tr.el-table__row--striped td {
  background: #f9fafb !important;
}
/* Header */
.inventory-table th.el-table__cell {
  background: #f8fafc !important;
  color: #6b7280 !important;
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.5px;
  padding: 8px 0 !important;
  border-bottom: 1px solid #e2e8f0 !important;
}
/* Loading overlay bg for light theme */
.table-wrapper .el-loading-mask {
  background: rgba(248, 250, 252, 0.85) !important;
}
</style>

