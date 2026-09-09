#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  teardown.sh – Harbor Coding Benchmark
#  Reverse-order cleanup: frontend → backend → node orphans
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

echo "[teardown] Stopping Vite preview (port 5173) …"
pkill -f "vite preview" 2>/dev/null || true
sleep 1

echo "[teardown] Stopping Express backend (port 3000) …"
pkill -f "node server.js" 2>/dev/null || true
sleep 1

# Belt-and-suspenders: kill any remaining node processes
echo "[teardown] Killing any orphan node processes …"
pkill -f "node" 2>/dev/null || true

# Release ports via lsof/fuser if still bound
for PORT in 3000 5173; do
  if command -v fuser &>/dev/null; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
  elif command -v lsof &>/dev/null; then
    lsof -ti tcp:"$PORT" | xargs -r kill -9 2>/dev/null || true
  fi
done

echo "[teardown] All services stopped. Ports 3000 and 5173 released."
exit 0
