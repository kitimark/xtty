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
# MECHANISM (verified against the vendor source @ f52fda2, by driving the
# real GUI once, and by a live minimal-PUT probe — see the forensics doc)
#   The preference lives at `agentModels.<agentId>.model` in the daemon's
#   app-config. At spawn the daemon resolves, in order (server.ts:4924-4936):
#       1. a per-request `model` field  (the UI sends this; we do not)
#       2. `agentModels.<agentId>.model`   <-- what this script writes
#       3. "default" -> NO --model flag is passed at all, and the agent CLI's
#          own configured model wins.
#   `sanitizeCustomModel` (models.ts:205: ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$,
#   <=200 chars, trimmed) gates only the PER-REQUEST field. A config-sourced
#   value bypasses it at the chat-spawn fallback (server.ts:4934) and reaches
#   the CLI verbatim as `--model <id>`; paths that re-send the stored pref as
#   the request field (e.g. Orbit routines, server.ts:8396-8406) sanitize it
#   to no-flag instead. Either way a bad stored id fails far from the write —
#   and the claude CLI rejects an unknown id with a readable message but EXIT
#   CODE 0 — so this script validates against the same regex at set time,
#   where failure is loud and attributable. The custom path is the documented
#   escape hatch for "a brand-new model the CLI's list hasn't surfaced yet" —
#   exactly our case: this build's pinned list is 4.x-era and predates
#   Claude 5 entirely.
#
# WRITE SHAPE (and why not write the file directly)
#   The daemon holds app-config in memory and fires `onAppConfigWritten`
#   hooks; a direct file poke is ignored until relaunch and overwritten by
#   the next GUI action. So we use the GUI's own route, PUT /api/app-config.
#   That route MERGES at the top-key level (`doWrite` starts from the stored
#   config and applies only the keys sent — app-config.ts) but REPLACES each
#   sent key wholesale (a sent `agentModels` replaces the whole per-agent
#   map). So this script read-modify-writes the `agentModels` map and sends
#   ONLY that key: unsent keys (the telemetry opt-out included) cannot be
#   dropped, and the read-modify-write race against a concurrent GUI action
#   is confined to the model prefs themselves — the route offers no
#   version/etag, so that residual last-writer-wins window (two simultaneous
#   model picks) is accepted, not closed.
#
# TELEMETRY GUARD
#   `telemetry.content: false` is repo posture (content telemetry ships file
#   bodies to a remote relay). On a fresh install the daemon SERVES absent
#   telemetry as {metrics: true, content: true} — content telemetry is the
#   pre-privacy-decision DEFAULT (app-config.ts applyTelemetryDefaults) — so
#   this script refuses to write until it is off, and re-checks after the
#   write that it did not move (our PUT never carries the telemetry key, so
#   any movement means a concurrent writer).
#
# Exit codes: 0 ok · 1 usage/validation · 2 daemon not running
#             · 3 write refused (telemetry guard, HTTP failure, or failed verify)

set -euo pipefail

SELF="$(basename "$0")"
AGENT_ID_OVERRIDE=""
WANT=""
MODE=set

die()  { printf '\033[31merror:\033[0m %s\n' "$1" >&2; exit "${2:-1}"; }
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
c = tel.get("content")
state = "true" if c is True else ("false" if c is False else "unset (consumers gate on content === true, so off today)")
print("  telemetry: content=" + state)
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
# Mirror sanitizeCustomModel (models.ts:205), including its trim — the value
# we store is the value the daemon would have accepted per-request. Reject
# here because a bad stored id only surfaces at spawn (as a verbatim --model
# the CLI rejects with exit 0, or silently sanitized to no-flag on the
# request-forwarding paths), where it looks like the setting did nothing.
want_norm="$(printf '%s' "$WANT" | "$py" -c '
import re, sys
v = sys.stdin.read().strip()
if not v or len(v) > 200 or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._/:@-]*", v):
    sys.exit(1)
sys.stdout.write(v)
')" || die "invalid model id: '$WANT' (must match ^[A-Za-z0-9][A-Za-z0-9._/:@-]*$, <=200 chars)"
WANT="$want_norm"

