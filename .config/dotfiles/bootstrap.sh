#!/usr/bin/env bash
# Bootstraps a fresh machine to match this dotfiles-managed environment.
# Supports macOS (Homebrew), Linux (apt/dnf/pacman), and WSL.
# Run this *after* cloning and checking out the dotfiles repo (see README).
# Safe to re-run — every step here is idempotent.
set -euo pipefail

DOTDIR="$HOME/.config/dotfiles"
BREWFILE="$DOTDIR/Brewfile"
PKGFILE="$DOTDIR/packages.linux"

# Collected as we go, printed at the end. Nothing here aborts the run.
SKIPPED=()
note() { SKIPPED+=("$1"); }

# --- Platform detection ---------------------------------------------------
OS="$(uname -s)"
IS_WSL=0
PKG=""

if [ "$OS" = "Darwin" ]; then
  PLATFORM="macos"
else
  PLATFORM="linux"
  # WSL identifies itself in /proc/version; WSL_DISTRO_NAME covers WSL2.
  if grep -qiE "microsoft|wsl" /proc/version 2>/dev/null || [ -n "${WSL_DISTRO_NAME:-}" ]; then
    IS_WSL=1
  fi
  for c in apt-get dnf pacman; do
    if command -v "$c" >/dev/null 2>&1; then
      case "$c" in
        apt-get) PKG="apt" ;;
        dnf)     PKG="dnf" ;;
        pacman)  PKG="pacman" ;;
      esac
      break
    fi
  done
  if [ -z "$PKG" ]; then
    echo "No supported package manager found (need apt, dnf, or pacman)." >&2
    exit 1
  fi
fi

echo "==> Platform: $PLATFORM${PKG:+ ($PKG)}$([ "$IS_WSL" = 1 ] && echo ' [WSL]')"

