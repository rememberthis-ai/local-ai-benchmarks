# The local backend that never launched — and why no benchmark caught it

Before benchmarking a local model against a hosted one on an agentic workload,
verify the local path *starts*. Ours didn't, for an unknown length of time, and
every layer of testing we had was structurally incapable of noticing.

## The bug

The product spawns a Claude Code session for its "Dreamer" background agent.
Switching the configured backend to a local ollama model produced this command:

```bash
ollama launch claude --permission-mode auto --model qwen3.6:35b 'prompt…'
```

`ollama launch` is a [cobra](https://github.com/spf13/cobra) CLI that parses
flags **for itself**. `--model` is its own; `--permission-mode` is not:

```
Error: unknown flag: --permission-mode
```

The session never started. Correct form puts everything agent-bound after `--`:

```bash
ollama launch claude --model qwen3.6:35b -- --permission-mode auto 'prompt…'
```

A second, independent bug sat behind it: we run our bundled ollama on **:21434**
(deliberately, so it can't collide with a user's own Homebrew `ollama serve`),
but the `ollama` CLI defaults to **:11434**. Even with the flags fixed, `launch`
would have addressed the wrong server — the one holding none of the models our
own UI had pulled. `OLLAMA_HOST=127.0.0.1:21434` fixes it, and `launch`
propagates it into the child's `ANTHROPIC_BASE_URL`.

## Why nothing caught it

- **Unit tests asserted the wrong thing.** There *was* a test. It checked
  `cmd.starts_with("ollama launch claude")` and `cmd.contains("--model …")` —
  both true of the broken command. It tested that we built the string we
  intended, never that the string was one `ollama` would accept.
- **Benchmarks were single-shot HTTP.** Every number in our matrix came from
  `POST /api/generate` or `/v1/chat/completions`. Those bypass the launcher
  entirely. A perfectly healthy tok/s column tells you nothing about whether the
  *agent integration* works.
- **The failure was silent where anyone would look.** The error went to a tmux
  pane inside a detached background session. No daemon log line, no UI state, no
  crash. From outside, "the local Dreamer produced nothing" is indistinguishable
  from "the local Dreamer is slow" — which is exactly what you'd expect a local
  model to be.

That last point is the trap. **When the expected outcome is "slow", a total
failure looks like success at the observability level you have.**

## What to do instead

**Shim the child binary.** The fastest way to see what a launcher actually hands
downstream — argv *and* environment — is to intercept it. Put this on `PATH`
ahead of the real one and run the launcher:

```sh
#!/bin/sh
echo "=== ARGV ==="; for a in "$@"; do echo "  [$a]"; done
echo "=== ENV ==="; env | grep -iE 'anthropic|ollama' | sort
```

Thirty seconds, no source reading, no guessing. It's how we established that
`ollama launch claude` sets not just `ANTHROPIC_BASE_URL` / `AUTH_TOKEN` but
also pins `ANTHROPIC_DEFAULT_{HAIKU,SONNET,OPUS}_MODEL` **and**
`CLAUDE_CODE_SUBAGENT_MODEL` — the last of which hand-rolled env setups
routinely miss, producing 404s on background subagent calls against a server
where no `haiku` tag exists.

**Assert against the real CLI, not your own string.** A test that shells out
once with a `--help`-ish or dry invocation catches an unknown-flag error; a test
that greps your own format string cannot.

**Prove the arm starts before you time it.** For any agentic benchmark, the
first checkpoint is "did a turn happen at all" — one transcript line, one
non-empty response — recorded separately from the timing. Otherwise a
zero-turn run enters your dataset as a fast one.
