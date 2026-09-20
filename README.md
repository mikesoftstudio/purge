# Purge

Declutter any device. `Purge` frees disk space by removing regenerable
caches, logs, and build artifacts left behind by everyday apps and common
developer tools — while never touching your source code or personal files.

This is the **Flutter** edition, shipping as a native app for Android, iOS,
Windows, macOS, and Linux.

## Platform support

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | Full | Full disk access via native APIs, all categories |
| Windows | Full | PowerShell + native APIs, all categories |
| Linux | Full | All desktop categories via native tooling |
| Android | Full | Scoped storage + `MANAGE_EXTERNAL_STORAGE` for caches |
| iOS | Partial | App sandbox limited — only shows own caches + guidance mode |

## Getting started

```bash
flutter pub get
flutter run                  # auto-detect platform
flutter run -d macos
flutter run -d linux
flutter run -d windows
flutter run -d android
```

### Build release

```bash
flutter build macos
flutter build linux
flutter build windows
flutter build apk --release
flutter build ios --release
```

## Project structure

```
lib/
├── main.dart                        # App entry
├── log.dart                         # Debug logging helper
├── state/purge_controller.dart      # Single source of truth (ChangeNotifier)
├── engine/
│   ├── types.dart                   # Domain models (Platform, ScanResult, …)
│   ├── platform.dart                # OS detection + platform labels
│   ├── bytes.dart                   # Byte parsing + formatting
│   ├── host.dart                    # Resolves home dir, cache paths, HostEnv
│   ├── scanner.dart                 # Walks disk, sizes directories, scans all categories
│   ├── cleaner.dart                 # Runs clean commands, removes paths, reports progress
│   ├── disk.dart                    # DiskInfo via native channels / df / PowerShell
│   ├── tool_detect.dart             # Detects installed tool binaries
│   ├── custom.dart                  # User-defined folder categories
│   ├── projects.dart                # Project-root discovery + per-project caches
│   └── categories.dart              # All category definitions (Trash, App Caches, …)
├── platform/
│   ├── notify.dart                  # Notification Center alerts (reclaimable threshold)
│   └── tray.dart                    # macOS menu-bar tray with live summary
├── screens/
│   ├── dashboard_screen.dart        # Dashboard page
│   ├── scan_screen.dart             # Scan + selection + confirm
│   ├── clean_screen.dart            # Live cleaning progress
│   └── summary_screen.dart          # Post-clean summary
├── ui/
│   └── strings.dart                 # Shared user-facing strings
├── widgets/
│   ├── app_shell.dart               # Adaptive scaffold: nav rail (desktop) / nav bar (mobile)
│   ├── category_card.dart           # Individual scan-result card with context menu
│   ├── clean_confirm.dart           # Confirm dialog for cleaning
│   ├── command_palette.dart         # ⌘K action palette
│   ├── confirm_dialog.dart          # Reusable confirm/acknowledge dialog
│   ├── disk_overview.dart           # Disk usage donut chart
│   ├── project_roots_dialog.dart    # Manage project roots to scan
│   ├── safety_badge.dart            # Safe / Moderate / Advanced badge
│   ├── safety_info.dart             # Safety-tier explainer dialog
│   ├── scanning_indicator.dart      # Animated radar during scans
│   └── settings_dialog.dart         # Preferences (exclusions, schedule, theme)
└── theme.dart                       # Light + dark Material 3 theme (Sora + Fraunces fonts)
```

## Supported categories

| Category | Platforms |
| --- | --- |
| Trash / Recycle Bin | macOS, Linux, Windows, Android |
| System Caches & Logs | macOS, Linux, Android |
| App Caches | Android, iOS |
| App Caches (per app) | macOS, Linux, Windows |
| Homebrew | macOS, Linux |
| npm | all |
| pnpm / Yarn | macOS, Linux, Windows, Android |
| pip | all |
| CocoaPods | macOS |
| Flutter / Dart | macOS, Linux, Windows, Android |
| Xcode DerivedData, DeviceSupport, Simulators | macOS |
| Gradle | macOS, Linux, Windows, Android |
| Docker | macOS, Linux, Windows |
| Go | macOS, Linux, Windows, Android |
| Cargo / Rust | macOS, Linux, Windows, Android |
| .NET / NuGet | macOS, Linux, Windows |
| Chocolatey / Scoop | Windows |
| Large files in your home folder (≥ 100 MB) | macOS, Linux, Windows |

**App Caches (per app)** covers every everyday app, not just developer tools.
Each app's cache becomes its own card (safe tier, recommended by default) so
you can clean a single app without touching the rest:

- **macOS** — each folder in `~/Library/Caches` (`com.apple.Safari`,
  `com.google.Chrome`, `com.spotify.client`, …).
- **Linux** — each folder in `~/.cache`.
- **Windows** — cache-named folders under `%LOCALAPPDATA%` (`Cache`, `GPUCache`,
  `Code Cache`, `CEFCache`, …), depth-bounded and matched by exact name so app
  data is never collected.

Caches that already have a dedicated category (Homebrew, npm, pip, CocoaPods,
Xcode, yarn, pnpm, go-build, …) are skipped here so nothing is counted twice,
and Purge's own cache is excluded as well.

## Safety model

- **Scans are read-only.** Nothing is deleted until you confirm.
- **Categories are regenerable.** Every item is a cache, log, or build artifact —
  never your source code, never personal files. The one exception is **Large
  Files** (personal files ≥ 100 MB), which is an *Advanced* item and is never
  auto-selected by "Recommended".
- **Guarded deletion.** Target paths are validated before removal; empty paths,
  your home directory, and volume roots are rejected.
- **Explicit confirmation.** You must acknowledge the selection before anything
  is cleaned.

## Contributing

- **Add a category:** add a `final` in `lib/engine/categories.dart` following
  the existing pattern (paths per platform, clean commands, safety tier), then
  register it in `allCategories()`.
- Run `dart analyze` before submitting.

## License

MIT — free to use, modify, and share.
