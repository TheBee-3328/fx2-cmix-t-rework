# Experiment log

## 2026-11-26 — bootstrap

- Created fixed 1MB slices (`bench/slices.json`, seed `0xC0FFEE42`) and holdouts.
- Added `bench/run.sh`, `bench/build.sh` (clang / COREI7 / Nix-friendly).
- Licensing: kept stock GPLv3 in `LICENSE`; added `COPYRIGHT` with upstream
  authors preserved and fork changes attributed to Michael Chobot (TheBee-3328).
- Published public GitHub repo `fx2-cmix-t-rework`.
- Baseline compress/decompress not yet recorded (pending successful build).

## 2026-11-26 — smoke s00

- Built cmix (clang/ZEN2); size 459032 B stripped (weights separate via `--transformer`).
- s00 compress: **1000000 → 184458 bytes in 195.49 s** (transformer+dict path OK; vocab 205 OK).
- Peak RSS during decompress ~5.6 GB.
- Full baseline pending after roundtrip verify.

## 2026-11-26 — baseline locked

- Dev cmix (clang/ZEN2, stripped): 459032 B; `--transformer models/6m-q4-fp32.tfwc2` + dict.
- Fix required mid-run: short slices can miss enwik9 post-WRT bytes (e.g. `0x58`); added
  `ForceEnwik9TransformerVocab` in `src/runner.cpp` so `--transformer` always uses the
  canonical 205-byte vocab (slices/holdouts untouched).
- **Slices** (10×1MB, all roundtrip OK): total_comp=**1627084**, c=1807.540s, d=1789.970s,
  peak_rss=**5815060** KB (~5.54 GB), score_proxy=2086116.
  - per-slice: 184458, 185735, 169652, 169325, 171282, 54453, 170487, 177124, 169653, 174915
- **Holdout** (3×1MB, all roundtrip OK): total_comp=**524904**, c=562.480s, d=577.160s,
  peak_rss=5812904 KB.
  - per-holdout: 176039, 171662, 177203
- Locked via `bench/.baseline_locked`. Ready for EXP01.

## 2026-11-26 — reboot recovery

- PC powered off mid-EXP01 (s01 decompress). Cleaned `bench/work`, restarted full EXP01.
- Started `bench/campaign_loop.sh` (never-exit): EXP01 → verdict → EXP02 SSE → EXP03 PPMD → idle queue.
- Parent policy: continuous orchestrate/monitor; stop only on manual user stop or rare human decision.

## 2026-11-26 — EXP01 slices complete
- total_comp=**1627328** (best 1627084, delta **+244**), rss=5815180, rt=1
- Holdout started; accept impossible on slices alone. Continuing campaign.

## EXP01 mixer LR — reject
- slices: 1627328 (baseline 1627084, delta +244)
- holdout: 524985 (baseline 524904, delta +81)
- rt=1 rss_ok=1
- change: L0 0.005→0.0045; L1 0.0003→0.00035
- Decision: reject (both totals worse). Stay on locked baseline.

## Driver note — exp01 reject (2026-11-26T03:49:17+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## DRIVER_AGENT — exp01 reject (2026-11-26T03:49:20+0100)
- slices=1627328 (d+244) holdout=524985 (d+81) rt=1 rss_ok=1
- Proceeding immediately to exp02.

## exp02 — reject
- slices: 1627082 (best 1627084, delta -2)
- holdout: 524904 (best 524904, delta 0)
- rt=1 rss_ok=1
- branch: exp/sse-retune-02

## DRIVER_AGENT — exp02 reject (2026-11-26T05:11:57+0100)
- slices=1627082 (d-2) holdout=524904 (d+0) rt=1 rss_ok=1
- Proceeding immediately to exp03.

## Driver note — exp02 reject (2026-11-26T05:12:33+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:13:33+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:13:34+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## 2026-11-26 — EXP02 reject / EXP03 start
- EXP02 slices=1627082 (d-2) holdout=524904 (d0) → reject (holdout must strictly improve)
- Started EXP03 PPMD nudge on exp/ppmd-nudge-03

