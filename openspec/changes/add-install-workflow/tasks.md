## 1. Makefile: install + version stamping

- [ ] 1.1 Add version-source variables to the `Makefile`: `VERSION` = latest tag minus `v` via `git describe --tags --abbrev=0` with a `project.yml`-`MARKETING_VERSION` fallback (`0.0.1`) when no tag/git; `BUILD` = `git rev-list --count HEAD` with a `1` fallback. Both must degrade cleanly in a tagless/no-git tree (D5).
- [ ] 1.2 Add `INSTALL_DIR ?= /Applications`, `RELEASE_CONFIG := Release`, and `RELEASE_APP := $(DERIVED)/Build/Products/Release/xtty.app`.
- [ ] 1.3 Add the `install` target: build `-configuration Release` with `$(SIGN_FLAGS)` + `MARKETING_VERSION="$(VERSION)" CURRENT_PROJECT_VERSION="$(BUILD)"` overrides (D1/D4), then back up any existing `$(INSTALL_DIR)/xtty.app` → `xtty.app.bak` and `ditto` the built app into `$(INSTALL_DIR)` (D2). Order-only-prereq on the SwiftTerm/project file-targets so it auto-reconstitutes/generates. Add a `## ` help description. No `codesign`/DMG/notarization (D3).
- [ ] 1.4 Add the `restart` target: terminate any running instance and `open $(INSTALL_DIR)/xtty.app` (D-restart), with a `## ` help description. Add both `install` and `restart` to `.PHONY`.
- [ ] 1.5 Confirm `make build`/`make run`/`make test`/`make bench` are unchanged (still Debug; no new `-configuration`).

## 2. Version anchor

- [ ] 2.1 Cut the annotated tag `v0.0.1` on the current `main` HEAD so `git describe` resolves (D5). *(Push of the tag is a separate owner action, per push-to-main policy.)*

## 3. Documentation

- [ ] 3.1 Update AGENTS.md → Building: add `make install` and `make restart` rows to the targets table and a short "install a stable build" note (Release → `/Applications`, `INSTALL_DIR` override, `XTTY_SIGN_IDENTITY=xtty-dev` for TCC-grant persistence, $0/no-notarization). Keep it bounded.

## 4. Verify (build-output checks — cheap/inline, no suite delegation per D7)

- [ ] 4.1 Run `make install` (default ad-hoc) and confirm: the built product is the **Release** config (`SWIFT_OPTIMIZATION_LEVEL=-O` in the config, not a Debug artifact); `/Applications/xtty.app` exists as a copy; `codesign -dvv` shows `Signature=adhoc`, `Identifier=com.xtty.app`.
- [ ] 4.2 Confirm the version stamp reached the synthesized plist: `PlistBuddy -c 'Print :CFBundleShortVersionString'` = `0.1.0`-style numeric from the tag (or the `project.yml` floor), and `CFBundleVersion` = the monotonic build number (D4/D5).
- [ ] 4.3 Confirm the `$0` launch: `xattr -l /Applications/xtty.app | grep quarantine` is empty, and the installed app launches (open it, or `make restart`) with no Gatekeeper prompt.
- [ ] 4.4 Confirm survival + override: `INSTALL_DIR=~/Applications make install` installs there; and after a `make clean` the previously installed `/Applications/xtty.app` still launches (it's a copy). Confirm the `.bak` backup appears on a second `make install`.
- [ ] 4.5 Run `make test-core` to confirm the fast core suite is still green (no regression from the Makefile change).

## 5. Coherence + archive (standard change tail)

- [ ] 5.1 Pre-archive coherence review ⟶ xtty-openspec-critic (add-install-workflow)
- [ ] 5.2 Archive + reconcile ⟶ archive-ritual — `openspec archive add-install-workflow`, finish the merge by hand (fill Purpose if any new spec, correct merged text to what shipped), then reconcile trackers (AGENTS.md Current-status row + snapshot, HISTORY.md narrative, `research/04-design/02-milestones.md`, Learned refutations if any) and verify against disk (`openspec list` · `ls openspec/changes/archive/` · `ls openspec/specs/`). Pre-tick self-check per AGENTS.md.
