#!/bin/sh
# Batch driver: run probes x reps against one variant with bounded concurrency.
# usage: run-batch.sh <variant-dir> <variant-name> <evidence-dir> <reps> [probe-id ...]
# Default probe set = all probes in probes.json. Concurrency 3 (batch-wait).
set -eu
DIR="$1"; NAME="$2"; EV="$3"; REPS="$4"; shift 4
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ $# -gt 0 ]; then
  PROBES="$*"
else
  PROBES="$(python3 -c "import json; print(' '.join(p['id'] for p in json.load(open('$HERE/probes.json'))['probes']))")"
fi
echo "BATCH START ${NAME} probes=[$PROBES] reps=${REPS} $(date -u +%FT%TZ)" >> "$EV/ledger.log"
i=0
for p in $PROBES; do
  r=1
  while [ "$r" -le "$REPS" ]; do
    "$HERE/run-probe.sh" "$DIR" "$NAME" "$p" "$r" "$EV" &
    i=$((i + 1))
    if [ $((i % 3)) -eq 0 ]; then wait; fi
    r=$((r + 1))
  done
done
wait
echo "BATCH DONE ${NAME} $(date -u +%FT%TZ)" >> "$EV/ledger.log"
