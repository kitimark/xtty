#!/usr/bin/env bash
#
# design-link.sh — register xtty's committed Open Design design-system package
# (design/xtty/) with the *installed* Open Design desktop app, by symlink, and
# verify the registration BY EFFECT.
#
# Why this route, and only this route: selecting a *published* design system in
# a project's picker is the ONLY channel that pastes DESIGN.md + tokens.css
# verbatim into the agent's system prompt (open-design @ f52fda2 —
# server.ts:3889-3915, prompts/system.ts:1129-1155). One call symlinks the repo
# package into the picker with zero copies:
#   POST /api/design-systems/install {"source":"local","path":"<abs>"}
#     -> fs.symlinkSync(realpath, <data>/design-systems/<basename>)
#        (library-install.ts:133-181; symlink at :175)
# /!\ NEVER use Settings > Design Systems > "Import from folder" for this
#     package — that is import-local, a CSS/JS scanner that REGENERATES
#     DESIGN.md and destroys the authored prose. The PROJECT-creation folder
#     import is a different, safe mechanism and is what design/mockups/ uses.
#
# The daemon binds an EPHEMERAL port and writes no port file (server.ts:
# 8976-8999): port is read from the running sidecar's listening socket, and the
# data dir from the same pid's open app.sqlite handle. If Open Design is not
# running this script FAILS with instructions — it never launches the app (a
# daemon started outside the desktop process has no desktop auth secret).
#
# Idempotent. Every decision is made from the FILESYSTEM and re-checked there;
# a 200 from the install call is logged but is not treated as evidence.
# Full mechanism record: research/03-analysis/open-design-integration-forensics.md
#
# Usage:
#   scripts/design-link.sh                      install / repair, then verify   (make design-link)
#   scripts/design-link.sh --status             verify only; mutates nothing    (make design-status)
#   scripts/design-link.sh --uninstall          unlink by hand, then verify     (make design-unlink)
#   scripts/design-link.sh --select-project ID  opt-in: set a project's picker
# Options:
#   --package-dir PATH   package to link (default: <repo>/design/xtty)
# Env:
#   OD_DATA_DIR   override the app data dir (default: the running daemon's own,
#                 else ~/Library/Application Support/Open Design/namespaces/release-stable/data)
#   OD_APP        override the app bundle   (default: /Applications/Open Design.app)
# Exit codes: 0 ok | 1 error/not linked | 2 Open Design not running or
#             verification inconclusive | 3 needs a human decision
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG_DIR="$ROOT/design/xtty"
MOCKUPS_DIR="$ROOT/design/mockups"
OD_APP="${OD_APP:-/Applications/Open Design.app}"
DEFAULT_DATA_DIR="$HOME/Library/Application Support/Open Design/namespaces/release-stable/data"
MODE=install
SELECT_PROJECT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --status)          MODE=status ;;
    --uninstall)       MODE=uninstall ;;
    --select-project)  MODE=select; SELECT_PROJECT="${2:?--select-project needs a project id or name}"; shift ;;
    --package-dir)     PKG_DIR="${2:?--package-dir needs a path}"; shift ;;
    -h|--help)         sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//;$d'; exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
  esac
  shift
done

