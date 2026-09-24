#!/usr/bin/env bash
# Downloads and stages the on-device Arabic Whisper model used by
# lib/modules/ai_intake/services/sherpa_whisper_arabic_transcriber.dart.
#
# This is a manual, explicit, one-time developer step — the app itself never
# fetches this file at runtime (see ARCHITECTURE.md, "On-device Arabic
# speech-to-text" for why).
#
# Usage:
#   bash scripts/setup_whisper_arabic_model.sh <output-directory>
#
# Then copy the 3 files it produces onto the target device/simulator at the
# path documented in ARCHITECTURE.md (getApplicationSupportDirectory() +
# "/ai_intake_whisper_tiny_ar"). Exact per-platform copy commands are also in
# ARCHITECTURE.md.
set -euo pipefail

OUT_DIR="${1:?Usage: setup_whisper_arabic_model.sh <output-directory>}"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-whisper-tiny.tar.bz2"
EXPECTED_SHA256="c46116994e539aa165266d96b325252728429c12535eb9d8b6a2b10f129e66b1"
ARCHIVE_NAME="sherpa-onnx-whisper-tiny.tar.bz2"
EXTRACTED_DIR="sherpa-onnx-whisper-tiny"

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

if [ ! -f "$ARCHIVE_NAME" ]; then
  echo "Downloading multilingual Whisper tiny model (~111MB) from sherpa-onnx's release..."
  curl -SL -o "$ARCHIVE_NAME" "$URL"
fi

echo "Verifying checksum..."
ACTUAL_SHA256="$(shasum -a 256 "$ARCHIVE_NAME" | cut -d' ' -f1)"
if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
  echo "Checksum mismatch! Expected $EXPECTED_SHA256, got $ACTUAL_SHA256." >&2
  exit 1
fi

tar xjf "$ARCHIVE_NAME"

DEST="$OUT_DIR/ai_intake_whisper_tiny_ar"
mkdir -p "$DEST"
cp "$EXTRACTED_DIR/tiny-encoder.int8.onnx" "$DEST/"
cp "$EXTRACTED_DIR/tiny-decoder.int8.onnx" "$DEST/"
cp "$EXTRACTED_DIR/tiny-tokens.txt" "$DEST/"

echo ""
echo "Done. The 3 files the app needs are in: $DEST"
echo "  tiny-encoder.int8.onnx  ($(du -h "$DEST/tiny-encoder.int8.onnx" | cut -f1))"
echo "  tiny-decoder.int8.onnx  ($(du -h "$DEST/tiny-decoder.int8.onnx" | cut -f1))"
echo "  tiny-tokens.txt         ($(du -h "$DEST/tiny-tokens.txt" | cut -f1))"
echo ""
echo "Copy these onto the target device — see ARCHITECTURE.md for the exact"
echo "destination path and per-platform copy command."
