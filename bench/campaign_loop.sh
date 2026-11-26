#!/usr/bin/env bash
# Continuous Hutter-campaign orchestrator. Never exits on its own.
# Owns: keep current experiment running → verdict → accept/reject → next pending.
set -uo pipefail
export LC_ALL=C
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# Single-instance guard (prevents dual start_exp races that un-patch mid-build)
mkdir -p bench
exec 9>bench/.campaign.lock
if ! flock -n 9; then
  echo "$(date -Iseconds) campaign_loop already running; exit" >> bench/campaign.log
  exit 0
fi
export DISCORD_WEBHOOK="$(cat bench/.discord_webhook 2>/dev/null || true)"
export GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Michael Chobot}"
export GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-thebee3328@gmail.com}"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME"
export GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

STATE=bench/.campaign_state
BEST_S=1626996
BEST_H=524882
[[ -f bench/.best_totals ]] && source bench/.best_totals
BASE_RSS_S=5815060
BASE_RSS_H=5812904
last_key=""

notify() {
  # Discord milestones are owned by parent_10h (human language only). Stay silent here.
  return 0
}

read_state() {
  if [[ -f "$STATE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE"
  else
    CURRENT_EXP=exp01
    CURRENT_LABEL=exp01
    CURRENT_BRANCH=exp/mixer-lr-01
    PHASE=slices   # slices|holdout|verdict|next
  fi
}

write_state() {
  cat >"$STATE" <<EOF
CURRENT_EXP=$CURRENT_EXP
CURRENT_LABEL=$CURRENT_LABEL
CURRENT_BRANCH=$CURRENT_BRANCH
PHASE=$PHASE
EOF
}

csv_val() {
  # csv_val path label set field
  python3 - "$1" "$2" "$3" "$4" <<'PY'
import csv,sys
path,lab,s,field=sys.argv[1:5]
rows=[r for r in csv.DictReader(open(path)) if r.get('label')==lab and r.get('set')==s]
print(rows[-1].get(field,'') if rows else '')
PY
}

alive_run() {
  pgrep -f "run.sh --label ${CURRENT_LABEL}" >/dev/null 2>&1
}
alive_hold() {
  pgrep -f "run.sh --holdout --label ${CURRENT_LABEL}" >/dev/null 2>&1
}
alive_cmix() {
  pgrep -f '/cmix ' >/dev/null 2>&1
}

detail_tail() {
  local f="bench/work/detail_${CURRENT_LABEL}.txt"
  [[ "$PHASE" == holdout ]] && f="bench/holdout_work/detail_${CURRENT_LABEL}.txt"
  if [[ -f "$f" ]]; then
    tr '\r' '\n' <"$f" | grep -E '^(===|[sh][0-9]{2} |TOTAL|Roundtrip)' | tail -1 || true
  fi
}

# True if detail shows in-progress slices/holdout without TOTAL, and mtime fresh (<25m).
# Prevents soft-relaunch from wiping a healthy mid-run after a brief cmix gap.
mid_run_fresh() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  local age
  age=$(( $(date +%s) - $(stat -c %Y "$f") ))
  (( age < 1500 )) || return 1
  grep -qE '^(s|h)[0-9]{2} comp=' "$f" 2>/dev/null || grep -qE '^=== (s|h)[0-9]{2} ' "$f" 2>/dev/null || return 1
  ! grep -qE '^TOTAL' "$f" 2>/dev/null
}

ensure_slices() {
  local s
  s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices total_comp_bytes)"
  if [[ -n "$s" ]]; then
    PHASE=holdout
    write_state
    return
  fi
  if ! alive_run && ! alive_cmix; then
    if mid_run_fresh "bench/work/detail_${CURRENT_LABEL}.txt"; then
      echo "$(date -Iseconds) SKIP relaunch slices $CURRENT_LABEL (mid-run detail fresh)" >> bench/campaign.log
      return
    fi
    if pgrep -f "run.sh --label ${CURRENT_LABEL}" >/dev/null 2>&1; then
      return
    fi
    echo "$(date -Iseconds) RELAUNCH slices $CURRENT_LABEL" | tee -a bench/campaign.log
    nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  fi
}

