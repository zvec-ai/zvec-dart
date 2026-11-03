#!/usr/bin/env bash
# Run the Dart/FFI suite with the pinned upstream SDK.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -z "${ZVEC_LIBRARY_PATH:-}" ]]; then
  case "$(uname -m)" in
    arm64|aarch64) arch=arm64 ;;
    x86_64|amd64) arch=amd64 ;;
    *) echo "Unsupported host architecture: $(uname -m)" >&2; exit 1 ;;
  esac
  case "$(uname -s)" in
    Darwin) target="osx-$arch"; library=libzvec_c_api.dylib ;;
    Linux)
      target="linux-$arch"
      libc=$(ldd --version 2>&1 || true)
      if [[ "$libc" == *musl* ]]; then target="linux-musl-$arch"; fi
      library=libzvec_c_api.so ;;
    *) echo "Set ZVEC_LIBRARY_PATH to the native C API library for this host." >&2; exit 1 ;;
  esac
  sdk="$PWD/build/zvec-sdk/$target"
  dart tool/fetch_zvec.dart --target "$target" --output "$sdk"
  export ZVEC_LIBRARY_PATH="$sdk/lib/$library"
fi
exec flutter test "$@"
