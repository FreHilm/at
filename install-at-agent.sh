#!/bin/sh
# Install @ to ~/.local/bin.
#
# From a checkout:  ./install-at-agent.sh
# Standalone:       curl -fsSL https://raw.githubusercontent.com/FreHilm/at/main/install-at-agent.sh | sh
set -eu

raw_url="https://raw.githubusercontent.com/FreHilm/at/main/@"

if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'error: @ requires python3, which was not found on PATH.' >&2
  printf '%s\n' 'Install Python 3 first, then re-run this installer.' >&2
  exit 1
fi

src="${1:-./@}"
dest="${HOME}/.local/bin/@"

mkdir -p "${HOME}/.local/bin"

if [ -f "$src" ]; then
  cp "$src" "$dest"
elif command -v curl >/dev/null 2>&1; then
  curl -fsSL "$raw_url" -o "$dest"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$dest" "$raw_url"
else
  printf '%s\n' 'error: no local ./@ found, and neither curl nor wget is available to download it.' >&2
  exit 1
fi

chmod +x "$dest"

case ":${PATH}:" in
  *":${HOME}/.local/bin:"*)
    ;;
  *)
    printf '%s\n' 'Installed, but ~/.local/bin is not currently on PATH.'
    printf '%s\n' 'For zsh, add this to ~/.zshrc:'
    printf '%s\n' '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

printf '%s\n' "Installed @ to $dest"
