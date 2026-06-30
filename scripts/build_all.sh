#!/bin/bash
# =============================================================================
# build_all.sh — Build zvec native libraries for all platforms
#
# Usage:
#   bash scripts/build_all.sh [BUILD_TYPE]
#
# Build targets:
#   - Android: arm64-v8a
#   - iOS:     arm64 device, arm64 simulator (Apple Silicon)
#   - macOS:   host architecture (when run on macOS)
#   - Linux:   host architecture (when run on Linux)
#   - Windows: use scripts/build_windows.ps1
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_TYPE=${1:-"Release"}

echo "============================================"
echo "  Building zvec for all platforms"
echo "  Build Type: $BUILD_TYPE"
echo "============================================"

# ---------------------------------------------------------------------------
# Android
# ---------------------------------------------------------------------------
echo ""
echo ">>> Android arm64-v8a"
bash "$SCRIPT_DIR/build_android.sh" arm64-v8a 21 "$BUILD_TYPE"

# ---------------------------------------------------------------------------
# iOS
# ---------------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
    echo ""
    echo ">>> iOS arm64 (device)"
    bash "$SCRIPT_DIR/build_ios.sh" OS "$BUILD_TYPE"

    echo ""
    echo ">>> iOS arm64 Simulator (Apple Silicon)"
    bash "$SCRIPT_DIR/build_ios.sh" SIMULATORARM64 "$BUILD_TYPE"
fi

# ---------------------------------------------------------------------------
# Desktop
# ---------------------------------------------------------------------------
case "$(uname -s)" in
    Darwin)
        echo ""
        echo ">>> macOS host"
        bash "$SCRIPT_DIR/build_macos.sh" "$BUILD_TYPE"
        ;;
    Linux)
        echo ""
        echo ">>> Linux host"
        bash "$SCRIPT_DIR/build_linux.sh" "$BUILD_TYPE"
        ;;
esac

echo ""
echo "============================================"
echo "  All builds complete!"
echo ""
echo "  Android artifacts:"
echo "    android/src/main/jniLibs/arm64-v8a/libzvec.so"
echo ""
echo "  iOS artifacts:"
echo "    ios/zvec.framework/zvec"
echo ""
echo "  Desktop artifacts:"
echo "    macos/zvec_native.framework/zvec_native (when run on macOS)"
echo "    linux/lib/libzvec.so (when run on Linux)"
echo "    windows/lib/zvec.dll (run scripts/build_windows.ps1 on Windows)"
echo ""
echo "  Release zips (for GitHub Releases):"
echo "    build/release/libzvec-android-arm64-v8a.zip"
echo "    build/release/zvec-framework-ios.zip"
echo "    build/release/zvec-framework-macos-<arch>.zip"
echo "    build/release/libzvec-linux-<arch>.zip"
echo "    build/release/libzvec-windows-x64.zip"
echo "============================================"
