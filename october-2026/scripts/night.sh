#!/usr/bin/env bash
# Local image + video generation bench, M1 Max 64 GB. One night, unattended.
# Waits for 23:00, for the LLM queue named in AFTER_PID to finish (if set), and for no compiler to run;
# stops between runs from 07:00. Each run is timed with /usr/bin/time -l (wall seconds + peak RSS) and
# appended to runs.jsonl; outputs go to $OUTDIR (outside git, they are large).
#
#   AFTER_PID=12524 nohup bash -c 'exec bash experiments/genmedia-2026-10/night.sh' >/dev/null 2>&1 </dev/null &
HERE="$(cd "$(dirname "$0")" && pwd)"
G=$HOME/Dev/ext/genmedia
RES=$HERE/results/$(scutil --get LocalHostName)-$(date +%Y%m%d)${NOW:+-day}
OUTDIR=$G/out/$(date +%Y%m%d)${NOW:+-day}   # a day pass and a night on the same date must not share a folder
mkdir -p "$RES" "$OUTDIR"
log() { echo "[$(date '+%F %T')] $*" >> "$RES/night.log"; }
morning() { [ -n "$NOW" ] && return 1; h=$(date +%H); [ "$h" -ge 7 ] && [ "$h" -lt 23 ]; }
want() { [ -z "$ONLY" ] || [[ " $ONLY " == *" $1 "* ]]; }   # ONLY="zimage flux3" runs just those groups
stop_if_morning() { morning && { log "stopped at 07:00, rest left for another night"; exit 0; }
  [ -n "$DEADLINE" ] && [ "$(date +%H%M)" -ge "$DEADLINE" ] && { log "stopped at DEADLINE $DEADLINE"; exit 0; }; }

# NOW=1: daytime quality pass; timings from it are not benchmark numbers (the Mac is in use)
[ -z "$NOW" ] && until [ "$(date +%H)" -ge 23 ] || [ "$(date +%H)" -lt 6 ]; do sleep 300; done
[ -n "$AFTER_PID" ] && while kill -0 "$AFTER_PID" 2>/dev/null; do sleep 120; done
stop_if_morning
[ -z "$NOW" ] && until ! pgrep -xq xcodebuild && ! pgrep -xq rustc && ! pgrep -xq swift-frontend || [ "$(date +%H)" -eq 3 ]; do sleep 120; done
# The LLM bench's ollama holds GPU memory; nothing of ours may be loaded while this runs.
[ -z "$NOW" ] && kill $(lsof -ti TCP:11555 -sTCP:LISTEN) 2>/dev/null
# GPU idle check: the apps' daemons run Metal whisper / Vision OCR with no ollama involved (see the bench
# skill). Wait up to an hour for the GPU to settle, and record what it read either way.
gpu() { sudo -n powermetrics --samplers gpu_power -i 1000 -n 3 2>/dev/null | awk '/GPU HW active residency/{gsub("%","",$5); s+=$5; n++} END{print (n? int(s/n) : "unknown")}'; }
if [ -z "$NOW" ]; then for i in $(seq 12); do g=$(gpu); [ "$g" != unknown ] && [ "$g" -lt 30 ] && break; sleep 300; done; log "GPU residency before start: ${g}%"; fi
log "start${NOW:+ (DAYTIME quality pass)} (load $(sysctl -n vm.loadavg)), $(sw_vers -productVersion), mflux $(mflux-generate --version 2>/dev/null | tail -1), ltx-2-mlx $(git -C $G/ltx-2-mlx log -1 --format=%h), mlx-video $(git -C $G/mlx-video log -1 --format=%h)"

