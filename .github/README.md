# dotfiles

Zac's macOS dev environment, managed as a [bare git repo](https://www.atlassian.com/git/tutorials/dotfiles)
checked out against `$HOME` — no symlinks, files live exactly where the
programs that use them expect to find them.

## What's here

| Path | What it is |
|---|---|
| `.zshrc`, `.zprofile` | Shell config: history, completion system (compinit, fzf-tab, autosuggestions, syntax highlighting), starship prompt, modern CLI replacements aliased over familiar commands (`ls`→eza, `cat`→bat, `cd`→zoxide-enhanced, `grep`→rg), man pages piped through bat |
| `.gitconfig`, `.config/git/ignore` | Git config — delta as the diff/show pager, global excludes |
| `.config/nvim/` | Neovim config — kickstart.nvim baseline, modular (`lua/config/`, `lua/plugins/`), native `vim.pack` (not lazy.nvim) |
| `.config/starship.toml` | Shell prompt, kanagawa-dragon colors |
| `.config/ghostty/config` | Terminal config — kanagawa-dragon theme (see note below on why there's also a stub file) |
| `.dotfiles-ignore` | Safety net, see below |
| `.config/dotfiles/Brewfile` | Every Homebrew formula/cask this environment needs |
| `.config/dotfiles/bootstrap.sh` | Sets up a fresh machine end to end, see below |

Theme is kanagawa-dragon end to end — Ghostty, Neovim, and starship all match.

Not tracked here: MSP tooling notes live in Obsidian, not this repo.

## Setup on a new machine

```sh
git clone --bare https://github.com/agoratopia/dotfiles.git "$HOME/.dotfiles"
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles checkout
dotfiles config --local status.showUntrackedFiles no
```

If `checkout` fails because existing files would be overwritten, back them up and retry:

```sh
mkdir -p ~/.dotfiles-backup
dotfiles checkout 2>&1 | grep -E "^\s+" | awk '{print $1}' | xargs -I{} mv {} ~/.dotfiles-backup/{}
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

## Why there's a stub at `Library/Application Support/com.mitchellh.ghostty/`

Ghostty only reads its config from that exact macOS-bundle-ID path — it
does not honor `~/.config/ghostty/config` (XDG_CONFIG_HOME), confirmed by
testing directly. Rather than track the real config at that awkward path,
`Library/Application Support/com.mitchellh.ghostty/config.ghostty` is just
a one-line redirect (`config-file = ?~/.config/ghostty/config`) — no
symlink, just Ghostty's own built-in config-include directive. The actual
content lives at `.config/ghostty/config`, same convention as everything
else here.

## Why this file lives in `.github/`

For a bare repo checked out against `$HOME`, the actual repo root *is*
`$HOME` — so a plain `README.md` at the root would mean a visible,
non-hidden file sitting in your home directory, which this whole setup is
built to avoid. GitHub happens to check `.github/README.md` *before* the
repo root when deciding what to render on the landing page, so the real
content lives at `.github/README.md` instead — a hidden directory, same as
every other dotfile here, but GitHub still renders it exactly the same way
it would a root-level README.
