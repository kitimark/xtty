#!/usr/bin/env bash
#
# design-link.sh — register xtty's committed Open Design design-system package
# (design/xtty-design-system/) with the *installed* Open Design desktop app, by symlink, and
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
#     import is a different, safe mechanism and is what design/xtty-mockups/ uses.
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
#   scripts/design-link.sh                      install / repair the link, then
#                                               create+configure the 'xtty'
#                                               project (folder design/xtty-mockups),
#                                               then verify                     (make design-link)
#   scripts/design-link.sh --status             verify only; mutates nothing    (make design-status)
#   scripts/design-link.sh --uninstall          undo install: delete the 'xtty'
#                                               project + the ds-<pkg> workspace
#                                               copy, unlink by hand, verify    (make design-unlink)
#   scripts/design-link.sh --create-project     dedupe/create/configure the 'xtty' project only
#   scripts/design-link.sh --select-project ID  opt-in: set a project's picker
# Options:
#   --package-dir PATH   package to link (default: <repo>/design/xtty-design-system)
#   --keep-project       with --uninstall: leave the project row (and its
#                        app-side run history) in place; remove the rest
# Env:
#   OD_DATA_DIR   override the app data dir (default: the running daemon's own,
#                 else ~/Library/Application Support/Open Design/namespaces/release-stable/data)
#   OD_APP        override the app bundle   (default: /Applications/Open Design.app)
# Exit codes: 0 ok | 1 error/not linked | 2 Open Design not running or
#             verification inconclusive | 3 needs a human decision
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The basename of this directory IS the identity: the install route symlinks
# <data>/design-systems/<basename> and the catalog id is always
# "user:<basename>" (library-install.ts:162-180; design-systems/index.ts:310 —
# no install-body field can decouple them). Renaming this directory renames the
# design-system id; manifest.json's "id" must equal the basename or the whole
# manifest is silently ignored (isProjectManifest, index.ts:3683-3702).
PKG_DIR="$ROOT/design/xtty-design-system"
MOCKUPS_DIR="$ROOT/design/xtty-mockups"
OD_APP="${OD_APP:-/Applications/Open Design.app}"
DEFAULT_DATA_DIR="$HOME/Library/Application Support/Open Design/namespaces/release-stable/data"
MODE=install
SELECT_PROJECT=""
KEEP_PROJECT=0
# Single target on purpose — see the platform note in the `select` branch.
PLATFORM="desktop-app"
# App-side DISPLAY name of the design/xtty-mockups project — never identity: every
# lookup here resolves projects by realpath(metadata.baseDir) (PY_PROJ). The
# folder stays design/xtty-mockups (design/xtty-design-system is the package dir, a sibling); the
# name exists for the app's project list and export filenames, and reaches
# neither the agent prompt nor any artifact path. Set at creation (--name) and
# converged on an existing row (ensure_name). Owner call, 2026-07-29.
PROJECT_NAME="xtty"

while [ $# -gt 0 ]; do
  case "$1" in
    --status)          MODE=status ;;
    --uninstall)       MODE=uninstall ;;
    --keep-project)    KEEP_PROJECT=1 ;;
    --create-project)  MODE=create ;;
    --select-project)  MODE=select; SELECT_PROJECT="${2:?--select-project needs a project id or name}"; shift ;;
    --platform)        PLATFORM="${2:?--platform needs a slug (default: desktop-app)}"; shift ;;
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
[ -d "$PKG_DIR" ] || die "no package at $PKG_DIR — author design/xtty-design-system/ first (DESIGN.md + tokens.css + metadata.json)"
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
  if [ "$MODE" = install ] || [ "$MODE" = select ] || [ "$MODE" = create ]; then
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

# One scratch dir for every mode. A single EXIT trap, set once — the chained
# flows below (create -> select) would otherwise clobber each other's traps.
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT

# Shared project matcher, defined ONCE: a project is identified by
# realpath(metadata.baseDir) — never by name. Open Design enforces NO
# uniqueness on name or baseDir (db.ts:58-67), so names are decoration and
# duplicate projects at the same directory are representable (and observed).
PY_PROJ='
import json,sys,os
def _base(p):
    b=((p.get("metadata") or {}).get("baseDir")) or ""
    return os.path.realpath(b) if b else ""
def by_basedir(projs, want):
    want=os.path.realpath(want)
    return [p for p in projs if _base(p)==want]
'

# stdin = /api/projects body; $1 = directory. Prints one
# "id|name|designSystemId|platform|importedFrom|fromTrustedPicker" line per
# project whose baseDir resolves to $1.
projects_at() {
  "$py" -c "$PY_PROJ"'
d=json.load(sys.stdin)
for p in by_basedir(d.get("projects") or [], sys.argv[1]):
    m=p.get("metadata") or {}
    print("|".join(str(x) for x in (p.get("id",""), p.get("name",""),
        p.get("designSystemId"), m.get("platform"),
        m.get("importedFrom"), m.get("fromTrustedPicker"))))' "$1"
}

