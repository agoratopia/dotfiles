#!/usr/bin/env bash
# Build a self-contained Neovim bundle for Linux servers reached over SSH.
#
# Produces dist/nvim-portable-<arch>.tar.gz: Neovim, this config running under
# NVIM_PROFILE=server, and every plugin, language server and treesitter parser
# already built. The result runs offline, as an unprivileged user, on a machine
# with no compiler, no Node and no network.
#
# Run this ON Linux — in a container locally, or on a CI runner. It builds for
# whatever architecture it is running on; cross-building would mean compiling
# treesitter parsers under emulation, which is slow and has already proven
# flaky here.
#
# Budget ~15 minutes and a few GB of disk. It copes with as little as ~1GB of
# free RAM, but is faster with 4GB+ — see the treesitter step for why.
#
#   docker run --rm -v "$HOME:/src:ro" -v "$PWD/dist:/dist" ubuntu:24.04 \
#     bash -c '/src/.config/dotfiles/build-portable.sh --out /dist'
#
set -euo pipefail

OUT_DIR="dist"
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# The Neovim config sits next to this script's directory: .config/dotfiles/
# here, .config/nvim/ there. True both in a $HOME checkout and in a CI checkout
# of the repo root.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$(cd "$SCRIPT_DIR/../nvim" && pwd)"

# Which language servers get baked in is NOT configured here. It is read out of
# the config itself further down, from whatever the server profile enables — see
# lua/plugins/lsp.lua. A list in this file would be a second source of truth in
# a different naming scheme (lspconfig calls it yamlls, Mason calls it
# yaml-language-server) and would quietly drift the moment either side changed.

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mbuild failed:\033[0m %s\n' "$*" >&2; exit 1; }

case "$(uname -m)" in
  x86_64)        ARCH=x86_64; NODE_ARCH=x64 ;;
  aarch64|arm64) ARCH=arm64;  NODE_ARCH=arm64 ;;
  *) die "no Neovim release build for $(uname -m)" ;;
esac

# npm is needed because Mason installs yaml-language-server and json-lsp from
# npm; cc because nvim-treesitter compiles parsers from source. Neither is
# needed on the target machine — that is the entire point of building here.
for tool in curl tar git cc jq npm; do
  command -v "$tool" >/dev/null 2>&1 || die "missing build dependency: $tool"
done

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT INT TERM
ROOT="$STAGE/nvim-portable"
mkdir -p "$ROOT/bin" "$ROOT/config" "$ROOT/data"

# --- Neovim itself -----------------------------------------------------------
say "Fetching Neovim ($ARCH)..."
NVIM_TMP="$STAGE/nvim-dl"; mkdir -p "$NVIM_TMP"
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${ARCH}.tar.gz" \
  | tar xz -C "$NVIM_TMP" || die "Neovim download failed"
mv "$NVIM_TMP"/nvim-linux-* "$ROOT/nvim"
NVIM="$ROOT/nvim/bin/nvim"
[ -x "$NVIM" ] || die "Neovim binary missing after extract"

# --- Node --------------------------------------------------------------------
# Mason installs yaml-language-server and json-lsp from npm, and their shims are
# `#!/usr/bin/env node` scripts — Mason does not bundle a runtime. Without this,
# the two most useful servers on a remote box silently fail to start. Only the
# binary is kept; npm and the headers are build-time concerns.
say "Fetching Node (LTS, $NODE_ARCH)..."
NODE_VER="$(curl -fsSL https://nodejs.org/dist/index.json \
  | jq -r '[.[] | select(.lts != false)][0].version')"
[ -n "$NODE_VER" ] && [ "$NODE_VER" != null ] || die "could not resolve Node LTS version"
NODE_TMP="$STAGE/node-dl"; mkdir -p "$NODE_TMP"
curl -fsSL "https://nodejs.org/dist/${NODE_VER}/node-${NODE_VER}-linux-${NODE_ARCH}.tar.xz" \
  | tar xJ -C "$NODE_TMP" || die "Node download failed"
cp "$NODE_TMP"/node-*/bin/node "$ROOT/bin/node"
chmod 755 "$ROOT/bin/node"

# --- Config ------------------------------------------------------------------
say "Staging the Neovim config..."
mkdir -p "$ROOT/config/nvim"
tar -C "$CONFIG_SRC" -cf - . | tar -C "$ROOT/config/nvim" -xf -
# Session.vim is a per-directory artifact of whatever machine built this, and
# has no business travelling. Config only.
rm -f "$ROOT/config/nvim/Session.vim"

