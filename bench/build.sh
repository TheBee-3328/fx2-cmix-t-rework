#!/usr/bin/env bash
# Build cmix for benchmarking. Default: fast non-PGO build (same SEED /
# UPDATE_LIMIT as the official script). Pass --official for PGO+UPX+embed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OFFICIAL=0
if [[ "${1:-}" == "--official" ]]; then OFFICIAL=1; fi

# nix-shell often exports CC=gcc; force clang++. COREI7 gives AVX2 without
# -march=native (which Nix strips via NIX_ENFORCE_NO_NATIVE).
CXX_COMPILER=clang++
SEED=923
UPDATE_LIMIT=3000
DEFINES="-DSEED=$SEED -DUPDATE_LIMIT=$UPDATE_LIMIT"
export NIX_ENFORCE_NO_NATIVE=0

if [[ "$OFFICIAL" -eq 1 ]]; then
  set -x
  rm -rf pgo_data && mkdir -p pgo_data
  make CC="$CXX_COMPILER" COREI7=1 CFLAGS_DEFINES="$DEFINES" prof_gen -j"$(nproc)"
  ./cmix -c ./prof_input/input ./prof_comp > ./prof_output
  rm -f ./prof_comp ./prof_output
  PROFDATA=llvm-profdata
  command -v llvm-profdata-17 >/dev/null && PROFDATA=llvm-profdata-17
  $PROFDATA merge -output=default.profdata ./pgo_data/*
  mv default.profdata pgo_data/
  make CC="$CXX_COMPILER" COREI7=1 CFLAGS_DEFINES="$DEFINES" prof_use -j"$(nproc)"
  if command -v upx-ucl >/dev/null; then upx-ucl -9 cmix; else upx -9 cmix; fi
  DIR=run
  mkdir -p ./$DIR
  cp ./cmix $DIR/cmix_orig
  pushd $DIR
  ./cmix_orig -c "$ROOT/dictionary/english.dic" ./comp_dict
  ./cmix_orig -c "$ROOT/src/readalike_prepr/data/new_article_order" ./comp_order
  cp "$ROOT/models/6m-q4-fp32.tfwc2" ./comp_tfweights
  ./cmix_orig -h "$(wc -c < ./comp_dict)" "$(wc -c < ./comp_order)" 0 "$(wc -c < ./comp_tfweights)"
  cat ./cmix_orig ./comp_dict ./comp_order ./comp_tfweights header.dat > ./cmix
  chmod +x ./cmix
  popd
  echo "Official build -> $ROOT/run/cmix ($(stat -c%s run/cmix) bytes)"
else
  make CC="$CXX_COMPILER" COREI7=1 CFLAGS_DEFINES="$DEFINES" -j"$(nproc)" cmix
  strip -s cmix 2>/dev/null || true
  echo "Dev build -> $ROOT/cmix ($(stat -c%s cmix) bytes)"
  echo "Note: use --transformer models/6m-q4-fp32.tfwc2 with -c/-d for TF path."
fi
