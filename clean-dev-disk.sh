#!/usr/bin/env bash
#
# clean-dev-disk.sh — free disk space on a macOS dev machine.
#
# Usage:
#   ./clean-dev-disk.sh          interactive, ask before each category
#   ./clean-dev-disk.sh --check  dry run, only report reclaimable space
#   ./clean-dev-disk.sh --yes    clean everything, no prompts
#   ./clean-dev-disk.sh --list   show detected toolchains
#
# Safe by design: never touches code, git repos, or sources. Only caches,
# logs, old artifacts, and other regenerable data.

set -uo pipefail

# ---- output helpers -------------------------------------------------------
C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_CYAN=$'\033[36m'
C_BOLD=$'\033[1m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'

check_mode=0; yes_mode=0
total_freed=0

say()  { printf '%b%s%b\n' "$C_BOLD" "$*" "$C_RESET"; }
info() { printf '%b%s%b\n' "$C_CYAN" "$*" "$C_RESET"; }
ok()   { printf '%b%s%b\n' "$C_GREEN" "$*" "$C_RESET"; }
warn() { printf '%b%s%b\n' "$C_YELLOW" "$*" "$C_RESET"; }
dim()  { printf '%b%s%b\n' "$C_DIM" "$*" "$C_RESET"; }

# ---- size helpers ---------------------------------------------------------
# Human-friendly size of a path (empty if it does not exist).
size_of() { du -sk "$1" 2>/dev/null | awk '{print $1}'; }

fmt() { # KB -> human readable
  local k=$1
  awk -v k="$k" 'BEGIN{
    if (k >= 1048576) printf "%.1fG", k/1048576
    else if (k >= 1024) printf "%.0fM", k/1024
    else printf "%dK", k
  }'
}

# Safe removal: path must exist, be non-empty, and not a mount/home root.
rm_safe() {
  local p=$1
  local kb
  (( check_mode )) && return 0
  [[ -e "$p" && -n "$p" && "$p" != "/" && "$p" != "$HOME" ]] || return 0
  kb=$(size_of "$p"); (( kb > 0 )) || return 0
  echo "  ${C_DIM}-> freeing $(fmt "$kb") ...${C_RESET}"
  rm -rf -- "$p"
}

# Ask before acting unless in --yes mode. Returns 0 to proceed.
confirm() {
  local prompt=$1
  (( yes_mode )) && return 0
  (( check_mode )) && return 1
  read -r -p "$prompt ${C_YELLOW}[y/N]${C_RESET} " reply
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

# Prune target paths; handles dry-run and size reporting. Sets the freed-kb var.
clean_target() { # clean_target <label> <size-kb> <freed-result-var-name>
  local label=$1 size=$2 freed_var=$3
  printf '%b%-36s %10s%b\n' "$C_CYAN" "$label" "$(fmt "$size")" "$C_RESET"
  if (( check_mode )); then
    eval "$freed_var=$size"; return 0
  fi
  if (( size == 0 )); then
    eval "$freed_var=0"; return 0
  fi
  if confirm "  clean it?"; then
    eval "$freed_var=$size"; return 0
  fi
  eval "$freed_var=0"; return 0
}

account() { # add to total and to overall freed
  local var=$1
  local v=${!var}
  if (( v > 0 )); then total_freed=$(( total_freed + v )); fi
}

has() { command -v "$1" >/dev/null 2>&1; }

# ---- usage ----------------------------------------------------------------
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --check   dry run — report reclaimable space without deleting
  --yes     skip all prompts (still safe: only regenerable caches/logs)
  --list    print detected toolchains and exit
  -h, --help
EOF
}

for a in "$@"; do
  case "$a" in
    --check) check_mode=1 ;;
    --yes)   yes_mode=1 ;;
    --list)  for t in brew npm pnpm yarn docker pod pip3 go cargo flutter dart xcodebuild; do
                 printf '%-10s %s\n' "$t:" "$(has "$t" && echo installed || echo missing)"
               done; exit 0 ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $a"; usage; exit 1 ;;
  esac
done

if (( check_mode )); then say "Dry run — nothing will be deleted."; else say "Dev-disk cleaner"; fi

# ===========================================================================
# 1. Homebrew — downloads cache, old versions, stale symlinks
# ===========================================================================
if has brew; then
  say "Homebrew"
  hc="$HOME/Library/Caches/Homebrew"
  hkb=$(size_of "$hc")
  clean_target "brew downloads cache" "$hkb" f1
  if (( f1 > 0 )); then
    rm_safe "$hc"
    if confirm "  run 'brew cleanup' too (keeps current installs)?"; then
      brew cleanup >/dev/null 2>&1
      ok "  brew cleanup done"
    fi
  fi
  account f1