ensure_holdout() {
  local s h
  s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices total_comp_bytes)"
  h="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout total_comp_bytes)"
  [[ -n "$s" ]] || { PHASE=slices; write_state; return; }
  if [[ -n "$h" ]]; then
    PHASE=verdict
    write_state
    return
  fi
  if ! alive_hold && ! alive_cmix; then
    if mid_run_fresh "bench/holdout_work/detail_${CURRENT_LABEL}.txt"; then
      echo "$(date -Iseconds) SKIP relaunch holdout $CURRENT_LABEL (mid-run detail fresh)" >> bench/campaign.log
      return
    fi
    if [[ -f bench/.holdout_lock ]]; then
      echo "$(date -Iseconds) holdout lock held; skip campaign launch" >> bench/campaign.log
    else
      echo "$(date -Iseconds) LAUNCH holdout $CURRENT_LABEL" | tee -a bench/campaign.log
      nohup env LC_ALL=C ./bench/run.sh --holdout --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_holdout.log" 2>&1 &
    fi
  fi
}

do_verdict() {
  local s h ds dh rt rss accept verdict
  s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices total_comp_bytes)"
  h="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout total_comp_bytes)"
  [[ -n "$s" && -n "$h" ]] || return
  ds=$((s - BEST_S))
  dh=$((h - BEST_H))
  local rt_s rt_h rss_s rss_h
  rt_s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices roundtrip_ok)"
  rt_h="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout roundtrip_ok)"
  rss_s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices peak_rss_kb)"
  rss_h="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout peak_rss_kb)"
  rt=0; [[ "$rt_s" == 1 && "$rt_h" == 1 ]] && rt=1
  rss=0
  python3 - <<PY
import sys
ok = int("$rss_s") <= int($BASE_RSS_S * 1.1) and int("$rss_h") <= int($BASE_RSS_H * 1.1)
sys.exit(0 if ok else 1)
PY
  rss=$?
  [[ $rss -eq 0 ]] && rss=1 || rss=0
  accept=0
  [[ $ds -lt 0 && $dh -lt 0 && $rt -eq 1 && $rss -eq 1 ]] && accept=1
  verdict=reject
  [[ $accept -eq 1 ]] && verdict=accept
  echo "$verdict" >"bench/.${CURRENT_LABEL}_verdict"
  {
    echo ""
    echo "## ${CURRENT_LABEL} — ${verdict}"
    echo "- slices: $s (best $BEST_S, delta ${ds})"
    echo "- holdout: $h (best $BEST_H, delta ${dh})"
    echo "- rt=$rt rss_ok=$rss"
    echo "- branch: $CURRENT_BRANCH"
  } >> LOG.md
  # parent_10h posts Accept/Reject in plain English when it sees the verdict file
  if [[ "$verdict" == accept ]]; then
    BEST_S=$s
    BEST_H=$h
    git checkout master 2>/dev/null || true
    git merge --no-ff "$CURRENT_BRANCH" -m "$(cat <<EOF
Accept ${CURRENT_LABEL} (${CURRENT_BRANCH}).

Improves slice and holdout compressed totals vs previous best.
EOF
)" || true
  else
    git checkout master 2>/dev/null || true
  fi
  PHASE=next
  write_state
}

start_exp02() {
  CURRENT_EXP=exp02
  CURRENT_LABEL=exp02
  CURRENT_BRANCH=exp/sse-retune-02
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # Small SSE weight nudge: M_x1W0 7649→7700 (+51), M_x2W0 2561→2600
  python3 - <<'PY'
from pathlib import Path
p = Path('src/mixer/sse.cpp')
t = p.read_text()
t2 = t.replace('static const int M_x1W0 = (7648+1) * (1);',
               'static const int M_x1W0 = (7648+52) * (1);')
t2 = t2.replace('static const int M_x2W0 = (2560+1) * (1);',
                'static const int M_x2W0 = (2560+40) * (1);')
if t2 == t:
    raise SystemExit('SSE patch markers not found')
p.write_text(t2)
print('patched sse.cpp M_x1W0/M_x2W0')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  echo "$(date -Iseconds) STARTED exp02" | tee -a bench/campaign.log
}