step "current pick"
show_current

# ── pre-write telemetry guard ───────────────────────────────────────────────
# Refuse to touch the config while content telemetry is on. On a fresh
# install "on" is what the daemon serves for an absent telemetry key — the
# pre-privacy-decision default — so this is the state to expect there.
PY_TEL='
import sys, json
cfg = json.load(sys.stdin).get("config") or {}
c = (cfg.get("telemetry") or {}).get("content")
print("true" if c is True else ("false" if c is False else "unset"))
'
pre_content="$(printf '%s' "$cfg_json" | "$py" -c "$PY_TEL")"
case "$pre_content" in
  true) die "content telemetry is ON (telemetry.content=true — it ships file bodies to a remote relay; on a fresh install this is the app's default until the privacy decision). Turn it off in Open Design's privacy settings, then re-run. Nothing was written." 3 ;;
  unset) warn "telemetry.content is unset — every consumer gates on content === true, so it is off today; set it explicitly to false in Open Design's privacy settings" ;;
esac

# ── read-modify-write the agentModels map, send ONLY that key ───────────────
# The route merges top-level keys but replaces a sent key wholesale, so the
# map (other agents' prefs + this agent's reasoning/serviceTier) must be
# carried over; everything else must NOT be echoed back — re-sending
# unrelated keys would clobber any concurrent GUI write with our stale read.
PY_MERGE='
import sys, json
agent, want = sys.argv[1], sys.argv[2]
cfg = json.load(sys.stdin).get("config") or {}
models = dict(cfg.get("agentModels") or {})
prefs = dict(models.get(agent) or {})
prefs["model"] = want
models[agent] = prefs
json.dump({"agentModels": models}, sys.stdout)
'
new_body="$(printf '%s' "$cfg_json" | "$py" -c "$PY_MERGE" "$AGENT_ID" "$WANT")"

# No -f here: the status line is checked explicitly, and -f would suppress
# the error body we want in the failure message.
tmp_resp="$(mktemp)"; trap 'rm -f "$tmp_resp"' EXIT
code="$(curl -sS --max-time 15 -o "$tmp_resp" -w '%{http_code}' \
        -X PUT -H 'Content-Type: application/json' \
        --data-binary "$new_body" "$BASE/api/app-config" 2>/dev/null || true)"
[ "$code" = 200 ] || die "PUT /api/app-config failed (HTTP ${code:-none}): $(head -c 300 "$tmp_resp")" 3

# ── verify by effect: re-read from the daemon, not from our own payload ─────
cfg_json="$(curl -fsS --max-time 10 "$BASE/api/app-config" 2>/dev/null)" \
  || die "wrote, but could not re-read app-config to verify" 3

# Our PUT never carries the telemetry key, so it cannot move telemetry —
# but assert that anyway: movement here means a concurrent writer or a
# daemon regression, and content telemetry silently on is the one failure
# in this workflow with a privacy consequence.
PY_VERIFY='
import sys, json
agent, want, pre = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(sys.stdin).get("config") or {}
got = ((cfg.get("agentModels") or {}).get(agent) or {}).get("model")
if got != want:
    print(f"error: re-read says model={got!r}, expected {want!r}", file=sys.stderr)
    sys.exit(1)
c = (cfg.get("telemetry") or {}).get("content")
post = "true" if c is True else ("false" if c is False else "unset")
if post != pre:
    print(f"error: telemetry.content moved across the write ({pre} -> {post}). "
          "This script never sends the telemetry key, so something else changed it mid-write. "
          "If it is not false, turn it off in Open Design\x27s privacy settings immediately.", file=sys.stderr)
    sys.exit(1)
'
printf '%s' "$cfg_json" | "$py" -c "$PY_VERIFY" "$AGENT_ID" "$WANT" "$pre_content" || exit 3

step "set"
show_current
printf '\nScope: global for agent \033[1m%s\033[0m — every Open Design project using it.\n' "$AGENT_ID"
printf 'Verify what actually SERVED a run in the stream events (per-message "model"),\n'
printf 'not just what was requested here.\n'
