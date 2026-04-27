This project is based on [ArtemYurov/TomoBar](https://github.com/ArtemYurov/TomoBar).

# ShuchuBar

ShuchuBar is a native macOS menu bar focus timer with a session-first flow.

## What Changed From The Original

- Simplified to a minimal focus -> break model.
- Session-based start form (theme, focus minutes, break minutes, project label).
- Lightweight local persistence for labels and recorded focus sessions.
- Built-in stats and session list/editing directly in the popover.
- Passive native notifications and simplified controls/settings.

## Design Direction

ShuchuBar intentionally removes preset-heavy and multi-mode behavior in favor of a compact, low-friction menu bar workflow.

## Build & Run (Local)

1. Open `ShuchuBar.xcodeproj` in Xcode.
2. Select the `ShuchuBar` target/scheme.
3. Build and run on macOS.
