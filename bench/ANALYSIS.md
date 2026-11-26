# Architecture analysis (fx2-cmix-t-rework)

Upstream: fx2-cmix-transformer (LSTM → pretrained transformer on fx2-cmix).
Claimed ~9.95× on enwik9. Score = archive bytes + decompressor executable bytes.

## Pipeline

### `-e` (enwik9 / prize path)

1. Unpack embedded dict, article order, transformer weights from `./cmix`
2. Split intro/main/coda → reorder articles → phda9/WIT markup transforms
3. WRT dictionary encode (`english.dic`) → vocab (205 bytes) → model pretrain on dict
4. Bit-level arithmetic coding via `Predictor` (transformer, no LSTM)
5. Build `archive9` = UPX’d decomp binary + dict.comp + tfweights + bitstream + header

### `-c` / `-d` (slice bench path)

Dictionary preprocess + optional `--transformer <weights>`. No article reorder / phda9.
Vocab must be exactly **205** for the transformer (observed OK on our 1MB wiki slices).

## Model stack (`predictor.cpp`)

| Component | Role |
|-----------|------|
| Bracket | Closing paren/`{}`/`[]`/quote predictions |
| FXCM (`fxcmv1`) | Large paq8-style context mixer; ~431 stretched probs + 6 APMs |
| Direct | Count-based on bracket context |
| Match | LZ-style match (60MB history) |
| Indirect\<Nonstationary\> / RunMap | State-machine indirect contexts |
| PPMD | Order 25, mem 14000; byte dist → transformer prior + mixer |
| ByteMixer | Holds next-byte dist from transformer (or LSTM if no TF) |
| Mixer L0 | 23 context-keyed logistic mixers (~461 inputs) |
| Mixer L1 | 1 mixer over 23 outs + FXCM + byte-mixer |
| SSE | Secondary symbol estimation after L1 |

## Transformer

- V=205, D=192, 12 layers, ~6M params; int4 weights / int8 acts
- File `models/6m-q4-fp32.tfwc2` ≈ **2,930,652 B** (dominates decompressor size)
- Kimi Linear on 75% of layers; sliding attn window 1024 on layers 3,7,11
- Prior = PPMD float16; article pieces reset every separator or 2¹⁷ tokens

## Mixer LRs (layer 0)

Mostly **0.005** (mx9/11/13, wordscxt, mx6/14–17); some 0.002 / 0.001 / 0.0007 / **0.0005**.
Layer 1: **0.0003**. Step decay 1.0→0.7→0.3→0.2 at 1M / 5M / 25M steps.

## Where bytes go

1. Residual bitstream after strong models (dominates archive)
2. FXCM + outer mixer/SSE (largest online adaptive capacity)
3. Transformer channel (~0.91 nats/byte vs LSTM ~1.23)
4. PPMD prior + direct mixer input
5. Match / Indirect / Bracket (smaller)
6. Preprocessing shrinks *input* (dict, phda9, reorder) — reorder/phda9 invisible on raw slices

## Decompressor size

| Piece | Approx |
|-------|--------|
| UPX’d code | ~1–few MB |
| Compressed dict | ≪412 KB |
| TF weights | **~2.93 MB** |
| Bitstream | dominant in archive9 |
| Header | 16 B |

## Compile flags that affect bits

- `SEED=923` → Indirect `map_offset_` (changes archive)
- `UPDATE_LIMIT=3000` → LSTM only (irrelevant for `-e` / `--transformer`)

## Slice-testing caveats

- 1MB is cold-start: understates late FXCM APM rates, mixer decay, dict pretrain carry-over, reorder.
- Dictionary still applied → slices biased toward WRT-friendly English.
- Extrapolate time/RAM to 1GB conservatively (~1000×) before accepting.

## Ranked improvement ideas

| # | Idea | Expected gain | Time/RAM/size cost | Risk | Slice-visible? |
|---|------|---------------|--------------------|------|----------------|
| 1 | Mixer LR retune (0.005 group / L1 0.0003) | 20–150 KB archive | ~0 | Low | Partial |
| 2 | SSE constant retune | 10–80 KB | ~0 | Low–med | Partial |
| 3 | PPMD order/mem nudge | ±50–200 KB | RAM/time | Med | Yes (prior) |
| 4 | Drop weakest match/indirect if ablation negative | 0–50 KB net | −RAM/−.text | Low | Better mid-file |
| 5 | Article-boundary / first-token handling | 20–100 KB | ~0 | Med | Weak on slices |
| 6 | Dict/WRT trim | Tens of KB program | Build | Med | Needs dict path |
| 7 | UPX / more `-Os` cold paths | 10–100 KB program | Build | Low | N/A |
| 8 | FXCM APM rate schedule | 20–100 KB | ~0 | Med | **No** on 1MB |
| 9 | Better TF QAT / weight file ≤2.93MB | 50–300 KB | GPU train | Med | Loss yes |
| 10 | Larger TF | Maybe large win | **+MB**, time | High | Score maybe worse |

**First experiment plan:** small mixer LR tweak (idea #1) — low risk, cheap to verify.
