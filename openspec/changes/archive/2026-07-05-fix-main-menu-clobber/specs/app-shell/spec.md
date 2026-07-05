# app-shell — fix-main-menu-clobber delta

## ADDED Requirements

### Requirement: Durable custom main menu

The application SHALL install its own main menu — every xtty-defined top-level menu with its configured key equivalents — and that menu SHALL remain intact for the entire application lifetime, on any machine speed and under any launch/activation timing. No framework-synthesized default menu SHALL replace the installed menu or mutate its items: xtty MUST be the sole owner of the main menu. Menu-dependent behaviors (menu key equivalents, dynamic submenus such as the profile-tab menu, and DEBUG-only test menus) SHALL therefore be available from the first moment the menu is installed until quit.

#### Scenario: The custom menu is installed at launch

- **WHEN** the app launches
- **THEN** the main menu contains xtty's own top-level menus (including Edit, View, Terminal, and Window) with their configured key equivalents

#### Scenario: The menu survives on a slow machine

- **WHEN** the app runs where launch, scene, or activation work is arbitrarily delayed (e.g. a heavily loaded or few-core machine)
- **THEN** the installed menu's top-level items are unchanged for the whole app lifetime — no xtty menu disappears and no framework-synthesized menu (e.g. a default Help menu xtty does not define) appears

#### Scenario: Menu key equivalents dispatch reliably

- **WHEN** a menu key equivalent (e.g. the configured split, find, or new-tab chord) is pressed at any time after launch, including immediately after activation by an external driver
- **THEN** it dispatches to xtty's menu action, because the item it matches is guaranteed to exist
