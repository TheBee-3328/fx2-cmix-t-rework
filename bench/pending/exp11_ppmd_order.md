# EXP11 — PPMD order nudge (ANALYSIS #3 follow-up)

**Depends on:** EXP10 closed.
**Branch:** `exp/ppmd-order-11`
**Idea:** On current best (EXP05 SSE unless a later accept), change PPMD `byte_model_.emplace(25, 14000, …)` → `(24, 14000, …)`. EXP03 only nudged mem 14000→13800; this tries order instead.
**Accept:** both totals < best, RT OK, RSS ≤110% baseline.
