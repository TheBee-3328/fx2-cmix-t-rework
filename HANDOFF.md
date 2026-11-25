# Handoff

## Layout

Work in `fx2-cmix-transformer/` (git root). Parent dir may hold `enwik9`
(symlink `./enwik9` → `../enwik9`); **enwik9 is gitignored**.

## Build (NixOS)

```bash
nix-shell -p clang llvm gnumake upx --run './bench/build.sh'
# official PGO+UPX+embed:
nix-shell -p clang llvm gnumake upx --run './bench/build.sh --official'
```

Do not rely on `CC` from the environment (nix sets `CC=gcc`). `bench/build.sh`
forces `clang++` and `COREI7=1` (AVX2) because Nix strips `-march=native`.

## Bench

- Slices: `bench/slices/` (never change). Holdout: `bench/holdout/`.
- `./bench/run.sh` then `./bench/run.sh --holdout`.
- Transformer path needs vocab size **205**; raw 1MB slices with `--transformer`
  may fail — verify on first run and document workaround if needed.

## Next steps

1. Build unmodified code; run slices + holdout; record baseline in
   `bench/results.csv` / `LOG.md` (never alter baseline numbers later).
2. Write `bench/ANALYSIS.md` from architecture notes; pick first small
   experiment (mixer LR or SSE retune).
3. One idea per branch; accept only if slices + holdout improve and
   round-trip is perfect.
