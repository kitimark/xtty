# UPSTREAM_CONFIG.sh — the pinned SwiftTerm upstream for the xtty patch
# (the P4b-2 accessors add + the retire-metal-renderer Metal-shader-resource strip +
# the fix-scroll-reversal-redraw-corruption Terminal.swift correctness fix).
#
# The single source of truth for *which* SwiftTerm we patch. scripts/bootstrap-swiftterm.sh
# sources this, clones UPSTREAM_URL into the gitignored external/SwiftTerm, checks out
# UPSTREAM_REF (enforced every run so the pin can't drift), and applies
# patches/swiftterm/xtty-accessors.diff via git apply (the patch also modifies
# Package.swift, so the pristine-restore step resets tracked files every run).
#
# Note: despite the file's "accessors" name, the patch is no longer purely additive.
# The fix-scroll-reversal-redraw-corruption hunk changes existing behavior inside
# Terminal.swift itself (cmdScrollDown gains the marginMode guard cmdScrollUp already
# had) — a departure from every earlier hunk here, which only ever added new code
# (accessors, a Metal-shader exclusion) without altering existing VT-engine logic.
# Replaces the old submodule gitlink as the pin (Playwright's UPSTREAM_CONFIG model).
# Retire the whole mechanism once the accessors land in an upstream SwiftTerm release.
UPSTREAM_URL="https://github.com/migueldeicaza/SwiftTerm.git"
UPSTREAM_REF="v1.13.0"