fi

# ===========================================================================
# 2. Xcode — DerivedData, old device support, stale simulators
# ===========================================================================
if has xcodebuild; then
  say "Xcode"
  dd="$HOME/Library/Developer/Xcode/DerivedData"
  dkb=$(size_of "$dd")
  clean_target "DerivedData (rebuilds regenerate it)" "$dkb" f2
  if (( f2 > 0 )); then rm_safe "$dd"; fi
  account f2

  ds="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  dskb=$(size_of "$ds")
  clean_target "old iOS DeviceSupport (keep current)" "$dskb" f3
  if (( f3 > 0 )); then
    if confirm "  keep the most recent version?"; then
      ( cd "$ds" 2>/dev/null && ls -dt */ 2>/dev/null | tail -n +2 | xargs -I{} rm -rf -- "$ds/{}" ) 2>/dev/null
    else rm_safe "$ds"; fi
  fi
  account f3

  sim="$HOME/Library/Developer/CoreSimulator/Caches"
  skb=$(size_of "$sim")
  clean_target "CoreSimulator caches (dyld/iOS)" "$skb" f4
  if (( f4 > 0 )); then rm_safe "$sim"; fi
  account f4
fi

# ===========================================================================
# 3. Node — npm cache, logs, package manager stores
# ===========================================================================
if has npm; then
  say "Node.js"
  nkb=$(size_of "$HOME/.npm")
  clean_target "npm cache" "$nkb" f5
  if (( f5 > 0 && !check_mode )); then npm cache clean --force >/dev/null 2>&1; ok "  npm cache cleaned"; fi
  account f5
fi
for mgr in pnpm yarn; do
  if has "$mgr"; then
    if [[ "$mgr" == "pnpm" ]]; then sp="$HOME/Library/Caches/pnpm"; else sp="$HOME/Library/Caches/Yarn"; fi
    skb=$(size_of "$sp")
    if (( skb > 0 )); then
      say "Node.js ($mgr store)"
      clean_target "$mgr cache" "$skb" f6
      if (( f6 > 0 )); then rm_safe "$sp"; fi
      account f6
    fi
  fi
done

# ===========================================================================
# 4. Python
# ===========================================================================
if has pip3; then
  say "Python"
  pkb=$(pip3 cache info 2>/dev/null | awk '/^Location:/{print $2}' | xargs du -sk 2>/dev/null | awk '{print $1}')
  clean_target "pip cache" "${pkb:-0}" f7
  if (( f7 > 0 && !check_mode )); then pip3 cache purge >/dev/null 2>&1; ok "  pip cache purged"; fi
  account f7
fi

# ===========================================================================
# 5. CocoaPods
# ===========================================================================
if has pod; then
  say "CocoaPods"
  pk="$HOME/Library/Caches/CocoaPods"
  pkkb=$(size_of "$pk")
  clean_target "CocoaPods cache" "$pkkb" f8
  if (( f8 > 0 )); then rm_safe "$pk"; fi
  account f8
fi

# ===========================================================================
# 6. Flutter & Dart — pub cache, SDK artifacts
# ===========================================================================
if has flutter || has dart; then
  say "Flutter / Dart"
  pub="$HOME/.pub-cache"
  pubkb=$(size_of "$pub")
  clean_target "Dart pub cache (re-download on 'pub get')" "$pubkb" fpub
  if (( fpub > 0 )); then rm_safe "$pub"; fi
  account fpub

  if has flutter; then
    fl_bin=$(command -v flutter)
    fl_real=$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$fl_bin" 2>/dev/null || echo "$fl_bin")
    fl_sdk=$(dirname "$(dirname "$fl_real")")
    fbc="$fl_sdk/bin/cache"
    fbkb=$(size_of "$fbc")
    clean_target "Flutter SDK bin/cache (re-downloads engine)" "$fbkb" fflsdk
    if (( fflsdk > 0 )); then rm_safe "$fbc"; fi
    account fflsdk
  fi
fi

# ===========================================================================
# 7. Gradle — build & wrapper caches (Android builds)
# ===========================================================================
if [[ -d "$HOME/.gradle" ]]; then
  say "Gradle"
  gkc="$HOME/.gradle/caches"
  gkb=$(size_of "$gkc")
  clean_target "Gradle build caches" "$gkb" fgk
  if (( fgk > 0 )); then rm_safe "$gkc"; fi
  account fgk

  gwd="$HOME/.gradle/wrapper/dists"
  gwkb=$(size_of "$gwd")
  clean_target "Gradle wrapper dists (re-downloaded)" "$gwkb" fgwd
  if (( fgwd > 0 )); then rm_safe "$gwd"; fi
  account fgwd
fi

