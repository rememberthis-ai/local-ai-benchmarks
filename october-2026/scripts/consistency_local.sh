#!/usr/bin/env bash
# Local half of consistency.py: FLUX 3 Klein (mflux, q8) with every cast portrait as a reference.
cd "$(dirname "$0")"; OUT=~/Dev/ext/genmedia/out/consistency-${RUN_DATE:-$(date +%Y%m%d)}; LOG=results/consistency-${RUN_DATE:-$(date +%Y%m%d)}/runs.jsonl
mkdir -p "$OUT" "$(dirname "$LOG")"
python3 consistency.py --print-local | while IFS=$'\t' read -r scene refs prompt; do
  key="flux3-klein-local-$scene"; [ -f "$OUT/$key.png" ] && continue
  t0=$(date +%s)
  mflux-generate-flux3-edit --image-paths $refs --prompt "$prompt" --width 1024 --height 768 --seed 7 -q 8 --output "$OUT/$key.png" > "$OUT/$key.log" 2>&1 </dev/null
  rc=$?; printf '{"key":"%s","provider":"local","status":"%s","predict_time":%s,"file":"%s"}\n' "$key" "$([ $rc = 0 ] && echo succeeded || echo failed)" $(( $(date +%s)-t0 )) "$OUT/$key.png" >> "$LOG"
done
