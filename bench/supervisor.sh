#!/usr/bin/env bash
# Supervise baseline→holdout. Only restart if BOTH run.sh and cmix are gone
# for a grace period (avoid thrashing mid-slice).
set -euo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DISCORD_WEBHOOK="$(cat bench/.discord_webhook)"
N=(python3 bench/discord_notify.py)
# NOTE: awk END runs even after exit in a rule; don't END{exit 1} or matches look like misses.
has_row() { awk -F, -v s="$1" 'BEGIN{f=1} NR>1 && $4==s {f=0; exit} END{exit f}' "$2" 2>/dev/null; }

dead_streak=0
last=0
while ! has_row slices bench/results.csv; do
  cur=$(tr '\r' '\n' < bench/baseline_run.log 2>/dev/null | grep -c '^===' || true)
  comps=$(ls bench/work/s*.comp 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$cur" != "$last" ]]; then
    last=$cur
    detail=$(tr '\r' '\n' < bench/baseline_run.log | grep -E '^(===|s[0-9]{2} )' | tail -3 | paste -sd ' · ' -)
    "${N[@]}" "Baseline progress" "${detail:0:500}" "comps=${comps}/10" --status run || true
  fi
  run_alive=0; cmix_alive=0
  pgrep -f 'run.sh --label baseline' >/dev/null && run_alive=1
  pgrep -f '/cmix ' >/dev/null && cmix_alive=1
  if [[ "$run_alive" -eq 0 && "$cmix_alive" -eq 0 ]]; then
    dead_streak=$((dead_streak+1))
  else
    dead_streak=0
  fi
  # 3 consecutive checks × 60s ≈ 3 min dead before restart
  if [[ "$dead_streak" -ge 3 ]]; then
    "${N[@]}" "Baseline dead 3m — restart" "comps=${comps}/10" --status fail || true
    nohup env LC_ALL=C nix-shell -p clang llvm gnumake upx --run './bench/run.sh --label baseline' >> bench/baseline_run.log 2>&1 &
    dead_streak=0
  fi
  sleep 60
done
row=$(awk -F, 'NR>1 && $4=="slices" {print; exit}' bench/results.csv)
"${N[@]}" "Baseline complete" "row=\`${row:0:350}\`" --status ok || true

if ! has_row holdout bench/holdout_results.csv; then
  pgrep -f 'run.sh --holdout' >/dev/null || \
    nohup env LC_ALL=C nix-shell -p clang llvm gnumake upx --run './bench/run.sh --holdout --label baseline' > bench/holdout_run.log 2>&1 &
  "${N[@]}" "Holdout started" "3 slices" --status run || true
  hlast=0
  hdead=0
  while ! has_row holdout bench/holdout_results.csv; do
    hp=$(tr '\r' '\n' < bench/holdout_run.log 2>/dev/null | grep -c '^===' || true)
    hc=$(ls bench/holdout_work/h*.comp 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$hp" != "$hlast" ]]; then
      hlast=$hp
      detail=$(tr '\r' '\n' < bench/holdout_run.log | grep -E '^(===|h[0-9]{2} )' | tail -2 | paste -sd ' · ' -)
      "${N[@]}" "Holdout progress" "${detail:0:400}" "comps=${hc}/3" --status run || true
    fi
    if ! pgrep -f 'run.sh --holdout' >/dev/null && ! pgrep -f '/cmix ' >/dev/null; then
      hdead=$((hdead+1))
    else
      hdead=0
    fi
    if [[ "$hdead" -ge 3 ]]; then
      "${N[@]}" "Holdout dead 3m — restart" --status fail || true
      nohup env LC_ALL=C nix-shell -p clang llvm gnumake upx --run './bench/run.sh --holdout --label baseline' >> bench/holdout_run.log 2>&1 &
      hdead=0
    fi
    sleep 60
  done
fi
hrow=$(awk -F, 'NR>1 && $4=="holdout" {print; exit}' bench/holdout_results.csv)
{
  echo ""
  echo "## $(date -Iseconds) — baseline locked"
  echo "- slices: \`$row\`"
  echo "- holdout: \`$hrow\`"
} >> LOG.md
touch bench/.baseline_locked
"${N[@]}" "Baseline LOCKED" "Ready for EXP01." \
  "slices=$(echo "$row"|cut -d, -f5)" "holdout=$(echo "$hrow"|cut -d, -f5)" --status ok || true
