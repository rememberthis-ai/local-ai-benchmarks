#!/usr/bin/env bash
# Start the bench's own ollama (OLLAMA_VERSION, unpacked in ~/Dev/ext/ollama-<version>) on
# :11555, stopping any other version of ours that holds that port. It shares the account's
# model store (~/.ollama/models), so nothing is downloaded twice. Exits 1 unless the server
# answers with the expected version, so a night never measures the wrong runtime.
set -uo pipefail
V="${OLLAMA_VERSION:-0.40.8}"; PORT=11555; DIR="$HOME/Dev/ext/ollama-$V"
[ -x "$DIR/ollama" ] || { echo "no $DIR/ollama"; exit 1; }
# Whatever holds the bench port is ours (lsof lists only this account's sockets); a server started
# as `./ollama serve` shows no path in its arguments, so match the port, never the command line.
if ! curl -s "127.0.0.1:$PORT/api/version" | grep -q "\"$V\""; then
  for p in $(lsof -ti TCP:$PORT -sTCP:LISTEN); do echo "stopping pid $p on :$PORT ($(curl -s 127.0.0.1:$PORT/api/version))"; kill "$p"; done
  sleep 3
fi
if ! curl -s "127.0.0.1:$PORT/api/version" | grep -q "\"$V\""; then
  (cd "$DIR" && OLLAMA_HOST=127.0.0.1:$PORT OLLAMA_KEEP_ALIVE=30m nohup "$DIR/ollama" serve >> serve.log 2>&1 &)
  for _ in $(seq 1 30); do curl -s "127.0.0.1:$PORT/api/version" | grep -q "\"$V\"" && break; sleep 2; done
fi
curl -s "127.0.0.1:$PORT/api/version" | grep -q "\"$V\"" || { echo "ollama $V is not answering on :$PORT"; exit 1; }
echo "ollama $V on :$PORT"