# The documented fallback whenever scripted creation cannot run. Route history:
# creation was believed GUI-only because POST /api/import/folder is HMAC-gated
# (measured live: 403 {"code":"FORBIDDEN","reason":"token missing"}). The gate
# stands — but the app ships a first-party CLI (`od project import-folder`)
# that mints the token itself, so the scripted path SATISFIES the gate rather
# than bypassing it. When that CLI is unusable, the GUI is the only path.
manual_creation_instructions() {
  cat <<EOF

  MANUAL FALLBACK — create the project in the GUI:
    In Open Design:  new project -> "Open folder"
    Choose:          $MOCKUPS_DIR
    /!\\ That is the PROJECT folder import. Do NOT confuse it with
        Settings > Design Systems > "Import from folder" — that one would
        regenerate DESIGN.md from a CSS scan and destroy design/xtty-design-system/.
    Then:            re-run  make design-link
                     (the GUI names the import '$(basename "$MOCKUPS_DIR")' after the folder;
                      the re-run renames it to '$PROJECT_NAME' and configures
                      design system + platform via the ungated PATCH path)
EOF
}

# The bundled CLI needs OD_SIDECAR_IPC_PATH to (a) discover the daemon's
# ephemeral HTTP port and (b) mint the folder-import HMAC token, both over the
# daemon's IPC socket (cli.ts mintCliImportToken; daemon-url.ts). Without it
# the CLI silently falls back to a wrong default port and a null token. Three
# discovery routes, most authoritative first — all read public process
# metadata via ps; this script NEVER connects to the socket itself.
discover_ipc_socket() {
  local cmd="" sock="" ns=""
  if [ -n "$DAEMON_PID" ]; then
    cmd="$(ps -p "$DAEMON_PID" -o command= 2>/dev/null || true)"
    # (a) the daemon process's own --od-stamp-ipc=<path> argument
    sock="$(printf '%s\n' "$cmd" | tr ' ' '\n' | sed -n 's/^--od-stamp-ipc=//p' | head -1)"
    if [ -n "$sock" ] && [ -S "$sock" ]; then printf '%s' "$sock"; return 0; fi
    # (b) the daemon process's own environment
    sock="$(ps -E -p "$DAEMON_PID" 2>/dev/null | tr ' ' '\n' | sed -n 's/^OD_SIDECAR_IPC_PATH=//p' | head -1)"
    if [ -n "$sock" ] && [ -S "$sock" ]; then printf '%s' "$sock"; return 0; fi
    ns="$(printf '%s\n' "$cmd" | tr ' ' '\n' | sed -n 's/^--od-stamp-namespace=//p' | head -1)"
  fi
  # (c) the deterministic default, namespaced like the daemon's stamp says
  sock="/tmp/open-design/ipc/${ns:-release-stable}/daemon.sock"
  if [ -S "$sock" ]; then printf '%s' "$sock"; return 0; fi
  return 1
}