say()  { printf '%s\n' "$*"; }
step() { printf '==> %s\n' "$*"; }
warn() { printf '  !  %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit "${2:-1}"; }
first_line() { printf '%s' "${1%%$'\n'*}"; }

# JSON helpers: stdlib python3 (Xcode-provided, already a repo prereq; NOT jq).
py=/usr/bin/python3
[ -x "$py" ] || py="$(command -v python3 || true)"
[ -n "$py" ] || die "python3 not found (expected /usr/bin/python3 from the Xcode CLT)"

# stdin = design-systems list body; $1 = wanted id.
# prints "<source>\t<status>\t<title>", exit 1 when absent.
ds_entry() {
  "$py" -c '
import json,sys
want=sys.argv[1]
try: d=json.load(sys.stdin)
except Exception: sys.exit(1)
for s in (d.get("designSystems") or []):
    if s.get("id")==want:
        print("\t".join(str(s.get(k)) for k in ("source","status","title"))); sys.exit(0)
sys.exit(1)' "$1"
}

# stdin = error body; handles both {"error":"str"} and {"error":{code,message}}.
api_err() {
  "$py" -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print(""); raise SystemExit
e=d.get("error")
print((e.get("message") or e.get("code") or "") if isinstance(e,dict) else (e or ""))'
}

# ── package pre-flight (local, before touching the daemon) ───────────────────
[ -d "$PKG_DIR" ] || die "no package at $PKG_DIR — author design/xtty/ first (DESIGN.md + tokens.css + metadata.json)"
# Canonicalize with the same primitive class the daemon uses
# (fs.realpathSync.native at library-install.ts:138-140) — NOT `pwd -P`, whose
# case handling can differ on case-insensitive APFS.
PKG_REAL="$("$py" -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$PKG_DIR")"
PKG_NAME="$(basename "$PKG_REAL")"        # the app names the link this (:162)
DS_ID="user:$PKG_NAME"
case "$PKG_NAME" in
  *[!a-zA-Z0-9._-]*) die "package dir name '$PKG_NAME' has characters the daemon's id validator rejects" ;;
esac

if [ "$MODE" != uninstall ]; then
  # DESIGN.md is a hard gate: installFromLocal 400s without it (library-install.ts:158-160).
  [ -f "$PKG_REAL/DESIGN.md" ] || die "missing $PKG_REAL/DESIGN.md — the install route refuses a package without it"
  # tokens.css is NOT checked by the app: it installs+publishes cleanly while the
  # whole token channel silently stays empty (index.ts:499 reads it opportunistically).
  [ -s "$PKG_REAL/tokens.css" ] || warn "missing/empty $PKG_REAL/tokens.css — installs fine, but NO tokens will reach the prompt"
  if [ -f "$PKG_REAL/metadata.json" ]; then
    grep -q '"status"[[:space:]]*:[[:space:]]*"published"'           "$PKG_REAL/metadata.json" \
      || warn 'metadata.json lacks "status":"published" — picker rejects with DESIGN_SYSTEM_NOT_PUBLISHED'
    grep -q '"artifactMode"[[:space:]]*:[[:space:]]*"agent-managed"' "$PKG_REAL/metadata.json" \
      || warn 'metadata.json lacks "artifactMode":"agent-managed" — the app will scaffold ~23 files INTO THE REPO on first read'
  else
    warn "no metadata.json — the package defaults to status 'draft' and is NOT selectable"
  fi
fi

# ── daemon discovery ─────────────────────────────────────────────────────────
PORT=""; BASE=""; DAEMON_PID=""; DATA_DIR=""
discover_daemon() {
  local pids pid ports p body sq
  pids="$(pgrep -f 'daemon-sidecar\.mjs' 2>/dev/null || true)"
  [ -n "$pids" ] || return 1
  for pid in $pids; do
    ports="$(lsof -nP -a -iTCP -sTCP:LISTEN -p "$pid" -Fn 2>/dev/null \
             | sed -n 's/^n.*:\([0-9][0-9]*\)$/\1/p' | sort -un || true)"
    for p in $ports; do
      # /api/health is unauthenticated and read-only.
      body="$(curl -fsS --max-time 5 "http://127.0.0.1:$p/api/health" 2>/dev/null || true)"
      case "$body" in
        *'"ok":true'*)
          PORT="$p"; BASE="http://127.0.0.1:$p"; DAEMON_PID="$pid"
          # Map pid -> data dir via its own open sqlite handle, so a
          # multi-namespace install can't be silently addressed wrong.
          sq="$(lsof -p "$pid" -Fn 2>/dev/null | sed -n 's|^n\(.*\)/app\.sqlite$|\1|p' || true)"
          DATA_DIR="$(first_line "$sq")"
          return 0 ;;
      esac
    done
  done
  return 1
}

if discover_daemon; then
  step "Open Design daemon: pid $DAEMON_PID, port $PORT"
else
  if [ "$MODE" = install ] || [ "$MODE" = select ]; then
    cat >&2 <<EOF
