# Experiment log

## 2026-11-26 — bootstrap

- Created fixed 1MB slices (`bench/slices.json`, seed `0xC0FFEE42`) and holdouts.
- Added `bench/run.sh`, `bench/build.sh` (clang / COREI7 / Nix-friendly).
- Licensing: kept stock GPLv3 in `LICENSE`; added `COPYRIGHT` with upstream
  authors preserved and fork changes attributed to Michael Chobot (TheBee-3328).
- Published public GitHub repo `fx2-cmix-t-rework`.
- Baseline compress/decompress not yet recorded (pending successful build).
