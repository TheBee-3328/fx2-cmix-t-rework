# EXP03 — PPMD order/mem nudge

**Depends on:** EXP02 closed.
**Branch:** `exp/ppmd-nudge-03`
**Idea:** ANALYSIS #3 — small PPMD order or mem change; watch RAM.
**Accept:** slices + holdout improve, RT OK, RSS ≤110% baseline, time not dangerous vs 50h/1GB.
**Measure:** `./bench/run.sh --label exp03` then `--holdout --label exp03`.
