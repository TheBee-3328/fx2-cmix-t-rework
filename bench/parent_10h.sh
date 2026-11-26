#!/usr/bin/env bash
# Parent orchestrate+monitor. Discord: rare human milestones only. Soft-restarts are silent.
set -uo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DISCORD_WEBHOOK="$(cat bench/.discord_webhook 2>/dev/null || true)"
if [[ -f bench/.parent_end_at ]]; then
  END_AT=$(cat bench/.parent_end_at)
  # If stale/expired window file, open a fresh 10h watch
  if [[ -z "$END_AT" ]] || (( END_AT < $(date +%s) + 60 )); then
    END_AT=$(( $(date +%s) + 10*3600 ))
    echo "$END_AT" > bench/.parent_end_at
  fi
else
  END_AT=$(( $(date +%s) + 10*3600 ))
  echo "$END_AT" > bench/.parent_end_at
fi
SEEN=bench/.discord_seen_events
touch "$SEEN"
LAST_CAMP_RESTART=0
BEST_S=1626996
BEST_H=524882
[[ -f bench/.best_totals ]] && source bench/.best_totals

EXP_NAMES_FILE=bench/.exp_human_names
# label -> short human name
human_name() {
  local lab="$1"
  case "$lab" in
    exp01) echo "Mixer learning-rate tweak" ;;
    exp02) echo "SSE constant nudge" ;;
    exp03) echo "PPMD memory nudge" ;;
    exp04) echo "Drop weakest match context" ;;
    exp05) echo "SSE opposite weight nudge" ;;
    exp06) echo "Layer-1 mixer learning-rate down" ;;
    exp07) echo "Drop match context on SSE best" ;;
    exp08) echo "Deeper SSE opposite nudge" ;;
    exp09) echo "Fine L0 mixer learning-rate down" ;;
    exp10) echo "Drop double-indirect contexts" ;;
    exp11) echo "PPMD order 25 to 24" ;;
    *) echo "$lab" ;;
  esac
}

announce_once() {
  local key="$1"; shift
  grep -qxF "$key" "$SEEN" 2>/dev/null && return 0
  echo "$key" >>"$SEEN"
  python3 bench/status_discord.py "$@" >/dev/null 2>&1 || true
}

# Never Discord about restarts. Cooldown so we don't fork-bomb.
  # Silently suppress disabled drivers (subagents keep resurrecting them)
  pkill -f "bench/driver_loop.sh|bench/driver_agent_forever" >/dev/null 2>&1 || true
ensure_campaign() {
  if pgrep -f 'bench/campaign_loop.sh' >/dev/null 2>&1; then
    return 0
  fi
  local now
  now=$(date +%s)
  if (( now - LAST_CAMP_RESTART < 120 )); then
    return 0
  fi
  LAST_CAMP_RESTART=$now
  echo "$(date -Iseconds) soft-start campaign_loop (silent)" >> bench/parent_10h.log
  nohup bash bench/campaign_loop.sh >> bench/campaign.stdout 2>&1 &
}

