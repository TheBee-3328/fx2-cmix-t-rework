# Handoff

## Current best (do not re-run baseline; BEST updated)
- **EXP05 accepted:** slices=**1626996**, holdout=**524882**
- Original baseline was 1627084 / 524904 (still in CSV as `baseline`)
- RSS caps still vs original baseline 5815060 / 5812904 (≤110%)

## EXP05 change
- `src/mixer/sse.cpp`: M_x1W0 (7648+1)→(7648−48); M_x2W0 (2560+1)→(2560−40)

## EXP09 reject (measured)
- slices=**1627085** (d+89) holdout=**524907** (d+25) rt=1 rss_ok
- mx9 LR 0.005→0.0048 only — no beat

## Now (DRIVER resumed — ignore stale STOPPED freeze)
- EXP10: drop `AddDoubleIndirect()` on `exp/indirect-drop-10`
- Campaign never-exit; parent_10h soft-restarts
- Accept iff both totals < 1626996 / 524882, RT OK, RSS ≤110%