error: Open Design is not running.

  Launch it first:   open -a "Open Design"
  Then re-run:       make design-link

  This script will NOT start the app: a daemon started outside the desktop
  process never registers the desktop auth secret, so the folder-import step
  you need afterwards would be permanently blocked.
EOF
    exit 2
  fi
  warn "daemon not running — on-disk checks only; the catalog half of the verification is SKIPPED"
fi

# Track HOW we learned DATA_DIR. `status` needs this to tell "not linked" from
# "cannot determine": with the daemon down we never read its sqlite handle, so
# the path is a guess and an absent link there proves nothing (a multi-namespace
# or relocated install would be checked at the wrong path entirely).
DATA_DIR_SOURCE=daemon
if [ -z "$DATA_DIR" ]; then
  DATA_DIR="${OD_DATA_DIR:-$DEFAULT_DATA_DIR}"
  DATA_DIR_SOURCE=default
  if [ -n "$BASE" ]; then
    warn "could not read the daemon's data dir from lsof; assuming $DATA_DIR (the post-install symlink check is what actually adjudicates)"
  fi
fi
# An explicit OD_DATA_DIR is an operator assertion — it makes the path known
# even with the daemon down, so `status` may answer definitively.
if [ -n "${OD_DATA_DIR:-}" ]; then DATA_DIR="$OD_DATA_DIR"; DATA_DIR_SOURCE=env; fi
LINK="$DATA_DIR/design-systems/$PKG_NAME"

od_get()  { curl -fsS --max-time 15 -H "Origin: $BASE" "$BASE$1"; }
od_json() { # $1=method $2=path $3=body $4=out-file -> prints http status
  curl -sS --max-time 30 -X "$1" \
       -H "Origin: $BASE" -H 'Content-Type: application/json' \
       -d "$3" -o "$4" -w '%{http_code}' "$BASE$2"
}

# ── on-disk state machine (authoritative; NOT the API) ───────────────────────
# A absent -> install | B correct link -> no-op | C wrong/dangling -> repair
# D real dir/file -> refuse; a human decides (never rm -rf here)
link_state() {
  if [ ! -e "$LINK" ] && [ ! -L "$LINK" ]; then echo A; return; fi
  if [ -L "$LINK" ]; then
    # -ef compares device+inode THROUGH the link — immune to the case/
    # canonicalization mismatches a string compare of readlink vs pwd -P
    # can hit on case-insensitive APFS (which would otherwise loop C forever).
    if [ "$LINK" -ef "$PKG_REAL" ] && [ -f "$LINK/DESIGN.md" ]; then echo B; else echo C; fi
    return
  fi
  echo D
}

LINK_STATE=""
report_state() {
  LINK_STATE="$(link_state)"
  case "$LINK_STATE" in
    A) say "  link:    absent            ($LINK)" ;;
    B) say "  link:    OK -> $PKG_REAL" ;;
    C) if [ -e "$LINK" ]; then say "  link:    WRONG TARGET -> $(readlink "$LINK")"
       else                    say "  link:    DANGLING -> $(readlink "$LINK")"; fi ;;
    D) say "  link:    NOT A SYMLINK (a real file/directory) at $LINK" ;;
  esac
}

# Returns: 0 present+published | 1 absent/draft/error | 2 daemon down (UNVERIFIED)
verify_catalog() {
  local body entry src st title
  [ -n "$BASE" ] || { say "  catalog: UNVERIFIED (Open Design not running)"; return 2; }
  body="$(od_get /api/design-systems)" || { warn "GET /api/design-systems failed"; return 1; }
  if ! entry="$(printf '%s' "$body" | ds_entry "$DS_ID")"; then
    say "  catalog: '$DS_ID' NOT LISTED"; return 1
  fi
  src="${entry%%$'\t'*}"; entry="${entry#*$'\t'}"
  st="${entry%%$'\t'*}";  title="${entry#*$'\t'}"
  say "  catalog: $DS_ID  source=$src  status=$st  title=\"$title\""
  [ "$src" = user ] || { warn "expected source=user"; return 1; }
  if [ "$st" = draft ]; then
    warn "status=draft — the picker will refuse it. Set \"status\":\"published\" in metadata.json and re-run."
    return 1
  fi
  return 0
}