start_exp03() {
  CURRENT_EXP=exp03
  CURRENT_LABEL=exp03
  CURRENT_BRANCH=exp/ppmd-nudge-03
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # PPMD mem 14000 → 13800 (slight RAM save / behavior nudge) if present
  if grep -q '14000' src/predictor.cpp; then
    sed -i 's/14000/13800/' src/predictor.cpp
  fi
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  echo "$(date -Iseconds) STARTED exp03" | tee -a bench/campaign.log
}

start_exp04() {
  CURRENT_EXP=exp04
  CURRENT_LABEL=exp04
  CURRENT_BRANCH=exp/match-ablation-04
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # Restore baseline PPMD if a prior exp left 13800 in the working tree
  sed -i 's/byte_model_.emplace(25, 13800,/byte_model_.emplace(25, 14000,/' src/predictor.cpp 2>/dev/null || true
  # ANALYSIS #4: drop weakest match context {13,2} from AddMatch
  python3 -c '
from pathlib import Path
p = Path("src/predictor.cpp")
t = p.read_text()
old = "      {11, 3}, \n      {13, 2}, \n  };"
new = "      {11, 3}, \n  };"
if old not in t:
    raise SystemExit("AddMatch {13,2} marker not found")
p.write_text(t.replace(old, new, 1))
print("dropped match context {13,2}")
'
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  echo "$(date -Iseconds) STARTED exp04" | tee -a bench/campaign.log
}

start_exp05() {
  CURRENT_EXP=exp05
  CURRENT_LABEL=exp05
  CURRENT_BRANCH=exp/sse-opposite-05
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  python3 - <<'PY'
from pathlib import Path
p = Path('src/mixer/sse.cpp')
t = p.read_text()
t2 = t.replace('static const int M_x1W0 = (7648+1) * (1);',
               'static const int M_x1W0 = (7648-48) * (1);')
t2 = t2.replace('static const int M_x2W0 = (2560+1) * (1);',
                'static const int M_x2W0 = (2560-40) * (1);')
if t2 == t:
    raise SystemExit('SSE opposite patch markers not found')
p.write_text(t2)
print('patched sse.cpp opposite nudge')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP05 start" "SSE opposite nudge on ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp05" | tee -a bench/campaign.log
}


start_exp06() {
  CURRENT_EXP=exp06
  CURRENT_LABEL=exp06
  CURRENT_BRANCH=exp/l1-lr-down-06
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  python3 - <<'PY'
from pathlib import Path
p = Path('src/predictor.cpp')
t = p.read_text()
old = 'AddMixer(1,manager_.zero_context_, 0.0003);'
new = 'AddMixer(1,manager_.zero_context_, 0.00028);'
if old not in t:
    raise SystemExit('L1 LR marker not found')
p.write_text(t.replace(old, new, 1))
print('L1 LR 0.0003→0.00028')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP06 start" "L1 LR 0.0003→0.00028 on ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp06" | tee -a bench/campaign.log
}


start_exp07() {
  CURRENT_EXP=exp07
  CURRENT_LABEL=exp07
  CURRENT_BRANCH=exp/match-drop-07
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  python3 - <<'PY'
from pathlib import Path
p = Path('src/predictor.cpp')
t = p.read_text()
old = "      {11, 3}, \n      {13, 2}, \n  };"
new = "      {11, 3}, \n  };"
if old not in t:
    raise SystemExit('AddMatch {13,2} marker not found')
p.write_text(t.replace(old, new, 1))
print('dropped match {13,2} on accepted SSE baseline')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP07 start" "Match {13,2} drop on accepted SSE ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp07" | tee -a bench/campaign.log
}


start_exp08() {
  CURRENT_EXP=exp08
  CURRENT_LABEL=exp08
  CURRENT_BRANCH=exp/sse-more-08
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  python3 - <<'PY'
from pathlib import Path
p = Path('src/mixer/sse.cpp')
t = p.read_text()
t2 = t.replace('static const int M_x1W0 = (7648-48) * (1);',
               'static const int M_x1W0 = (7648-72) * (1);')
t2 = t2.replace('static const int M_x2W0 = (2560-40) * (1);',
                'static const int M_x2W0 = (2560-60) * (1);')
if t2 == t:
    raise SystemExit('SSE further patch markers not found')
p.write_text(t2)
print('SSE further -72/-60')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP08 start" "SSE further nudge on ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp08" | tee -a bench/campaign.log
}

