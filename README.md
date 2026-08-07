```
             █████╗ ████████╗
            ██╔══██╗╚══██╔══╝
            ███████║   ██║
            ██╔══██║   ██║
            ██║  ██║   ██║
            ╚═╝  ╚═╝   ╚═╝
── A   S H E L L - N A T I V E   A I ──
```

# @ — your shell is the AI interface

`@` turns AI coding agents into a shell command. No app to launch, no interactive mode to enter and leave — you stay in your terminal and talk to the agent the same way you run `git` or `pytest`:

```sh
git status
pytest

@ inspect this repo and find the auth bug

git diff

@ keep the existing API and fix it another way
```

Each call streams the agent's work and drops you straight back at your prompt. The conversation carries over between calls, so the agent remembers everything you've discussed in this project.

Under the hood, `@` drives your choice of **Codex CLI**, **Claude Code**, or **opencode** — one wrapper, one muscle memory, whichever agent you prefer today.

## Why it's more than a shortcut

**Pipes just work.** Anything you can put in a pipe becomes context for the agent:

```sh
git diff | @ "review this change"
pytest 2>&1 | @ "why is this failing"
kubectl logs api-7d4b | @ "what went wrong here"
```

**Conversations persist per project.** Each repo (or directory) gets its own thread per backend. Ask a follow-up tomorrow and the agent still knows what you were doing. When one thread isn't enough, name them and jump between parallel workstreams:

```sh
@ --save auth-bug          # name the current conversation
@ --new                    # start a clean one for something else
@ --switch auth-bug        # pick up right where you left off
@ --list                   # see everything you've saved
```

**Your shell stays yours.** `@` never wraps or emulates your shell. Between agent calls you run ordinary commands, inspect what the agent did with `git diff`, and steer with the next `@`. Prompts are never mistaken for commands — only `--` prefixed words are commands, so `@ save this data to a file` goes to the agent, untouched.

**It's inspectable.** The whole thing is a single Python file with no dependencies beyond the standard library. You can read every line of what sits between you and your agent.

## Install

```sh
./install-at-agent.sh
```

This copies `@` to `~/.local/bin/@`. If that directory isn't on your `PATH`, the script tells you exactly what to add.

You'll also need at least one backend CLI installed and authenticated:

| Backend | Command | |
|---|---|---|
| [Codex CLI](https://github.com/openai/codex) | `codex` | default |
| [Claude Code](https://claude.com/claude-code) | `claude` | |
| [opencode](https://opencode.ai) | `opencode` | |

Requirements: `python3`, macOS or Linux. `git` is optional — it's used to find the project root, but `@` works fine outside repositories too.

## Commands

```text
@ <instruction>       Ask the agent to work in the current repo/directory
@ --use <backend>     Choose backend: codex, claude or opencode
@ --new               Start a fresh conversation for this repo
@ --save <name>       Name the current conversation
@ --switch <name>     Switch to a named conversation
@ --list              List named conversations for this repo
@ --forget [name]     Forget the current conversation (or a named one)
@ --status            Show the repo, backend, and saved conversations
@ --spinner-test [x]  Test the thinking animation
@ --help              Show help
```

### Choosing a backend

The backend is resolved per project, in this order:

1. `@ --use codex|claude|opencode` (saved for the repo)
2. The `AT_AGENT_BACKEND` environment variable
3. Default: `codex`

Each backend keeps its own conversation, so switching never loses the other's thread:

```sh
@ --use claude
@ say hello
@ --use codex        # the Claude session is still saved
@ --status
```

## What output looks like

Agent replies print plainly to stdout — no banners, no framing. While the agent thinks, a small spinner runs on the terminal (and never leaks into redirected or piped output). Commands the agent executes are echoed compactly to stderr with their output beneath:

```text
  $ pytest
  ...
```

Other tool activity (file reads, searches) shows as a short `[Name target]` note instead of flooding your terminal. Because replies go to stdout and everything else to stderr, you can pipe `@`'s answer onward like any other command. Ctrl-C stops the agent cleanly — the conversation is saved, ask again to continue.

## State and privacy

State lives in `${XDG_STATE_HOME:-~/.local/state}/at-agent/` — one small JSON file per project holding only what's needed to resume: the chosen backend and conversation IDs. No prompts, no command output, no repository content is ever stored.

`@` also doesn't touch your agents' safety settings: it passes no permission-widening flags (like `--dangerously-skip-permissions`), so whatever approval and sandboxing behavior your backend has remains in effect.

## License

MIT — see [LICENSE](LICENSE). Spinner animations come from [cli-spinners](https://github.com/sindresorhus/cli-spinners); see [ATTRIBUTIONS.md](ATTRIBUTIONS.md).