# Run the app's own first-party CLI through the app's bundled Electron helper
# as the interpreter — no system node required, and the exact CLI build that
# matches the running daemon. Returns 9 when the CLI cannot run at all
# (distinct from the CLI's own exit codes).
od_cli() {
  local cli="$OD_APP/Contents/Resources/app/prebundled/daemon/daemon-cli.mjs"
  local helper="$OD_APP/Contents/Frameworks/Open Design Helper.app/Contents/MacOS/Open Design Helper"
  local sock
  sock="$(discover_ipc_socket)" || { warn "no daemon IPC socket found — the CLI could not mint an import token"; return 9; }
  [ -f "$cli" ] || { warn "bundled CLI not found at $cli"; return 9; }
  if [ -x "$helper" ]; then
    ELECTRON_RUN_AS_NODE=1 OD_SIDECAR_IPC_PATH="$sock" "$helper" "$cli" "$@"
  elif command -v node >/dev/null 2>&1; then
    OD_SIDECAR_IPC_PATH="$sock" node "$cli" "$@"
  else
    warn "neither the bundled Electron helper nor a system node is available"
    return 9
  fi
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
  # 0a. The project at design/xtty-mockups: report it, and warn on the two hazards.
  # Duplicates: Open Design does NOT dedupe — the import route has no
  # existing-project check, and `projects` constrains only `id` — not `name`,
  # not metadata.baseDir (db.ts:58-67). So importing design/xtty-mockups twice
  # yields two independent projects writing into the SAME directory, each with
  # its own design-system setting. Observed for real: a double-fired click
  # produced two rows at the same folder, one configured and one not, which
  # then made a by-name --select-project ambiguous. Names are not identity
  # here — always resolve by baseDir.
  if [ -n "$BASE" ]; then
    local projs pn
    projs="$(od_get /api/projects 2>/dev/null | projects_at "$MOCKUPS_DIR" 2>/dev/null || true)"
    pn=0; [ -n "$projs" ] && pn="$(printf '%s\n' "$projs" | wc -l | tr -d ' ')"
    if [ "$pn" -eq 0 ]; then
      say "  project: none at $MOCKUPS_DIR (make design-link creates it)"
    elif [ "$pn" -eq 1 ]; then
      local pi pnm pds ppf _rest
      IFS='|' read -r pi pnm pds ppf _rest <<<"$projs"
      say "  project: '$pnm'  id=$pi  designSystem=$pds  platform=$ppf"
      [ "$pnm" = "$PROJECT_NAME" ] || warn "project name is '$pnm', expected '$PROJECT_NAME' — make design-link renames it in place (display only; identity is baseDir)"
    else
      warn "DUPLICATE PROJECTS: more than one project has baseDir $MOCKUPS_DIR."
      warn "  Open Design does not dedupe folder imports (no uniqueness on name or baseDir),"
      warn "  so these are independent projects writing into the same directory — one may"
      warn "  have the design system attached and another not, and a generation run in the"
      warn "  wrong one silently skips your tokens. Delete the extras IN THE APP (deleting"
      warn "  a project never touches baseDir), keeping the one that reports $DS_ID:"
      printf '%s\n' "$projs" | while IFS='|' read -r i n ds _rest; do
        warn "    id=$i  name=$n  designSystem=$ds"
      done
    fi
  fi

  # 0. Artifact-mode tripwire — the one marker design/.gitignore hides from git status.
  if [ -e "$PKG_REAL/.od-generated.json" ]; then
    warn "TRIPWIRE: $PKG_REAL/.od-generated.json exists — artifactMode was lost; the scaffold"
    warn "  generator ran (or is armed). Inspect design/xtty-design-system/ for scaffolded README.md/"
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

# ── project configuration (shared by --select-project, --create-project, install)
# Setting the picker on an EXISTING project IS scriptable: PATCH
# /api/projects/:id accepts designSystemId and is NOT behind the desktop-auth
# gate (routes/project/index.ts:2218-2228). Creation is gated over raw HTTP but
# scriptable via the app's own bundled CLI — see create_flow.
# NOTE on names: a GUI folder import defaults the project name to
# basename(baseDir) = "xtty-mockups" (import-export-routes.ts:380-382); the scripted
# import passes --name $PROJECT_NAME instead. Either way names are not
# identity: when the given name/id matches nothing, resolve by baseDir ==
# design/xtty-mockups (the shared matcher), and when it matches MORE than one row,
# narrow by baseDir — the ds-<pkg> workspace row displays the design system's
# TITLE (server-services.ts:255 stamps summary.title), which equals
# $PROJECT_NAME here, so '--select-project xtty' can name-hit both rows.
select_flow() {
  step "Pointing project '$SELECT_PROJECT' at $DS_ID"
  verify_catalog || die "refusing: $DS_ID is not present+published — run 'make design-link' first"
  local projects match ppid was tmp code now meta
  projects="$(od_get /api/projects)"
  match="$("$py" -c "$PY_PROJ"'
want=sys.argv[1]; root=os.path.realpath(sys.argv[2]); mock=sys.argv[3]
d=json.load(sys.stdin); projs=d.get("projects") or []
hits=[p for p in projs if p.get("id")==want or p.get("name")==want]
if not hits:
    hits=by_basedir(projs, mock)   # fallback: resolve by baseDir (shared matcher)
elif len(hits)>1:
    # A display-name collision (e.g. the ds-<pkg> workspace row also shows
    # the design-system title): narrow to the row(s) at design/xtty-mockups.
    hits=by_basedir(hits, mock) or hits
if len(hits)!=1: print("AMBIGUOUS %d"%len(hits)); raise SystemExit
p=hits[0]; b=_base(p)
if not (b==root or b.startswith(root+os.sep)): print("OUTSIDE %s"%b); raise SystemExit
print("OK %s %s"%(p["id"], p.get("designSystemId")))' "$SELECT_PROJECT" "$ROOT" "$MOCKUPS_DIR" <<<"$projects")"
  case "$match" in
    "AMBIGUOUS 0") die "no project matches '$SELECT_PROJECT' by id/name, and none has baseDir $MOCKUPS_DIR — run 'scripts/design-link.sh --create-project' (or import the folder in the GUI)" 3 ;;
    AMBIGUOUS*)    die "more than one project matches — pass the exact project id" 3 ;;
    OUTSIDE*)      die "that project's baseDir (${match#OUTSIDE }) is outside $ROOT — refusing to retarget an unrelated project" 3 ;;
  esac
  ppid="$(printf '%s' "$match" | cut -d' ' -f2)"
  was="$(printf '%s' "$match" | cut -d' ' -f3)"
  say "  project $ppid (design_system_id was: $was)"
  tmp="$TMPD/select-resp"
  code="$(od_json PATCH "/api/projects/$ppid" "{\"designSystemId\":\"$DS_ID\"}" "$tmp")"
  [ "$code" = 200 ] || die "PATCH failed ($code): $(api_err <"$tmp")"
  # Verify by re-READ, never by the PATCH echo.
  now="$(od_get "/api/projects/$ppid" | "$py" -c 'import json,sys; d=json.load(sys.stdin); print((d.get("project") or d).get("designSystemId"))')"
  [ "$now" = "$DS_ID" ] || die "re-read says design_system_id=$now, expected $DS_ID"
  say "  verified: design_system_id = $now"

  # Target platform. The folder-import route sets NO platform at all, which
  # leaves the prompt carrying "platform: (unknown — ask …)" (prompts/system.ts
  # :1626) so the agent re-asks every session. Worse is the WRONG value:
  # `responsive` injects a contract demanding no horizontal scroll at 360px and
  # verification across ten breakpoints (:1631) — which flatly contradicts this
  # design base (DESIGN.md §8: no breakpoints; panels collapse to zero, they do
  # not reflow). `desktop-app` as a SINGLE target avoids both, and also avoids
  # the >1-target rule that would demand one file per platform (:1636).
  # Slug per apps/web NewProjectPanel.tsx:119. Metadata is replaced wholesale,
  # so re-send the whole object; the route re-stamps baseDir/fromTrustedPicker
  # itself (routes/project/index.ts:2100-2145), which the re-read below proves.
  meta="$(od_get "/api/projects/$ppid" | "$py" -c '
