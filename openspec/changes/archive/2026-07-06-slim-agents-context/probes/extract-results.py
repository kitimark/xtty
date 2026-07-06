#!/usr/bin/env python3
"""Extract probe-run results into a compact grading sheet (one md file per variant)."""
import json, sys, pathlib

ev = pathlib.Path(sys.argv[1])          # evidence dir
variant = sys.argv[2]                   # e.g. v0
d = ev / "probes" / variant
out = [f"# Grading sheet — {variant}\n"]
for f in sorted(d.glob("*.json")):
    try:
        data = json.load(open(f))
        res = [x for x in data if x.get("type") == "result"][0] if isinstance(data, list) else data
        out.append(f"\n## {f.stem}  (turns={res.get('num_turns')} err={res.get('is_error')} subtype={res.get('subtype')})\n")
        out.append(str(res.get("result", "<no result field>")).strip())
        out.append("")
    except Exception as e:
        out.append(f"\n## {f.stem}  EXTRACTION ERROR: {e}\n")
sheet = ev / f"grading-{variant}.md"
sheet.write_text("\n".join(out))
print(f"{sheet}: {len(sheet.read_text())} chars, {len(list(d.glob('*.json')))} runs")
