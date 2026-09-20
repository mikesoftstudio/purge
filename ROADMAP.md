# Roadmap

Ideas for making Purge more efficient — grouped by effort and value.

## Quick wins

✓ Done:

- **Persist last selection** — remember which categories were toggled in the last scan so a rescan doesn't require re-selecting. Selection is saved to `SharedPreferences` on every change and restored (intersected with the new scan's ids) after a rescan.
- **"Clean recommended" one-tap from dashboard** — a `Clean recommended` button on the dashboard card runs the confirm dialog and cleans Safe + Moderate items in one step.
- **Age-based cleaning** — optional "Clean age" filter (1/3/7/14/30 days) on the Scan tab; only `rm` targets whose mtime is older than the cutoff are deleted, recent items are skipped (`rm`-only, so tool commands like brew/npm stay opt-in).
- **Reclaim-progress estimates** — Clean screen shows `X freed of ≈ Y` during and after a run, where Y is the sum of the selected categories' reported sizes.

## Medium effort, high value

✓ Done:

- **Cached scan results** — sizes are cached keyed by a path's mtime, so "Rescan" replays unchanged results instead of re-running `du`. The cache is cleared after a clean so deleted content is never replayed from a stale entry (`sizeOfPath`/`clearSizeCache` in `lib/engine/scanner.dart`).
- **Custom categories / exclusions** — Preferences lets you add custom folders (each becomes its own selectable card, cleaned by clearing their contents) and a blocklist of paths never to touch. Blocklisted paths are excluded from both measurement and deletion, including nested paths (`applyPathExclusions`, `CleanerStrings.excludedSkipped`).
- **Keyboard + command palette** — ⌘K opens an action palette (rescan, tabs, clean recommended, preferences, project folders, clear selection, theme), ⌘R rescans, and Space/Enter toggles a focused card.
- **Scheduled/auto scan + tray icon** — Purge auto-scans on launch and on a configurable schedule (default 30 min), shows a live reclaimable/free summary in the macOS menu bar with Scan now / Open Purge / Quit, and notifies via Notification Center (`osascript`) when reclaimable space crosses a configurable threshold.
- **Per-app caches for everyday apps** — App Caches now covers all apps on desktop, not just developer tools. Each app's cache folder becomes its own Safe card: `~/Library/Caches/*` on macOS, `~/.cache/*` on Linux, and cache-named folders (`Cache`, `GPUCache`, `Code Cache`, …) under `%LOCALAPPDATA%` on Windows. Dev-tool caches that already have a category are skipped to avoid double counting (`user-app-caches` in `lib/engine/categories.dart`).

## Bigger features

- **Undo / staged deletion** — move files to a holding folder instead of hard `rm`, with a "restore" window (strong safety story for the Advanced tier).
- **Project-level breakdown** — extend project-roots to show which projects own the most caches and clean per project.
- **Report export (JSON/CSV)** — inventory of scan results for shared drives or CI.
- **Free-space history chart** — track reclaimed totals over time on the dashboard.