start_exp09() {
  CURRENT_EXP=exp09
  CURRENT_LABEL=exp09
  CURRENT_BRANCH=exp/l0-lr-fine-09
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # ANALYSIS #1 follow-up: hottest L0 mixer LR 0.005→0.0048 (smaller than rejected EXP01)
  python3 - <<'PY'
from pathlib import Path
p = Path('src/predictor.cpp')
t = p.read_text()
# Only replace exact 0.005 mixer LRs (leave other rates alone)
import re
t2, n = re.subn(r'(AddMixer\(0,\s*manager_\.(?:mx9|mx11|mx13|wordscxt|mx6|mx17|mx16|mx14|mx15),\s*)0\.005\)',
                r'\g<1>0.0048)', t)
if n < 1:
    raise SystemExit(f'L0 0.005 markers not found (n={n})')
p.write_text(t2)
print(f'patched {n} L0 mixer LRs 0.005→0.0048')
PY
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP09 start" "L0 LR 0.005→0.0048 on ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp09" | tee -a bench/campaign.log
}

start_exp10() {
  CURRENT_EXP=exp10
  CURRENT_LABEL=exp10
  CURRENT_BRANCH=exp/indirect-drop-10
  # Idempotent: if already running this label, do not wipe
  if alive_run || alive_cmix; then
    echo "$(date -Iseconds) start_exp10 skipped (run already alive)" | tee -a bench/campaign.log
    PHASE=slices
    write_state
    return
  fi
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # ANALYSIS #4: drop AddDoubleIndirect() on accepted SSE baseline
  python3 - <<'PY' || { echo "$(date -Iseconds) EXP10 patch FAILED" | tee -a bench/campaign.log; return 1; }
from pathlib import Path
p = Path('src/predictor.cpp')
t = p.read_text()
old = '  AddMatch();\n  AddDoubleIndirect();'
new = '  AddMatch();\n  // EXP10: AddDoubleIndirect() dropped (ANALYSIS #4 ablation)'
if 'EXP10: AddDoubleIndirect' in t:
    print('already patched')
elif old not in t:
    raise SystemExit('AddDoubleIndirect marker not found')
else:
    p.write_text(t.replace(old, new, 1))
    print('dropped AddDoubleIndirect()')
PY
  # Commit so a racing checkout cannot silently un-patch the worktree mid-build
  git add src/predictor.cpp 2>/dev/null || true
  git commit -m "EXP10: drop AddDoubleIndirect() ablation on SSE best" >/dev/null 2>&1 || true
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  # Refuse to launch if source lost the patch (race)
  grep -q 'EXP10: AddDoubleIndirect' src/predictor.cpp \
    || { echo "$(date -Iseconds) EXP10 abort: patch missing after build" | tee -a bench/campaign.log; return 1; }
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  notify "Campaign EXP10 start" "Drop AddDoubleIndirect on ${CURRENT_BRANCH}" --status run
  echo "$(date -Iseconds) STARTED exp10" | tee -a bench/campaign.log
}

