# dotfiles

A macOS dev environment, managed as a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles)
checked out against `$HOME` — no symlinks, files live exactly where the
programs that use them expect to find them.

## What's here

| Path | What it is |
|---|---|
| `.zshrc`, `.zprofile` | Shell config: history, completion system (compinit, fzf-tab, autosuggestions, syntax highlighting), starship prompt, modern CLI replacements aliased over familiar commands (`ls`→eza, `cat`→bat, `cd`→zoxide-enhanced, `grep`→rg), man pages piped through bat |
| `.gitconfig`, `.config/git/ignore` | Git config — delta as the diff/show pager, global excludes, and an include of an untracked local file (see below) |
| `.config/nvim/` | Neovim config — kickstart.nvim baseline, modular (`lua/config/`, `lua/plugins/`), native `vim.pack` (not lazy.nvim) |
| `.config/starship.toml` | Shell prompt, kanagawa-dragon colors |
| `.config/ghostty/config` | Terminal config — kanagawa-dragon theme |
| `.dotfiles-ignore` | Safety net, see below |
| `.config/dotfiles/Brewfile` | Every Homebrew formula/cask this environment needs |
| `.config/dotfiles/bootstrap.sh` | Sets up a fresh machine end to end, see below |

Theme is kanagawa-dragon end to end — Ghostty, Neovim, and starship all match.

Not tracked here: MSP tooling notes live in Obsidian, not this repo.

## Setup on a new machine

On a factory-fresh Mac the first `git` command triggers the Xcode Command
Line Tools install dialog — click through it and re-run. Everything else,
Homebrew included, is handled by `bootstrap.sh` below.

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

Then run the bootstrap script — installs Xcode CLT/Homebrew if missing,
every formula/cask in `Brewfile`, sets rustup's default toolchain, fetches
nuclei's templates, and installs the M365/Exchange Online PowerShell
modules. Safe to re-run; every step is idempotent:

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
