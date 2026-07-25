#!/bin/sh
# Fetch and run the portable Neovim bundle on a Linux box.
#
#   curl -fsSL <url>/nvim-go.sh | sh                  # run once, leave nothing
#   curl -fsSL <url>/nvim-go.sh | sh -s -- /etc/hosts # ...on a specific file
#   curl -fsSL <url>/nvim-go.sh | sh -s -- --install  # keep it in ~/.local
#
# Needs curl or wget, tar, and about 500MB of free space. No root, no package
# manager, no compiler.
set -eu

REPO=${NVIM_PORTABLE_REPO:-agoratopia/dotfiles}
# The rolling tag, not /releases/latest/. CI republishes portable-latest every
# time the Neovim config changes, so this always tracks the repo; /latest/ would
# instead resolve to whichever release was published most recently, which a
# pinned version tag would silently take over.
BASE=${NVIM_PORTABLE_URL:-https://github.com/$REPO/releases/download/portable-latest}
PREFIX=${NVIM_PORTABLE_PREFIX:-$HOME/.local}

INSTALL=0
if [ "${1:-}" = "--install" ]; then INSTALL=1; shift; fi

die() { printf 'nvim-go: %s\n' "$*" >&2; exit 1; }

case "$(uname -s)" in Linux) ;; *) die "this bundle is Linux-only (found $(uname -s))" ;; esac
case "$(uname -m)" in
  x86_64)        arch=x86_64 ;;
  aarch64|arm64) arch=arm64 ;;
  *) die "no bundle for $(uname -m)" ;;
esac

if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
else
  die "need curl or wget"
fi

url=$BASE/nvim-portable-$arch.tar.gz

if [ "$INSTALL" = 1 ]; then
  dest=$PREFIX/nvim-portable
  printf 'nvim-go: installing to %s\n' "$dest" >&2
  rm -rf "$dest"
  mkdir -p "$PREFIX" "$PREFIX/bin"
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/nvim-go.XXXXXX")
  trap 'rm -rf "$tmp"' EXIT INT TERM
  fetch "$url" | tar xz -C "$tmp" || die "download or extract failed: $url"
  mv "$tmp/nvim-portable" "$dest"

  # A persistent install is one you chose to leave behind, so undo history and
  # marks should persist too — unlike the ephemeral path below.
  cat >"$PREFIX/bin/nvim-portable" <<EOF
#!/bin/sh
NVIM_PORTABLE_STATE=\${NVIM_PORTABLE_STATE:-\$HOME/.local/state/nvim-portable}
export NVIM_PORTABLE_STATE
exec "$dest/run" "\$@"
EOF
  chmod 755 "$PREFIX/bin/nvim-portable"
  printf 'nvim-go: installed. Run: nvim-portable\n' >&2
  case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) printf 'nvim-go: note - %s/bin is not on your PATH\n' "$PREFIX" >&2 ;;
  esac
  exit 0
fi

# Ephemeral: extract, run, remove. Nothing survives on the host.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/nvim-go.XXXXXX")
trap 'rm -rf "$tmp"' EXIT INT TERM
printf 'nvim-go: fetching %s...\n' "$url" >&2
fetch "$url" | tar xz -C "$tmp" || die "download or extract failed: $url"

# Piped into `sh`, this script *is* stdin — so Neovim would inherit the script
# text as its input and exit immediately. Hand it the real terminal instead.
#
# Test by actually opening it, not with [ -e ]: under cron, a container without
# a tty, or `ssh host command`, /dev/tty exists as a device node but opening it
# fails with ENXIO, and the bare existence check sails past into a confusing
# error from the shell itself.
if [ ! -t 0 ]; then
  if (exec </dev/tty) 2>/dev/null; then
    exec </dev/tty
  else
    die "no terminal available — this mode needs one to run an editor.
  Use --install instead, or fetch the tarball and run ./nvim-portable/run yourself."
  fi
fi

"$tmp/nvim-portable/run" "$@"
