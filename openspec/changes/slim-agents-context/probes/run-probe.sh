#!/bin/sh
# Behavioral probe runner (design D5/D7; rubric in README.md).
# usage: run-probe.sh <variant-dir> <variant-name> <probe-id> <rep> <evidence-dir>
# Fresh headless session in the variant worktree; read-only tools; max 8 turns.
set -eu
DIR="$1"; NAME="$2"; PROBE="$3"; REP="$4"; EV="$5"
HERE="$(cd "$(dirname "$0")" && pwd)"
PROMPT="$(python3 -c "
import json,sys
p=[x for x in json.load(open('$HERE/probes.json'))['probes'] if x['id']=='$PROBE'][0]
sys.stdout.write(p['prompt'])
")"
mkdir -p "$EV/probes/$NAME"
OUT="$EV/probes/$NAME/${PROBE}-rep${REP}.json"
echo "LAUNCH probe ${NAME}/${PROBE} rep${REP} $(date -u +%FT%TZ)" >> "$EV/ledger.log"
( cd "$DIR" && claude -p "$PROMPT" --output-format json --max-turns 8 \
    --allowedTools "Read" "Grep" "Glob" \
    --disallowedTools "Write" "Edit" "Bash" "Task" "WebSearch" "WebFetch" ) > "$OUT" || \
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
