#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  tests/test.sh – Harbor Benchmark · Unique Grading Entrypoint
#  task_id: task_pc_inventory_001  |  spec: Harbor 1.3
#
#  Lifecycle:
#    1. bootstrap.sh  – DB reset + service startup + health probe
#    2. playwright    – run tests, emit JSON report
#    3. score_report  – parse JSON → structured score → rubric_result.json
#    4. teardown.sh   – safe port release
#    5. exit code     – 0 if gate_passed AND total_score >= 5, else 1
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

# ── Paths ───────────────────────────────────────────────────────────
# 动态计算根目录，兼容本地 Mac 与 Docker 容器
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$(cd "$SCRIPT_DIR/.." && pwd)}"

TESTS_DIR="$APP_DIR/tests"
REPORT_JSON="/tmp/playwright_report.json"
RESULT_JSON="$APP_DIR/rubric_result.json"
BOOTSTRAP="$APP_DIR/environment/bootstrap.sh"
TEARDOWN="$APP_DIR/environment/teardown.sh"

# ── Colour helpers (gracefully degrade if no tty) ───────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
_log()  { echo -e "${CYAN}[test.sh]${NC} $*"; }
_ok()   { echo -e "${GREEN}[PASS]${NC} $*"; }
_fail() { echo -e "${RED}[FAIL]${NC} $*"; }
_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

PASSING_SCORE=5

# ════════════════════════════════════════════════════════════════════
#  STEP 1 – Bootstrap (DB reset + service start + health probe)
# ════════════════════════════════════════════════════════════════════
_log "Step 1 – Bootstrapping services …"

if [ ! -x "$BOOTSTRAP" ]; then
  _fail "bootstrap.sh not found or not executable: $BOOTSTRAP"
  exit 1
fi

"$BOOTSTRAP"
_ok "Services are healthy."

# ════════════════════════════════════════════════════════════════════
#  STEP 2 – Execute Playwright tests (JSON reporter)
# ════════════════════════════════════════════════════════════════════
_log "Step 2 – Running Playwright test suite …"

cd "$TESTS_DIR"

# 运行 playwright；优先使用本地 bin 路径，兼容断网与无全局包环境
PLAYWRIGHT_BIN="./node_modules/.bin/playwright"
if [ ! -x "$PLAYWRIGHT_BIN" ]; then
  PLAYWRIGHT_BIN="npx --no-install playwright"
fi

PLAYWRIGHT_EXIT=0
$PLAYWRIGHT_BIN test \
    --reporter=json \
    2>/dev/null > "$REPORT_JSON" || PLAYWRIGHT_EXIT=$?

_log "Playwright process exited with code: $PLAYWRIGHT_EXIT"

# ════════════════════════════════════════════════════════════════════
#  STEP 3 – Parse report & compute score
# ════════════════════════════════════════════════════════════════════
_log "Step 3 – Computing structured score …"

# ── Inner Node.js scorer ─────────────────────────────────────────
node - "$REPORT_JSON" "$RESULT_JSON" << 'NODE_SCRIPT'
'use strict';
const fs   = require('fs');
const path = require('path');

const reportPath = process.argv[2];
const resultPath = process.argv[3];

// ── Rubric definition (mirrors rubric.yaml) ─────────────────────
const RUBRIC = [
  { id: 'gate_render',    gate: true,  score: 2, match: 'T1' },
  { id: 'non_gate_tab',   gate: false, score: 2, match: 'T2' },
  { id: 'gate_persist',   gate: true,  score: 3, match: 'T3/T4/T5' },
  { id: 'non_gate_esc',   gate: false, score: 2, match: 'T6' },
  { id: 'non_gate_track', gate: false, score: 1, match: 'T7' },
];

// ── Parse Playwright JSON report ────────────────────────────────
let report = { suites: [] };
try {
  const raw = fs.readFileSync(reportPath, 'utf8');
  const jsonStart = raw.indexOf('{');
  if (jsonStart !== -1) {
    report = JSON.parse(raw.slice(jsonStart));
  }
} catch (e) {
  console.error('[scorer] Cannot read/parse report:', e.message);
  process.exit(2);
}

