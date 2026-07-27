#!/bin/sh
# Behavioral probe runner (design D7; rubric in README.md).
# Copied from openspec/changes/archive/2026-07-06-slim-agents-context/probes/run-probe.sh
# with exactly two declared edits, applied identically to every arm (design D7):
#   (1) turn cap 8 -> 10
#   (2) a per-probe "tools" override read from probes.json (defaults identical to the
#       archived suite); used only by the Bash-enabled orientation probe O1b.
# usage: run-probe.sh <variant-dir> <variant-name> <probe-id> <rep> <evidence-dir>
# Fresh headless session in the variant worktree; read-only tools; max 10 turns.
set -eu
DIR="$1"; NAME="$2"; PROBE="$3"; REP="$4"; EV="$5"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMPT="$(python3 -c "
import json,sys
p=[x for x in json.load(open('$HERE/probes.json'))['probes'] if x['id']=='$PROBE'][0]
sys.stdout.write(p['prompt'])
")"
ALLOWED="$(python3 -c "
import json
p=[x for x in json.load(open('$HERE/probes.json'))['probes'] if x['id']=='$PROBE'][0]
print(' '.join(p.get('tools',{}).get('allowed',['Read','Grep','Glob'])))
")"
DISALLOWED="$(python3 -c "
import json
p=[x for x in json.load(open('$HERE/probes.json'))['probes'] if x['id']=='$PROBE'][0]
print(' '.join(p.get('tools',{}).get('disallowed',['Write','Edit','Bash','Task','WebSearch','WebFetch'])))
")"
mkdir -p "$EV/probes/$NAME"
OUT="$EV/probes/$NAME/${PROBE}-rep${REP}.json"
echo "LAUNCH probe ${NAME}/${PROBE} rep${REP} $(date -u +%FT%TZ)" >> "$EV/ledger.log"
( cd "$DIR" && claude -p "$PROMPT" --output-format json --max-turns 10 \
    --allowedTools $ALLOWED \
    --disallowedTools $DISALLOWED ) > "$OUT" || \
  echo "ERROR probe ${NAME}/${PROBE} rep${REP} exit=$? $(date -u +%FT%TZ)" >> "$EV/ledger.log"
python3 - "$OUT" <<'EOF'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    res = [x for x in d if x.get("type") == "result"][0] if isinstance(d, list) else d
    print(f"{sys.argv[1]}: turns={res.get('num_turns')} err={res.get('is_error')} result[:200]={str(res.get('result'))[:200]!r}")
except Exception as e:
    print(f"{sys.argv[1]}: UNPARSEABLE ({e})")
EOF
