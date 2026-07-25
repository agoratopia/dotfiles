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
