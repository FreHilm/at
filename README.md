# @ — a shell-native AI coding agent

`@` is a tiny wrapper that makes AI coding agents (OpenAI Codex CLI or Anthropic Claude Code) feel like a normal shell command. No separate app, no interactive mode to enter and exit — you just interleave agent calls with your regular shell workflow:

```sh
git status
pytest

@ inspect this repository and find the auth bug

git diff

@ keep the existing API and fix it another way
```

Each `@` invocation runs the agent, streams its output, and returns you to your shell. Conversation context is preserved between calls, per project.

## Requirements

- `python3`
- At least one backend CLI, installed and authenticated:
  - [Codex CLI](https://github.com/openai/codex) (`codex`) — the default backend
  - [Claude Code](https://claude.com/claude-code) (`claude`)
- `git` (optional — used to detect the project root; `@` also works outside Git repositories)

Supported platforms: macOS and Linux.

## Installation

```sh
./install-at-agent.sh
```

This copies `@` to `~/.local/bin/@` and makes it executable. If `~/.local/bin` is not on your `PATH`, the script tells you what to add to your shell config.

## Usage

```text
@ <instruction>       Ask the agent to work in the current repo/directory
@ use codex|claude    Choose the backend for this repo
@ new                 Start a fresh conversation for this repo
@ forget              Forget the saved conversation for this repo
@ status              Show the repo, backend, and saved conversations
@ help                Show this help
```

Anything that isn't one of the built-in commands is sent to the agent as a prompt:

```sh
@ fix the failing tests
@ explain this stack trace
```

### Conversations

`@` keeps one persistent conversation per backend per project. A project is identified by its Git repository root, or by the current directory when outside a repository. Follow-up calls from the same project resume the same conversation, so the agent remembers what you discussed:

```sh
@ say hello
@ say something that follows from my previous request   # same conversation
@ new                                                    # start over
```

If a saved conversation can no longer be resumed (for example, it went stale), `@` prints a short error and suggests `@ new`.

### Backends

The backend is resolved in this order:

1. The project setting made with `@ use codex` or `@ use claude`
2. The `AT_AGENT_BACKEND` environment variable
3. Default: `codex`

Each backend keeps its own conversation, so switching back and forth doesn't lose either one:

```sh
@ use claude
@ say hello
@ use codex        # the old Codex thread is still saved
@ status
```

## Output

Agent replies are printed plainly to stdout. Shell commands the agent runs are echoed compactly to stderr, with their output beneath:

```text
  $ pytest
  ...
```

Other tool activity (file reads, searches) is shown as a short `[Name target]` note rather than dumping the content into your terminal. Wrapper errors use the prefix `@: <message>`.

## State

State lives in:

```text
${XDG_STATE_HOME:-~/.local/state}/at-agent/
```

One small JSON file per project, holding only what's needed to resume: the chosen backend and each backend's conversation ID (Codex thread ID, Claude session ID). No prompts, command output, or repository content is ever logged there.

```json
{
  "root": "/path/to/project",
  "backend": "claude",
  "codex":  {"thread_id": "..."},
  "claude": {"session_id": "..."}
}
```

## Security

`@` does not pass permission-widening flags (such as `--dangerously-skip-permissions`) to the underlying agents. Whatever approval and sandboxing behavior your Codex or Claude Code installation has remains in effect.
