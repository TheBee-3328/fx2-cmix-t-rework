#!/usr/bin/env bash
# Compress/decompress every bench slice (or holdout) with the current build.
# Usage:
#   bench/run.sh                 # 10 screening slices -> bench/results.csv
#   bench/run.sh --holdout       # 3 holdout slices -> bench/holdout_results.csv
#   bench/run.sh --label LABEL   # tag the CSV row (default: git short hash)
#
# Score proxy for slices: sum of compressed sizes. Decompressor size is recorded
# separately (full Hutter score needs archive9 + decompressor on full enwik9).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

HOLD=0
LABEL=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --holdout) HOLD=1; shift ;;
    --label) LABEL="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -x "$ROOT/run/cmix" ]]; then
  CMIX="$ROOT/run/cmix"
  # Constructed binary already embeds dict/order/weights; -c still needs an
  # external dict path for the WRT stage, and --transformer for non -e modes.
  DICT="$ROOT/dictionary/english.dic"
  TF="$ROOT/models/6m-q4-fp32.tfwc2"
elif [[ -x "$ROOT/cmix" ]]; then
  CMIX="$ROOT/cmix"
  DICT="$ROOT/dictionary/english.dic"
  TF="$ROOT/models/6m-q4-fp32.tfwc2"
else
  echo "No cmix binary. Build with: nix-shell -p clang llvm gnumake upx --run './bench/build.sh'" >&2
  exit 1
fi

if [[ ! -f "$TF" ]]; then
  echo "Missing transformer weights: $TF" >&2
  exit 1
fi
if [[ ! -f "$DICT" ]]; then
  echo "Missing dictionary: $DICT" >&2
  exit 1
fi

