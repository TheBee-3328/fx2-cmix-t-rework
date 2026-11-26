# EXP01 patch plan (do NOT apply until baseline locked)

In `Predictor::AddMixers()` (`src/predictor.cpp`):

1. Layer-1: `0.0003` → `0.00035`  (gentle bump)
2. Hottest L0 group `0.005` → `0.0045` for: mx9, mx11, mx13, wordscxt, mx6, mx17, mx16, mx14, mx15

Rationale: slightly slower L0 adaptation on cold 1MB; slightly faster late combine.
Reject if holdout does not improve.
