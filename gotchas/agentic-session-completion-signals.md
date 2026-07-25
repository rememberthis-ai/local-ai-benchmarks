# Benchmarking an agentic session: the completion signal is the hard part

Single-shot LLM benchmarks have a trivial notion of "done": the HTTP response
arrives. Benchmarking an **agentic** session — one that runs a real CLI agent
which decides for itself how many turns to take — has no such luxury, and the
obvious signals are all subtly wrong.

Concretely, from benchmarking Remember This's "Dreamer" sessions (a `claude`
CLI spawned in a detached tmux pane, driving itself over MCP for ~50 turns):

## Signals that don't work

**Process exit.** The agent runs as an interactive TUI, deliberately *not* in
headless/`--print` mode (headless can't accept mid-run human input, which the
product needs). So the process never exits on its own. There is nothing to
`wait` on.

**The application's own completion sentinel.** The session is instructed to
`touch` a sentinel file as its final action, and a supervisor reaps the tmux
session when that file appears. Perfect signal — except the supervisor **polls
every 10 s and deletes the sentinel** as part of reaping. An external observer
polling at the same interval routinely loses the race.

We hit exactly this: the model touched the sentinel, the supervisor consumed it
~seconds later, and the benchmark harness then waited a further **25 minutes**
for a file that no longer existed, on a run that had already finished. The only
surviving evidence was the sentinel *directory's* mtime and the `touch` command
in the agent's own transcript.

If a signal is *consumed* by the system under test, it isn't yours to observe.

**tmux session disappearance.** Depends on the same reaper, so it inherits the
same raciness — and in our case the session outlived the sentinel deletion
anyway.

**Output-file mtime.** Fires on the *first* write, not the last. An agent that
writes a draft, then keeps refining for ten more turns, looks finished long
before it is.

## The signal that does work: transcript quiescence

Claude Code (and most agent runtimes) append to a per-session JSONL transcript
on every turn. **No growth for N seconds means the agent has stopped working.**

```bash
# newest transcript touched since the run began
find "$TRANSCRIPT_DIR" -name '*.jsonl' -newermt "@$START_EPOCH" \
  | xargs -I{} stat -f '%m %N' {} | sort -rn | head -1
# ...then treat (now - mtime) >= QUIET_SECS as done
```

It's robust because it's an artifact the system *writes* rather than one it
*manages*: nothing reaps it, and it reflects genuine agent activity rather than
a lifecycle event that may or may not fire. Keep the application's own sentinel
as an opportunistic fast path when you happen to win the race, but never depend
on it.

Pick `QUIET_SECS` above the agent's slowest single turn. 90 s is comfortable for
a hosted model; a local model generating at ~20 tok/s can spend several minutes
on one turn, so raise it accordingly — or you'll record a "completion" mid-run
and silently truncate your own measurement.

## While you're here: the transcript is also your only instrumentation

The application recorded no token/wall-time/tool-call telemetry at all (we
grepped: zero hits for `token_usage`, `input_tokens`, `wall_time`,
`tool_calls`). The agent runtime's transcript carried all of it, per turn.

Worth parsing carefully — the input-token buckets are not interchangeable:

| Field | Meaning |
|---|---|
| `input_tokens` | genuinely new tokens this turn |
| `cache_creation_input_tokens` | written into the prompt cache |
| `cache_read_input_tokens` | re-read from cache |

On our hosted run, **89 % of all input tokens were cache reads** — 3.77 M of
4.23 M. Collapse those into one "input tokens" number and you erase the single
biggest structural advantage hosted inference has over a local runtime, which
must either re-prefill that context or serve it from its own KV prefix cache.
That distinction was the whole point of the comparison.