import json,sys
d=json.load(sys.stdin); m=((d.get("project") or d).get("metadata")) or {}
m["platform"]=sys.argv[1]; m["platformTargets"]=[sys.argv[1]]
m.pop("fromTrustedPicker", None)   # immutable; the route rejects any change
print(json.dumps({"metadata": m}))' "$PLATFORM")"
  code="$(od_json PATCH "/api/projects/$ppid" "$meta" "$tmp")"
  [ "$code" = 200 ] || die "platform PATCH failed ($code): $(api_err <"$tmp")"
  od_get "/api/projects/$ppid" | "$py" -c '
import json,sys
m=((json.load(sys.stdin).get("project") or {}).get("metadata")) or {}
want=sys.argv[1]
if m.get("platform")!=want: raise SystemExit("platform re-read=%s, expected %s"%(m.get("platform"),want))
if not m.get("baseDir"):    raise SystemExit("baseDir LOST by the platform patch — folder link broken")
print("  verified: platform = %s, targets = %s"%(m["platform"], m.get("platformTargets")))
print("  verified: baseDir still %s"%m["baseDir"])' "$PLATFORM" \
    || die "platform verification failed"
  say ""
  say "This proves the DB field. It does NOT prove tokens reach a prompt — for"
  say "that: change one value in design/xtty-design-system/tokens.css, generate a mockup, and"
  say "grep the produced HTML for the new value."
}

# ── project display name (converge in place; never delete-and-recreate) ─────
# PATCH /api/projects/:id accepts {name} through the same ungated handler the
# designSystemId PATCH uses (routes/project/index.ts:2095). Renaming in place
# preserves the row's id and its app-side run/chat history. It cannot reach
# the repo: the daemon's one rename write-through — into the bound design
# system's metadata.json, which for us is the SYMLINKED design/xtty-design-system/ — is
# gated on metadata.importedFrom=="design-system" (a ds-<pkg> workspace row;
# design-systems/index.ts:1279-1291), and every row this script touches is
# importedFrom=="folder". That is still proven by the git bracket below, not
# assumed. Verified by re-read, never by the PATCH echo.
ensure_name() { # $1=project id  $2=current display name
  local id="$1" nm="$2" before after code now
  [ "$nm" = "$PROJECT_NAME" ] && return 0
  before="$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)"
  say "  renaming: '$nm' -> '$PROJECT_NAME' (display only — identity stays baseDir; id and run history kept)"
  code="$(od_json PATCH "/api/projects/$id" \
    "$("$py" -c 'import json,sys;print(json.dumps({"name":sys.argv[1]}))' "$PROJECT_NAME")" \
    "$TMPD/name-resp")"
  [ "$code" = 200 ] || die "rename PATCH failed ($code): $(api_err <"$TMPD/name-resp")"
  now="$(od_get "/api/projects/$id" | "$py" -c 'import json,sys; d=json.load(sys.stdin); print((d.get("project") or d).get("name"))')"
  [ "$now" = "$PROJECT_NAME" ] || die "re-read says name=$now, expected $PROJECT_NAME"
  after="$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)"
  [ "$after" = "$before" ] || die "RENAME TOUCHED THE REPO: git status design/ changed — inspect immediately (git status design/ && git diff design/)"
  say "  verified: name = $now (git status design/ unchanged)"
}

