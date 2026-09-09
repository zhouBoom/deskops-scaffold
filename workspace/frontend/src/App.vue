<template>
  <div class="app-shell">
    <!-- ── Top Bar ─────────────────────────────────────────── -->
    <header class="topbar">
      <div class="topbar-brand">
        <el-icon class="brand-icon"><DataAnalysis /></el-icon>
        <span class="brand-name">Harbor Benchmark</span>
        <span class="brand-divider">|</span>
        <span class="brand-sub">资产管理平台</span>
      </div>
      <div class="topbar-right">
        <el-tag type="success" effect="light" size="small">运行中</el-tag>
        <span class="topbar-time">{{ currentTime }}</span>
      </div>
    </header>

    <div class="main-layout">
      <!-- ── Left Sidebar ──────────────────────────────────── -->
      <aside class="sidebar">
        <el-menu
          :default-active="activeMenu"
          class="sidebar-menu"
          background-color="#ffffff"
          text-color="#374151"
          active-text-color="#0284c7"
          @select="activeMenu = $event"
        >
          <div class="menu-section-label">核心功能</div>
          <el-menu-item index="workbench">
            <el-icon><PriceTag /></el-icon>
            <span>库存调价工作台</span>
          </el-menu-item>
          <el-menu-item index="dashboard" disabled>
            <el-icon><TrendCharts /></el-icon>
            <span>数据看板</span>
          </el-menu-item>
          <el-menu-item index="orders" disabled>
            <el-icon><List /></el-icon>
            <span>订单管理</span>
          </el-menu-item>

          <div class="menu-section-label">系统</div>
          <el-menu-item index="settings" disabled>
            <el-icon><Setting /></el-icon>
            <span>系统设置</span>
          </el-menu-item>
          <el-menu-item index="logs" disabled>
            <el-icon><Document /></el-icon>
            <span>操作日志</span>
          </el-menu-item>
        </el-menu>

        <div class="sidebar-footer">
          <span class="sidebar-version">v1.0.0 · SQLite</span>
        </div>
      </aside>

      <!-- ── Main Content ──────────────────────────────────── -->
      <main class="content-area">
        <InventoryWorkbench v-if="activeMenu === 'workbench'" />
        <div v-else class="placeholder-page">
          <el-empty description="该模块暂未开放" />
        </div>
      </main>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import InventoryWorkbench from './views/InventoryWorkbench.vue'

const activeMenu  = ref('workbench')
const currentTime = ref('')

function updateTime() {
  currentTime.value = new Date().toLocaleTimeString('zh-CN', { hour12: false })
}
let timer
onMounted(() => { updateTime(); timer = setInterval(updateTime, 1000) })
onUnmounted(() => clearInterval(timer))
</script>

<style>
/* ── Reset & base ───────────────────────────────────────────── */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

body {
  font-family: 'Inter', 'PingFang SC', 'Microsoft YaHei', system-ui, sans-serif;
  background: #f1f5f9;
  color: #1e293b;
  height: 100vh;
  overflow: hidden;
}

#app { height: 100vh; display: flex; flex-direction: column; }

/* ── App Shell ──────────────────────────────────────────────── */
.app-shell { display: flex; flex-direction: column; height: 100vh; }

/* ── Top Bar ────────────────────────────────────────────────── */
.topbar {
  height: 52px;
  background: #ffffff;
  border-bottom: 1px solid #e2e8f0;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 24px;
  flex-shrink: 0;
  z-index: 100;
}
.topbar-brand  { display: flex; align-items: center; gap: 10px; }
.brand-icon    { font-size: 22px; color: #0284c7; }
.brand-name    { font-size: 16px; font-weight: 700; color: #0f172a; letter-spacing: 0.3px; }
.brand-divider { color: #e2e8f0; font-size: 18px; }
.brand-sub     { font-size: 13px; color: #94a3b8; }
.topbar-right  { display: flex; align-items: center; gap: 16px; }
.topbar-time   { font-size: 13px; color: #94a3b8; font-variant-numeric: tabular-nums; }

/* ── Main Layout ────────────────────────────────────────────── */
.main-layout { display: flex; flex: 1; overflow: hidden; }

/* ── Sidebar ────────────────────────────────────────────────── */
.sidebar {
  width: 220px;
  flex-shrink: 0;
  background: #ffffff;
  border-right: 1px solid #e2e8f0;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
}
.sidebar-menu { border-right: none !important; flex: 1; }
.menu-section-label {
  font-size: 10px;
  font-weight: 700;
  color: #94a3b8;
  letter-spacing: 1.8px;
  text-transform: uppercase;
  padding: 20px 20px 6px;
}
.sidebar-footer {
  padding: 16px 20px;
  border-top: 1px solid #f1f5f9;
}
.sidebar-version { font-size: 11px; color: #94a3b8; }

/* ── Content Area ───────────────────────────────────────────── */
.content-area {
  flex: 1;
  overflow: hidden;
  display: flex;
  flex-direction: column;
  background: #f1f5f9;
}
.placeholder-page {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
}

/* ── Element Plus menu overrides (light theme) ──────────────── */
.el-menu-item.is-active {
  background: rgba(2, 132, 199, 0.08) !important;
  border-left: 3px solid #0284c7 !important;
  padding-left: 17px !important;
  color: #0284c7 !important;
}
.el-menu-item:not(.is-disabled):hover {
  background: #f8fafc !important;
  color: #0f172a !important;
}
.el-menu-item.is-disabled {
  opacity: 0.4 !important;
  cursor: not-allowed !important;
}
</style>
