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
| `Library/Application Support/com.mitchellh.ghostty/config.ghostty` | Terminal config — kanagawa-dragon theme |
| `.dotfiles-ignore` | Safety net, see below |

Theme is kanagawa-dragon end to end — Ghostty, Neovim, and starship all match.

Not tracked here: Homebrew packages (network/security tooling, PowerShell
modules, etc.) are installed but not dotfiles-managed — see
`brew leaves`/`brew list` for what's on this machine. MSP tooling notes
live in Obsidian, not this repo.

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

Then install Homebrew and everything referenced above (neovim, starship,
eza, bat, zoxide, fzf, ripgrep, fd, tree-sitter-cli, node, go, rustup,
git-delta, the zsh completion/suggestion/highlighting formulae, Ghostty,
Iosevka Nerd Font) — there's no single bootstrap script for this yet, it's
built up incrementally.

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

## Why this file lives in `.github/`

For a bare repo checked out against `$HOME`, the actual repo root *is*
`$HOME` — so a plain `README.md` at the root would mean a visible,
non-hidden file sitting in your home directory, which this whole setup is
built to avoid. GitHub happens to check `.github/README.md` *before* the
repo root when deciding what to render on the landing page, so the real
content lives at `.github/README.md` instead — a hidden directory, same as
every other dotfile here, but GitHub still renders it exactly the same way
it would a root-level README.
