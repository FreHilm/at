# AGENTS.md

## Project overview

This repository contains `@`, a tiny shell-native wrapper around AI coding agent CLIs. It supports three backends — the OpenAI Codex CLI, Anthropic's Claude Code CLI, and opencode — selected per project.

The goal is to make an AI coding agent feel like a native shell primitive rather than a separate interactive application.

Typical usage:

```sh
git status
pytest

@ inspect this repository and find the auth bug

git diff

@ keep the existing API and fix it another way
```

The user should be able to freely interleave ordinary shell commands and agent calls. Every invocation of `@` returns control directly to the user's existing shell.

## Core UX principles

1. `@` must behave like a normal executable.
2. Do not replace or emulate the user's shell.
3. Do not require entering or exiting an interactive agent session.
4. Preserve conversation context between `@` invocations within the same project.
5. Keep terminal output minimal, clean, and shell-like.
6. Prefer invisible implementation details over extra UI.
7. The command should feel fast and lightweight even when the underlying agent takes time.
8. Avoid surprising changes to the user's shell configuration.

## Command location

Recommended installation path:

```text
~/.local/bin/@
```

The implementation should remain usable from zsh, bash, fish, and other shells as long as that directory is on `PATH`.

Avoid implementing the main behavior as a zsh-only alias or shell function unless a shell-specific feature explicitly requires it.

## State

Persistent state is stored under:

```text
${XDG_STATE_HOME:-~/.local/state}/at-agent/
```

Global user configuration (currently only the default backend) lives in:

```text
~/.at/config.json
```

Conversation state is scoped per project.

Project identity should use:

1. the Git repository root when inside a Git repository;
2. otherwise, the resolved current working directory.

The wrapper stores each backend's conversation ID (Codex thread ID, Claude session ID) and resumes it on the next invocation from the same project.

State file schema:

```json
{
  "root": "/path/to/project",
  "backend": "claude",
  "codex":  {"thread_id": "..."},
  "claude": {"session_id": "..."},
  "opencode": {"session_id": "..."}
}
```

Legacy state files with a top-level `thread_id` are migrated on load: the value is treated as `codex.thread_id`. Switching backends must not discard the other backend's saved conversation.

`@ --new` and `@ --forget` reset only the active backend's conversation.

Commands:

```text
@ --status             Show project root, backend, conversation IDs, and state file
@ --use <backend>      Choose the backend: codex, claude or opencode
@ --default [backend]  Show or set the global default backend (~/.at/config.json)
@ --on <backend> <instruction>   Run one prompt on another backend (nothing saved)
@ --new                Start a fresh conversation for the current project
@ --save <name>        Name the active backend's current conversation
@ --switch <name>      Activate a named conversation (also switches backend)
@ --list               List named conversations for the current project
@ --forget [name]      Forget the current conversation, or delete a named one
@ --color [name]       Show or set the spinner color, or 'random' (~/.at/config.json)
@ --spinner-test [x] [color]   Test the thinking animation without invoking the backend
@ --version            Show the installed version
@ --update             Replace the installed @ with the latest from the repo
@ --completion <sh>    Print a completion script for zsh or bash
@ --saved-names        Hidden helper: saved conversation names, one per line
@ --help               Show usage
```

## Named conversations

`@ --save <name>` records the active backend's conversation ID under a user-chosen name in the project state file (`saved`: name → `{backend, id}`). `@ --switch <name>` restores it: the backend becomes the saved entry's backend and its current conversation is set to the saved ID. `@ --list` shows all names for the project, marking the one matching the active conversation with `*`. `@ --forget <name>` deletes a name (the conversation itself stays with the backend).

This is wrapper-level and backend-uniform: it relies only on resume-by-ID, which all backends support. It does not enumerate sessions created outside `@`.

State file schema with saved names:

```json
{
  "saved": {
    "auth-bug": {"backend": "claude", "id": "<session-id>"}
  }
}
```

Prompt-collision rule: commands are recognized ONLY with a `--` prefix. Any first argument not starting with `-` is part of a prompt, so `@ save this data to a file` or `@ list the files here` always go to the agent. `-h` is accepted as an alias for `--help`; any other `-`/`--` token that is not a known command is a usage error (exit 2), never a prompt.

## Piped input

