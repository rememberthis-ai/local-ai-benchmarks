#!/usr/bin/env bash
# bench-all.sh — top-level bench dispatcher.
#
# Detects the host architecture and forwards to the appropriate chain script.
# Designed so a single `cd experiments && ./bench-all.sh` works on either Mac
# the household has — Intel i9 (x86_64) or M1 Max (arm64).
#
# Both chain scripts produce a morning report at /tmp/bench-chain-*-report.log
# and write aggregate summaries under their own results dir.
#
# Usage:
#   ./bench-all.sh                  # full chain on detected arch
#   ./bench-all.sh preflight        # readiness checks only
#   ./bench-all.sh <other-arg>      # forwarded to the chain script
#
#   ./bench-all.sh > /tmp/bench-all.log 2>&1 &
#
# Exit codes:
#   0  success
#   1  chain script failure
#   2  unsupported architecture or preflight failure

set -uo pipefail
cd "$(dirname "$0")"
ROOT="$(pwd)"

ARCH="$(uname -m)"
ARG="${1:-full}"

case "$ARCH" in
  arm64)
    CHAIN="$ROOT/swiftlm/bench-chain-silicon.sh"
    LABEL="Apple Silicon"
    ;;
  x86_64)
    CHAIN="$ROOT/intel-bench/bench-chain-intel.sh"
    LABEL="Intel"
    ;;
  *)
    echo "ERROR: unsupported arch '$ARCH'. Expected arm64 (Apple Silicon) or x86_64 (Intel Mac)." >&2
    exit 2
    ;;
esac

if [ ! -x "$CHAIN" ]; then
  echo "ERROR: chain script not found or not executable: $CHAIN" >&2
  exit 2
fi

echo "[bench-all] detected arch: $ARCH ($LABEL)"
echo "[bench-all] forwarding to: $CHAIN $ARG"
echo ""

exec "$CHAIN" "$ARG"