# ── project creation (dedupe-first; the app itself NEVER dedupes) ────────────
# Auto-run from `install` on purpose, not opt-in, because:
#  - dedupe-first makes it a no-op whenever a project already points at
#    design/xtty-mockups, so auto-running cannot mint duplicates — while leaving
#    creation to humans provably CAN (the app has no uniqueness on name or
#    baseDir, and a double-fired GUI click already produced two `mockups` rows);
#  - every failure degrades to exactly the pre-CLI behavior: print the manual
#    GUI instructions and leave the link intact;
#  - it collapses a fresh clone's setup to the one documented command.
# Exit: 0 ok/no-op | 2 fell back to manual | 3 duplicates need a human.
create_flow() {
  step "Project '$PROJECT_NAME' (baseDir $MOCKUPS_DIR)"
  local before hits n out rc id nm ds pf ifrom trusted
  hits="$(od_get /api/projects | projects_at "$MOCKUPS_DIR")" || die "GET /api/projects failed"
  n=0; [ -n "$hits" ] && n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"

  if [ "$n" -gt 1 ]; then
    warn "refusing to touch anything: $n projects already point at design/xtty-mockups —"
    printf '%s\n' "$hits" | while IFS='|' read -r id nm ds pf _rest; do
      warn "    id=$id  name=$nm  designSystem=$ds  platform=$pf"
    done
    warn "Open Design does not dedupe folder imports; delete the extras IN THE APP"
    warn "(deleting via the API leaves a phantom card in the UI until relaunch),"
    warn "keeping the one that reports designSystem=$DS_ID. Then re-run."
    return 3
  fi

  if [ "$n" -eq 1 ]; then
    IFS='|' read -r id nm ds pf ifrom trusted <<<"$hits"
    say "  exists:  id=$id  name=$nm  designSystem=$ds  platform=$pf"
    # Converge the display name first (no-op when it already matches), so a
    # pre-rename row or a GUI fallback import (named after the folder) ends up
    # as '$PROJECT_NAME' without losing its id or run history.
    ensure_name "$id" "$nm"
    if [ "$ds" = "$DS_ID" ] && [ "$pf" = "$PLATFORM" ]; then
      say "  already configured — nothing to do"
      return 0
    fi
    # Exists but half-configured (exactly the shape the observed duplicate-
    # import incident left behind) — finish it via the ungated PATCH path.
    SELECT_PROJECT="$id"
    select_flow
    return 0
  fi

  # No project yet -> create via the app's own bundled first-party CLI, which
  # mints the folder-import HMAC token itself over the daemon's IPC socket.
  # The HTTP gate is SATISFIED, not bypassed — this script never reads secrets
  # or hand-mints tokens; if the CLI route fails we print manual instructions.
  #
  # NOTE the trust-semantics shift, documented in design/README.md: the route
  # stamps fromTrustedPicker:true for ANY valid token regardless of origin.
  # With creation scripted, that flag attests "a valid HMAC was presented",
  # NOT "a human chose this folder in the native picker". Owner-accepted.
  before="$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)"
  say "  creating via the bundled od CLI (Electron helper as interpreter)"
  # --name sets the display name at creation (the route trims it and only
  # falls back to basename(baseDir) when absent; import-export-routes.ts:
  # 380-384) — one fewer mutation than create-then-rename, and the seeded
  # conversation title reads "Imported from $PROJECT_NAME". --design-system
  # is deliberately NOT folded in: the import route 400s outright on a
  # missing/draft package (validateProjectDesignSystemId), which would turn
  # today's recoverable created-but-half-configured state into no project at
  # all; the platform PATCH has no import flag and must run anyway, so the
  # chained select_flow stays the one configuration path for every shape
  # (fresh create, half-configured repair, standalone --select-project).
  rc=0
  out="$(od_cli project import-folder "$MOCKUPS_DIR" --name "$PROJECT_NAME" --daemon-url "$BASE" --json 2>&1)" || rc=$?
  if [ "$rc" -ne 0 ]; then
    warn "bundled-CLI import failed (rc=$rc): $(first_line "$out")"
    manual_creation_instructions >&2
    return 2
  fi
  say "  CLI call succeeded (not evidence — verifying by effect next)"

  # ── verify by effect: three independent checks, none trusting the CLI ──────
  # 1. the daemon's own project list shows exactly one folder-backed project
  #    whose baseDir realpath-resolves to design/xtty-mockups (the matcher's test);
  # 2. its shape is the trusted folder import (importedFrom + fromTrustedPicker);
  # 3. the import wrote zero bytes into the repo (git status unchanged).
  hits="$(od_get /api/projects | projects_at "$MOCKUPS_DIR")" || true
  n=0; [ -n "$hits" ] && n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
  if [ "$n" -ne 1 ]; then
    warn "post-create re-read finds $n projects at design/xtty-mockups (expected exactly 1)"
    manual_creation_instructions >&2
    return 2
  fi
  IFS='|' read -r id nm ds pf ifrom trusted <<<"$hits"
  if [ "$ifrom" != folder ] || [ "$trusted" != True ]; then
    warn "created project has importedFrom=$ifrom fromTrustedPicker=$trusted (expected folder/True) — wrong project shape; delete it in the app and use the GUI import"
    manual_creation_instructions >&2
    return 2
  fi
  if [ "$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)" != "$before" ]; then
    warn "IMPORT WROTE INTO THE REPO: git status design/ changed across the import — inspect immediately (git status design/ && git diff design/)"
    return 2
  fi
  say "  verified: id=$id  baseDir -> $MOCKUPS_DIR  importedFrom=folder  fromTrustedPicker=true"
  say "  verified: zero bytes written into design/ (git status unchanged)"
  # Belt-and-braces: the re-read above carries the name — if a future CLI
  # build silently dropped --name, converge it here instead of trusting it.
  ensure_name "$id" "$nm"

  # Chain design system + platform in the same command, via the existing
  # ungated PATCH path (each step verified by re-read inside select_flow).
  SELECT_PROJECT="$id"
  select_flow
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
  step "Tearing down what install set up ($DS_ID + the '$PROJECT_NAME' project at design/xtty-mockups)"
  # The whole teardown is bracketed by a git-status byte-compare: nothing in
  # this branch may touch the repo. (The app's project delete removes only its
  # OWN dir — removeProjectDir resolves <data>/projects/<id>, never
  # metadata.baseDir; projects.ts:1339-1342 — but that is proven by the
  # compare below, not assumed.)
  GIT_BEFORE="$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)"
  DID=0        # 1 => something was actually removed
  RC=0         # sticky worst outcome: 0 ok | 2 daemon down/unverified | 3 human needed
  PHANTOM=0    # 1 => a daemon-side delete happened; the UI card outlives it
  bump() { [ "$1" -gt "$RC" ] && RC="$1"; return 0; }

  # Guard every realpath comparison the same way install does (the daemon's
  # own primitive class), computed once.
  ROOT_REAL="$("$py" -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$ROOT")"
  MOCK_REAL="$("$py" -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$MOCKUPS_DIR")"

  # ── 1. the design/xtty-mockups project (reverse of create_flow) ────────────────
  # Deletion is UNCONDITIONAL, with --keep-project as the escape hatch — not
  # opt-in — because `make design-unlink` means "undo `make design-link`", and
  # install now CREATES the project: a teardown that leaves it behind quietly
  # re-inverts the symmetry this mode exists for. What deletion costs is
  # app-side only — every mockup lives in design/xtty-mockups/ in the repo, which
  # the delete provably never touches — so the one honest reason to keep the
  # row is its app-side run/chat history, and that is exactly what
  # --keep-project preserves.
  #
  # Mechanism: the ungated HTTP DELETE /api/projects/:id, not the bundled od
  # CLI. The CLI's own `project delete` is a bare unauthenticated fetch of the
  # very same route (cli.ts:6220-6230); the Electron-helper + IPC-socket
  # ceremony exists only to mint the *import* token, which deletion does not
  # need — same mechanism, fewer moving parts. This is the PROJECT delete
  # route (row + <data>/projects/<id> only); the DESIGN-SYSTEM delete route
  # stays banned below, unchanged.
  if [ "$KEEP_PROJECT" = 1 ]; then
    say "  project: kept (--keep-project)"
  elif [ -n "$BASE" ]; then
    hits="$(od_get /api/projects | projects_at "$MOCKUPS_DIR")" || die "GET /api/projects failed"
    n=0; [ -n "$hits" ] && n="$(printf '%s\n' "$hits" | wc -l | tr -d ' ')"
    if [ "$n" -eq 0 ]; then
      say "  project: none at $MOCKUPS_DIR — nothing to delete"
    elif [ "$n" -gt 1 ]; then
      # The known no-dedupe hazard: independent projects at the same baseDir,
      # each with its own runs. Guessing which to delete is exactly what this
      # script refuses to do — a human decides.
      warn "$n projects point at design/xtty-mockups — refusing to guess which to delete:"
      printf '%s\n' "$hits" | while IFS='|' read -r pid pnm pds _rest; do
        warn "    id=$pid  name=$pnm  designSystem=$pds"
      done
      warn "Delete the extras in the app (or curl -X DELETE $BASE/api/projects/<id>), then re-run."
      bump 3
    else
      IFS='|' read -r pid pnm pds _rest <<<"$hits"
      # Belt-and-braces on top of the baseDir matcher: refuse to delete
      # anything that resolves outside this repo (design/xtty-mockups itself could
      # be a symlink pointing elsewhere).
      case "$MOCK_REAL/" in
        "$ROOT_REAL"/*) : ;;
        *) die "refusing: $MOCKUPS_DIR resolves outside the repo ($MOCK_REAL)" 3 ;;
      esac
      say "  project: deleting id=$pid  name=$pnm  designSystem=$pds"
      code="$(od_json DELETE "/api/projects/$pid" '' "$TMPD/del-resp")"
      [ "$code" = 200 ] || die "DELETE /api/projects/$pid failed ($code): $(api_err <"$TMPD/del-resp")"
      # Verify by effect: the daemon's own list, never the DELETE echo.
      left="$(od_get /api/projects | projects_at "$MOCKUPS_DIR")" || true
      [ -z "$left" ] || die "a project still points at $MOCKUPS_DIR after the delete: $(first_line "$left")"
      say "  project: deleted (re-read confirms nothing points at design/xtty-mockups)"
      DID=1; PHANTOM=1
      # Honest residue: the app's own delete leaves finished run dirs behind
      # too (runs are keyed by run id at <data>/runs/, not under the project).
      orphans="$(grep -l "\"projectId\":\"$pid\"" "$DATA_DIR"/runs/*/state.json 2>/dev/null | wc -l | tr -d ' ' || true)"
      [ "${orphans:-0}" -gt 0 ] && say "  note:    $orphans run-history dir(s) under $DATA_DIR/runs/ still reference the deleted project — app-side only; remove by hand if you want them gone"
    fi
  else
    warn "daemon not running: the project row at design/xtty-mockups (if any) cannot be found or deleted from the filesystem — relaunch Open Design and re-run"
    bump 2
  fi

  # ── 2. the ds-<pkg> workspace copy (the frozen DESIGN.md) ─────────────────
  # This is BOTH a directory (<data>/projects/ds-<pkg>) and a project row the
  # app maintains for it (ensureUserDesignSystemWorkspaceProject,
  # server-services.ts:226-270). Not gated by --keep-project: it belongs to
  # the design-system registration, not to the design/xtty-mockups project. With the
  # daemon up, the same ungated project DELETE removes row+dir in one
  # app-sanctioned move (removeProjectDir is exactly rm -rf of the app-side
  # dir, and ds-<pkg> has no baseDir to confuse it with). Without the daemon,
  # fall back to removing the directory — already the documented remedy for
  # the DESIGN.md freeze — and report the row as unreachable.
  WS="$DATA_DIR/projects/ds-$PKG_NAME"
  ws_present=0; { [ -e "$WS" ] || [ -L "$WS" ]; } && ws_present=1
  ws_row=""
  if [ -n "$BASE" ]; then
    ws_row="$(od_get /api/projects | "$py" -c '
