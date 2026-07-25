# dotfiles

A macOS and Linux dev environment, managed as a
[bare git repo](https://www.atlassian.com/git/tutorials/dotfiles) checked out
against `$HOME` — no symlinks, files live exactly where the programs that use
them expect to find them.

The same checkout works on macOS, Debian/Ubuntu, Fedora, and Arch; `bootstrap.sh`
detects the platform and installs accordingly. See
[Platform support](#platform-support) for what's verified where.

## What's here

| Path | What it is |
|---|---|
| `.zshrc`, `.zprofile` | Shell config: history, completion system (compinit, fzf-tab, autosuggestions, syntax highlighting), starship prompt, modern CLI replacements aliased over familiar commands (`ls`→eza, `cat`→bat, `cd`→zoxide-enhanced, `grep`→rg), man pages piped through bat |
| `.gitconfig`, `.config/git/ignore` | Git config — delta as the diff/show pager, global excludes, and an include of an untracked local file (see below) |
| `.config/nvim/` | Neovim config — kickstart.nvim baseline, modular (`lua/config/`, `lua/plugins/`), native `vim.pack` (not lazy.nvim) |
| `.config/starship.toml` | Shell prompt, kanagawa-dragon colors |
| `.config/ghostty/config` | Terminal config — kanagawa-dragon theme |
| `.dotfiles-ignore` | Safety net, see below |
| `.config/dotfiles/Brewfile` | Every Homebrew formula/cask this environment needs (macOS) |
| `.config/dotfiles/packages.linux` | The Linux equivalent — one table mapping each tool to its apt/dnf/pacman package name |
| `.config/dotfiles/bootstrap.sh` | Sets up a fresh machine end to end on any supported platform, see below |
| `.config/dotfiles/build-portable.sh` | Builds the self-contained Neovim bundle for remote servers, see below |
| `.config/dotfiles/nvim-go.sh` | One-liner that fetches and runs that bundle on a box you've SSHed into |

Theme is kanagawa-dragon end to end — Ghostty, Neovim, and starship all match.

Not tracked here: MSP tooling notes live in Obsidian, not this repo.

## Setup on a new machine

The only prerequisite is `git` itself. On a factory-fresh Mac the first `git`
command triggers the Xcode Command Line Tools install dialog — click through it
and re-run. On a minimal Linux image, install `git` (and `tar`) from your
package manager first. Everything else — Homebrew, Neovim, every tool — is
handled by `bootstrap.sh` below.

```sh
git clone --bare https://github.com/agoratopia/dotfiles.git "$HOME/.dotfiles"
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

If `checkout` fails because existing files would be overwritten, back them up
and retry. The loop recreates each file's parent directory in the backup, so
nested paths like `.config/nvim/init.lua` survive:

```sh
mkdir -p ~/.dotfiles-backup
dotfiles checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | while read -r f; do
  mkdir -p ~/.dotfiles-backup/"$(dirname "$f")"
  mv "$f" ~/.dotfiles-backup/"$f"
done
dotfiles checkout
```

Then run the bootstrap script. It detects the platform and does the right
thing: on macOS, Xcode CLT and Homebrew if missing plus everything in
`Brewfile`; on Linux, every package in `packages.linux` through apt, dnf, or
pacman. Either way it sets up the Rust toolchain, fetches nuclei's templates,
and installs the M365/Exchange Online PowerShell modules. Safe to re-run;
every step is idempotent:

```sh
~/.config/dotfiles/bootstrap.sh
```

A few things genuinely can't be scripted and the script will tell you about
them at the end: Wireshark's packet-capture permission (ChmodBPF needs an
admin password prompt), Ghostty's quick-terminal hotkey (needs Accessibility
permission granted in System Settings), and `bw login` for Bitwarden (your
actual master password, not something to automate).

## Usage

Everything in `$HOME` is ignored by default (see `.dotfiles-ignore`), so
adding a new file requires `-f`:

```sh
dotfiles add -f .some_new_dotfile
dotfiles commit -m "add .some_new_dotfile"
dotfiles push
```

This prevents an accidental `dotfiles add .` from sweeping in your entire
home directory.

## Platform support

`bootstrap.sh` detects the platform and installs accordingly — Homebrew and
`Brewfile` on macOS, apt/dnf/pacman and `packages.linux` on Linux. The dotfiles
themselves are identical everywhere; `.zshrc` probes for tools and plugin
directories rather than assuming one layout, so a partially provisioned machine
still gets a working shell instead of a screenful of errors.

Four things genuinely differ on Linux:

**Neovim does not come from your package manager.** This config uses
`vim.pack`, which needs Neovim 0.12+, and distro packages lag badly — Ubuntu
24.04 ships 0.9.5, where `vim.pack` does not exist at all and the config cannot
load. `bootstrap.sh` installs the official release build into `~/.local/nvim`
and links it into `~/.local/bin`.

**Debian and Ubuntu rename two binaries.** `fd` is `fdfind` there and `bat` is
`batcat`. Bootstrap symlinks both into `~/.local/bin` rather than aliasing
them, because Neovim and Telescope never see shell aliases and would otherwise
silently fall back to slower defaults.

**A few tools have no distro package** and are installed directly: rustup and
starship from their official installers, and nuclei, glow and yq via
`go install`. That compile step is the slow part of a Linux bootstrap — budget
several minutes.

**Not everything exists on every distro.** Bootstrap asks the package manager
what it actually has before installing, so a missing package never fails the
run; whatever was skipped is listed at the end.

Ghostty is not installed on Linux — its config is checked out and will be used
if you install Ghostty yourself, but bootstrap doesn't pull a GUI terminal onto
what might be a server or WSL box.

### WSL

WSL is detected via `/proc/version` and `$WSL_DISTRO_NAME`, and otherwise
follows its distro's path. Two caveats it will remind you about:

- Neovim's clipboard provider needs
  [win32yank](https://github.com/equalsraf/win32yank/releases) on `PATH` for
  `"+y` to reach Windows. `clip.exe` can copy but never paste.
- The Ghostty config is inert — use a Windows terminal emulator instead.

### What's actually verified

Each Linux platform below was exercised in a container from a clean image:
the real `bootstrap.sh`, then a real interactive zsh, then a real Neovim
launch — not a dry run.

| Platform | bootstrap | shell | Neovim | Notes |
|---|---|---|---|---|
| macOS (Apple Silicon) | daily driver | ✅ | ✅ | the primary environment |
| Ubuntu 24.04 | ✅ | ✅ | 0.12.4, 38 plugins | |
| Debian 13 | ✅ | ✅ | 0.12.4, 38 plugins | `nikto` no longer packaged |
| Fedora 44 | ✅ | ✅ | 0.12.4, 38 plugins | needs versioned Node streams |
| Arch | ✅ | ✅ | 0.12.4, 38 plugins | see caveat below |
| WSL2 | detection only | — | — | not run against a real WSL install |

Re-running is genuinely a no-op: a second bootstrap on Ubuntu took 17s against
284s for the first, with zero reinstall attempts.

Two honest caveats. Arch has no arm64 image, so it was tested under x86
emulation; there, `go install` segfaults inside Go's own module code — a
QEMU/Go interaction, not a fault in this setup — so `nuclei` and `glow` are
the only pieces not proven on Arch. And WSL is covered only by its detection
logic (both `/proc/version` and `$WSL_DISTRO_NAME`, confirmed not to
false-positive on plain Linux); the rest follows its distro's path, which is
tested, but no real WSL install has run this.

## Portable Neovim for servers you SSH into

Running `bootstrap.sh` on a box makes sense when it's yours. On a client's
server it doesn't: it installs packages, needs sudo, and leaves a home
directory full of things that weren't there before.

So there's a second artifact — a single tarball containing Neovim, this config,
and every plugin, language server and treesitter parser already built. It needs
no root, no package manager, no compiler and no network, and by default it
leaves nothing behind.

```sh
# Run it once and leave no trace
curl -fsSL https://github.com/agoratopia/dotfiles/releases/download/portable-latest/nvim-go.sh | sh

# ...on a particular file
curl -fsSL .../nvim-go.sh | sh -s -- /etc/nginx/nginx.conf

# Or keep it, on a machine you own
curl -fsSL .../nvim-go.sh | sh -s -- --install   # -> ~/.local/bin/nvim-portable
```

`portable-latest` is a rolling release that CI replaces whenever the Neovim
config changes, rather than `/releases/latest/`, which would point at whichever
release was published most recently — a pinned version tag would take it over.

Ephemeral is the default because Neovim records the path of every file you open
in its shada file, and writes undo history alongside it. The launcher points
all of that at a temp directory and deletes it on exit, so none of it outlives
the session on someone else's machine. `--install` keeps it instead, under
`~/.local/state/nvim-portable`, which is what you want on your own boxes.

**Which mode to use.** The ephemeral one-liner downloads ~100MB and throws it
away every time you quit, so it's for a box you're touching once. Anywhere
you'll come back to, use `--install`: it downloads once and you then just run
`nvim-portable`, with undo history and marks persisting between sessions.
Re-run with `--install` to update it.

### What's different about the server profile

The bundle runs the same config under `NVIM_PROFILE=server` (see
`lua/config/profile.lua`). Six things change, each because the workstation
behaviour is actively wrong on a machine that isn't yours:

| | Why |
|---|---|
| No Mason or treesitter installs at runtime | Everything is prebuilt. A client's server may have no egress, and certainly has no compiler. |
| No dap, neotest or rustaceanvim | These need the project's own toolchain resolved locally. |
| Only yaml, json, toml and markdown servers | gopls and basedpyright need modules and virtualenvs a remote box doesn't have — and they're 320MB of the 804MB Mason tree. |
| No format-on-save | Turning a one-line fix to someone else's config into a whole-file reformat is rude and unreviewable. `<leader>f` still works. |
| No session writing | It writes `Session.vim` into the working directory, i.e. into their `/etc/nginx`. |
| Ships its own Node | Mason's yaml and json servers are `#!/usr/bin/env node` scripts and Mason bundles no runtime, so without this the two most useful servers silently fail to start. |

Copying works over SSH: with no X11 or Wayland to talk to, the profile switches
the clipboard to OSC 52, which tunnels the copy through the terminal itself, so
`"+y` reaches the machine in front of you. Pasting back needs the terminal to
answer an OSC 52 query and many refuse to, for good security reasons — use your
terminal's own paste when it doesn't.

### Keeping the bundle from drifting

The bundle is built from `.config/nvim/` in this repo, and there is deliberately
nothing to keep in sync by hand:

- **Editing the config republishes the bundle.** CI rebuilds on any push to
  `main` that touches `.config/nvim/**` or the build scripts, and replaces the
  rolling `portable-latest` release — which is exactly what `nvim-go.sh`
  downloads. Change the config, push, and the next `curl | sh` on a server has
  it. An `--install`ed copy is updated by re-running with `--install`.
- **No duplicated lists.** The language servers come from whatever the server
  profile enables in `lua/plugins/lsp.lua`, translated to Mason package names by
  mason-lspconfig's own mapping. The treesitter parsers come from
  `lua/config/parsers.lua`, the same module the live config reads. Neither is
  restated in the build script.
- **The build fails rather than shipping something stale.** It refuses if a
  parser is missing by name, if a language server didn't install, or if a
  plugin the server profile excludes turns up anyway.
- **Lazy-loaded plugins are caught.** Anything deferring `vim.pack.add` until
  first keypress has to call `config.pack.prefetch()` or it won't be in the
  bundle — and would then fail on a machine with no network to fetch it. The
  build greps for the deferral pattern and refuses to proceed if a module
  defers without prefetching.
- **Every bundle records what it came from.** `BUILD-INFO` inside the tarball
  carries the config commit, Neovim and Node versions, and the plugin, parser
  and server counts.

The one thing that isn't automatic: adding a *new* language server to the
server profile means editing the `servers` table in `lua/plugins/lsp.lua` under
the `profile.server` branch. The build follows whatever is there.

### What's actually verified

The bundle was exercised from a clean image with `--network none`, as a non-root
user, with the bundle directory mode 555 and no `git`, `node`, `cc` or `nvim` on
the machine:

| Check | Result |
|---|---|
| Launches offline, unprivileged, read-only | ✅ |
| yamlls attaches to a `.yaml` buffer | ✅ with no network |
| Treesitter parsers load | ✅ 6/6 sampled, no compiler present |
| Server profile active | ✅ 4 language servers, format-on-save off |
| OSC 52 copy reaches the terminal | ✅ verified through a real pty |
| Writes nothing to `$HOME` | ✅ |
| Ephemeral state directory removed on exit | ✅ |
| `nvim-go.sh`, both modes | ✅ install, ephemeral, and the no-tty refusal |

macOS is unaffected: an interleaved A/B of 25 runs each against the pre-change
config puts them within noise of each other (p50 50.3ms after vs 50.4ms before),
and the two new modules cost 0.163ms combined.

### Requirements, and the one real limitation

**glibc 2.34.** This is inherited from Neovim's own official release build, not
from anything here, and it's the binding constraint:

| Works | Does not |
|---|---|
| Ubuntu 22.04+, Debian 12+, RHEL/Rocky/Alma 9+, Fedora 35+ | Ubuntu 20.04, Debian 11, RHEL/CentOS 8 and older |

Confirmed by running it: Debian 12 (glibc 2.36) and Rocky 9 (2.34, the exact
boundary) both launch; Ubuntu 20.04 (2.31) fails immediately with
`version 'GLIBC_2.33' not found`. The bundled Node is not the constraint — it
only needs 2.28.

There's no easy way around it. The AppImage Neovim also publishes is built from
the same binary, so it carries the same floor and adds a FUSE dependency.
Reaching older boxes would mean building Neovim from source against an older
glibc, or falling back to a container on those specific machines.

### Building it

CI does this on tag push (`.github/workflows/build-portable.yml`), building
each architecture on its own native runner — this compiles treesitter parsers
from source, and emulated toolchains have already proven unreliable for this
repo. To build one by hand:

```sh
docker run --rm -v "$HOME:/src:ro" -v "$PWD/dist:/dist" ubuntu:24.04 \
  bash -c 'apt-get update -qq && apt-get install -y -qq curl git build-essential jq xz-utils binutils nodejs npm && /src/.config/dotfiles/build-portable.sh --out /dist'
```

## Keeping private settings out of a public `.gitconfig`

`.gitconfig` is tracked here, so anything written into it is published. The
identity in it (`agoratopia` and a GitHub noreply address) is deliberately
public — but `git config --global ...` writes to that same file, and since
it's already tracked, a stray `commit -a` would sweep the change in.

So the last thing `.gitconfig` does is include an untracked file:

```ini
[include]
	path = ~/.config/git/local
```

Git skips the include silently if the file is absent, and values there
override everything above it. Work identity, signing keys, and per-client
`includeIf` rules go there and never reach the repo.

## Why this file lives in `.github/`

For a bare repo checked out against `$HOME`, the actual repo root *is*
`$HOME` — so a plain `README.md` at the root would mean a visible,
non-hidden file sitting in your home directory, which this whole setup is
built to avoid. GitHub happens to check `.github/README.md` *before* the
repo root when deciding what to render on the landing page, so the real
content lives at `.github/README.md` instead — a hidden directory, same as
every other dotfile here, but GitHub still renders it exactly the same way
it would a root-level README.
