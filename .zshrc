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

# Modern CLI replacements — same commands, better output, no new muscle memory
alias ls='eza --icons --group-directories-first'
alias cat='bat --paging=never --style=plain'
# NOTE: ripgrep recurses and respects .gitignore by default, unlike grep —
# usually what you want, but worth knowing if a search seems to "miss" files
# that are gitignored/hidden.
alias grep='rg'

# --- Tool integrations ---
# man stays man, just renders through bat for syntax highlighting/paging
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# lynis hardcodes lynis.log/lynis-report.dat into $HOME when not run as root
# (no CLI flag to redirect this) — same command, just auto-tidied afterward.
lynis() {
  command lynis "$@"
  local dest="$HOME/.local/share/lynis"
  mkdir -p "$dest"
  [[ -f "$HOME/lynis.log" ]] && mv "$HOME/lynis.log" "$dest/"
  [[ -f "$HOME/lynis-report.dat" ]] && mv "$HOME/lynis-report.dat" "$dest/"
}

eval "$(zoxide init zsh --cmd cd)"  # cd gains fuzzy jump-to-frecent-dir, falls through to real cd for literal paths
eval "$(fzf --zsh)"                 # enhances existing Ctrl+R (history) / Ctrl+T (file) keybindings

# --- Completion system ---
# zsh-completions adds definitions beyond what's already in fpath; must be
# added before compinit runs.
fpath=(/opt/homebrew/share/zsh-completions $fpath)

# Cached compinit: only re-scans fpath and re-verifies security once every
# 24h, instead of on every single new shell/tab.
autoload -Uz compinit
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

# fzf-tab: fzf-powered interactive Tab-completion menu. No brew formula, so
# this self-bootstraps via git clone on first run. Must load after compinit,
# before any widget-wrapping plugin (autosuggestions/syntax-highlighting).
FZF_TAB_DIR="$HOME/.local/share/zsh/plugins/fzf-tab"
[[ -d "$FZF_TAB_DIR" ]] || git clone --quiet https://github.com/Aloxaf/fzf-tab "$FZF_TAB_DIR"
source "$FZF_TAB_DIR/fzf-tab.plugin.zsh"

# Inline history-based suggestions (accept with → or End)
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh

eval "$(starship init zsh)"

# Syntax highlighting while typing — must be sourced last, after every other
# widget-wrapping plugin above.
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
