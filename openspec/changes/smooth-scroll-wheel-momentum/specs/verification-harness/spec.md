## ADDED Requirements

### Requirement: Mouse-wheel momentum routing coverage via synthetic injection

Because a real inertial-coast (momentum) wheel event cannot be produced through the XCUITest automation channel (synthesized gestures carry no momentum) and a raw event cannot be posted in the test runner, the harness SHALL cover the **momentum routing logic** through a DEBUG-only **synthetic-wheel-event injection** trigger: the test supplies a wheel-event spec (momentum phase, precise-vs-discrete, vertical delta, modifiers) and the app constructs a faithful wheel event carrying that momentum phase and precise-delta state, then drives it through the **real** wheel-routing path on the focused pane (never a reimplementation of the branch logic) — after which the routed action is asserted from the DEBUG state dump. This exercises the exact fields the router reads (momentum phase, precise-scrolling state, vertical scrolling delta) without depending on the OS delivering a physical coast. The trigger MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument. The real-OS coast **delivery, rate, and consume-side responsiveness** are explicitly **out of scope** for this automated coverage — they remain a manual physical-trackpad verify. Coverage SHALL include: an injected momentum frame **is not dropped** (it routes on the same branch as a finger-driven frame, recorded as a momentum event); a fast precise sequence **does not lose distance** (the emitted whole-cell count tracks the accumulated travel rather than being clamped to a fixed per-event cap); and the accumulated sub-cell remainder **resets between gestures** (a fresh gesture does not inherit a stale fraction).

#### Scenario: An injected momentum frame is routed, not dropped

- **WHEN** the tests inject a synthetic wheel event carrying an inertial-coast (momentum) phase over a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last-wheel-routing action records the event on its branch (program wheel-report / program cursor-key / local scrollback per the pane's state) with the momentum flag set — it is not silently dropped

#### Scenario: An injected fast precise gesture does not lose scroll distance

- **WHEN** the tests inject precise (trackpad) wheel input whose accumulated travel exceeds several whole cells
- **THEN** the routed emission count tracks the whole cells traversed (carrying the sub-cell remainder forward), rather than being clamped to a fixed per-event cap that discards the overflow

#### Scenario: The accumulated remainder resets between gestures

- **WHEN** the tests inject one precise gesture that leaves a sub-cell remainder, then begin a new user-driven gesture
- **THEN** the new gesture does not emit a phantom extra cell carried over from the previous gesture's leftover remainder

## MODIFIED Requirements

### Requirement: Mouse-wheel routing is observable

The DEBUG state dump SHALL expose, for the focused pane, the **last mouse-wheel routing action** — the **branch** taken (a wheel mouse-report to the program, a cursor-key send to the program, or a local-scrollback move) together with the routed detail: for the report branch, the emitted **wheel button** (up/down) and the number of reports, and for the cursor-key branch, the emitted **key form** (application-cursor vs normal) and direction and count; a local-scrollback move is recorded as such. The dump SHALL additionally record, for the routed event, whether it was an **inertial-coast (momentum) frame** (versus a finger-driven frame) and whether it carried **precise (trackpad) deltas** (versus discrete wheel notches), so the momentum-honoring behavior is observable to both the synthetic-injection coverage and a physical-trackpad verify. This lets a test assert which branch a wheel gesture took and what was sent to the program, on xtty's custom-drawn view that exposes no per-cell content or input stream to accessibility. Like every other dump field, it MUST be gated by `#if DEBUG` and the `-UITestGridDump` launch argument, and the dump path SHALL only **observe** the last routing action, never synthesize or replay a gesture.

#### Scenario: The focused pane's last wheel-routing action is reported

- **WHEN** a wheel gesture has been routed in a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump reports the branch taken (program wheel-report / program cursor-key / local scrollback) and, for a program-directed branch, the emitted button-or-key form, direction, and count — so a test can assert the routing without a real mouse-tracking program parsing the bytes

#### Scenario: The routed event's momentum and precise nature is reported

- **WHEN** a wheel gesture has been routed in a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump additionally reports whether the routed event was an inertial-coast (momentum) frame and whether it carried precise (trackpad) deltas — so the momentum-honoring behavior is assertable by the synthetic-injection coverage and observable on a physical-trackpad verify

### Requirement: Mouse-wheel routing end-to-end coverage

The harness SHALL cover mouse-wheel routing end-to-end by driving a real wheel gesture over a focused pane in each routing state and asserting, via the DEBUG state dump's last-wheel-routing action, that the correct branch was taken. Coverage SHALL include: an **alternate-screen program with button-event mouse reporting active** (a wheel notch is reported to the program as a wheel button, not swallowed); an **alternate-screen program without mouse reporting** (a wheel notch is delivered as a cursor Up/Down key); a **primary-screen pane with no mouse reporting** (the wheel moves local scrollback); and the **Shift-bypass** (Shift+wheel over a mouse-reporting program moves local scrollback instead of reporting). A real mouse-tracking program's own scroll state SHALL NOT be required for the assertions — the routed action is asserted from the state dump. Because the **real wheel gestures** the harness drives through the automation channel carry **no inertial-coast (momentum) frames**, the harness SHALL assert that such a gesture is recorded as a **non-momentum** routed event (a crisp negative proving the momentum field is wired on the real-gesture path); the **momentum routing logic** is covered separately by the synthetic-injection requirement, and only the real-OS coast **delivery, rate, and consume-side responsiveness** remain a manual physical-trackpad verify (out of automated harness scope).

#### Scenario: Wheel over a mouse-tracking alt-screen pane reports to the program

- **WHEN** the tests focus a pane whose program has button-event mouse reporting active on the alternate screen and scroll the wheel down over it
- **THEN** the state dump's last-wheel-routing action is a program wheel-report with the down button, rather than a local-scrollback move

#### Scenario: Wheel over an alt-screen pane without mouse reporting sends cursor keys

- **WHEN** the tests focus a pane on the alternate screen with no mouse reporting active and scroll the wheel
- **THEN** the state dump's last-wheel-routing action is a program cursor-key send (Up on scroll-up, Down on scroll-down), in the DECCKM-appropriate form

#### Scenario: Shift+wheel over a mouse-tracking pane moves local scrollback

- **WHEN** the tests scroll the wheel while holding Shift over a focused pane whose program has mouse reporting active
- **THEN** the state dump's last-wheel-routing action is a local-scrollback move, not a program wheel-report

#### Scenario: A real synthetic gesture is recorded as a non-momentum event

- **WHEN** the tests drive a real wheel gesture through the automation channel over a focused pane in a `-UITestGridDump` DEBUG build
- **THEN** the state dump's last-wheel-routing action records the event as a non-momentum (finger-driven) frame, since automation-channel gestures carry no inertial coast — proving the momentum field is wired on the real-gesture path (the momentum-true path is covered by synthetic injection)