# The workstation lockfile has to go, and this is not an optimisation.
# vim.pack treats the lockfile as the authority on what should be installed:
# lock_sync() walks every entry and clones any that is missing on disk,
# regardless of whether the config ever called vim.pack.add for it. Ship the
# 38-plugin workstation lock and the server profile is silently overridden —
# dap, neotest and rustaceanvim all reappear.
#
# Worse, that same behaviour would fire on the target machine: any lock entry
# without a matching directory becomes a git clone at startup, on a box that
# may have no network. Removing it lets vim.pack write a fresh lock describing
# exactly what this build installed, which is the only state that is safe at
# runtime. The bundle's own lock ships with resolved revisions, so the artifact
# stays fully described.
rm -f "$ROOT/config/nvim/nvim-pack-lock.json"

# Everything below runs the staged Neovim against the staged config, so what is
# exercised at build time is exactly what ships.
export XDG_CONFIG_HOME="$ROOT/config"
export XDG_DATA_HOME="$ROOT/data"
export XDG_STATE_HOME="$STAGE/state"
export XDG_CACHE_HOME="$STAGE/cache"
export NVIM_PROFILE=server
# Force modules that normally defer vim.pack.add until first keypress to load
# now, so diffview and trouble end up in the bundle instead of trying to clone
# themselves on a machine with no network. See config/pack.lua.
export NVIM_PREFETCH=1
export PATH="$ROOT/bin:$PATH"
# Mason's npm installs spawn Node, and Node writes deprecation warnings to
# stderr. Neovim surfaces anything a :command writes to stderr as an error,
# which aborts the install step even though the install itself worked.
export NODE_NO_WARNINGS=1

# nvim-treesitter's main branch shells out to the tree-sitter CLI to generate
# parsers; a C compiler alone is not enough. Kept in the staging area, not
# installed globally, and it never reaches the bundle — the target machine
# builds nothing.
if ! command -v tree-sitter >/dev/null 2>&1; then
  say "Installing the tree-sitter CLI (build-only)..."
  npm install --silent --no-fund --no-audit --prefix "$STAGE/npm" tree-sitter-cli >/dev/null 2>&1 \
    || die "could not install tree-sitter-cli"
  export PATH="$STAGE/npm/node_modules/.bin:$PATH"
fi
command -v tree-sitter >/dev/null 2>&1 || die "tree-sitter CLI still not on PATH"

# vim.pack.add defaults to confirm=true, which calls vim.fn.confirm() — an
# interactive prompt that has no good answer with no UI attached. Patch it off
# via --cmd, which runs before any config is loaded.
NO_CONFIRM='lua local a=vim.pack.add; vim.pack.add=function(s,o) return a(s, vim.tbl_extend("force", o or {}, {confirm=false})) end'

run_nvim() { "$NVIM" --headless --cmd "$NO_CONFIRM" "$@" +qa </dev/null; }