import json,sys
d=json.load(sys.stdin)
print(next((p.get("id") for p in d.get("projects") or [] if p.get("id")==sys.argv[1]), ""))' "ds-$PKG_NAME")" \
      || die "GET /api/projects failed while checking for the ds-$PKG_NAME row"
  fi
  if [ "$ws_present" = 0 ] && [ -z "$ws_row" ]; then
    say "  workspace: none (no dir at $WS, no ds-$PKG_NAME row)"
  else
    [ -L "$WS" ] && die "refusing: $WS is a symlink, not the app's workspace directory — inspect it yourself" 3
    if [ -n "$BASE" ]; then
      code="$(od_json DELETE "/api/projects/ds-$PKG_NAME" '' "$TMPD/ws-resp")"
      [ "$code" = 200 ] || die "DELETE /api/projects/ds-$PKG_NAME failed ($code): $(api_err <"$TMPD/ws-resp")"
      PHANTOM=1
    fi
    if [ -e "$WS" ]; then
      # Daemon down (or its delete left the dir): guarded rm -rf. The guard is
      # paranoid on purpose — this is the branch's only recursive remove.
      [ -n "$DATA_DIR" ] && [ -d "$DATA_DIR/projects" ] || die "refusing rm -rf: no projects dir under $DATA_DIR" 3
      [ "$(basename "$WS")" = "ds-$PKG_NAME" ] || die "internal: workspace basename mismatch" 3
      WS_REAL="$("$py" -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$WS")"
      DD_REAL="$("$py" -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$DATA_DIR")"
      case "$WS_REAL/" in
        "$ROOT_REAL"/*) die "refusing rm -rf: $WS resolves INTO the repo ($WS_REAL) — is OD_DATA_DIR wrong?" 3 ;;
      esac
      case "$WS_REAL/" in
        "$DD_REAL/projects/"*) : ;;
        *) die "refusing rm -rf: $WS resolves outside $DATA_DIR/projects ($WS_REAL)" 3 ;;
      esac
      rm -rf "$WS"
    fi
    # Verify by effect on both halves.
    if [ -e "$WS" ] || [ -L "$WS" ]; then die "workspace dir still present after removal: $WS"; fi
    if [ -n "$BASE" ]; then
      ws_row="$(od_get /api/projects | "$py" -c '
import json,sys
d=json.load(sys.stdin)
print(next((p.get("id") for p in d.get("projects") or [] if p.get("id")==sys.argv[1]), ""))' "ds-$PKG_NAME")" \
        || die "GET /api/projects failed while re-checking the ds-$PKG_NAME row"
      [ -z "$ws_row" ] || die "the daemon still lists project ds-$PKG_NAME after the delete"
      say "  workspace: removed (dir gone; re-read confirms no ds-$PKG_NAME row)"
    else
      say "  workspace: dir removed; the ds-$PKG_NAME row (if any) needs the daemon"
      bump 2
    fi
    DID=1
  fi

  # ── 3. the design-system symlink ──────────────────────────────────────────
  st="$(link_state)"
  case "$st" in
    A) say "  link:    nothing to do (no link at $LINK)" ;;
    B|C)
      # BY HAND, on purpose. The app's own DELETE for a `user:` id bypasses the
      # safe lstat+unlink sibling (static-resource.ts:827-829) and runs
      # rm(path,{recursive:true,force:false}) (index.ts:1451-1460) — whether
      # that unlinks or recurses into the repo working tree is UNVERIFIED, and
      # the downside if wrong is the git tree. unlink(2) can only remove a link.
      # (The PROJECT deletes above are a different route with a verified-safe
      # target resolution; this ban is specifically the design-system route.)
      [ -L "$LINK" ] || die "refusing: $LINK is not a symlink" 3
      rm "$LINK"
      say "  link:    unlinked $LINK  (repo untouched — unlink(2) on the symlink only)"
      DID=1
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
    bump 2
  fi

  # ── verify by effect, then report ─────────────────────────────────────────
  [ -d "$PKG_REAL" ] || die "the committed package dir vanished during teardown: $PKG_REAL"
  GIT_AFTER="$(git -C "$ROOT" status --porcelain design/ 2>/dev/null || true)"
  if [ "$GIT_AFTER" != "$GIT_BEFORE" ]; then
    die "TEARDOWN TOUCHED THE REPO: git status design/ changed — inspect immediately (git status design/ && git diff design/)"
  fi
  say "  verified: git status design/ byte-identical across the teardown"

  if [ "$PHANTOM" = 1 ]; then
    say ""
    say "  /!\\ The app's open UI may still show a card for what was just deleted:"
    say "      an API/CLI delete leaves a phantom card that the in-app Refresh"
    say "      does NOT clear — quit and relaunch Open Design to see truth."
  fi
  if [ "$RC" = 2 ]; then
    say ""
    say "Filesystem teardown done; the daemon half could not run (app not running):"
    [ "$KEEP_PROJECT" = 1 ] || say "  - the project row at design/xtty-mockups (if any) was not deleted"
    say "  - catalog/project-list re-reads were skipped — relaunch Open Design and re-run to finish + verify"
  elif [ "$RC" = 0 ] && [ "$DID" = 0 ]; then
    say ""; say "Already clean — nothing to do."
  fi
  exit "$RC"
  ;;

select)
  # OPT-IN standalone entry; the shared flow is also chained from create_flow.
  select_flow
  exit 0
  ;;

create)
  # Standalone entry for the same flow `install` auto-runs. Exit code says
  # what happened: 0 created-or-already-exists (idempotent no-op), 2 fell
  # back to the printed manual GUI instructions, 3 duplicates need a human.
  rc=0; create_flow || rc=$?
  exit "$rc"
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
    tmp="$TMPD/install-resp"
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

  # Project creation + configuration, auto-run (rationale at create_flow).
  # POST /api/import/folder IS HMAC-gated (measured: 403 "token missing"
  # without a token; import-export-routes.ts:287-323) — the pre-CLI era read
  # that gate as "expected to require the GUI". The app's own bundled CLI
  # mints the token internally, so the gate is satisfied, never bypassed.
  # Soft-fail in a subshell: a creation failure prints the manual GUI
  # instructions and must not un-succeed the linkage above.
  CREATE_RC=0
  ( create_flow ) || CREATE_RC=$?

  if [ "$CREATE_RC" -eq 0 ]; then
    cat <<EOF

──────────────────────────────────────────────────────────────────────────────
Linked, published, and the '$PROJECT_NAME' project (design/xtty-mockups) is created
and configured.

 ONE CHECK REMAINS, AND IT IS BY EFFECT: change one value in
 design/xtty-design-system/tokens.css, generate a mockup, grep the produced HTML for
 the new value. Nothing above proves a single token reached a prompt; that does.

 Before that first run: clean, pushed working tree. After: repo-wide
 'git status' + 'git diff'; check design/xtty-design-system/.od-generated.json does not
 exist; stage by explicit path only. The agent runs with
 --permission-mode bypassPermissions and folder scope is not enforced.
──────────────────────────────────────────────────────────────────────────────
EOF
  else
    cat <<EOF

──────────────────────────────────────────────────────────────────────────────
Linked and published — but the '$PROJECT_NAME' project (design/xtty-mockups) is NOT
fully set up (details
and the manual fallback are printed above; exit code $CREATE_RC).

 After finishing it by hand, verify the channel BY EFFECT: change one value
 in design/xtty-design-system/tokens.css, generate a mockup, grep the produced
 HTML for the new value.
──────────────────────────────────────────────────────────────────────────────
EOF
  fi
  ;;
esac