advisories() {
  # 0. Artifact-mode tripwire — the one marker design/.gitignore hides from git status.
  if [ -e "$PKG_REAL/.od-generated.json" ]; then
    warn "TRIPWIRE: $PKG_REAL/.od-generated.json exists — artifactMode was lost; the scaffold"
    warn "  generator ran (or is armed). Inspect design/xtty/ for scaffolded README.md/"
    warn "  design-tokens.json/tailwind-v4.css/preview/ and re-assert artifactMode:\"agent-managed\"."
  fi

  # 1. Token-SCHEMA coverage, derived from the INSTALLED app (no clone needed):
  #    the bundled `default` brand = all 56 schema tokens + exactly --space-20.
  #    Count = schema names covered, NOT total declarations (Layer C --xtty-*
  #    extensions are expected and counted separately).
  local ref="$OD_APP/Contents/Resources/open-design/design-systems/default/tokens.css"
  if [ -r "$ref" ] && [ -r "$PKG_REAL/tokens.css" ]; then
    local tmp covered ext missing extra
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
    grep -oE '^[[:space:]]*--[a-zA-Z0-9-]+[[:space:]]*:' "$ref" \
      | tr -d ' :' | sort -u | grep -v '^--space-20$' > "$tmp/schema"
    grep -oE '^[[:space:]]*--[a-zA-Z0-9-]+[[:space:]]*:' "$PKG_REAL/tokens.css" \
      | tr -d ' :' | sort -u > "$tmp/ours"
    covered="$(comm -12 "$tmp/schema" "$tmp/ours" | wc -l | tr -d ' ')"
    ext="$(grep -c '^--xtty-' "$tmp/ours" || true)"
    missing="$(comm -23 "$tmp/schema" "$tmp/ours" | tr '\n' ' ')"
    extra="$(comm -13 "$tmp/schema" "$tmp/ours" | grep -v '^--xtty-' | tr '\n' ' ' || true)"
    say "  tokens:  $covered/56 schema tokens covered (+$ext --xtty-* extensions)"
    if [ -n "$missing" ]; then warn "missing schema tokens (artifacts will carry dead var() refs): $missing"; fi
    if [ -n "$extra" ];   then warn "non-schema, non---xtty-* names (the --font-chrome trap): $extra"; fi
  else
    say "  tokens:  (schema reference not readable at $ref — coverage check skipped)"
  fi

  # 2. The kill switch that silently empties the token channel (index.ts:646-657).
  if [ -n "$DAEMON_PID" ]; then
    local ch; ch="$(ps -E -p "$DAEMON_PID" 2>/dev/null | tr ' ' '\n' | sed -n 's/^OD_DESIGN_TOKEN_CHANNEL=//p' || true)"
    case "$(first_line "${ch:-}")" in
      0)  warn "OD_DESIGN_TOKEN_CHANNEL=0 in the daemon env — tokens/components injection DISABLED; only DESIGN.md is pushed" ;;
      "") say "  channel: OD_DESIGN_TOKEN_CHANNEL unset (default = enabled)" ;;
      *)  say "  channel: OD_DESIGN_TOKEN_CHANNEL=$(first_line "$ch")" ;;
    esac
  fi

  # 3. The DESIGN.md workspace freeze.
  if [ -d "$DATA_DIR/projects/ds-$PKG_NAME" ]; then
    warn "frozen workspace copy exists: $DATA_DIR/projects/ds-$PKG_NAME"
    warn "  tokens.css re-reads live through the symlink; DESIGN.md does NOT — the prompt prefers this copy."
    warn "  After editing DESIGN.md:  rm -rf \"$DATA_DIR/projects/ds-$PKG_NAME\"  then start one run."
  fi

  # 4. Telemetry content flag — prevention-only (no send-log exists to audit
  #    retroactively). Config-file location is verify-on-first-use.
  local cfg="" c
  for c in "$DATA_DIR/app-config.json" "$DATA_DIR/../app-config.json"; do
    if [ -f "$c" ]; then cfg="$c"; break; fi
  done
  if [ -n "$cfg" ]; then
    local tel; tel="$("$py" -c '
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: print("unreadable"); raise SystemExit
t=(d.get("telemetry") or {}).get("content")
print("false" if t is False else ("true" if t is True else "unset"))' "$cfg")"
    case "$tel" in
      false) say "  telemetry: content=false  ($cfg)" ;;
      *)     warn "telemetry.content is '$tel' in $cfg — the default ships prompt + file bodies; set false BEFORE any run" ;;
    esac
  else
    warn "app-config.json not found under $DATA_DIR (location verify-on-first-use) — confirm telemetry.content:false on disk by hand"
  fi

  # 5. The app-owned write-back into the git tree.
  say "  note:    on first picker use the daemon rewrites $PKG_REAL/metadata.json"
  say "           (whole-file 2-space JSON, 9-key allowlist) adding \"projectId\" —"
  say "           expect that one-line diff; commit or discard it deliberately."
}