# ===========================================================================
# 8. Docker — dangling images, build cache, stopped containers
# ===========================================================================
if has docker; then
  say "Docker"
  if docker info >/dev/null 2>&1; then
    warn "  docker system prune -af removes ALL unused images (safe for disk, slow to re-pull)"
    if confirm "  run docker system prune --volumes?"; then
      docker system prune -af --volumes >/dev/null 2>&1
      ok "  docker pruned"
    fi
  else
    dim "  daemon not running — skipping"
  fi
fi

# ===========================================================================
# 9. Go build cache
# ===========================================================================
if has go; then
  say "Go"
  gkb=$(du -sk "$(go env GOCACHE 2>/dev/null)" 2>/dev/null | awk '{print $1}')
  clean_target "go build cache (slower first build)" "${gkb:-0}" f9
  if (( f9 > 0 && !check_mode )); then go clean -cache >/dev/null 2>&1; fi
  account f9
fi

# ===========================================================================
# 10. Rust — cargo registry cache
# ===========================================================================
if has cargo; then
  say "Rust"
  ckb=$(size_of "$HOME/.cargo/registry/cache")
  clean_target "cargo registry cache" "$ckb" f10
  if (( f10 > 0 )); then rm_safe "$HOME/.cargo/registry/cache"; fi
  account f10
fi

# ===========================================================================
# 11. Trash
# ===========================================================================
say "Trash"
tkb=$(size_of "$HOME/.Trash")
if [[ -z "$tkb" && -d "$HOME/.Trash" ]]; then
  n=$(stat -f %l "$HOME/.Trash" 2>/dev/null)
  n=$(( ${n:-0} - 2 ))
  if (( n > 0 )); then
    warn "  ~/.Trash has $n item(s) but macOS privacy blocks direct access"
    if (( check_mode )); then
      dim "  (empty it via Finder, or grant the terminal Full Disk Access)"
    elif (( yes_mode )) || confirm "  empty Trash via Finder?"; then
      if osascript -e 'tell application "Finder" to empty trash' >/dev/null 2>&1; then
        ok "  Trash emptied via Finder"
      else
        warn "  could not empty — grant the terminal Full Disk Access, or use Finder > Empty Trash"
      fi
    fi
  fi
  f11=0
else
  clean_target "user Trash" "${tkb:-0}" f11
  if (( f11 > 0 )); then rm_safe "$HOME/.Trash"; fi
  account f11
fi

# ===========================================================================
# 12. User caches & logs
# ===========================================================================
say "User caches & logs"
total_user=0
for item in \
  "$HOME/Library/Caches/com.apple.dt.Xcode" \
  "$HOME/Library/Caches/com.apple.helpd" \
  "$HOME/Library/Caches/org.carthage.CarthageKit" \
  "$HOME/Library/Caches/com.google.SoftwareUpdateAgent" \
  "$HOME/.local/share/Trash" \
  "$HOME/Library/Logs" ; do
  kb=$(size_of "$item")
  if (( kb > 0 )); then
    printf '%b%-36s %10s%b\n' "$C_CYAN" "$item" "$(fmt "$kb")" "$C_RESET"
    if (( check_mode )); then continue; fi
    if confirm "  clean it?"; then
      rm_safe "$item"
      total_user=$(( total_user + kb ))
    fi
  fi
done
if (( total_user > 0 )); then ok "  freed $(fmt "$total_user")"; fi
total_freed=$(( total_freed + total_user ))

# ===========================================================================
# 13. Simulator devices that are no longer needed (only if dev on iOS)
# ===========================================================================
if has xcrun && [[ -d "$HOME/Library/Developer/CoreSimulator/Devices" ]]; then
  say "iOS Simulators"
  n_dev=$(xcrun simctl list devices eclipsed -j 2>/dev/null | grep -c '"udid"' || true)
  if (( n_dev > 0 )); then
    warn "  $n_dev eclipsed/inactive simulator device(s) (kept state, can be large)"
    if confirm "  delete eclipsed simulator devices?"; then
      xcrun simctl delete unavailable >/dev/null 2>&1
      ok "  unavailable simulators deleted"
    fi
  else
    dim "  none unavailable"
  fi
fi

# ---- summary ---------------------------------------------------------------
echo ""
if (( check_mode )); then
  say "Estimated reclaimable: ${C_GREEN}$(fmt "${total_freed:-0}")${C_RESET}"
  dim "Run with --yes to actually clean."
else
  say "Total freed this run: ${C_GREEN}$(fmt "$total_freed")${C_RESET}"
fi

disk_free_kb=$(df -k "$HOME" | awk 'NR==2{print $4}')
ok "Free on $HOME now: $(fmt "$disk_free_kb")"