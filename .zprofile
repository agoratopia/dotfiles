
# Homebrew, wherever this machine keeps it: Apple Silicon, Intel macOS, or
# Linuxbrew. A Linux box using its native package manager has none of these
# and simply skips — brew is not required there.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew \
             /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [[ -x $_brew ]]; then
    eval "$($_brew shellenv zsh)"
    break
  fi
done
unset _brew
