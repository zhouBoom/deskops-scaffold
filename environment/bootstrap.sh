#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  bootstrap.sh – Harbor Coding Benchmark
#  1. Reset app.db from seed.db (millisecond-level)
#  2. Start Express backend (port 3000) in background
#  3. Start Vite preview frontend (port 5173) in background
#  4. Health-check both services; exit 0 on success
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# 自动推导项目根目录：支持本地 Mac 任意路径运行，同时兼容容器内 APP_DIR 覆盖
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

BACKEND_DIR="$APP_DIR/workspace/backend"
FRONTEND_DIR="$APP_DIR/workspace/frontend"

LOG_DIR="$APP_DIR/logs"
LOG_BACKEND="$LOG_DIR/backend.log"
LOG_FRONTEND="$LOG_DIR/frontend.log"

mkdir -p "$LOG_DIR"

# ── Step 1: Reset database ───────────────────────────────────────
echo "[bootstrap] Resetting app.db from seed.db …"
cp -f "$BACKEND_DIR/seed.db" "$BACKEND_DIR/app.db"
echo "[bootstrap] Database reset complete."

# ── Step 2: Start backend ────────────────────────────────────────
echo "[bootstrap] Starting Express backend on port 3000 …"
cd "$BACKEND_DIR"
node server.js > "$LOG_BACKEND" 2>&1 &
BACKEND_PID=$!
echo "[bootstrap] Backend PID: $BACKEND_PID"

# ── Step 3: Start frontend preview ──────────────────────────────
echo "[bootstrap] Starting Vite preview on port 5173 …"
cd "$FRONTEND_DIR"
# 使用本地 node_modules 二进制，规避 npx 解析行为差异
./node_modules/.bin/vite preview \
    --port 5173 \
    --host 0.0.0.0 \
    --outDir dist > "$LOG_FRONTEND" 2>&1 &
FRONTEND_PID=$!
echo "[bootstrap] Frontend PID: $FRONTEND_PID"

# ── Step 4: Health-check helper ──────────────────────────────────
wait_for() {
  local name="$1"
  local url="$2"
  local max_attempts=60
  local attempt=0
  echo "[bootstrap] Waiting for $name at $url …"
  until curl -sf "$url" > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "$attempt" -ge "$max_attempts" ]; then
      echo "[bootstrap] ERROR: $name did not become ready after ${max_attempts}s"
      exit 1
    fi
    sleep 1
  done
  echo "[bootstrap] $name is ready (attempt $attempt)."
}

wait_for "Backend"  "http://127.0.0.1:3000/api/health"
wait_for "Frontend" "http://127.0.0.1:5173"

echo "[bootstrap] All services ready. Benchmark environment is UP."
echo "  Backend  → http://0.0.0.0:3000"
echo "  Frontend → http://0.0.0.0:5173"

# ── Step 5: Process management ───────────────────────────────────
# 如果显式传入 FOREGROUND=1 参数（如作为常驻容器的 CMD 启动时），挂起进程
# 供 test.sh 调用时保持非阻塞退出（exit 0），测试进程方可接管
if [ "${FOREGROUND:-0}" = "1" ]; then
  echo "[bootstrap] FOREGROUND=1 set. Keeping process alive …"
  wait $BACKEND_PID $FRONTEND_PID
fi