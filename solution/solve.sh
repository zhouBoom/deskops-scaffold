#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  solution/solve.sh – Harbor Benchmark · One-shot Solution Applier
#  task_id: task_pc_inventory_001
#
#  Usage (from project root):
#    bash solution/solve.sh
#
#  What it does:
#    1. Applies solution/golden.patch to the working tree (if present)
#    2. Re-installs backend / frontend dependencies (idempotent)
#    3. Rebuilds the Vite frontend production bundle
#    4. Re-generates seed.db + app.db from current db.js
# ─────────────────────────────────────────────────────────────────
set -euo pipefail

# Resolve project root (one level above solution/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
_log()  { echo -e "${CYAN}[solve.sh]${NC} $*"; }
_ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
_fail() { echo -e "${RED}[FAIL]${NC} $*"; exit 1; }

_log "Project root: $ROOT_DIR"

# ── Step 1: Apply patch (skip if already applied or patch absent) ──
PATCH_FILE="$SCRIPT_DIR/golden.patch"
if [ -f "$PATCH_FILE" ]; then
  _log "Applying golden.patch …"
  cd "$ROOT_DIR"
  if git apply --check "$PATCH_FILE" 2>/dev/null; then
    git apply "$PATCH_FILE"
    _ok "Patch applied."
  else
    _log "Patch already applied or conflicts detected – skipping."
  fi
else
  _log "No golden.patch found – skipping patch step."
fi

# ── Step 2: Install / refresh backend dependencies ─────────────────
_log "Installing backend dependencies …"
cd "$ROOT_DIR/workspace/backend"
npm install --prefer-offline 2>&1 | tail -3
_ok "Backend deps ready."

# ── Step 3: Install / refresh frontend dependencies ────────────────
_log "Installing frontend dependencies …"
cd "$ROOT_DIR/workspace/frontend"
npm install --prefer-offline 2>&1 | tail -3
_ok "Frontend deps ready."

# ── Step 4: Rebuild Vite production bundle ─────────────────────────
_log "Building frontend …"
cd "$ROOT_DIR/workspace/frontend"
npm run build 2>&1
_ok "Frontend build complete (dist/ updated)."

# ── Step 5: Regenerate seed.db + app.db ───────────────────────────
_log "Regenerating seed.db and app.db …"
cd "$ROOT_DIR/workspace/backend"
node db.js --seed
_ok "Databases ready."

echo ""
_ok "solve.sh finished successfully. Run 'bash environment/bootstrap.sh' to start services."
