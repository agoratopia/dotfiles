# dotfiles

Managed as a bare git repo checked out against `$HOME`, rather than symlinks.

## Setup on a new machine

```sh
git clone --bare git@github.com:agoratopia/dotfiles.git "$HOME/.dotfiles"
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

## Usage

Everything in `$HOME` is ignored by default (see `.dotfiles-ignore`), so adding a
new file requires `-f`:

```sh
dotfiles add -f .some_new_dotfile
dotfiles commit -m "add .some_new_dotfile"
dotfiles push
```

This prevents an accidental `dotfiles add .` from sweeping in your entire home
directory.