When stdin is not a TTY, the wrapper reads it and appends it to the prompt as a labeled block. The read is bounded by UTF-8 byte length, not character count: the prompt travels as a single argv argument, and Linux caps one argument at 128 KiB (`MAX_ARG_STRLEN`), so the limit must stay safely below that in bytes.

```text
<instruction>

Piped input:
<stdin data>
```

This makes `git diff | @ "review this change"` deterministic on every backend. When stdin is not a TTY the backend subprocess receives `stdin=DEVNULL` (the wrapper already consumed the pipe); an interactive terminal stdin is inherited unchanged so backends behave exactly as if run directly. Oversized input is truncated with a visible warning; undecodable bytes are replaced, never fatal. Piped stdin with no instruction argument still just prints help.

## Shell completion

`@ --completion zsh|bash` prints a completion script for the user to
`eval` from their shell config; the wrapper never installs completion
itself. The script is generated from the real command/backend/spinner
lists in the source so it cannot drift from them. Saved conversation
names are resolved at completion time through the hidden
`@ --saved-names` command, which prints one name per line and nothing
else — completion depends on that format staying stable. The zsh script
registers for `@` and the argv[0] aliases.

## Backend selection

Resolution order:

1. per-invocation override: `@ --on <backend> ...`, or `argv[0]` is one of
   the symlink aliases `@x` (codex), `@c` (claude), `@o` (opencode);
2. `backend` in the project state file (set via `@ --use ...`);
3. the `AT_AGENT_BACKEND` environment variable;
4. the global user default (set via `@ --default ...`, stored in
   `~/.at/config.json`);
5. built-in default: `claude` if installed, otherwise the first installed
   backend in declaration order; `claude` when none are installed (its
   runner then prints the install hint).

Per-invocation overrides must never write the backend choice to the state
file. The overridden backend's conversation ID is still saved and resumed
as usual. The installer does not create the alias symlinks; users opt in
with `ln -s`.

The installed-backend fallback applies only when no explicit choice exists
at any level: an explicitly chosen backend that is missing from PATH must
error clearly, never silently switch. Malformed or unknown values in
`~/.at/config.json` are ignored, never fatal. Writes to the config use the
same temp-file + `os.replace` pattern as project state.

## Codex integration

The wrapper invokes the Codex CLI in non-interactive exec mode and consumes JSON event output.

Conceptually:

```text
codex exec --json ... <prompt>
```

For an existing project conversation it resumes the saved thread/session.

Do not parse human-oriented terminal output when structured JSON events are available.

Save a newly reported thread ID as soon as it is received so that subsequent `@` calls can resume the conversation.

If a saved thread can no longer be resumed, provide a concise error and tell the user that `@ --new` starts a fresh conversation.

## Claude Code integration

The wrapper invokes the Claude Code CLI in non-interactive mode with structured JSON output:

```text
claude -p --output-format stream-json --verbose <prompt>
```

For an existing project conversation it appends `--resume <session-id>`. Claude uses the process working directory as its workspace, so the wrapper runs it with the project root as the subprocess `cwd`.

Relevant stream events:

- `{"type": "system", "subtype": "init", "session_id": ...}` — first event; save the session ID immediately.
- `{"type": "assistant", "message": {"content": [...]}}` — content blocks: `text` (print to stdout), `tool_use` (render Bash commands as `  $ <command>` on stderr, other tools as a compact `[Name target]` note), `thinking` (ignore).
- `{"type": "user", "message": {"content": [...]}}` — `tool_result` blocks; `content` may be a plain string or a list of text blocks. Echo only results of Bash `tool_use` blocks (matched by `tool_use_id`) to stderr; other tool results (file reads, searches) would flood the terminal.
- `{"type": "result", "is_error": ..., "result": ...}` — final event. Do not reprint `result` text (assistant text was already streamed); surface errors only.
- Noise events (`system/thinking_tokens`, `rate_limit_event`, etc.) must be silently ignored.

If a saved session can no longer be resumed, Claude exits non-zero; provide the same concise `@ --new` hint as for Codex.

Do not pass permission-widening flags (e.g. `--dangerously-skip-permissions`) by default.

## opencode integration

The wrapper invokes the opencode CLI in non-interactive run mode with raw JSON events:

```text
opencode run --format json --dir <project-root> <prompt>
```

For an existing project conversation it appends `--session <session-id>`.

Relevant stream events (every event carries a top-level `sessionID` — save it eagerly on first sight):