case "$MODE" in

status)
  step "Open Design linkage for $DS_ID"
  say "  data:    $DATA_DIR"
  report_state
  rc=0; verify_catalog && rc=0 || rc=$?
  advisories
  if [ "$LINK_STATE" = B ] && [ "$rc" -eq 0 ]; then
    say ""; say "Linked and published."; exit 0
  fi
  if [ "$LINK_STATE" = B ] && [ "$rc" -eq 2 ]; then
    # Never claim success on the strength of a symlink alone — DATA_DIR itself
    # may be a guess when the daemon is down.
    say ""; say "Link OK on disk; catalog UNVERIFIED (Open Design not running) — inconclusive."
    exit 2
  fi
  # Absent link + unconfirmed data dir is NOT "not linked" — we may have looked
  # in the wrong place. Only the daemon (or an explicit OD_DATA_DIR) makes the
  # path authoritative, so without one the honest answer is "cannot determine".
  if [ "$LINK_STATE" = A ] && [ "$DATA_DIR_SOURCE" = default ]; then
    say ""
    say "Cannot determine: Open Design is not running, so its data directory was"
    say "assumed, not read. No link at the assumed path — but that is not proof."
    say "  assumed: $DATA_DIR"
    say "Launch Open Design and re-run, or pin the path with OD_DATA_DIR=<dir>."
    exit 2
  fi
  say ""; say "Not fully linked — run: make design-link"
  exit 1
  ;;

uninstall)
  step "Unlinking $DS_ID"
  st="$(link_state)"
  case "$st" in
    A) say "  nothing to do (no link at $LINK)" ;;
    B|C)
      # BY HAND, on purpose. The app's own DELETE for a `user:` id bypasses the
      # safe lstat+unlink sibling (static-resource.ts:827-829) and runs
      # rm(path,{recursive:true,force:false}) (index.ts:1451-1460) — whether
      # that unlinks or recurses into the repo working tree is UNVERIFIED, and
      # the downside if wrong is the git tree. unlink(2) can only remove a link.
      [ -L "$LINK" ] || die "refusing: $LINK is not a symlink" 3
      rm "$LINK"
      say "  unlinked $LINK  (repo untouched — unlink(2) on the symlink only)"
      ;;
    D) die "$LINK is a real file/directory, not our symlink. Refusing to delete it. Inspect and remove it yourself if you are sure." 3 ;;
  esac
  if [ -e "$LINK" ] || [ -L "$LINK" ]; then die "link still present after unlink"; fi
  if [ -n "$BASE" ]; then
    if od_get /api/design-systems | ds_entry "$DS_ID" >/dev/null; then
      die "the daemon still lists $DS_ID — something re-created it"
    fi
    say "  catalog: $DS_ID no longer listed"
  else
    warn "daemon not running: could not confirm the catalog dropped it (it will — discovery is a bare readdir)"
  fi
  say ""
  say "App-side residue this does NOT remove (delete by hand for a clean slate):"
  say "  $DATA_DIR/projects/ds-$PKG_NAME      (workspace copy of DESIGN.md)"
  say "  the mockups project row + its runs/  (delete the project in the app UI)"
  exit 0
  ;;

