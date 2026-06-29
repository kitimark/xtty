#!/usr/bin/env bash
#
# P7c one-time / spot-check leak & allocation audit (the lifecycle-census change).
#
# A DIAGNOSTIC AID — explicitly NOT a CI/build gate. The deterministic leak
# guard is the in-process census (XttyCore LifecycleLeakTests) + the churn
# XCUITest (XttyLifecycleCensusUITests), which `make test` runs. This script
# exists for the one-time deep pass + later spot-checks against what the per-type
# census cannot name: third-party engine/renderer internals (notably SwiftTerm's
# unbounded glyph/font caches + renderer deinit) and OS-level allocations.
#
# It runs Apple's `leaks` exit-time detector (true leaks, not pooled/abandoned
# memory) with malloc stack logging for backtraces, plus a `vmmap` region
# summary (IOSurface / Metal / malloc zones). No privileged install and no
# entitlement beyond the `get-task-allow` a local debug build already carries;
# ad-hoc signing is sufficient.
#
# Because Swift/AppKit pooled memory + intentional caches make leak-count gating
# false-positive-prone, READ the reports — do not wire them into a pass/fail gate.
# Findings are recorded in research/03-analysis/p7c-leak-retain-audit.md.
#
# Usage:  make audit-leaks        (or)   scripts/audit-leaks.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Build/Products/Debug/xtty.app"
BIN="$APP/Contents/MacOS/xtty"
OUT="$ROOT/build/leaks"

if [ ! -x "$BIN" ]; then
  echo "error: $BIN not found — run 'make build' first." >&2
  exit 1
fi

mkdir -p "$OUT"
echo "Leak audit (diagnostic, not a gate) — reports → $OUT"
echo "App: $BIN"
echo

# Exit-time leak check with backtraces. The app self-terminates after the
# benchmark scenarios (idle → multi-pane → saturated scrollback → alt-screen),
# giving `leaks -atExit` a representative heap to inspect, plus a .memgraph for
# post-mortem `heap`/`malloc_history` and run-to-run `leaks -diffFrom`.
echo "[1/2] leaks -atExit (this exercises the bench scenarios; needs a visible display)…"
MallocStackLogging=1 \
  leaks --atExit --outputGraph="$OUT/xtty.memgraph" -- \
  "$BIN" -Benchmark -UITestRenderer coregraphics -BenchmarkReport "$OUT/bench.json" \
  > "$OUT/leaks.txt" 2>&1 || true
echo "      → $OUT/leaks.txt   (graph: $OUT/xtty.memgraph)"

# A quick VM-region summary captured from the memory graph (IOSurface = glyph
# atlas; Metal/anonymous = framebuffers; malloc zones = scrollback-bounded).
echo "[2/2] vmmap --summary (from the memory graph)…"
vmmap --summary "$OUT/xtty.memgraph" > "$OUT/vmmap-summary.txt" 2>&1 || true
echo "      → $OUT/vmmap-summary.txt"

echo
echo "=== leaks summary ==="
grep -E "leaks for|total leaked|Process .* leaks" "$OUT/leaks.txt" || \
  echo "(no leak-summary line — open $OUT/leaks.txt; latency/bench needs Screen Recording + a display)"
echo
echo "Done. These reports are diagnostics — interpret, don't gate. See"
echo "research/03-analysis/p7c-leak-retain-audit.md for the recorded findings."
