# EXP04 — Drop weakest match context (ANALYSIS #4)

**Depends on:** EXP03 closed.
**Branch:** `exp/match-ablation-04`
**Idea:** Remove AddMatch context `{13, 2}` (shortest hash match) — slice-visible capacity cut.
**Accept:** slices + holdout improve, RT OK, RSS ≤110% baseline.
**Measure:** `./bench/run.sh --label exp04` then `--holdout --label exp04`.