select)
  # OPT-IN. Setting the picker on an EXISTING project IS scriptable:
  # PATCH /api/projects/:id accepts designSystemId and is NOT behind the
  # desktop-auth gate (routes/project/index.ts:2218-2228). Creation is gated.
  # NOTE the project NAME defaults to basename(baseDir) = "mockups" when the
  # GUI import dialog's name field is left alone (import-export-routes.ts:
  # 380-382); when the given name/id matches nothing, fall back to resolving
  # by baseDir == design/mockups.
  step "Pointing project '$SELECT_PROJECT' at $DS_ID"
  verify_catalog || die "refusing: $DS_ID is not present+published — run 'make design-link' first"
  projects="$(od_get /api/projects)"
  match="$("$py" -c '
import json,sys,os
want=sys.argv[1]; root=os.path.realpath(sys.argv[2]); mock=os.path.realpath(sys.argv[3])
d=json.load(sys.stdin); projs=d.get("projects") or []
def base(p):
    b=((p.get("metadata") or {}).get("baseDir")) or ""
    return os.path.realpath(b) if b else ""
hits=[p for p in projs if p.get("id")==want or p.get("name")==want]
if not hits:
    hits=[p for p in projs if base(p)==mock]   # fallback: resolve by baseDir
if len(hits)!=1: print("AMBIGUOUS %d"%len(hits)); raise SystemExit
p=hits[0]; b=base(p)
if not (b==root or b.startswith(root+os.sep)): print("OUTSIDE %s"%b); raise SystemExit
print("OK %s %s"%(p["id"], p.get("designSystemId")))' "$SELECT_PROJECT" "$ROOT" "$MOCKUPS_DIR" <<<"$projects")"
  case "$match" in
    "AMBIGUOUS 0") die "no project matches '$SELECT_PROJECT' by id/name, and none has baseDir $MOCKUPS_DIR — create it first (GUI folder import; see 'make design-link' output)" 3 ;;
    AMBIGUOUS*)    die "more than one project matches — pass the exact project id" 3 ;;
    OUTSIDE*)      die "that project's baseDir (${match#OUTSIDE }) is outside $ROOT — refusing to retarget an unrelated project" 3 ;;
  esac
  pid="$(printf '%s' "$match" | cut -d' ' -f2)"
  was="$(printf '%s' "$match" | cut -d' ' -f3)"
  say "  project $pid (design_system_id was: $was)"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  code="$(od_json PATCH "/api/projects/$pid" "{\"designSystemId\":\"$DS_ID\"}" "$tmp")"
  [ "$code" = 200 ] || die "PATCH failed ($code): $(api_err <"$tmp")"
  # Verify by re-READ, never by the PATCH echo.
  now="$(od_get "/api/projects/$pid" | "$py" -c 'import json,sys; d=json.load(sys.stdin); print((d.get("project") or d).get("designSystemId"))')"
  [ "$now" = "$DS_ID" ] || die "re-read says design_system_id=$now, expected $DS_ID"
  say "  verified: design_system_id = $now"
  say ""
  say "This proves the DB field. It does NOT prove tokens reach a prompt — for"
  say "that: change one value in design/xtty/tokens.css, generate a mockup, and"
  say "grep the produced HTML for the new value."
  exit 0
  ;;

install)
  step "Linking $PKG_REAL  ->  $LINK"
  st="$(link_state)"; REPAIRED=0
  case "$st" in
    A) : ;;
    B) say "  already linked correctly — no API call needed" ;;
    C)
      if [ -e "$LINK" ]; then warn "link points at $(readlink "$LINK") — repairing"
      else                    warn "DANGLING link -> $(readlink "$LINK") (the repo moved?) — repairing"; fi
      [ -L "$LINK" ] || die "internal: state C but $LINK is not a symlink"
      rm "$LINK"   # unlink(2) on a symlink; cannot touch the target
      st=A; REPAIRED=1 ;;
    D)
      cat >&2 <<EOF
error: $LINK exists and is NOT a symlink.

  Something (probably Settings > Design Systems > "Import from folder" /
  import-local) created a real directory there. This script will not delete
  it — that is a human decision. Inspect, remove, re-run:
      ls -la "$LINK"
