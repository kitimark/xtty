#!/usr/bin/env bash
# design-model.sh — select the model Open Design's code-agent runtime uses.
#
# WHY THIS EXISTS
#   Open Design's model pick is a *global, per-agent* preference — not a
#   per-project one. The GUI exposes it as a dropdown buried two clicks deep
#   in the composer's runtime chip, which is fine to set once by hand and
#   miserable to set repeatedly (e.g. cheap model to iterate, strong model to
#   author a baseline). This script is that dropdown, scripted.
#
# MECHANISM (verified against the vendor source @ f52fda2 and by driving the
# real GUI once and diffing the config it wrote — see the forensics doc)
#   The preference lives at `agentModels.<agentId>.model` in the daemon's
#   app-config. At spawn the daemon resolves, in order (server.ts:4925-4936):
#       1. a per-request `model` field  (the UI sends this; we do not)
#       2. `agentModels.<agentId>.model`   <-- what this script writes
#       3. "default" -> NO --model flag is passed at all, and the agent CLI's
#          own configured model wins.
#   A value that `isKnownModel` recognizes passes through verbatim; anything
#   else goes through `sanitizeCustomModel` (models.ts:205) and is passed
#   through if it matches ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$ and is <=200 chars.
#   That custom path is the documented escape hatch for "a brand-new model the
#   CLI's list hasn't surfaced yet" — which is exactly our case: this Open
#   Design build's pinned list is 4.x-era and predates Claude 5 entirely.
#
# WHY NOT WRITE THE FILE DIRECTLY
#   The daemon holds app-config in memory and fires `onAppConfigWritten` hooks
#   on every write. A direct file poke is ignored until relaunch and can be
#   overwritten by the next GUI action. We use the same HTTP route the GUI
#   uses. That route is a WHOLE-CONFIG REPLACE, not a merge — so this script
#   always does read-modify-write of the full object, and verifies afterwards
#   that it did not drop the telemetry opt-out.
#
# Exit codes: 0 ok · 1 usage/validation · 2 daemon not running · 3 write refused

set -euo pipefail

SELF="$(basename "$0")"
AGENT_ID_OVERRIDE=""
WANT=""
MODE=set

die()  { printf '\033[31merror:\033[0m %s\n' "$*" >&2; exit "${2:-1}"; }
warn() { printf '\033[33mwarn:\033[0m %s\n' "$*" >&2; }
step() { printf '\033[36m==>\033[0m %s\n' "$*"; }

usage() {
  cat <<EOF
Usage:
  $SELF <model>            set the model for the configured code agent
  $SELF --status           show the current pick (also the default with no args)
  $SELF --agent <id> ...   target a specific runtime (default: the configured one)

Models (Claude Code runtime):
  default   pass no --model flag; the claude CLI's own config decides
  haiku     cheap/fast — mechanical edits, quick iterations
  sonnet    balanced
  opus      strongest — design judgment, token discipline, source fidelity
  fable     Claude 5 Fable
  <custom>  any id the agent CLI accepts, e.g. claude-fable-5

  The four aliases resolve inside the agent CLI at spawn, so they always mean
  the CURRENT model of that tier. Prefer them over pinned ids like
  claude-opus-4-5 (this Open Design build's list predates Claude 5, and a
  pinned id that is no longer served fails the run).

Scope: GLOBAL per agent, not per project. Changing it here changes it for
every Open Design project using the same runtime.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --status|-s) MODE=status; shift ;;
    --agent) [ $# -ge 2 ] || die "--agent needs a value"; AGENT_ID_OVERRIDE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) [ -z "$WANT" ] || die "only one model may be given (got '$WANT' and '$1')"; WANT="$1"; shift ;;
  esac
done
[ -n "$WANT" ] || MODE=status

py="$(command -v python3 || true)"
[ -n "$py" ] || die "python3 is required"

# ── daemon discovery ────────────────────────────────────────────────────────
# Same shape as design-link.sh: find the sidecar, probe each listening port's
# unauthenticated /api/health, and take the one that answers.
PORT=""; BASE=""
discover_daemon() {
  local pids pid ports p body
  pids="$(pgrep -f 'daemon-sidecar\.mjs' 2>/dev/null || true)"
  [ -n "$pids" ] || return 1
  for pid in $pids; do
    ports="$(lsof -nP -a -iTCP -sTCP:LISTEN -p "$pid" -Fn 2>/dev/null \
             | sed -n 's/^n.*:\([0-9][0-9]*\)$/\1/p' | sort -un || true)"
    for p in $ports; do
      body="$(curl -fsS --max-time 5 "http://127.0.0.1:$p/api/health" 2>/dev/null || true)"
      case "$body" in
        *'"ok":true'*) PORT="$p"; BASE="http://127.0.0.1:$p"; return 0 ;;
      esac
    done
  done
  return 1
}