# --- Drift guard -------------------------------------------------------------
# Modules that defer vim.pack.add until first keypress only reach the bundle if
# they call config.pack.prefetch(). Nothing forces that at runtime, so adding a
# new lazy-loaded plugin would ship a bundle that looks fine and then fails the
# first time you press the key, on a machine with no network to recover from it.
#
# Every deferred module in this config marks itself with `local loaded = false`,
# so check that each one either prefetches or is deliberately absent from the
# server profile (see init.lua).
SERVER_EXCLUDED="dap neotest"
for f in "$CONFIG_SRC"/lua/plugins/*.lua; do
  grep -q 'local loaded = false' "$f" || continue
  base="$(basename "$f" .lua)"
  case " $SERVER_EXCLUDED " in *" $base "*) continue ;; esac
  grep -q 'prefetch(' "$f" || die "$base defers loading but never calls config.pack.prefetch() —
  it would be missing from the bundle. Add the prefetch call, or exclude the
  module from the server profile in init.lua and list it in SERVER_EXCLUDED."
done

# --- Plugins -----------------------------------------------------------------
say "Installing plugins..."
run_nvim 2>&1 | sed 's/^/    /'

PLUGIN_DIR="$ROOT/data/nvim/site/pack/core/opt"
PLUGIN_COUNT="$(find "$ROOT/data/nvim/site/pack" -mindepth 3 -maxdepth 3 -type d 2>/dev/null | wc -l)"
[ "$PLUGIN_COUNT" -gt 0 ] || die "no plugins were installed"

# The server profile must actually have taken effect. Cheap to assert, and the
# failure it catches is invisible otherwise: the bundle still works, it is just
# hundreds of megabytes of debugger and test-runner that can never run here.
for excluded in nvim-dap neotest rustaceanvim; do
  if [ -d "$PLUGIN_DIR/$excluded" ]; then
    die "$excluded was installed — NVIM_PROFILE=server did not take effect"
  fi
done
say "  $PLUGIN_COUNT plugins"

# --- Language servers --------------------------------------------------------
# Which servers get baked in is read out of the config, not listed here: take
# whatever the server profile enabled in lua/plugins/lsp.lua and translate it to
# Mason package names with mason-lspconfig's own mapping. Editing that table is
# therefore all it takes to change what the bundle ships.
#
# The refresh has to come first. That mapping is generated from the Mason
# registry, so before the registry is fetched it is not merely stale, it is
# empty — and an empty mapping yields an empty package list rather than an
# error, which is how this silently produced a bundle with no servers at all.
SERVERS_FILE="$STAGE/servers.txt"
say "Installing language servers (derived from lsp.lua)..."
run_nvim -c "lua
  local reg = require('mason-registry')
  local refreshed = false
  reg.refresh(function() refreshed = true end)
  if not vim.wait(120000, function() return refreshed end, 100) then
    io.stderr:write('mason registry refresh timed out\n')
    vim.cmd('cquit 1')
  end

  local map = require('mason-lspconfig').get_mappings().lspconfig_to_package
  local enabled = vim.lsp._enabled_configs or {}
  local want = {}
  for name in pairs(enabled) do
    if map[name] then want[#want + 1] = map[name] end
  end
  table.sort(want)

  if #want == 0 then
    io.stderr:write(('derived no servers: %d enabled [%s], %d mapping entries\n')
      :format(vim.tbl_count(enabled), table.concat(vim.tbl_keys(enabled), ','), vim.tbl_count(map)))
    vim.cmd('cquit 1')
  end
  vim.fn.writefile(want, '$SERVERS_FILE')
  io.stderr:write('installing: ' .. table.concat(want, ' ') .. '\n')

  -- pcall because a Node deprecation warning on stderr makes :MasonInstall look
  -- like it failed when it did not. The poll below is what decides.
  pcall(vim.cmd, 'MasonInstall ' .. table.concat(want, ' '))
  local ok = vim.wait(900000, function()
    for _, n in ipairs(want) do
      if not reg.get_package(n):is_installed() then return false end
    end
    return true
  end, 1000)
  if not ok then
    for _, n in ipairs(want) do
      if not reg.get_package(n):is_installed() then io.stderr:write('NOT INSTALLED: ' .. n .. '\n') end
    end
    vim.cmd('cquit 1')
  end
" 2>&1 | sed 's/^/    /'

[ -s "$SERVERS_FILE" ] || die "no language servers were derived from the config"
mapfile -t MASON_PKGS <"$SERVERS_FILE"
for p in "${MASON_PKGS[@]}"; do
  [ -d "$ROOT/data/nvim/mason/packages/$p" ] || die "language server missing after install: $p"
done
say "  ${MASON_PKGS[*]}"

# --- Treesitter parsers ------------------------------------------------------
# nvim-treesitter's main branch compiles from source, which is exactly what the
# target machine cannot do — so it has to happen here.
say "Building treesitter parsers..."
run_nvim -c "lua
  local ts = require('nvim-treesitter')
  local want = require('config.parsers')
  ts.install(want):wait(1800000)

  -- Some grammars generate a very large parser.c, and the tree-sitter CLI
  -- compiles at an optimisation level whose peak memory is wildly out of
  -- proportion to it: gitcommit needs 3.7GB at the default, versus 630MB at
  -- -O1, for a 3MB source file. On a build machine with less than ~4GB free
  -- the compiler is simply OOM-killed ('cc1: Killed').
  --
  -- So keep the fast default for everything that fits, and retry only the
  -- casualties at -O1. The tree-sitter CLI honours CFLAGS. Parsers built this
  -- way are marginally slower, which is a good trade against not having them.
  local installed = {}
  for _, p in ipairs(ts.get_installed('parsers')) do installed[p] = true end
  for _, p in ipairs(want) do
    if not installed[p] then
      io.write('retrying ' .. p .. ' at -O1 (default optimisation ran out of memory)\n')
      vim.env.CFLAGS = '-O1'
      pcall(function() ts.install(p):wait(600000) end)
      vim.env.CFLAGS = nil
    end
  end
" 2>&1 | sed 's/^/    /'

# Assert by name, not by count. Neovim's own runtime ships several parsers, so
# a count comparison silently passes while a requested parser is missing — an
# earlier build shipped 25 '.so' files with gitcommit absent.
MISSING="$("$NVIM" --headless --cmd "$NO_CONFIRM" -c "lua
  local installed = {}
  for _, p in ipairs(require('nvim-treesitter').get_installed('parsers')) do installed[p] = true end
  local missing = {}
  for _, p in ipairs(require('config.parsers')) do
    if not installed[p] then missing[#missing + 1] = p end
  end
  io.write(table.concat(missing, ' '))
" +qa </dev/null 2>/dev/null)"
[ -z "$MISSING" ] || die "treesitter parsers failed to build: $MISSING"
PARSER_COUNT="$("$NVIM" --headless --cmd "$NO_CONFIRM" \
  -c 'lua io.write(#require("nvim-treesitter").get_installed("parsers"))' +qa </dev/null 2>/dev/null | tr -dc '0-9')"
say "  $PARSER_COUNT parsers, all requested ones present"

# --- Trim --------------------------------------------------------------------
# Plugin git history is the bulk of the plugin tree and is useless in a bundle
# that never updates itself. Deliberately conservative otherwise: plugins do
# sometimes load files out of directories that look like test fixtures, and a
# smaller tarball is not worth an editor that breaks in an unobvious way.
say "Trimming..."
BEFORE_KB="$(du -sk "$ROOT" | cut -f1)"
find "$ROOT/data/nvim/site" -type d -name '.git' -prune -exec rm -rf {} + 2>/dev/null || true
rm -rf "$ROOT/data/nvim/mason/tmp" "$ROOT/data/nvim/mason/staging" 2>/dev/null || true
find "$ROOT" -type f \( -name '*.tar.gz' -o -name '*.zip' \) -delete 2>/dev/null || true
say "  $(( (BEFORE_KB - $(du -sk "$ROOT" | cut -f1)) / 1024 ))MB reclaimed"

# --- Launcher ----------------------------------------------------------------
cat >"$ROOT/run" <<'LAUNCHER'
#!/bin/sh
# Portable Neovim. Extract anywhere, run this. Needs no root and no network.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# State (undo history, shada, swap) is ephemeral by default: nvim records the
# path of every file opened, and on a machine that isn't yours that trail
# should not outlive the session. Set NVIM_PORTABLE_STATE to a directory to
# keep it — worth doing on your own infrastructure.
if [ -n "${NVIM_PORTABLE_STATE:-}" ]; then
  state=$NVIM_PORTABLE_STATE
  mkdir -p "$state"
  keep=1
else
  state=$(mktemp -d "${TMPDIR:-/tmp}/nvim-portable.XXXXXX")
  keep=0
  trap 'rm -rf "$state"' EXIT INT TERM
fi

NVIM_PROFILE=server
XDG_CONFIG_HOME=$root/config
XDG_DATA_HOME=$root/data
XDG_STATE_HOME=$state
XDG_CACHE_HOME=$state/cache
PATH=$root/bin:$PATH
export NVIM_PROFILE XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME PATH

# Deliberately not exec in the ephemeral case: exec replaces this shell, and
# the EXIT trap above goes with it, leaving the state directory behind on every
# single run. Only exec when there is nothing to clean up.
if [ "$keep" = 1 ]; then
  exec "$root/nvim/bin/nvim" "$@"
fi
"$root/nvim/bin/nvim" "$@"
LAUNCHER
chmod 755 "$ROOT/run"

# The highest glibc symbol version any shipped binary references — i.e. the
# oldest distro this bundle can run on. Recorded rather than assumed, since it
# moves whenever Neovim or Node change their build images.
glibc_floor() {
  local max
  max="$(objdump -T "$@" 2>/dev/null | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1)"
  printf '%s' "${max:-unknown}"
}

cat >"$ROOT/BUILD-INFO" <<EOF
built:     $(date -u +%Y-%m-%dT%H:%M:%SZ)
arch:      $ARCH
neovim:    $("$NVIM" --version | head -1)
node:      $NODE_VER
plugins:   $PLUGIN_COUNT
parsers:   $PARSER_COUNT
servers:   ${MASON_PKGS[*]}
config:    $(cd "$CONFIG_SRC" && git rev-parse --short HEAD 2>/dev/null || echo "not a git checkout")
glibc-min: $(glibc_floor "$ROOT/nvim/bin/nvim" "$ROOT/bin/node")
EOF
cat "$ROOT/BUILD-INFO"

# --- Package -----------------------------------------------------------------
mkdir -p "$OUT_DIR"
TARBALL="$OUT_DIR/nvim-portable-${ARCH}.tar.gz"
say "Packaging $TARBALL..."
tar -C "$STAGE" -czf "$TARBALL" nvim-portable
say "Done: $TARBALL ($(du -h "$TARBALL" | cut -f1))"