// Flatten all test results
const allTests = [];
function collectTests(suites) {
  for (const suite of (suites || [])) {
    for (const spec of (suite.specs || [])) {
      allTests.push({ title: spec.title, ok: spec.ok === true });
    }
    collectTests(suite.suites);
  }
}
collectTests(report.suites || []);

// ── Map tests → rubric items ────────────────────────────────────
const itemScores   = {};
const itemPassed   = {};
const itemDetails  = {};

for (const item of RUBRIC) {
  const matched = allTests.find(t => t.title.includes(item.match));
  const passed  = matched ? matched.ok : false;
  itemPassed[item.id]  = passed;
  itemScores[item.id]  = passed ? item.score : 0;
  itemDetails[item.id] = {
    title:     item.match,
    gate:      item.gate,
    max_score: item.score,
    earned:    passed ? item.score : 0,
    passed,
    status:    matched ? (matched.ok ? 'passed' : 'failed') : 'not_found',
  };
}

// ── Aggregate ───────────────────────────────────────────────────
const totalScore   = Object.values(itemScores).reduce((a, b) => a + b, 0);
const gateItems    = RUBRIC.filter(i => i.gate);
const gatePassed   = gateItems.every(i => itemPassed[i.id]);
const overallPassed = gatePassed && totalScore >= 5;

// ── Write result ────────────────────────────────────────────────
const result = {
  task_id:        'task_pc_inventory_001',
  rubric_version: '1.3.0',
  timestamp:      new Date().toISOString(),
  total_score:    totalScore,
  max_score:      10,
  passing_score:  5,
  gate_passed:    gatePassed,
  overall_passed: overallPassed,
  item_scores:    itemDetails,
};

fs.writeFileSync(resultPath, JSON.stringify(result, null, 2));
NODE_SCRIPT

SCORER_EXIT=$?

if [ "$SCORER_EXIT" -ne 0 ]; then
  _fail "Scorer script failed (exit $SCORER_EXIT). Proceeding with teardown."
fi

# ── Pretty-print summary ─────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Harbor Benchmark · Scoring Summary${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ -f "$RESULT_JSON" ]; then
  node -e "
    const r = require('$RESULT_JSON');
    for (const [id, item] of Object.entries(r.item_scores)) {
      const icon   = item.passed ? '✓' : '✗';
      const gate   = item.gate   ? '[GATE]' : '      ';
      const earned = item.earned + '/' + item.max_score;
      console.log(icon + ' ' + gate + ' ' + id.padEnd(20) + earned + 'pt  ' + item.title);
    }
    console.log('');
    console.log('  Total Score : ' + r.total_score + ' / ' + r.max_score);
    console.log('  Gate Passed : ' + r.gate_passed);
    console.log('  RESULT      : ' + (r.overall_passed ? 'PASSED ✓' : 'FAILED ✗'));
  " 2>/dev/null || true
fi
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
_log "rubric_result.json written to: $RESULT_JSON"

# ════════════════════════════════════════════════════════════════════
#  STEP 4 – Teardown
# ════════════════════════════════════════════════════════════════════
_log "Step 4 – Teardown …"
if [ -x "$TEARDOWN" ]; then
  "$TEARDOWN" || true
fi
_ok "Teardown complete."

# ════════════════════════════════════════════════════════════════════
#  STEP 5 – Final exit code
# ════════════════════════════════════════════════════════════════════
if [ ! -f "$RESULT_JSON" ]; then
  _fail "No rubric_result.json produced – scoring failed."
  exit 1
fi

OVERALL=$(node -e "process.stdout.write(String(require('$RESULT_JSON').overall_passed))" 2>/dev/null)

if [ "$OVERALL" = "true" ]; then
  _ok "All gate items passed, total_score >= $PASSING_SCORE. → exit 0"
  exit 0
else
  _fail "Gate(s) failed or total_score < $PASSING_SCORE. → exit 1"
  exit 1
fi