start_exp11() {
  CURRENT_EXP=exp11
  CURRENT_LABEL=exp11
  CURRENT_BRANCH=exp/ppmd-order-11
  if alive_run || alive_cmix; then
    echo "$(date -Iseconds) start_exp11 skipped (run already alive)" | tee -a bench/campaign.log
    PHASE=slices
    write_state
    return
  fi
  git checkout master 2>/dev/null || true
  git checkout -B "$CURRENT_BRANCH" 2>/dev/null || git checkout "$CURRENT_BRANCH"
  # ANALYSIS #3 follow-up: PPMD order 25→24 (EXP03 only nudged mem)
  python3 - <<'PY' || { echo "$(date -Iseconds) EXP11 patch FAILED" | tee -a bench/campaign.log; return 1; }
from pathlib import Path
p = Path('src/predictor.cpp')
t = p.read_text()
old = 'byte_model_.emplace(25, 14000,'
new = 'byte_model_.emplace(24, 14000,'
if old not in t:
    if 'byte_model_.emplace(24, 14000,' in t:
        print('already patched')
    else:
        raise SystemExit('PPMD order marker not found')
else:
    p.write_text(t.replace(old, new, 1))
    print('PPMD order 25→24')
PY
  git add src/predictor.cpp 2>/dev/null || true
  git commit -m "EXP11: PPMD order 25→24 on current best" >/dev/null 2>&1 || true
  if command -v nix-shell >/dev/null 2>&1; then
    nix-shell -p clang llvm gnumake upx --run './bench/build.sh' >>"bench/${CURRENT_LABEL}_build.log" 2>&1 \
      || ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  else
    ./bench/build.sh >>"bench/${CURRENT_LABEL}_build.log" 2>&1 || true
  fi
  grep -q 'byte_model_.emplace(24, 14000,' src/predictor.cpp \
    || { echo "$(date -Iseconds) EXP11 abort: patch missing after build" | tee -a bench/campaign.log; return 1; }
  rm -rf bench/work bench/holdout_work
  mkdir -p bench/work bench/holdout_work
  PHASE=slices
  write_state
  nohup env LC_ALL=C ./bench/run.sh --label "$CURRENT_LABEL" >>"bench/${CURRENT_LABEL}_run.log" 2>&1 &
  echo "$(date -Iseconds) STARTED exp11" | tee -a bench/campaign.log
}

pick_next() {
  # Ignore stale freeze files — DRIVER owns continuity (CEO may re-freeze via explicit ask)
  if [[ -f bench/.campaign_freeze ]]; then
    echo "$(date -Iseconds) clearing stale freeze; continuing" | tee -a bench/campaign.log
    rm -f bench/.campaign_freeze
  fi
  case "$CURRENT_EXP" in
    exp01) start_exp02 ;;
    exp02) start_exp03 ;;
    exp03) start_exp04 ;;
    exp04) start_exp05 ;;
    exp05) start_exp06 ;;
    exp06) start_exp07 ;;
    exp07) start_exp08 ;;
    exp08) start_exp09 ;;
    exp09) start_exp10 ;;
    exp10) start_exp11 ;;
    *)
      PHASE=idle
      write_state
      ;;
  esac
}

# ---- main forever ----
read_state
write_state
echo "$(date -Iseconds) CAMPAIGN_START exp=$CURRENT_EXP phase=$PHASE" | tee -a bench/campaign.log

while true; do
  read_state
  DETAIL="$(detail_tail)"
  S="$(csv_val bench/results.csv "$CURRENT_LABEL" slices total_comp_bytes)"
  H="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout total_comp_bytes)"
  AR=0; AH=0; AC=0
  alive_run && AR=1
  alive_hold && AH=1
  alive_cmix && AC=1
  key="${CURRENT_EXP}|${PHASE}|${AR}|${AH}|${AC}|${DETAIL}|${S}|${H}"
  if [[ "$key" != "$last_key" ]]; then
    last_key=$key
    echo "CHANGE $(date -Iseconds) $key" | tee -a bench/campaign.log
    # Discord progress is owned by parent_10h (clean compress/decompress messages).
  fi

  case "$PHASE" in
    slices) ensure_slices ;;
    holdout) ensure_holdout ;;
    verdict) do_verdict ;;
    next) pick_next ;;
    idle) : ;;  # wait for human/parent to add work; keep looping
    *) PHASE=slices; write_state ;;
  esac
  # Same-tick advance: if ensure_* flipped phase, act immediately once
  read_state
  case "$PHASE" in
    holdout)
      s="$(csv_val bench/results.csv "$CURRENT_LABEL" slices total_comp_bytes)"
      h="$(csv_val bench/holdout_results.csv "$CURRENT_LABEL" holdout total_comp_bytes)"
      if [[ -n "$s" && -n "$h" ]]; then PHASE=verdict; write_state; do_verdict; fi
      ;;
    verdict) do_verdict ;;
    next) pick_next ;;
  esac

  # Soft watchdog: if PHASE slices/holdout and nothing alive for this label, ensure_* handles relaunch
  sleep 60
done