# run <id> <cmd...>: time one generation, record wall + peak RSS + exit code
run() {
  local id=$1; shift
  stop_if_morning
  # night runs (and a daytime run with SKIPDONE=1): skip what already succeeded on an earlier night
  if { [ -z "$NOW" ] || [ -n "$SKIPDONE" ]; } && cat "$HERE"/results/*[0-9]/runs.jsonl 2>/dev/null | grep -F "\"id\":\"$id\"," | grep -q '"rc":0'; then log "$id: done on an earlier night, skipped"; return; fi
  local t0=$(date +%s)
  /usr/bin/time -l "$@" > "$RES/$id.log" 2>&1
  local rc=$? t1=$(date +%s)
  local rss=$(awk '/maximum resident set size/{print $1}' "$RES/$id.log")
  printf '{"id":"%s","wall_s":%d,"peak_rss_gb":%.1f,"rc":%d,"cmd":"%s"}\n' "$id" $((t1-t0)) "$(echo "${rss:-0}/1073741824" | bc -l)" $rc "$*" >> "$RES/runs.jsonl"
  log "$id: rc=$rc $((t1-t0)) s"
}

P() { python3 -c "import json,sys;d=json.load(open('$HERE/prompts.json'));print(next(x['prompt'] for x in d[sys.argv[1]] if x['id']==sys.argv[2]))" "$1" "$2"; }
IMGS=${IMGS:-"portrait office chalkboard friends harbour robot"}
VIDS=${VIDS:-"barista ferry dog"}

# --- stills, 1024x1024, seed 42, fp16 compute (M1 has no native bf16) ---
want zimage && for i in $IMGS; do run "zimage-turbo-q8-$i" mflux-generate-z-image-turbo --prompt "$(P images $i)" --width 1024 --height 1024 --steps 9 --seed 42 -q 8 --compute-precision float16 --output "$OUTDIR/zimage-turbo-$i.png"; done
want flux3 && for i in $IMGS; do run "flux3-klein-q8-$i" mflux-generate-flux3 --prompt "$(P images $i)" --width 1024 --height 1024 --seed 42 -q 8 --compute-precision float16 --output "$OUTDIR/flux3-klein-$i.png"; done
want flux2 && for i in $IMGS; do run "flux2-klein4b-q8-$i" mflux-generate-flux2 --model flux2-klein-4b --prompt "$(P images $i)" --width 1024 --height 1024 --steps 4 --seed 42 -q 8 --compute-precision float16 --output "$OUTDIR/flux2-klein4b-$i.png"; done

# --- video: LTX-2.5 and 2.3, distilled, 768x512, 97 frames (4 s at 24 fps), with sound ---
LTX=$G/ltx-2-mlx/.venv/bin/ltx-2-mlx
want ltx25 && for v in $VIDS; do run "ltx25-q8-dist-$v" env LTX2_COMPUTE_DTYPE=float16 $LTX generate --model dgrauet/ltx-2.5-mlx-q8 --distilled -p "$(P videos $v)" -W 768 -H 512 -f 97 --frame-rate 24 --seed 42 -o "$OUTDIR/ltx25-$v.mp4"; done
# the README's M1 Max reference shape (576x1024, 241 frames), to check our number against theirs
want ltx25ref && run "ltx25-q8-dist-ref241" env LTX2_COMPUTE_DTYPE=float16 $LTX generate --model dgrauet/ltx-2.5-mlx-q8 --distilled -p "$(P videos ferry)" -W 576 -H 1024 -f 241 --frame-rate 24 --seed 42 -o "$OUTDIR/ltx25-ref241.mp4"
want ltx23 && for v in $VIDS; do run "ltx23-q8-dist-$v" env LTX2_COMPUTE_DTYPE=float16 $LTX generate --model dgrauet/ltx-2.3-mlx-q8 --distilled -p "$(P videos $v)" -W 768 -H 512 -f 97 --frame-rate 24 --seed 42 -o "$OUTDIR/ltx23-$v.mp4"; done

# --- video: Wan 2.2 TI2V-5B (Apache), 1280x704, 121 frames, 20 unipc steps; no sound ---
WAN=$G/Wan2.2-TI2V-5B-MLX
if want wan && [ ! -f "$WAN/t5_encoder.safetensors" ]; then   # a file, not the folder: a failed conversion leaves an empty folder
  run "wan22-5b-convert" $G/mlx-video/.venv/bin/python -m mlx_video.models.wan_2.convert --checkpoint-dir "$($G/mlx-video/.venv/bin/python -c "from huggingface_hub import snapshot_download as s; print(s('Wan-AI/Wan2.2-TI2V-5B', local_files_only=True))")" --output-dir "$WAN"
fi
want wan && for v in barista ferry; do run "wan22-5b-$v" $G/mlx-video/.venv/bin/python -m mlx_video.models.wan_2.generate --model-dir "$WAN" --prompt "$(P videos $v)" --width 1280 --height 704 --num-frames 121 --steps 20 --seed 42 --output-path "$OUTDIR/wan22-5b-$v.mp4"; done

log "done"