# sudo is needed for system package installs, but not inside a root container.
SUDO=""
if [ "$PLATFORM" = "linux" ] && [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

# --- macOS ----------------------------------------------------------------
if [ "$PLATFORM" = "macos" ]; then
  echo "==> Checking for Xcode Command Line Tools..."
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "Not found. Triggering install (opens a GUI dialog — click through it,"
    echo "then re-run this script)."
    xcode-select --install
    exit 1
  fi

  echo "==> Checking for Homebrew..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Not found, installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  echo "==> Installing packages from Brewfile ($BREWFILE)..."
  brew bundle install --file="$BREWFILE"

  echo "==> Setting rustup's default toolchain to stable..."
  "$(brew --prefix rustup)/bin/rustup" default stable
fi

# --- Linux ----------------------------------------------------------------
if [ "$PLATFORM" = "linux" ]; then
  # Several things below install into ~/.local/bin (Neovim, starship, the Go
  # tools, the Debian fd/bat shims) and rustup installs into ~/.cargo/bin.
  # .zshrc puts both on PATH for interactive shells, but this script runs under
  # bash — without them every "is it already installed?" check below would miss
  # and re-do the work on each run.
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  # Which column of packages.linux to read.
  case "$PKG" in
    apt)    COL=2 ;;
    dnf)    COL=3 ;;
    pacman) COL=4 ;;
  esac

  if [ ! -r "$PKGFILE" ]; then
    echo "Missing package manifest: $PKGFILE" >&2
    echo "The dotfiles checkout is incomplete — re-run 'dotfiles checkout'." >&2
    exit 1
  fi

  echo "==> Refreshing package lists..."
  case "$PKG" in
    apt)    $SUDO apt-get update -qq ;;
    dnf)    $SUDO dnf -q makecache || true ;;
    # -Syu, not -Sy: Arch does not support partial upgrades, and refreshing
    # the database without upgrading can leave you installing packages built
    # against libraries newer than the ones on disk.
    pacman) $SUDO pacman -Syu --noconfirm >/dev/null ;;
  esac

  # Build the install list from the manifest, dropping unavailable entries.
  mapfile -t WANT < <(grep -vE '^\s*#|^\s*$' "$PKGFILE" | awk -v c="$COL" '{print $c}' | grep -v '^-$' | sort -u)
  echo "==> Installing ${#WANT[@]} packages via $PKG..."

  pkg_install() {
    case "$PKG" in
      # `$SUDO env VAR=...` rather than `VAR=... $SUDO`: sudo scrubs the
      # environment by default, so the latter sets the variable for sudo
      # itself and apt-get never sees it — which means wireshark-common's
      # debconf prompt would block the whole run on a real (non-root) machine.
      apt)    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" ;;
      dnf)    $SUDO dnf install -y -q "$@" ;;
      pacman) $SUDO pacman -S --noconfirm --needed "$@" ;;
    esac
  }

  # Ask the package manager what it actually has before installing anything.
  # A single missing name makes the whole batch fail, and retrying 37 packages
  # one at a time is painfully slow — these queries are local and cheap, and
  # they let the summary name exactly what this distro is missing.
  pkg_available() {
    case "$PKG" in
      apt)    apt-cache show "$1" ;;
      dnf)    dnf info "$1" ;;
      pacman) pacman -Si "$1" ;;
    esac
  } >/dev/null 2>&1

  # A manifest cell may list alternatives separated by "|" — the first one this
  # distro actually has wins. Fedora needs this: it ships versioned Node streams
  # (nodejs22, nodejs24) with no plain "nodejs" package, and the stream names
  # change release to release.
  AVAIL=()
  for entry in "${WANT[@]}"; do
    picked=""
    IFS='|' read -ra cands <<<"$entry"
    for c in "${cands[@]}"; do
      if pkg_available "$c"; then picked="$c"; break; fi
    done
    if [ -n "$picked" ]; then
      AVAIL+=("$picked")
    else
      note "package not available via $PKG: $entry"
    fi
  done

  if [ "${#AVAIL[@]}" -gt 0 ] && ! pkg_install "${AVAIL[@]}" >/dev/null 2>&1; then
    # Something failed for a reason other than a bad name — fall back so one
    # broken package can't cost you all the others.
    echo "    batch install failed, retrying individually..."
    for p in "${AVAIL[@]}"; do
      pkg_install "$p" >/dev/null 2>&1 || note "install failed via $PKG: $p"
    done
  fi

  # Debian and Ubuntu rename these to avoid clashing with other packages.
  # Shim them into ~/.local/bin (already first on PATH) so that everything —
  # including Neovim and Telescope, which don't see shell aliases — finds them.
  mkdir -p "$HOME/.local/bin"
  if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
    echo "    shimmed fdfind -> ~/.local/bin/fd"
  fi
  if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
    echo "    shimmed batcat -> ~/.local/bin/bat"
  fi

  # Neovim: this config uses vim.pack, which needs 0.12+, and distro packages
  # lag far behind (Ubuntu 24.04 ships 0.9.5 — vim.pack simply doesn't exist
  # there). Always install the official release build into ~/.local.
  need_nvim=1
  if command -v nvim >/dev/null 2>&1; then
    read -r nvmaj nvmin <<<"$(nvim --version | head -1 | sed -E 's/^NVIM v([0-9]+)\.([0-9]+).*/\1 \2/')"
    if [ "${nvmaj:-0}" -gt 0 ] 2>/dev/null || [ "${nvmin:-0}" -ge 12 ] 2>/dev/null; then
      need_nvim=0
    fi
  fi
  if [ "$need_nvim" = 1 ]; then
    case "$(uname -m)" in
      x86_64)        nvarch=x86_64 ;;
      aarch64|arm64) nvarch=arm64 ;;
      *)             nvarch="" ;;
    esac
    if [ -n "$nvarch" ]; then
      echo "==> Installing Neovim from the official release (distro build is too old)..."
      nvtmp="$(mktemp -d)"
      if curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvarch}.tar.gz" \
           | tar xz -C "$nvtmp" 2>/dev/null; then
        rm -rf "$HOME/.local/nvim"
        mv "$nvtmp"/nvim-linux-* "$HOME/.local/nvim"
        ln -sf "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"
      else
        note "Neovim download failed — install 0.12+ manually from https://github.com/neovim/neovim/releases"
      fi
      rm -rf "$nvtmp"
    else
      note "no Neovim release build for $(uname -m) — install 0.12+ manually"
    fi
  fi

  # Not reliably packaged on Linux — each has its own official installer.
  if ! command -v rustup >/dev/null 2>&1; then
    echo "==> Installing rustup..."
    curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path >/dev/null \
      || note "rustup install failed — see https://rustup.rs"
  fi
  if command -v rustup >/dev/null 2>&1; then
    rustup default stable >/dev/null 2>&1 || true
  elif [ -x "$HOME/.cargo/bin/rustup" ]; then
    "$HOME/.cargo/bin/rustup" default stable >/dev/null 2>&1 || true
  fi

  if ! command -v starship >/dev/null 2>&1; then
    echo "==> Installing starship..."
    curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin" >/dev/null \
      || note "starship install failed — see https://starship.rs"
  fi

  # Go-based tools with no distro packages. Needs the Go toolchain above.
  if command -v go >/dev/null 2>&1; then
    export GOBIN="$HOME/.local/bin"
    for t in \
      "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest:nuclei" \
      "github.com/charmbracelet/glow@latest:glow" \
      "github.com/mikefarah/yq/v4@latest:yq"; do
      mod="${t%%:*}"; bin="${t##*:}"
      command -v "$bin" >/dev/null 2>&1 && continue
      echo "==> go install $bin..."
      go install "$mod" >/dev/null 2>&1 || note "go install failed: $bin"
    done
  else
    note "Go toolchain missing — nuclei, glow and yq were not installed"
  fi

  if command -v npm >/dev/null 2>&1 && ! command -v bw >/dev/null 2>&1; then
    echo "==> Installing Bitwarden CLI via npm..."
    npm install -g --silent @bitwarden/cli >/dev/null 2>&1 \
      || note "bitwarden-cli install failed (npm global install may need sudo)"
  fi

  command -v pwsh >/dev/null 2>&1 || \
    note "PowerShell not installed — see https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux"

  if [ "$IS_WSL" = 1 ]; then
    # Neovim's clipboard provider looks for win32yank.exe on WSL; without it
    # "+y goes nowhere. clip.exe can only copy, never paste.
    if ! command -v win32yank.exe >/dev/null 2>&1; then
      note "WSL: install win32yank for Neovim clipboard support — https://github.com/equalsraf/win32yank/releases"
    fi
    note "WSL: Ghostty config is checked out but unused here; use a Windows terminal"
  fi