if [[ -z "$LABEL" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    LABEL="$(git rev-parse --short HEAD 2>/dev/null || echo nogit)"
    if [[ -n "$(git status --porcelain 2>/dev/null || true)" ]]; then
      LABEL="${LABEL}-dirty"
    fi
  else
    LABEL="nogit"
  fi
fi

if [[ "$HOLD" -eq 1 ]]; then
  SET_DIR="$ROOT/bench/holdout"
  WORK="$ROOT/bench/holdout_work"
  CSV="$ROOT/bench/holdout_results.csv"
  GLOB_PREFIX="h"
else
  SET_DIR="$ROOT/bench/slices"
  WORK="$ROOT/bench/work"
  CSV="$ROOT/bench/results.csv"
  GLOB_PREFIX="s"
fi

mkdir -p "$WORK"
DECOMP_SIZE="$(stat -c%s "$CMIX")"

# Peak RSS via GNU time if available, else /proc sampling helper.
run_measured() {
  local out_time="$1" out_rss="$2"; shift 2
  # Prefer GNU time (Nix: $(command -v time) may be the binary; bash builtin
  # has no -v). Fall back to wall-clock only.
  local TIME_BIN=""
  if [[ -x /usr/bin/time ]] && /usr/bin/time -v true >/dev/null 2>&1; then
    TIME_BIN=/usr/bin/time
  elif command -v time >/dev/null 2>&1 && \
       env time -v true >/dev/null 2>&1; then
    TIME_BIN="env time"
  fi
  if [[ -n "$TIME_BIN" ]]; then
    local tmp
    tmp="$(mktemp)"
    # shellcheck disable=SC2086
    $TIME_BIN -v "$@" >"$WORK/last_stdout.txt" 2>"$tmp" || {
      cat "$tmp" >&2
      return 1
    }
    # Prefer elapsed wall time; fall back to User time
    local el rss
    el="$(grep -E 'Elapsed \(wall clock\) time' "$tmp" | awk -F': ' '{print $2}' | tail -1)"
    rss="$(grep 'Maximum resident set size' "$tmp" | awk -F': ' '{print $2}' | tail -1)"
    # convert m:ss or h:mm:ss to seconds
    python3 - "$el" "$rss" "$out_time" "$out_rss" <<'PY'
import sys
el, rss, ot, orss = sys.argv[1:5]
parts = el.strip().split(":")
secs = 0.0
for p in parts: secs = secs*60 + float(p)
# GNU time reports KB on Linux
open(ot,"w").write(f"{secs:.3f}\n")
open(orss,"w").write(str(int(rss))*1 if False else str(int(float(rss))) + "\n")
# rss is in KB -> store as KB
open(orss,"w").write(str(int(float(rss))) + "\n")
PY
    rm -f "$tmp"
  else
    local start end
    start="$(date +%s.%N)"
    "$@" >"$WORK/last_stdout.txt" 2>"$WORK/last_stderr.txt" || {
      cat "$WORK/last_stderr.txt" >&2
      return 1
    }
    end="$(date +%s.%N)"
    python3 -c "print(f'{float('$end')-float('$start'):.3f}')" >"$out_time"
    echo "0" >"$out_rss"
  fi
}

echo "cmix=$CMIX decomp_size=$DECOMP_SIZE label=$LABEL set=$SET_DIR"

HEADER="timestamp,label,git,set,total_comp_bytes,decomp_exe_bytes,score_proxy,total_comp_s,total_decomp_s,peak_rss_kb,roundtrip_ok"
if [[ ! -f "$CSV" ]]; then
  echo "$HEADER" >"$CSV"
fi

# Per-slice detail log
DETAIL="$WORK/detail_${LABEL}.txt"
: >"$DETAIL"

total_comp=0
total_cs=0
total_ds=0
peak_rss=0
all_ok=1
declare -a sizes=()

mapfile -t SLICES < <(ls -1 "$SET_DIR"/${GLOB_PREFIX}*.bin | sort)
for src in "${SLICES[@]}"; do
  base="$(basename "$src" .bin)"
  comp="$WORK/${base}.comp"
  out="$WORK/${base}.out"
  rm -f "$comp" "$out"

  echo "=== $base compress ===" | tee -a "$DETAIL"
  run_measured "$WORK/t_comp.txt" "$WORK/rss_comp.txt" \
    "$CMIX" --transformer "$TF" -c "$DICT" "$src" "$comp"
  cs="$(cat "$WORK/t_comp.txt")"
  rss="$(cat "$WORK/rss_comp.txt")"
  csize="$(stat -c%s "$comp")"
  total_comp=$((total_comp + csize))
  total_cs="$(python3 -c "print(f'{float('$total_cs')+float('$cs'):.3f}')")"
  if [[ "$rss" -gt "$peak_rss" ]]; then peak_rss="$rss"; fi

  echo "=== $base decompress ===" | tee -a "$DETAIL"
  run_measured "$WORK/t_decomp.txt" "$WORK/rss_decomp.txt" \
    "$CMIX" --transformer "$TF" -d "$DICT" "$comp" "$out"
  ds="$(cat "$WORK/t_decomp.txt")"
  rss="$(cat "$WORK/rss_decomp.txt")"
  total_ds="$(python3 -c "print(f'{float('$total_ds')+float('$ds'):.3f}')")"
  if [[ "$rss" -gt "$peak_rss" ]]; then peak_rss="$rss"; fi

  if cmp -s "$src" "$out"; then
    rt=OK
  else
    rt=FAIL
    all_ok=0
  fi
  sizes+=("$csize")
  # LC_ALL=C: bash printf rejects "187.403" under comma-decimal locales and
  # with `set -e` that aborts the whole bench after the first slice.
  LC_ALL=C printf "%s comp=%s bytes  c=%.3fs d=%.3fs rss_peak_so_far=%sKB  %s\n" \
    "$base" "$csize" "$cs" "$ds" "$peak_rss" "$rt" | tee -a "$DETAIL"
  # free space between slices
  rm -f "$out"
done

score_proxy=$((total_comp + DECOMP_SIZE))
git_full="$(git rev-parse HEAD 2>/dev/null || echo none)"
ts="$(date -Iseconds)"
setname="$([[ "$HOLD" -eq 1 ]] && echo holdout || echo slices)"
rt_ok="$([[ "$all_ok" -eq 1 ]] && echo 1 || echo 0)"

echo "$ts,$LABEL,$git_full,$setname,$total_comp,$DECOMP_SIZE,$score_proxy,$total_cs,$total_ds,$peak_rss,$rt_ok" >>"$CSV"

echo
echo "TOTAL compressed bytes: $total_comp"
echo "Decompressor exe bytes: $DECOMP_SIZE"
echo "Score proxy (sum+exe):  $score_proxy"
echo "Compress time (s):      $total_cs"
echo "Decompress time (s):    $total_ds"
echo "Peak RSS (KB):          $peak_rss"
echo "Roundtrip all OK:       $rt_ok"
echo "Per-slice sizes:        ${sizes[*]}"
echo "Wrote $CSV"
