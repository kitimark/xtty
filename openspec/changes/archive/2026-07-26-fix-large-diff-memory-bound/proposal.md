## Why

Selecting a very large file in Git review currently buffers and copies the complete `git diff` output before the existing 5,000-line parser cap runs, so peak xtty memory grows with the total diff rather than with the preview it can display. This violates the product's lean-memory requirement and can make the panel slow or terminate the app on adversarially large diffs.

## What Changes

- Bound per-file Git-diff ingestion before the complete child output is materialized, including both many-line diffs and a single extremely long line.
- Stop and reap Git when the bounded preview is full, without pipe deadlock or a lingering child process; ordinary small diffs continue to complete normally.
- Carry producer-side cutoff into the diff model so the panel reports truncation and retains the existing open-in-editor escape hatch, including when the bounded prefix contains no displayable hunk.
- Keep binary files on Git's binary-summary path without executing configured text converters that could expand them into unbounded text.
- Keep a changed submodule's preview to its own one-line commit-range summary regardless of the user's `diff.submodule` configuration, so it cannot recurse into the submodule's own nested content diff or execute a text converter configured inside it (found and closed in cross-review).
- Add view-free boundary tests plus by-effect Git-review coverage for bounded retention, truncation, responsiveness, and process cleanup.

## Capabilities

### New Capabilities

<!-- none -->

### Modified Capabilities

- `git-review`: requires large per-file diff previews to use bounded memory independent of total Git output, terminate cleanly at the preview boundary, and expose truncation with an open-in-editor fallback while preserving complete behavior for ordinary diffs.
- `verification-harness`: exposes bounded preview state plus exact Git-process cutoff/reap/absence metadata and covers both many-line and single-overlong-line fixtures through the real panel path.

## Impact

- **App Git execution:** the per-file diff routes in `App/GitRunner.swift` gain bounded stdout consumption and cutoff-aware process lifecycle handling; status and numstat queries remain on their existing complete-output path.
- **XttyCore model/parsing:** producer-side truncation is propagated through the toolkit-independent diff model and combined with parser-side truncation.
- **Git behavior:** per-file diffs and snapshot numstat explicitly suppress text conversion and submodule-diff recursion so repository refresh/preview cannot execute a configured converter (directly, or via a recursed submodule diff) and binary classification remains consistent with the panel's existing binary-summary behavior.
- **Git-review UI and harness:** the existing truncated/open-in-editor state is made reliable for every cutoff shape and covered through deterministic state plus by-effect tests.
- **DEBUG observation:** the state dump adds bounded metadata for the exact preview Git PID, selected path, cutoff reason, reap completion, and post-reap absence; it never emits diff text.
- No configuration key, repository write operation, external dependency, or public API is added.