EOF
      exit 3 ;;
  esac

  if [ "$st" = A ]; then
    tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
    code="$(od_json POST /api/design-systems/install \
      "$("$py" -c 'import json,sys; print(json.dumps({"source":"local","path":sys.argv[1]}))' "$PKG_REAL")" "$tmp")"
    msg="$(api_err <"$tmp")"
    case "$code" in
      200) say "  install call returned 200 (not evidence — verifying on disk next)" ;;
      400)
        case "$msg" in
          *"already installed"*) warn "daemon says already installed but the filesystem disagreed — re-checking" ;;
          *EEXIST*)              warn "EEXIST — a stale link raced us; re-run to repair"; exit 1 ;;
          *) die "install rejected (400): $msg" ;;
        esac ;;
      403) die "403 $msg — origin guard rejected us (unexpected: plain-curl + explicit Origin is accepted per origin-validation.ts:212-255)" ;;
      500)
        # The symlink IS created and NOT cleaned up on this arm
        # (static-resource.ts:648-666) — 500 means "linked, but the catalog
        # scan didn't find it" (usually: DESIGN.md unreadable through the link).
        warn "500: $msg"
        warn "Symlink left in place on purpose for inspection; a re-run will detect and repair."
        say  "  link now: $( [ -L "$LINK" ] && readlink "$LINK" || echo '(absent)')"
        exit 1 ;;
      *) die "unexpected HTTP $code: $msg" ;;
    esac
  fi

  # ── verify by effect: two independent halves ──────────────────────────────
  step "Verifying"
  report_state
  if [ "$LINK_STATE" != B ]; then
    if [ "$REPAIRED" = 1 ]; then
      die "still state $LINK_STATE after a repair — refusing to loop (a second rm would thrash the link). Compare by hand: readlink \"$LINK\" vs $PKG_REAL"
    fi
    die "post-install link check failed (state $LINK_STATE). If you overrode OD_DATA_DIR it may not match the daemon's actual data dir."
  fi
  [ -s "$LINK/tokens.css" ] || warn "tokens.css not readable through the link — the daemon's read will come back empty"
  verify_catalog || die "the daemon does not list $DS_ID as a published user system"
  advisories

  cat <<EOF

──────────────────────────────────────────────────────────────────────────────
Linked and published. Two steps remain; only ONE is expected to need you.

 1. CREATE THE MOCKUPS PROJECT — expected to require the GUI.
      In Open Design: new project -> import a folder
      Choose:  $MOCKUPS_DIR
    Why: POST /api/import/folder demands an HMAC token bound to the chosen
    path + a one-shot nonce whenever the desktop has registered its auth
    secret (import-export-routes.ts:287-323; registration confirmed at
    sidecar/server.ts:212-219, sticky once set). Whether the gate fired on
    THIS install is verify-on-first-use — record the outcome in
    design/README.md. This script does not probe the route: the only safe
    probe IS the real import (the route creates projects, and its ungated
    behaviour on a bogus baseDir is unobserved).
    /!\\ This is the PROJECT folder import. Do NOT confuse it with
        Settings > Design Systems > "Import from folder" — that one would
        regenerate DESIGN.md from a CSS scan and destroy design/xtty/.

 2. POINT THE PROJECT AT THIS DESIGN SYSTEM — GUI or scripted:
      GUI:     project settings -> Design system -> "$PKG_NAME"
      Script:  scripts/design-link.sh --select-project mockups
    (The GUI import names the project basename(baseDir) = "mockups" unless
     you typed a name; the script also falls back to matching by baseDir.)

 THEN VERIFY THE CHANNEL BY EFFECT: change one value in design/xtty/tokens.css,
 generate a mockup, grep the produced HTML for the new value. Nothing above
 proves a single token reached a prompt; that check does.

 Before that first run: clean, pushed working tree. After: repo-wide
 'git status' + 'git diff'; check design/xtty/.od-generated.json does not
 exist; stage by explicit path only. The agent runs with
 --permission-mode bypassPermissions and folder scope is not enforced.
──────────────────────────────────────────────────────────────────────────────
EOF
  ;;
esac