fi

# --- Both platforms -------------------------------------------------------
if command -v nuclei >/dev/null 2>&1; then
  echo "==> Fetching nuclei templates..."
  mkdir -p "$HOME/.local/share/nuclei"
  nuclei -update-templates -ud "$HOME/.local/share/nuclei/templates" >/dev/null 2>&1 \
    || note "nuclei template fetch failed — retry with: nuclei -update-templates -ud ~/.local/share/nuclei/templates"
fi

if command -v pwsh >/dev/null 2>&1; then
  echo "==> Installing PowerShell modules (Microsoft 365 / Exchange Online)..."
  pwsh -NoProfile -Command '
    $modules = "Microsoft.Graph", "Microsoft.Online.SharePoint.PowerShell", "PnP.PowerShell", "ExchangeOnlineManagement"
    foreach ($m in $modules) {
      if (-not (Get-Module -ListAvailable -Name $m)) {
        Write-Host "  installing $m..."
        Install-Module -Name $m -Scope CurrentUser -Force
      } else {
        Write-Host "  $m already installed"
      }
    }
  ' || note "PowerShell module install failed"
fi

# --- Summary --------------------------------------------------------------
echo ""
echo "==> Done."

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  echo ""
  echo "Not everything was available on this platform:"
  for s in "${SKIPPED[@]}"; do echo "  - $s"; done
fi

echo ""
echo "A few things can't be scripted and need one-time manual action:"
echo ""
if [ "$PLATFORM" = "macos" ]; then
  echo "  - Packet capture permissions: if 'tshark -D' shows no interfaces, the"
  echo "    wireshark-app cask's ChmodBPF installer needs your admin password —"
  echo "    re-run in a real terminal: brew reinstall --cask wireshark-app"
  echo ""
  echo "  - Ghostty's quick-terminal hotkey (cmd+alt+\`) needs Accessibility"
  echo "    permission: System Settings > Privacy & Security > Accessibility"
  echo "    (Ghostty prompts for this itself once you try the hotkey)"
else
  echo "  - Packet capture as a non-root user:"
  if [ "$PKG" = "apt" ]; then
    echo "      sudo dpkg-reconfigure wireshark-common   # answer Yes"
  fi
  echo "      sudo usermod -aG wireshark \"\$USER\"       # then log out and back in"
  echo ""
  echo "  - Make zsh your login shell if it isn't already:  chsh -s \"\$(command -v zsh)\""
fi
echo ""
echo "  - Bitwarden CLI: run 'bw login' with your actual credentials when"
echo "    you need it — not something this script should do for you"
