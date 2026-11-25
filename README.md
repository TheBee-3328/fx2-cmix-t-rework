# fx2-cmix-t-rework

Fork of **fx2-cmix-transformer** aimed at further reducing the Hutter Prize
score (compressed archive size + decompressor executable size) on enwik9.

Upstream contribution (preserved): replace the online LSTM in Kaido Orav and
Byron Knoll's **fx2-cmix** with a pretrained quantized transformer. Details of
that work remain in `writeup.md`.

This fork's changes (benchmarking, parameter/model tweaks, and any accepted
score improvements) are by **Michael Chobot (TheBee-3328)**. See `COPYRIGHT`.

## License

This program is free software under the **GNU General Public License v3**.
The full license text is in [`LICENSE`](LICENSE) (FSF GPLv3; do not edit that
file). Copyright holders and third-party notices are in [`COPYRIGHT`](COPYRIGHT).

## Compiling

1. Run `./setup.sh` once to install requirements (Debian/Ubuntu), or use a
   Nix shell with `clang`, `llvm`, `gnumake`, and `upx`.
2. If you need to comply with the Hutter Prize's 10GB RAM limit, set
   `bool mmap_to_disk = true;` in `src/models/ppmd.cpp`. This may crash on
   some machines and writes heavily to disk. Leaving it at `false` is fine
   when you have enough RAM.
3. Official build: `./build_and_construct_comp.sh` (or `./bench/build.sh --official`
   under Nix). Produces `./run/cmix`, the enwik9-specialized compressor —
   not the same as `./cmix` or `./run/cmix_orig`.
4. Fast dev build: `./bench/build.sh`.

## Compressing

Create an empty directory and place `enwik9` and `./run/cmix` in it, then:

```bash
./cmix -e enwik9 enwik9.comp
```

This produces a self-extracting archive `archive9`. Ignore other outputs,
including `enwik9.comp`.

`enwik9` is not shipped in this repository (see `.gitignore`). Download it
from [Matt Mahoney's page](http://mattmahoney.net/dc/textdata.html).

## Decompressing

```bash
./archive9
```

Produces `enwik9_uncompressed`, identical to `enwik9`.

## Slice benchmarking

```bash
./bench/build.sh
./bench/run.sh              # 10 fixed 1MB slices -> bench/results.csv
./bench/run.sh --holdout    # 3 holdout slices
```

Offsets are fixed in `bench/slices.json` and must not be changed.

## Training the Transformer

First save PPMD outputs (needs ~300GB disk):

```bash
./make_training_data.sh
```

Then with [uv](https://docs.astral.sh/uv/getting-started/installation/):

```bash
uv run torchrun --nproc_per_node $N_GPUS -m training_recipes.train_6m
uv run torchrun --nproc_per_node $N_GPUS -m training_recipes.quantize
uv run torchrun --nproc_per_node $N_GPUS -m training_recipes.cooldown
```

If you have fewer than 8 GPUs, either scale batch size / grad accumulation by
`N_GPUS / 8`, or leave them unchanged (may alter training dynamics).

## Development notes

Setting `mmap_to_disk = true` in `src/models/ppmd.cpp` crashed on some
machines; it was tested on GCE image `ubuntu-2004-focal-v20240731`.