last_label=""
i=0
while true; do
  i=$((i+1))
  NOW=$(date +%s)
  TS=$(date -Iseconds)
  LABEL=$(grep CURRENT_LABEL= bench/.campaign_state 2>/dev/null | cut -d= -f2)
  LABEL=${LABEL:-exp01}
  PHASE=$(grep PHASE= bench/.campaign_state 2>/dev/null | cut -d= -f2)
  PHASE=${PHASE:-?}
  NAME=$(human_name "$LABEL")

  DETAIL=""
  if [[ "$PHASE" == holdout && -f "bench/holdout_work/detail_${LABEL}.txt" ]]; then
    DETAIL=$(tr '\r' '\n' <"bench/holdout_work/detail_${LABEL}.txt" | grep -E '^(===|[sh][0-9]{2} |TOTAL)' | tail -1 || true)
  elif [[ -f "bench/work/detail_${LABEL}.txt" ]]; then
    DETAIL=$(tr '\r' '\n' <"bench/work/detail_${LABEL}.txt" | grep -E '^(===|[sh][0-9]{2} |TOTAL)' | tail -1 || true)
  fi

  AR=0; AH=0; AC=0
  pgrep -f "run.sh --label ${LABEL}" >/dev/null 2>&1 && AR=1
  pgrep -f "run.sh --holdout --label ${LABEL}" >/dev/null 2>&1 && AH=1
  pgrep -f '/cmix ' >/dev/null 2>&1 && AC=1
  EXP_S=$(python3 -c "import csv; r=[x for x in csv.DictReader(open('bench/results.csv')) if x.get('label')=='$LABEL' and x.get('set')=='slices']; print(r[-1]['total_comp_bytes'] if r else '')" 2>/dev/null || true)
  EXP_H=$(python3 -c "import csv; r=[x for x in csv.DictReader(open('bench/holdout_results.csv')) if x.get('label')=='$LABEL' and x.get('set')=='holdout']; print(r[-1]['total_comp_bytes'] if r else '')" 2>/dev/null || true)
  LEFT=$(( (END_AT - NOW) / 60 ))
  echo "min$i $TS left≈${LEFT}m run=$AR hold=$AH cmix=$AC $LABEL/$PHASE | ${DETAIL:-?} | s=${EXP_S:-.} h=${EXP_H:-.}" >> bench/parent_10h.log

  # Milestone: new edit (label change) — once
  if [[ -n "$last_label" && "$LABEL" != "$last_label" ]]; then
    announce_once "started|$LABEL" started --name "$NAME"
  fi
  last_label=$LABEL

  # Milestone: screening finished
  if [[ -n "$EXP_S" ]]; then
    ds=$((EXP_S - BEST_S))
    announce_once "screening|$LABEL|$EXP_S" screening-done --name "$NAME" --bytes "$EXP_S" --delta "$ds"
  fi

  # Milestone: holdout finished
  if [[ -n "$EXP_H" ]]; then
    dh=$((EXP_H - BEST_H))
    announce_once "holdout|$LABEL|$EXP_H" holdout-done --name "$NAME" --bytes "$EXP_H" --delta "$dh"
  fi

  # Milestone: accept/reject (verdict file)
  if [[ -f "bench/.${LABEL}_verdict" && -n "$EXP_S" && -n "$EXP_H" ]]; then
    VERDICT=$(cat "bench/.${LABEL}_verdict")
    if [[ "$VERDICT" == accept ]]; then
      announce_once "verdict|$LABEL|accept" accept --name "$NAME" --slices "$EXP_S" --holdout "$EXP_H" \
        --why "Both screening and holdout beat our previous best, with a clean roundtrip."
    else
      why="It did not beat our best on both screening and holdout, so we keep the baseline."
      if [[ "$EXP_S" -lt "$BEST_S" && "$EXP_H" -ge "$BEST_H" ]]; then
        why="Screening got a little better, but holdout did not improve — not enough to keep."
      elif [[ "$EXP_S" -eq "$BEST_S" && "$EXP_H" -eq "$BEST_H" ]]; then
        why="Results matched the baseline exactly — no gain."
      elif [[ "$EXP_S" -gt "$BEST_S" ]]; then
        why="Screening got worse, so we drop it."
      fi
      announce_once "verdict|$LABEL|reject" reject --name "$NAME" --slices "$EXP_S" --holdout "$EXP_H" --why "$why"
    fi
  fi

  # Silently suppress disabled drivers (subagents keep resurrecting them)
  pkill -f "bench/driver_loop.sh|bench/driver_agent_forever" >/dev/null 2>&1 || true
  ensure_campaign

  # Silent soft relaunch of benches (no Discord).
  # Defer to campaign_loop when it is alive — dual launch was wiping mid-run progress.
  CAMP_ALIVE=0
  pgrep -f 'bench/campaign_loop.sh' >/dev/null 2>&1 && CAMP_ALIVE=1
  if [[ "$CAMP_ALIVE" == 0 && -z "$EXP_S" && "$AR" == 0 && "$AC" == 0 && "$PHASE" == slices ]]; then
    # Do not wipe a fresh mid-run detail file
    detail="bench/work/detail_${LABEL}.txt"
    age=99999
    [[ -f "$detail" ]] && age=$(( $(date +%s) - $(stat -c %Y "$detail") ))
    if [[ -f "$detail" ]] && (( age < 1500 )) && ! grep -qE '^TOTAL' "$detail" 2>/dev/null; then
      echo "$(date -Iseconds) skip soft-start slices $LABEL (mid-run detail age=${age}s)" >> bench/parent_10h.log
    else
      echo "$(date -Iseconds) soft-start slices $LABEL" >> bench/parent_10h.log
      nohup env LC_ALL=C ./bench/run.sh --label "$LABEL" >>"bench/${LABEL}_run.log" 2>&1 &
    fi
  fi
  if [[ "$CAMP_ALIVE" == 0 && -n "$EXP_S" && -z "$EXP_H" && "$AH" == 0 && "$AC" == 0 ]]; then
    echo "$(date -Iseconds) soft-start holdout $LABEL" >> bench/parent_10h.log
    nohup env LC_ALL=C ./bench/run.sh --holdout --label "$LABEL" >>"bench/${LABEL}_holdout.log" 2>&1 &
  fi

  if [[ $NOW -ge $END_AT && "$PHASE" == idle && "$AC" == 0 ]]; then
    announce_once "window-done" note --title "Taking a pause" --why "The 10-hour watch window ended and there is nothing running right now."
    exit 0
  fi
  sleep 60
done
