#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  solution/solve.sh – Harbor Benchmark · One-shot Solution Applier
#  task_id: task_pc_inventory_001
#
#  断网原则：本脚本严禁任何 npm install / npm ci / npx 下载行为。
#  所有 node_modules 已在 Docker 构建期通过 npm ci 预装完毕，
#  运行期只允许使用已存在的本地 node_modules。
#
#  Usage (from project root, inside container):
#    bash solution/solve.sh
#
#  What it does:
#    1. Apply solution/golden.patch (if not already applied)
#    2. Rebuild Vite frontend with pre-installed node_modules (no network)
#    3. Re-generate seed.db + app.db from db.js (no network)
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
_log()  { echo -e "${CYAN}[solve.sh]${NC} $*"; }
_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
_fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

_log "Project root : $ROOT_DIR"

# ── Guard: node_modules must already exist (no network allowed) ───
for DIR in workspace/backend workspace/frontend tests; do
  if [ ! -d "$ROOT_DIR/$DIR/node_modules" ]; then
    _fail "node_modules missing in $DIR. This script requires deps pre-installed at build time (npm ci in Dockerfile). Aborting to preserve air-gap."
  fi
done
_ok "All node_modules present – air-gap constraint satisfied."

# ── Step 1: Apply golden patch ────────────────────────────────────
PATCH_FILE="$SCRIPT_DIR/golden.patch"
if [ -f "$PATCH_FILE" ]; then
  _log "Checking golden.patch …"
  cd "$ROOT_DIR"
  if git apply --check "$PATCH_FILE" 2>/dev/null; then
    git apply "$PATCH_FILE"
    _ok "golden.patch applied."
  else
    _log "Patch already applied or conflicts detected – skipping."
  fi
else
  _log "No golden.patch found – skipping patch step."
fi

# ── Step 2: Rebuild frontend (local node_modules only, no network) ─
_log "Rebuilding frontend with local node_modules …"
cd "$ROOT_DIR/workspace/frontend"

# Vite must NOT attempt to fetch anything; --mode production uses only
# the already-installed packages under node_modules/.
NODE_ENV=production \
  node node_modules/.bin/vite build 2>&1

_ok "Frontend build complete (dist/ updated, zero network calls)."

# ── Step 3: Regenerate seed.db + app.db ──────────────────────────
_log "Regenerating seed.db and app.db …"
cd "$ROOT_DIR/workspace/backend"
node db.js --seed
_ok "Databases ready."

echo ""
_ok "solve.sh finished. Run 'bash environment/bootstrap.sh' to start services."
