#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
APP="${1:-$ROOT/.build/DerivedData/Build/Products/Debug/xtty.app/Contents/MacOS/xtty}"
REPORT="${2:-/tmp/xtty-large-diff-memory.tsv}"
STATE="/tmp/xtty-state-dump.json"
GRID="/tmp/xtty-grid-dump.txt"
PROBE_ROOT="$(mktemp -d /tmp/xtty-large-diff-memory.XXXXXX)"
APP_PID=""
SAMPLER_PID=""

cleanup() {
  if [[ -n "$SAMPLER_PID" ]] && kill -0 "$SAMPLER_PID" 2>/dev/null; then
    kill "$SAMPLER_PID" 2>/dev/null || true
    wait "$SAMPLER_PID" 2>/dev/null || true
  fi
  if [[ -n "$APP_PID" ]] && kill -0 "$APP_PID" 2>/dev/null; then
    kill -TERM "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
  case "$PROBE_ROOT" in
    /tmp/xtty-large-diff-memory.*) rm -rf "$PROBE_ROOT" ;;
    *) echo "refusing unexpected cleanup path: $PROBE_ROOT" >&2 ;;
  esac
  rm -f "$STATE" "$GRID"
}
trap cleanup EXIT INT TERM

[[ -x "$APP" ]] || { echo "app binary is not executable: $APP" >&2; exit 2; }

now_ms() {
  /usr/bin/perl -MTime::HiRes=time -e 'printf "%.0f\n", time() * 1000'
}

state_value() {
  /usr/bin/plutil -extract "$1" raw -o - "$STATE" 2>/dev/null || true
}

rss_kib() {
  /bin/ps -o rss= -p "$1" | /usr/bin/awk '{ print $1 + 0 }'
}

wait_for_repo() {
  local expected="$1"
  for _ in {1..400}; do
    [[ "$(state_value gitReview.repoRoot)" == "$expected" ]] && return 0
    sleep 0.025
  done
  return 1
}

wait_for_truncated_selection() {
  local expected="$1"
  for _ in {1..400}; do
    if [[ "$(state_value gitReview.selectedDiff.path)" == "$expected" ]] &&
       [[ "$(state_value gitReview.selectedDiff.truncated)" == "true" ]]; then
      return 0
    fi
    sleep 0.025
  done
  return 1
}

preview_children() {
  local repo="$1"
  /bin/ps -axo comm=,args= | /usr/bin/awk -v repo="$repo" '
    $1 ~ /(^|\/)git$/ && index($0, repo) && index($0, "diff") &&
      index($0, "--unified=") { count += 1 }
    END { print count + 0 }
  '
}

generate_payload() {
  local kind="$1" bytes="$2" path="$3"
  if [[ "$kind" == "many" ]]; then
    /usr/bin/perl -e '
      $remaining = shift;
      $line = ("x" x 100) . "\n";
      while ($remaining >= 101) { print $line; $remaining -= 101; }
      print "x" x $remaining;
    ' "$bytes" >"$path"
  else
    /usr/bin/perl -e 'print "x" x shift' "$bytes" >"$path"
  fi
}

run_case() {
  local label="$1" kind="$2" mib="$3"
  local bytes=$((mib * 1024 * 1024))
  local case_root="$PROBE_ROOT/$label"
  local repo="$case_root/repo"
  local config_root="$case_root/config"
  local trigger="$case_root/select"
  local samples="$case_root/rss-kib.txt"
  local log="$case_root/xtty.log"

  mkdir -p "$repo" "$config_root/xtty"
  repo="$(cd "$repo" && pwd -P)"  # Git canonicalizes macOS /tmp → /private/tmp.
  /usr/bin/git -C "$repo" init -q
  printf 'base\n' >"$repo/sample.txt"
  /usr/bin/git -C "$repo" add sample.txt
  /usr/bin/git -C "$repo" -c user.email=t@e -c user.name=t commit -qm init
  generate_payload "$kind" "$bytes" "$repo/sample.txt"
  printf 'cwd = %s\n' "$repo" >"$config_root/xtty/config"

  rm -f "$STATE" "$GRID" "$trigger"
  (
    cd "$ROOT"
    exec /usr/bin/env \
      XDG_CONFIG_HOME="$config_root" \
      XTTY_TEST_GIT_SELECT="$trigger" \
      "$APP" -UITestGridDump -UITestGitReview
  ) >"$log" 2>&1 &
  APP_PID=$!

  if ! wait_for_repo "$repo"; then
    echo "case $label: Git review never reported $repo" >&2
    /usr/bin/plutil -p "$STATE" >&2 || true
    tail -40 "$log" >&2
    exit 3
  fi

  local baseline="$(rss_kib "$APP_PID")"
  : >"$samples"
  (
    while kill -0 "$APP_PID" 2>/dev/null; do
      rss_kib "$APP_PID" >>"$samples"
      sleep 0.01
    done
  ) &
  SAMPLER_PID=$!

  local started="$(now_ms)"
  printf 'sample.txt\n' >"$trigger"
  if ! wait_for_truncated_selection sample.txt; then
    echo "case $label: truncated selection never published" >&2
    tail -60 "$log" >&2
    exit 4
  fi
  local finished="$(now_ms)"

  kill "$SAMPLER_PID" 2>/dev/null || true
  wait "$SAMPLER_PID" 2>/dev/null || true
  SAMPLER_PID=""

  local peak="$(/usr/bin/sort -n "$samples" | /usr/bin/tail -1)"
  local delta=$((peak - baseline))
  local duration=$((finished - started))
  local cutoff="$(
    /usr/bin/sed -n 's/.*diff cutoff: \([^ ]*\) (\([0-9]*\) retained bytes).*/\1:\2/p' "$log" |
      /usr/bin/tail -1
  )"
  local lingering="$(preview_children "$repo")"

  printf '%s\t%s\t%d\t%d\t%d\t%d\t%d\t%s\t%d\n' \
    "$label" "$kind" "$bytes" "$baseline" "$peak" "$delta" "$duration" \
    "${cutoff:-missing}" "$lingering" | tee -a "$REPORT"

  kill -TERM "$APP_PID" 2>/dev/null || true
  wait "$APP_PID" 2>/dev/null || true
  APP_PID=""
}

printf 'case\tshape\tinput_bytes\tbaseline_rss_kib\tpeak_rss_kib\trss_delta_kib\tduration_ms\tcutoff\tlingering_preview_children\n' >"$REPORT"
run_case many-5m many 5
run_case many-25m many 25
run_case many-75m many 75
run_case single-25m single 25

echo "report: $REPORT"