- `{"type": "text", "part": {"text": ...}}` — assistant text; print to stdout.
- `{"type": "tool_use", "part": {"tool": ..., "state": {...}}}` — one event per tool call with `status`, `input`, `output`, and `metadata.exit` all included. Render only `status == "completed"`. `tool == "bash"` → `  $ <input.command>` plus output (and `[exit N]` when non-zero) on stderr; other tools → compact `[tool title]` note on stderr.
- `{"type": "step_start"}` / `{"type": "step_finish"}` — bookkeeping; silent.
- `{"type": "error"}` — `@ error: ...` on stderr.

Do not pass `--auto` (auto-approves permissions; opencode itself marks it dangerous). Do not pass model/agent flags; opencode's own configuration governs those.

## Thinking indicator

While the backend agent is working and there is no user-visible output, display a small single-character spinner animation.

The frame data is the `dots` through `dots11` styles from [cli-spinners](https://github.com/sindresorhus/cli-spinners) (MIT, Sindre Sorhus — see `ATTRIBUTIONS.md`), embedded directly in `@` to keep the tool single-file.

Style selection:

- Each invocation picks one of the eleven styles at random.
- `dots` is the default style: an explicitly requested but unknown style name falls back to it.
- Frame intervals come from the upstream definitions (80–100 ms per style).

The frames repeat continuously.

Loading words:

- A status word (from the `LOADING_WORDS` list in `@`, e.g. "Pondering",
  "Brewing") is shown after the spinner character, separated by one
  space. The separator space is part of the fixed layout: it is always
  rendered, even while the word is empty — only word letters are ever
  typed and deleted.
- The word is typed one letter at a time, fast and machine-confident
  (8-30 ms per keystroke with rare micro hesitations for texture; a
  word lands in ~0.2 s), held fully typed for 7-15 s,
  then deleted one letter at a time with accelerating backspace rhythm
  (~50 ms down to ~12 ms per character — a whole word vanishes in
  ~0.2 s), a short blank gap (0.25-0.7 s), and a new word begins.
  Never the same word twice in a row. The pace should read as a
  powerful agent at work, not a human typist.
- The word shares the spinner's color and breathing.
- When the line shrinks (deletion), leftover characters must be padded
  over; clearing must erase the full drawn width, not just the spinner
  character.
- Word state continues across clear/redraw cycles caused by real output;
  it does not restart on every event.

Color:

- The spinner is colored, and the color "breathes": brightness pulses
  smoothly between full and ~35 % of the base color, one cycle ≈ 2 s.
- Each invocation picks a random base color from the built-in palette,
  unless the user pinned one with `@ --color <name>` (stored under the
  `color` key in `~/.at/config.json`; `@ --color random` unpins).
- Truecolor escapes are used when `COLORTERM` advertises
  truecolor/24bit, otherwise the nearest 256-color cube entry.
- Color must be disabled entirely when `NO_COLOR` is set, or `TERM` is
  `dumb` or unset. Frames are then rendered plain — never drop the
  animation itself just because color is unavailable.
- Unknown color names fall back to a random palette color.
- Color codes follow the same TTY rules as the frames: they must never
  reach redirected or piped output.

Important behavior:

- Render the animation on one terminal line.
- Do not print a newline for each frame.
- Clear the animation before printing agent text, command execution output, errors, or other visible information.
- Resume the animation if the agent continues working after visible output.
- Internal JSON events that produce no visible output must NOT stop or restart the animation.
- Do not let spinner frames remain in shell scrollback.
- Prefer writing directly to the controlling terminal (`/dev/tty`) when available.
- Fall back to stderr only when stderr is an interactive TTY.
- If no interactive terminal is available, silently disable the animation.
- Never emit spinner escape sequences into redirected or piped output.

`@ --spinner-test [style] [color]` should animate for roughly three seconds (a random style/color, or the named ones) and then print:

```text
spinner test complete (<style>, <color>)
```

Use this command to debug terminal rendering independently of the backends.

## Output behavior

Agent messages should be printed plainly, without large banners or decorative framing.

When useful, shell commands executed by the agent may be shown in a compact form such as:

```text
  $ pytest
```

Command output may follow directly beneath it.

Avoid dumping raw JSON events unless explicitly running in a debug mode.

Errors emitted by the wrapper should use a short prefix:

```text
@: <message>
```

## Implementation constraints

The current implementation is a single Python 3 executable named `@`.

Keep dependencies limited to the Python standard library unless adding a dependency provides a substantial benefit.

Expected external commands:

- `codex`, `claude` and/or `opencode` (only the active backend needs to be installed)
- `git` (optional; behavior must still work outside Git repositories)

The wrapper should tolerate:

- repositories with spaces in their paths;
- execution outside a Git repository;
- redirected stdout;
- redirected stderr;
- terminals where stderr itself is not reported as a TTY;
- stale or malformed local state files;
- unexpected non-JSON lines from Codex;
- piped stdin that is empty, binary, or very large.

Use argument arrays with `subprocess`; do not construct shell command strings.

## Concurrency and cleanup

Spinner/background rendering must never prevent the process from exiting.

Background threads should be daemonized or reliably joined.

Always clear the spinner in `finally`-style cleanup paths, including failures and interrupts where practical.

Avoid races where the spinner writes over agent output.

Ctrl-C must never print a Python traceback. On interrupt: terminate and reap the backend child, clear the spinner, print a one-line `@: interrupted; conversation saved, ask again to continue` notice, and exit with status 130 (128 + SIGINT). The conversation ID is saved eagerly at stream start, so an interrupted question can be re-asked in the same conversation.

If output rendering becomes more complex, centralize terminal writes rather than adding independent writers.

## Security

Do not silently increase Codex permissions or sandbox access.

Do not add flags that bypass approvals, sandboxing, or safety controls merely to make the wrapper more convenient.

Do not log prompts, command output, secrets, or repository content into the state directory.

Persist only the minimum information required to resume a conversation.

## Licensing

The project is licensed under the MIT License (`LICENSE`).

Third-party material embedded in `@` (currently the cli-spinners frame data) must be attributed in `ATTRIBUTIONS.md` with its license text. Keep the `@` implementation single-file; embed data rather than vendoring extra source files.

## Compatibility

Primary targets:

- macOS
- Linux

The `/dev/tty` implementation is Unix-oriented. If Windows support is added, isolate platform-specific terminal behavior cleanly rather than complicating the main event loop.

## Development style

Prefer small, readable functions.

Keep the project small enough that a user can inspect and understand the entire wrapper.

When fixing behavior, address the underlying event/TTY lifecycle rather than adding arbitrary sleeps.

Do not add elaborate abstractions unless they make terminal concurrency or Codex event handling materially safer.

## Testing changes

At minimum, manually verify:

```sh
@ --help
@ --status
@ --spinner-test
@ say hello
@ say something that follows from my previous request
@ --new
```

Backend switching (repeat the flow for each backend: claude, opencode, codex):

```sh
@ --use claude
@ --status                 # backend: claude, other conversations still listed
@ say hello
@ say something that follows from my previous request
@ --use codex
@ --status                 # old Codex thread still saved
```

Also verify legacy state migration: a state file containing only `{"root": ..., "thread_id": ...}` must surface the thread as the Codex conversation without data loss.

Named conversations:

```sh
@ say hello
@ --save first
@ --new
@ say hi again
@ --save second
@ --list                   # two names, '*' on second
@ --switch first
@ "what did I first ask you to say?"   # must recall the 'first' thread
@ --forget second
@ --list                   # only 'first' remains
@ list the files in this directory    # a prompt: goes to the agent, NOT --list
@ save this data to a file            # a prompt: goes to the agent, NOT --save
```

Piped input:

```sh
ls -l | @ "how many files, answer with a number only"
echo "" | @ "say hello"          # empty pipe: prompt unchanged, no hang
echo hi | @                      # no instruction: prints help, no hang
```

Also verify:

```sh
@ --spinner-test > /tmp/out
```

The spinner should remain on the terminal when appropriate and must not contaminate `/tmp/out`.

Test inside and outside a Git repository.

For changes to the event loop, test an agent request that:

1. takes several seconds before responding;
2. runs at least one shell command;
3. prints a final response.

Confirm that the spinner is visible while idle, disappears cleanly for real output, and does not flicker on invisible Codex events.

## Product direction

The long-term idea is that `@` should feel as natural as any other shell command:

```sh
@ fix this
```

not:

```sh
launch-agent
enter-agent-mode
type-prompt
exit-agent-mode
```

When choosing between technically powerful behavior and a seamless shell experience, prefer the seamless shell experience unless doing so would compromise safety or correctness.
