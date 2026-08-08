# dev.md — ideas and open work

Candidate improvements, filtered through the project philosophy in
AGENTS.md: shell-native, invisible, small enough to read in one sitting.
Nothing here is committed roadmap; it's a parking lot.

## Features worth adding

### Smarter default backend
If no backend is configured and the default (`codex`) is not on PATH,
fall back to whichever backend is installed instead of erroring on
first run.

### Shell completion
Complete the `--` commands and, more usefully, saved conversation names
for `--switch` / `--forget` (already in the state JSON). Ship as
`@ --completion zsh|bash` printing a completion script — no config
files, no install magic.

### `@ --edit` for long prompts
Open `$EDITOR`, send the saved buffer as the prompt (same pattern as
`git commit`). Multi-paragraph instructions in shell quoting are
painful.

## Deliberately out of scope

- Config files, model/temperature flags, prompt templates — that's the
  backends' job; `@`'s value is having nothing to configure.
- Transcript viewing/search — the backends own their session logs;
  duplicating them breaks "persist only the minimum".
- TUI, colors, markdown rendering — plain output is the product.

## Suggested order

1. Smarter default backend
2. Shell completion
3. `--edit`

## Done

- Atomic state writes (temp file + `os.replace`, pid-unique temp names)
- `--status` annotates the active conversation with its saved name,
  e.g. `* codex: tid-abc123 (= auth-bug)`
- `--version` / `--update` (validated download, atomic self-replace)
- Per-invocation backend override: `@ --on <backend> <instruction>` and
  argv[0] symlink aliases `@x` / `@c` / `@o` (never persisted)