discover_daemon || die "Open Design is not running (launch it: open -a \"Open Design\")" 2
step "Open Design daemon: port $PORT"

# curl sends Host: 127.0.0.1:<port> and no Origin, which is exactly what the
# route's isLocalSameOrigin check accepts for a local non-browser client.
cfg_json="$(curl -fsS --max-time 10 "$BASE/api/app-config" 2>/dev/null)" \
  || die "could not read app-config from the daemon" 2

AGENT_ID="$AGENT_ID_OVERRIDE"
[ -n "$AGENT_ID" ] || AGENT_ID="$(printf '%s' "$cfg_json" | "$py" -c '
import sys, json
cfg = json.load(sys.stdin).get("config") or {}
print(cfg.get("agentId") or "claude")
')"
[ -n "$AGENT_ID" ] || AGENT_ID=claude

# Python programs are held in variables and fed to `python3 -c`: a heredoc
# would claim stdin, which is where the config JSON arrives.
PY_SHOW='
import sys, json
agent = sys.argv[1]
cfg = json.load(sys.stdin).get("config") or {}
prefs = (cfg.get("agentModels") or {}).get(agent) or {}
model = prefs.get("model")
print(f"  agent:   {agent}")
if not model:
    print("  model:   (unset) -> no --model flag; the agent CLI\x27s own config decides")
elif model == "default":
    print("  model:   default -> no --model flag; the agent CLI\x27s own config decides")
else:
    print(f"  model:   {model} -> spawned as --model {model}")
tel = cfg.get("telemetry") or {}
print("  telemetry: content=" + str(tel.get("content")).lower())
'

show_current() {
  printf '%s' "$cfg_json" | "$py" -c "$PY_SHOW" "$AGENT_ID"
}

if [ "$MODE" = status ]; then
  step "current pick"
  show_current
  exit 0
fi

# ── validate ────────────────────────────────────────────────────────────────
# Mirror sanitizeCustomModel (models.ts:205). We reject here rather than let
# the daemon silently drop the value at spawn time, where it would look like
# the setting simply did nothing.
printf '%s' "$WANT" | "$py" -c '
import re, sys
v = sys.stdin.read().strip()
if not v or len(v) > 200 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/:@-]*", v):
    sys.exit(1)
' || die "invalid model id: '$WANT' (must match ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$, <=200 chars)"

step "current pick"
show_current

# ── read-modify-write the WHOLE config ──────────────────────────────────────
PY_MERGE='
import sys, json
agent, want = sys.argv[1], sys.argv[2]
cfg = json.load(sys.stdin).get("config") or {}
models = dict(cfg.get("agentModels") or {})
prefs = dict(models.get(agent) or {})
prefs["model"] = want
models[agent] = prefs
cfg["agentModels"] = models
json.dump(cfg, sys.stdout)
'
new_body="$(printf '%s' "$cfg_json" | "$py" -c "$PY_MERGE" "$AGENT_ID" "$WANT")"

tmp_resp="$(mktemp)"; trap 'rm -f "$tmp_resp"' EXIT
code="$(curl -fsS --max-time 15 -o "$tmp_resp" -w '%{http_code}' \
        -X PUT -H 'Content-Type: application/json' \
        --data-binary "$new_body" "$BASE/api/app-config" 2>/dev/null || true)"
[ "$code" = 200 ] || die "PUT /api/app-config failed (HTTP ${code:-none}): $(head -c 300 "$tmp_resp")" 3

# ── verify by effect: re-read from the daemon, not from our own payload ─────
cfg_json="$(curl -fsS --max-time 10 "$BASE/api/app-config" 2>/dev/null)" \
  || die "wrote, but could not re-read app-config to verify" 3

# The PUT is a whole-config replace, so a bad merge here would silently
# re-enable content telemetry (which ships file bodies to a remote relay).
# Check it on every write and fail loudly rather than leave that on.
PY_VERIFY='
import sys, json
agent, want = sys.argv[1], sys.argv[2]
cfg = json.load(sys.stdin).get("config") or {}
got = ((cfg.get("agentModels") or {}).get(agent) or {}).get("model")
if got != want:
    print(f"error: re-read says model={got!r}, expected {want!r}", file=sys.stderr)
    sys.exit(1)
tel = cfg.get("telemetry") or {}
if tel.get("content") is not False:
    print("error: THE WRITE CHANGED TELEMETRY - content=" + repr(tel.get("content")) +
          ", expected False. Turn it back off in Settings immediately.", file=sys.stderr)
    sys.exit(1)
'
printf '%s' "$cfg_json" | "$py" -c "$PY_VERIFY" "$AGENT_ID" "$WANT" || exit 3

step "set"
show_current
printf '\nScope: global for agent \033[1m%s\033[0m — every Open Design project using it.\n' "$AGENT_ID"
printf 'Verify what actually SERVED a run in the stream events (per-message "model"),\n'
printf 'not just what was requested here.\n'
