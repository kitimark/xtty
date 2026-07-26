## ADDED Requirements

### Requirement: Bounded large-diff preview

For each selected file's read-only unified diff, the application SHALL bound xtty-side retained and materialized preview input by fixed limits independent of the total Git output. The limits SHALL cover both a large number of lines and a single physical line without a newline. When a limit is exceeded, the application SHALL stop the preview operation, terminate and reap its Git process without waiting on unread pipe output, mark the resulting file diff as truncated, and offer the existing open-in-editor action. A diff that completes within the limits SHALL retain its complete existing preview behavior. Git-review refresh and per-file preview generation SHALL NOT execute repository-configured text converters; binary content SHALL retain the binary-summary behavior. A changed submodule's per-file preview SHALL show only its own one-line commit-range summary regardless of the user's `diff.submodule` configuration, and SHALL NOT recurse into the submodule's own nested content diff or execute a text converter configured inside it.

#### Scenario: Ordinary diff remains complete

- **WHEN** the selected file's Git diff completes within every preview limit
- **THEN** the panel renders the complete parsed diff, does not mark it truncated, and preserves its existing read-only behavior

#### Scenario: Many-line diff reaches a bounded preview

- **WHEN** a selected file produces more diff records or retained bytes than the fixed preview limits permit
- **THEN** xtty's retained and materialized preview input stays bounded independently of the remaining Git output, the selected diff is marked truncated, and the panel offers open-in-editor

#### Scenario: A single overlong line cannot bypass the bound

- **WHEN** a selected file's diff contains a physical line longer than the fixed line-byte limit without an intervening newline
- **THEN** xtty stops without draining the rest of that line, keeps preview input bounded, marks the selected diff truncated, and offers open-in-editor

#### Scenario: Cutoff completes without a blocked or lingering Git process

- **WHEN** xtty reaches any per-file preview limit while Git still has more output
- **THEN** the preview resolves promptly without a pipe deadlock and the corresponding Git preview process is terminated and reaped before the truncated result is published

#### Scenario: Truncation before a displayable hunk is not reported as an empty diff

- **WHEN** a producer cutoff yields no complete displayable hunk
- **THEN** the panel reports that the diff is too large and offers open-in-editor instead of reporting “No textual changes”

#### Scenario: Configured text conversion is not executed

- **WHEN** a changed binary file has a repository-configured textconv driver
- **THEN** neither Git-review refresh nor its selected-file preview executes that driver, and the panel presents the file using binary badges and summary behavior

#### Scenario: A changed submodule's preview does not recurse into its own diff

- **WHEN** a changed submodule is selected and the user's Git configuration sets `diff.submodule` to recurse into nested content
- **THEN** the preview shows only the safe one-line commit-range summary, does not execute a text converter configured inside the submodule, and does not treat the submodule's own changed files as this preview's content