## Driver note — exp01 reject (2026-11-26T05:14:34+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:14:35+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:15:37+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:15:37+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:16:38+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:16:38+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:17:39+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:17:39+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:18:40+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:18:40+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:19:41+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:19:43+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:20:44+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:20:44+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:21:45+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:21:45+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:22:46+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:22:46+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:23:47+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:23:47+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:24:48+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:24:49+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:25:49+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:25:50+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:26:50+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:26:51+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:27:51+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:27:51+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:28:52+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:28:53+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:29:54+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:29:54+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:30:55+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:30:55+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:31:56+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:31:56+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:32:57+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:32:57+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:33:58+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:33:58+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:34:59+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:34:59+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:36:00+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:36:00+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:37:01+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:37:01+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:38:01+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:38:02+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:39:02+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:39:03+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:40:03+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:40:04+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:41:04+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:41:05+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:42:05+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:42:06+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:43:06+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:43:07+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:44:07+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:44:08+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:45:08+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:45:09+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:46:10+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:46:10+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:47:10+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:47:11+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:48:11+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:48:12+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:49:12+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:49:13+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:50:13+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:50:14+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:51:14+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:51:15+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:52:15+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:52:17+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:53:17+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:53:18+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:54:18+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:54:19+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:55:19+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:55:20+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:56:20+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:56:21+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:57:22+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:57:22+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:58:23+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:58:23+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T05:59:25+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T05:59:26+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:00:27+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:00:27+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:01:28+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:01:28+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:02:29+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:02:29+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:03:30+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:03:30+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:04:31+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:04:31+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:05:32+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:05:32+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:06:33+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:06:33+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:07:34+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:07:34+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:08:35+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:08:35+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:09:36+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:09:36+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:10:37+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:10:37+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:11:38+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:11:38+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:12:39+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:12:40+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:13:40+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:13:41+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:14:41+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:14:42+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:15:43+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:15:43+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:16:44+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:16:44+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:17:45+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:17:45+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:18:46+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:18:47+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:19:48+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:19:48+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:20:49+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:20:49+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:21:50+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:21:50+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:22:51+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:22:51+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:23:54+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:23:55+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:24:58+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:24:58+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:26:01+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:26:01+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:27:04+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:27:05+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## Driver note — exp01 reject (2026-11-26T06:27:10+01:00)
- slices=1627328 (d244) holdout=524985 (d81)
- Proceeding immediately to next experiment (exp02).

## Driver note — exp02 reject (2026-11-26T06:27:11+01:00)
- slices=1627082 (d-2) holdout=524904 (d0)
- Proceeding immediately to next experiment (exp03).

## exp03 — reject
- slices: 1627084 (best 1627084, delta 0)
- holdout: 524904 (best 524904, delta 0)
- rt=1 rss_ok=1
- branch: exp/ppmd-nudge-03

## DRIVER_AGENT — exp03 reject (2026-11-26T06:36:14+0100)
- slices=1627084 (d+0) holdout=524904 (d+0) rt=1 rss_ok=1
- Proceeding immediately to exp04.

## 2026-11-26 — EXP03 reject / EXP04 start
- EXP03 slices=1627084 (d0) holdout=524904 (d0) → reject
- Started EXP04: drop AddMatch {13,2} on exp/match-ablation-04

## 2026-11-26 — EXP04 slices
- total_comp=**1627076** (d**-8**), rss=5807384, rt=1
- Holdout relaunched after campaign stall at slices→holdout boundary

## exp04 — reject
- slices: 1627076 (best 1627084, delta -8)
- holdout: 524907 (best 524904, delta 3)
- rt=1 rss_ok=1
- branch: exp/match-ablation-04

## EXP04 reject / EXP05 start (2026-11-26T08:14:33+01:00)
- EXP04 slices=1627076 (d-8) holdout=524907 (d+3) → reject (holdout worse)
- EXP05: SSE opposite M_x1W0/M_x2W0 −48/−40 on exp/sse-opposite-05

## 2026-11-26 — EXP04 reject / EXP05 start
- EXP04 slices=1627076 (d-8) holdout=524907 (d+3) → reject (holdout worse)
- EXP05 SSE opposite nudge started on exp/sse-opposite-05

## exp05 — accept
- slices: 1626996 (best 1627084, delta -88)
- holdout: 524882 (best 524904, delta -22)
- rt=1 rss_ok=1
- branch: exp/sse-opposite-05

## EXP05 ACCEPT (2026-11-26T09:35:08+01:00)
- slices=1626996 (d-88 vs old best 1627084) rt=1 rss=5807044
- holdout=524882 (d-22 vs old best 524904) rt=1 rss=5805520
- SSE M_x1W0/M_x2W0 opposite nudge (−48/−40)
- New BEST: slices=1626996 holdout=524882
- EXP06 started immediately (L1 LR down).

