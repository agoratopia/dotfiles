export PATH="$HOME/.local/bin:$PATH"
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"

alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles --work-tree=$HOME'

# Modern CLI replacements — same commands, better output, no new muscle memory
alias ls='eza --icons --group-directories-first'
alias cat='bat --paging=never --style=plain'

eval "$(zoxide init zsh --cmd cd)"  # cd gains fuzzy jump-to-frecent-dir, falls through to real cd for literal paths
eval "$(fzf --zsh)"                 # enhances existing Ctrl+R (history) / Ctrl+T (file) keybindings
eval "$(starship init zsh)"         # must be last — takes over prompt rendering
