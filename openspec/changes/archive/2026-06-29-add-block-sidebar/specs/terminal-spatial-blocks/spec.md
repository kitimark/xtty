## ADDED Requirements

### Requirement: Scroll to a designated block

xtty SHALL provide an operation to scroll the focused pane's viewport to a **specific designated command block** (chosen externally — e.g. selected from the session sidebar), as distinct from the viewport-relative previous/next jump. The operation SHALL reverse-map the designated block's prompt anchor to a current display row and scroll the viewport to it, moving the **viewport only** (never the cursor or a text selection). When the designated block has no valid anchor (none captured, invalidated, or trimmed out of scrollback), the operation SHALL clamp or be a graceful no-op, never scrolling to unrelated content. Like the relative jump, it SHALL function only when shell-integration anchors are present and SHALL degrade gracefully otherwise. The reverse-map and target resolution SHALL reuse the view-free spatial logic in `XttyCore`.

#### Scenario: Scroll to a designated earlier block
- **WHEN** a block earlier in the session is designated (e.g. selected in the sidebar) and it has a valid anchor
- **THEN** the focused pane's viewport scrolls so that block's prompt is visible, without moving the cursor or selecting text

#### Scenario: A designated block with no valid anchor does not scroll to wrong content
- **WHEN** the designated block's anchor has been invalidated or trimmed out
- **THEN** the operation clamps or no-ops with a non-destructive indication, and never scrolls to unrelated content

## MODIFIED Requirements

### Requirement: Copy command output
xtty SHALL provide an action to copy a command block's **output** to the system clipboard for either the default target (the focused/last completed block, or the running block's output so far) **or a designated block chosen externally (e.g. from the session sidebar)**. The copied range SHALL be the captured output region (from the output-start anchor to the output-end anchor) and SHALL exclude the trailing prompt that follows the command. The text SHALL be obtained via the engine's public text-extraction API (no on-screen visual selection is created — the operation is engine-only). On success xtty SHALL show a transient, non-modal confirmation (e.g. a brief flash/toast) indicating output was copied; when the target block has no valid anchor, the action SHALL no-op with a non-destructive indication rather than copy wrong or empty content silently.

#### Scenario: Copy the last command's output
- **WHEN** the user triggers copy-command-output after a command completed
- **THEN** that command's output text (excluding the following prompt) is placed on the clipboard and a transient confirmation is shown

#### Scenario: Copy a designated block's output
- **WHEN** the user copies the output of a specific block designated externally (e.g. via the sidebar's per-block menu) and that block has a valid anchor
- **THEN** that block's output text (excluding the following prompt) is placed on the clipboard

#### Scenario: Copy excludes the trailing prompt
- **WHEN** the copied block is followed by a new shell prompt
- **THEN** the clipboard contains only the command's output region, not the subsequent prompt text

#### Scenario: Copy with no valid anchor does not copy wrong content
- **WHEN** the target block's anchor has been invalidated or trimmed out
- **THEN** the action no-ops with a non-destructive indication and does not place mismatched or empty text on the clipboard
