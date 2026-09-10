# Purge 

Declutter any device. `Purge` frees disk space by removing regenerable
caches, logs, and build artifacts left behind by common developer tools — while
never touching your source code or personal files.

Purge ships as **two tools** with the same safe philosophy:

1. **A web app (Next.js)** — a visual dashboard that scans your machine,
   shows exactly what is reclaimable, and cleans with real-time progress.
   Runs locally at `http://localhost:3000`.
2. **A CLI script (`clean-dev-disk.sh`)** — the original zero-dependency,
   macOS-only bash tool.

## Platform support

The web app auto-detects the operating system and only shows categories that
apply to it.

| Platform | Status | Notes |
| --- | --- | --- |
| macOS | Full | All categories |
| Linux | Full | All desktop categories |
| Windows | Full | Native via Node.js + PowerShell for Recycle Bin |
| Android | Partial | Works under Termux (npm, pip, Gradle, Go, Rust, pub cache) |
| iOS | Partial | Works under a-Shell / iSH for basic caches |

Supported categories: Homebrew, npm, pnpm, Yarn, pip, CocoaPods, Xcode
(DerivedData, DeviceSupport, Simulators), Flutter/Dart, Gradle, Docker, Go,
Cargo/Rust, .NET/NuGet, Chocolatey, Scoop, Trash/Recycle Bin, and system caches
& logs.

## Getting started (web app)

> Runs entirely on your machine — no data leaves it.

```bash
npm install
npm run dev        # → http://localhost:3000
```

For production:

```bash
npm run build
npm start
```

### Flow

1. **Dashboard** — see how much disk space you have and how much is reclaimable.
2. **Scan** — read-only detection of installed tools and their cache sizes.
3. **Clean** — select categories, confirm, watch live progress.
4. **Summary** — see what was freed and the trade-offs that follow.

### Safety model

- **Scans are read-only.** Nothing is deleted until you confirm.
- **Categories are regenerable.** Every item is a cache, log, or build artifact —
  no source code, no `node_modules`, no personal documents.
- **Safety tiers.** Each category is labelled *Safe*, *Moderate*, or *Advanced*
  (Docker is Advanced).
- **Guarded deletion.** Target paths are validated before any removal; empty
  paths, your home directory, and volume roots are rejected.
- **Explicit confirmation.** You must review and confirm the selection before
  anything is cleaned.

## Using the CLI script

```bash
./clean-dev-disk.sh            # interactive — asks before each category
./clean-dev-disk.sh --check    # dry run — report only, delete nothing
./clean-dev-disk.sh --yes      # clean all items, no prompts
./clean-dev-disk.sh --list     # show detected toolchains
```

## What it cleans

| Category | Items | Platforms |
| --- | --- | --- |
| Homebrew | `~/Library/Caches/Homebrew` (macOS), `~/.cache/Homebrew` (Linux); `brew cleanup` | macOS, Linux |
| npm | npm cache via `npm cache clean --force` | all |
| pnpm / Yarn | store + cache dirs | macOS, Linux, Windows, Android |
| pip | pip cache via `pip cache purge` | all |
| Xcode | DerivedData, old DeviceSupport, CoreSimulator caches, unavailable simulators | macOS |
| CocoaPods | `~/Library/Caches/CocoaPods` | macOS |
| Flutter / Dart | pub cache, Flutter engine cache | macOS, Linux, Windows, Android |
| Gradle | `~/.gradle/caches`, `~/.gradle/wrapper/dists` | macOS, Linux, Windows, Android |
| Docker | `docker system prune -af --volumes` | macOS, Linux, Windows |
| Go | `go clean -cache`, `go clean -modcache` | macOS, Linux, Windows, Android |
| Rust | cargo registry cache | macOS, Linux, Windows, Android |
| .NET / NuGet | `dotnet nuget locals all --clear` | macOS, Linux, Windows |
| Chocolatey / Scoop | `choco cache remove`, `scoop cache rm *` | Windows |
| Trash | `~/.Trash` / XDG Trash / Recycle Bin | macOS, Linux, Windows |
| System | select `~/Library/Caches` entries, `~/Library/Logs`, `~/.cache` | macOS, Linux, Android |

## What it never touches

- Your source code, git repos, or project directories
- `node_modules` — project dependency folders are left alone
- Anything outside your home directory except paths you are explicitly prompted about
- `/` or your home directory themselves (guarded at the removal step)
- Any path that does not exist, is empty, or is unknown to the tool

## Trade-offs

Clearing caches has a follow-up cost — every item regenerates on next use:

| Item | Cost after cleaning |
| --- | --- |
| npm / pip / pub caches | re-download packages on next install |
| Xcode DerivedData / Gradle / Go | slower first build |
| Flutter engine cache | re-downloads ~1–2 GB of engine artifacts |
| Docker | containers/images must be re-pulled |
| Trash | deleted items cannot be restored |

## Project structure

```
src/
├── app/                 # pages + API routes (Next.js App Router)
│   └── api/             # /api/disk · /api/scan · /api/clean · /api/progress · /api/tools · /api/cancel
├── lib/
│   ├── engine/          # cross-platform scan/clean engine (TypeScript)
│   │   └── categories/  # one module per toolchain, platform-aware paths
│   └── ...
├── components/          # UI components
└── hooks/               # React hooks (useDisk, useScan, useClean)
```

## Contributing

- **Add a category:** create `src/lib/engine/categories/<name>.ts` following
  the existing pattern (paths per platform, clean commands, safety tier), then
  register it in `src/lib/engine/categories/index.ts`.
- Run `npm run build` (type-checks) before submitting.

## License

MIT — free to use, modify, and share.
