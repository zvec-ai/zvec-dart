#!/bin/bash
# =============================================================================
# prepare_jieba_assets.sh - Copy Jieba dictionaries into Flutter package assets.
#
# The source dictionaries live in the zvec submodule. Keep the generated
# package asset directory out of git, and run this before publishing.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_DIR="$PROJECT_ROOT/third_party/zvec/thirdparty/cppjieba/cppjieba-5.6.7/dict"
TARGET_DIR="$PROJECT_ROOT/assets/jieba_dict"

REQUIRED_FILES=(
  "jieba.dict.utf8"
  "hmm_model.utf8"
)

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Jieba dictionary source directory not found: $SOURCE_DIR"
  echo "Run: git submodule update --init --recursive"
  exit 1
fi

mkdir -p "$TARGET_DIR"

for file in "${REQUIRED_FILES[@]}"; do
  if [ ! -f "$SOURCE_DIR/$file" ]; then
    echo "Error: required Jieba dictionary missing: $SOURCE_DIR/$file"
    exit 1
  fi
  cp "$SOURCE_DIR/$file" "$TARGET_DIR/$file"
done

echo "Prepared Jieba dictionary assets in $TARGET_DIR"
