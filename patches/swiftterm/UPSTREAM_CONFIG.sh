# UPSTREAM_CONFIG.sh — the pinned SwiftTerm upstream for the P4b-2 accessors.
#
# The single source of truth for *which* SwiftTerm we patch. scripts/bootstrap-swiftterm.sh
# sources this, clones UPSTREAM_URL into the gitignored external/SwiftTerm, checks out
# UPSTREAM_REF (enforced every run so the pin can't drift), and drops in XttyAccessors.swift.
# Replaces the old submodule gitlink as the pin (Playwright's UPSTREAM_CONFIG model).
# Retire the whole mechanism once the accessors land in an upstream SwiftTerm release.
UPSTREAM_URL="https://github.com/migueldeicaza/SwiftTerm.git"
UPSTREAM_REF="v1.13.0"