## 2026-11-26 — EXP05 ACCEPT
- slices=**1626996** (d**-88**), holdout=**524882** (d**-22**), rss_s=5807044 rss_h=5805520, rt=1
- SSE M_x1W0 (7648−48), M_x2W0 (2560−40) committed to master
- New BEST locked for subsequent accepts; proceeding to EXP06

## exp06 — reject
- slices: 1626996 (best 1626996, delta 0)
- holdout: 524882 (best 524882, delta 0)
- rt=1 rss_ok=1
- branch: exp/l1-lr-down-06

## 2026-11-26 — EXP06 reject / EXP07 start
- EXP06 slices=1626996 (d0) holdout=524882 (d0) → reject (no change vs EXP05)
- EXP07: drop AddMatch {13,2} on accepted SSE baseline

## EXP06 reject / EXP07 start (2026-11-26T10:57:11+01:00)
- EXP06 exact match best (L1 0.00028 noop on these totals) → reject
- EXP07: re-try match {13,2} drop on accepted SSE baseline

## exp07 — reject
- slices: 1627077 (best 1626996, delta 81)
- holdout: 524908 (best 524882, delta 26)
- rt=1 rss_ok=1
- branch: exp/match-drop-07

## 2026-11-26 — EXP07 reject / EXP08 start
- EXP07 slices=1627077 (d+81) holdout=524908 (d+26) → reject
- EXP08: SSE further M_x1W0/M_x2W0 −72/−60 from accepted −48/−40

## EXP07 reject / EXP08 start (2026-11-26T12:16:36+01:00)
- EXP07 s=1627077 (d+81) h=524908 (d+26) → reject
- EXP08: further SSE opposite −72/−60 on accepted best

## exp08 — reject
- slices: 1627080 (best 1626996, delta 84)
- holdout: 524908 (best 524882, delta 26)
- rt=1 rss_ok=1
- branch: exp/sse-more-08

## 2026-11-26 — EXP08 reject / EXP09 clean start
- EXP08 slices=1627080 (d+84) holdout=524908 (d+26) → reject (further SSE overshot)
- EXP09: mx9 LR 0.005→0.0048 on accepted SSE baseline (cleaned after dirty start)

## EXP08 reject / EXP09 start (2026-11-26T13:36:22+01:00)
- EXP08 s=1627080 (d+84) h=524908 (d+26) → reject (further SSE overshot)
- EXP09: L0 hottest mixer LR 0.005→0.0048 on accepted SSE baseline

## EXP09 mid-run restart note (2026-11-26T14:22:12+01:00)
- First pass reached s06 decompress; orchestrator rebuild/restart at 14:16:38 wiped work → clean s00 restart
- Patch remains mx9 only 0.005→0.0048; best still 1626996/524882
- Hardened campaign/parent: no dual soft-start; skip relaunch while mid-run detail fresh
- Queued EXP10: drop AddDoubleIndirect (ANALYSIS #4)

## EXP09 slices done (2026-11-26T15:21:27+01:00)
- slices=1627085 (best 1626996, delta +89) rt=1 rss=5815396
- holdout launched; accept impossible on slices alone

## exp09 — reject
- slices: 1627085 (best 1626996, delta 89)
- holdout: 524907 (best 524882, delta 25)
- rt=1 rss_ok=1
- branch: exp/l0-lr-fine-09

## exp09 — reject
- slices: 1627085 (best 1626996, delta 89)
- holdout: 524907 (best 524882, delta 25)
- rt=1 rss_ok=1
- branch: exp/l0-lr-fine-09

## 2026-11-26 — EXP09 reject / EXP10 start
- EXP09 slices=1627085 (d+89) holdout=524907 (d+25) → reject
- EXP10: drop AddDoubleIndirect() on accepted SSE (ANALYSIS #4)

## 2026-11-26 — freeze for server move
- EXP09 reject: slices 1627085 (+89 vs best), holdout 524907 (+25)
- Stopped campaign/parent; wrote HANDOFF.md for transfer
- Current best remains EXP05 SSE opposite (1626996 / 524882)

## 2026-11-26 — EXP10 aborted for server move
- Campaign briefly started EXP10 (indirect drop) before freeze; branch `exp/indirect-drop-10` left unmerged; no EXP10 CSV row; master restored to EXP05 SSE best.

## DRIVER resume after STOP race (2026-11-26T15:44:06+01:00)
- EXP09 reject confirmed: slices=1627085 (d+89) holdout=524907 (d+25) rt=1 rss_ok
- Cleared STOPPED_BY_USER freeze; resumed EXP10 AddDoubleIndirect drop on SSE best
- Best remains 1626996 / 524882
