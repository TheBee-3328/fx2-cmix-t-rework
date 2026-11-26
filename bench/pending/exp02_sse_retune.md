# EXP02 — SSE constant retune

**Depends on:** EXP01 closed (accept → merge first; reject → base master).
**Branch:** `exp/sse-retune-02`
**Idea:** ANALYSIS #2 — nudge SSE scale/bias constants for small archive gain, ~0 time/RAM cost.
**Accept:** slices total < best, holdout total < best, RT OK, RSS ≤110% of locked baseline.
**Measure:** `./bench/run.sh --label exp02` then `--holdout --label exp02`.
