#!/bin/sh
# Context-usage instrument (design D8, instrument 1).
# usage: measure-context.sh <variant-dir> <variant-name> <rep> <evidence-dir>
# Startup context = input + cache_creation + cache_read tokens of a 1-turn trivial run.
set -eu
DIR="$1"; NAME="$2"; REP="$3"; EV="$4"
mkdir -p "$EV/context"
OUT="$EV/context/${NAME}-rep${REP}.json"
echo "LAUNCH context ${NAME} rep${REP} $(date -u +%FT%TZ)" >> "$EV/ledger.log"
( cd "$DIR" && claude -p "Reply with exactly: OK" --output-format json --max-turns 1 ) > "$OUT"
python3 - "$OUT" <<'EOF'
import json, sys
d = json.load(open(sys.argv[1]))
u = d.get("usage", {})
total = u.get("input_tokens", 0) + u.get("cache_creation_input_tokens", 0) + u.get("cache_read_input_tokens", 0)
print(f"{sys.argv[1]}: startup_context={total} (input={u.get('input_tokens',0)} cache_create={u.get('cache_creation_input_tokens',0)} cache_read={u.get('cache_read_input_tokens',0)})")
EOF
