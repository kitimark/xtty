## 1. Source the local-host name set without a network lookup

- [ ] 1.1 Add a view-free pure helper to `XttyCore` — `LocalHost.names(from rawHostName: String) -> Set<String>` — reproducing today's derivation (`{"", "localhost", name.lowercased(), the short form up to the first "."}`) from a **given** host-name string, with no syscall or network I/O of its own (design D2).
- [ ] 1.2 Rewire `PaneController.localHostNames` (`App/PaneController.swift:92`) to read the host name once via `gethostname(2)` and pass it to `LocalHost.names(from:)`, **removing** the `ProcessInfo.processInfo.hostName` reverse-DNS call (`:94`, design D1). Leave the sole consumer (`:265` → `OSC7.decode(_:localHostNames:)`) unchanged.
- [ ] 1.3 (verify, inline) `make test-core` — a new `LocalHost.names(from:)` unit test passes (covers the "Local-name derivation runs without the app" scenario), and the 20 existing `OSC7Tests` are unchanged (they inject their own set and cannot see the swap).

## 2. Verify the reverse-DNS trigger is gone (by-effect)

- [ ] 2.1 (verify — by-effect, VM graphics tier) On a **fresh** `xtty-test-zsh:26.5` clone (G3 — the LN arbiter remembers per-bundle-id, so a clean clone rules out a stale NE-store record) running the **fixed** xtty build in a **graphics** session (WindowServer live, so the modal *would* appear if the trigger survived), capture the forensics **P1** `log stream` and confirm **P2** reads **0 / 0 / 0** — no reverse-DNS PTR volley (`client pid … (xtty)`), no `policy 'pending'`, no "find devices on local networks?" modal — **and** that no `com.xtty.app` record is created in the NE store (P5 — the query never happens) **and** that the first prompt does **not** freeze the UI (design D3; recipe `research/03-analysis/local-network-privacy-forensics.md` §8g). This is the **red→green complement** to `add-zsh-test-image` task 4.1 (same graphics zsh rig, the *unfixed* build → 40 `pending` + modal). Keep the `log stream` + NE-store dump + a graphics screenshot as the review bundle. ⟶ xtty-test-validator (graphics VM, fresh zsh clone — LN-gate by-effect, expect 0/0/0; **not** a full-envelope run)

## 3. Confirm no regression (acceptance)

- [ ] 3.1 (verify — full sweep, product-code change) Run the acceptance sweep and confirm the documented envelope is unchanged: **local bare-metal `make test`** on the zsh dev host (where the swapped path actually executes — the file-link relative-resolve, git-review non-repo empty-state, and live-cwd tests must stay green) **plus** the VM rigs (≥2 headless + graphics; the bash rig's `40/1/1` is untouched by construction since bash emits no OSC 7). ⟶ xtty-test-validator (full sweep — local bare-metal + bash `xtty-test:26.5`, product-code change)

## 4. Reverse duty + on completion

- [ ] 4.1 Update `research/03-analysis/local-network-privacy-forensics.md` (§6 residual + §8) and its `research/README.md` line: flip the product `gethostname` fix from "proposed / owner-dropped" to **landed in `fix-osc7-hostname-reverse-dns`**, and record the §8g by-effect verification result from task 2.1 (append a dated note; do not rewrite the prior addenda).
- [ ] 4.2 (verify — coherence, pre-archive) Review the change for coherence against AGENTS.md's rulebook + disk state. ⟶ xtty-openspec-critic (fix-osc7-hostname-reverse-dns)
- [ ] 4.3 On completion, reconcile trackers per AGENTS.md "Keep progress current": add/refresh this change's Current-status row + snapshot in `AGENTS.md` (note it removes the shipping zsh LN trigger and **enables** `add-zsh-test-image` to drop its refuted rig-level LN machinery), append the dated narrative to `HISTORY.md`, add a one-liner to **Learned refutations** if warranted, and verify against disk (`openspec list`, `ls openspec/changes/archive/`, `ls openspec/specs/`).
