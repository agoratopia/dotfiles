#!/usr/bin/env bash
# Bootstraps a fresh macOS machine to match this dotfiles-managed environment.
# Run this *after* cloning and checking out the dotfiles repo (see README.md).
# Safe to re-run — every step here is idempotent.
set -euo pipefail

BREWFILE="$HOME/.config/dotfiles/Brewfile"

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

echo "==> Fetching nuclei templates..."
mkdir -p "$HOME/.local/share/nuclei"
nuclei -update-templates -ud "$HOME/.local/share/nuclei/templates" || \
  echo "  (nuclei template fetch failed — check network, retry later with the same command)"

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
'

echo ""
echo "==> Done. A few things can't be scripted and need one-time manual action:"
echo ""
echo "  - Packet capture permissions: if 'tshark -D' shows no interfaces, the"
echo "    wireshark-app cask's ChmodBPF installer needs your admin password —"
echo "    re-run in a real terminal: brew reinstall --cask wireshark-app"
echo ""
echo "  - Ghostty's quick-terminal hotkey (cmd+alt+\`) needs Accessibility"
echo "    permission: System Settings > Privacy & Security > Accessibility"
echo "    (Ghostty prompts for this itself once you try the hotkey)"
echo ""
echo "  - Bitwarden CLI: run 'bw login' with your actual credentials when"
echo "    you need it — not something this script should do for you"
