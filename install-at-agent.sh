#!/bin/sh
set -eu

src="${1:-./@}"
dest="${HOME}/.local/bin/@"

mkdir -p "${HOME}/.local/bin"
cp "$src" "$dest"
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
