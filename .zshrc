# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"

# --- History ---
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY       # live-share history across all open sessions/tabs
setopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS    # don't record a line that repeats the previous one
setopt HIST_IGNORE_ALL_DUPS # keep only the most recent occurrence of a duplicate
setopt HIST_IGNORE_SPACE   # lines starting with a space aren't recorded (secrets/tokens)
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY         # show history expansions (e.g. !!) before running them
setopt EXTENDED_HISTORY    # store timestamp + duration per entry

# --- Aliases ---
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Modern CLI replacements — same commands, better output, no new muscle memory.
#
# Each is guarded on the tool existing: between checking this repo out and
# bootstrap.sh finishing, none of these are installed yet, and an unguarded
# alias would leave `ls` and `cat` themselves broken. Guarded, a half-set-up
# machine just falls back to the real commands.
(( $+commands[eza] )) && alias ls='eza --icons --group-directories-first'
(( $+commands[bat] )) && alias cat='bat --paging=never --style=plain'
# NOTE: ripgrep recurses and respects .gitignore by default, unlike grep —
# usually what you want, but worth knowing if a search seems to "miss" files
# that are gitignored/hidden.
(( $+commands[rg] )) && alias grep='rg'

# --- Tool integrations ---
# man stays man, just renders through bat for syntax highlighting/paging
(( $+commands[bat] )) && export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# lynis hardcodes lynis.log/lynis-report.dat into $HOME when not run as root
# (no CLI flag to redirect this) — same command, just auto-tidied afterward.
lynis() {
  command lynis "$@"
  local dest="$HOME/.local/share/lynis"
  mkdir -p "$dest"
  [[ -f "$HOME/lynis.log" ]] && mv "$HOME/lynis.log" "$dest/"
  [[ -f "$HOME/lynis-report.dat" ]] && mv "$HOME/lynis-report.dat" "$dest/"
}

(( $+commands[zoxide] )) && eval "$(zoxide init zsh --cmd cd)"  # cd gains fuzzy jump-to-frecent-dir, falls through to real cd for literal paths
(( $+commands[fzf] ))    && eval "$(fzf --zsh)"                 # enhances existing Ctrl+R (history) / Ctrl+T (file) keybindings

# --- Completion system ---
# zsh-completions adds definitions beyond what's already in fpath; must be
# added before compinit runs.
[[ -d /opt/homebrew/share/zsh-completions ]] && fpath=(/opt/homebrew/share/zsh-completions $fpath)

# Cached compinit: only re-scan fpath and re-verify security once every 24h,
# instead of on every single new shell/tab.
#
# The (#q...) glob qualifier needs EXTENDED_GLOB, which zsh does not enable by
# default. Without it the test never matches, the cached branch is unreachable,
# and every shell silently pays the full ~150ms rescan. Enabled only for the
# test and restored right after, so # ^ ~ keep their normal meaning in globs.
autoload -Uz compinit
setopt EXTENDED_GLOB
_zcompdump_fresh=( ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh-24) )
unsetopt EXTENDED_GLOB
if (( ${#_zcompdump_fresh} )); then
  compinit -C   # dump is under 24h old — trust it, skip the rescan
else
  compinit      # missing or stale — full rescan + fpath security check
fi
unset _zcompdump_fresh

# fzf-tab: fzf-powered interactive Tab-completion menu. No brew formula, so
# this self-bootstraps via git clone on first run. Must load after compinit,
# before any widget-wrapping plugin (autosuggestions/syntax-highlighting).
#
# Pinned to an explicit commit: this is the only third-party code that
# auto-executes in every shell, and an unpinned clone means each machine gets
# whatever master happened to be that day. 24105b1 is three fixes past the
# v1.3.0 tag and is the revision this environment was built against — bump it
# deliberately, not by accident.
FZF_TAB_DIR="$HOME/.local/share/zsh/plugins/fzf-tab"
FZF_TAB_REV="24105b15714bfec37989ed5c5b6e60f572253019"
if [[ ! -d "$FZF_TAB_DIR" ]]; then
  if git clone --quiet https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"; then
    git -C "$FZF_TAB_DIR" checkout --quiet "$FZF_TAB_REV"
  else
    print -u2 "fzf-tab: clone failed — Tab completion falls back to zsh's default"
  fi
fi
# Guarded so a failed or partial clone doesn't throw an error in every shell
# from here on; you just lose the fancy completion menu until it's fixed.
[[ -r "$FZF_TAB_DIR/fzf-tab.plugin.zsh" ]] && source "$FZF_TAB_DIR/fzf-tab.plugin.zsh"

# Inline history-based suggestions (accept with → or End)
[[ -r /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] &&
  source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

(( $+commands[starship] )) && eval "$(starship init zsh)"

# Syntax highlighting while typing — must be sourced last, after every other
# widget-wrapping plugin above.
[[ -r /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] &&
  source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
