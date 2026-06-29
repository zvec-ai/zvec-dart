#!/bin/bash
# =============================================================================
# build_macos.sh — Build zvec native dynamic library for macOS
#
# Usage:
#   bash scripts/build_macos.sh [BUILD_TYPE]
#
# Parameters:
#   BUILD_TYPE - Release (default) | Debug
#
# Examples:
#   bash scripts/build_macos.sh            # Release build
#   bash scripts/build_macos.sh Debug      # Debug build
#
# Output:
#   build/macos/libzvec.dylib       — direct Dart/FFI test library
#   build/macos/zvec.framework/     — Flutter macOS framework
#   macos/zvec.framework/           — local CocoaPods cache
#   build/release/zvec-framework-macos-<arch>.zip
#
# Notes:
#   This builds the native zvec_c_api shared library for the host macOS
#   platform. The framework zip is uploaded to GitHub Releases and downloaded
#   by macos/zvec.podspec during Flutter desktop builds.
#
#   Run tests with:
#     DYLD_LIBRARY_PATH=build/macos flutter test
#   or use the convenience script:
#     bash scripts/run_tests.sh
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZVEC_SRC="$PROJECT_ROOT/third_party/zvec"

BUILD_TYPE=${1:-"Release"}
MACOS_DEPLOYMENT_TARGET="10.15"
ARCH="$(uname -m)"

case "$ARCH" in
    arm64)  RELEASE_ARCH="arm64" ;;
    x86_64) RELEASE_ARCH="x64" ;;
    *)
        echo "Error: Unsupported macOS architecture '$ARCH'"
        exit 1 ;;
esac

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
if [ ! -d "$ZVEC_SRC/src" ]; then
    echo "Error: third_party/zvec does not exist or is not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

echo "============================================"
echo "  Zvec macOS Build"
echo "  Build Type: $BUILD_TYPE"
echo "  Arch:       $ARCH"
echo "  Target:     macOS $MACOS_DEPLOYMENT_TARGET"
echo "============================================"

# ---------------------------------------------------------------------------
# Step 1: Build host protoc (required for protobuf compilation)
# ---------------------------------------------------------------------------
echo ""
echo "[1/3] Building host protoc..."

HOST_BUILD_DIR="$PROJECT_ROOT/build/host"
PROTOC_EXECUTABLE="$HOST_BUILD_DIR/bin/protoc"

if [ -x "$PROTOC_EXECUTABLE" ]; then
    echo "  Already exists, skipping: $PROTOC_EXECUTABLE"
else
    # Reset thirdparty submodules
    pushd "$ZVEC_SRC" > /dev/null
    git submodule foreach --recursive 'git stash --include-untracked 2>/dev/null || true' > /dev/null 2>&1
    popd > /dev/null

    mkdir -p "$HOST_BUILD_DIR"
    pushd "$HOST_BUILD_DIR" > /dev/null
    cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" "$ZVEC_SRC"
    make -j"$(sysctl -n hw.ncpu)" protoc
    popd > /dev/null
fi

echo "[1/3] Done"

# ---------------------------------------------------------------------------
# Step 2: Build zvec_c_api shared library for macOS
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Building zvec_c_api for macOS..."

# Reset thirdparty submodules (patches may conflict)
pushd "$ZVEC_SRC" > /dev/null
git submodule foreach --recursive 'git stash --include-untracked 2>/dev/null || true' > /dev/null 2>&1
popd > /dev/null

MACOS_BUILD_DIR="$PROJECT_ROOT/build/macos_build"
mkdir -p "$MACOS_BUILD_DIR"
pushd "$MACOS_BUILD_DIR" > /dev/null

cmake \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
    -DBUILD_C_BINDINGS=ON \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DBUILD_TOOLS=OFF \
    -DCMAKE_INSTALL_PREFIX="./install" \
    -DGLOBAL_CC_PROTOBUF_PROTOC="$PROTOC_EXECUTABLE" \
    "$ZVEC_SRC"

# Build only the zvec_c_api target
make -j"$(sysctl -n hw.ncpu)" zvec_c_api
popd > /dev/null

echo "[2/3] Done"

# ---------------------------------------------------------------------------
# Step 3: Package desktop artifacts
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Packaging macOS artifacts ..."

MACOS_OUTPUT_DIR="$PROJECT_ROOT/build/macos"
FRAMEWORK_BUILD_DIR="$MACOS_OUTPUT_DIR/zvec.framework"
FRAMEWORK_PLUGIN_DIR="$PROJECT_ROOT/macos/zvec.framework"
mkdir -p "$MACOS_OUTPUT_DIR"

# Find build artifact
DYLIB_FILE=$(find "$MACOS_BUILD_DIR" -name "libzvec_c_api.dylib" -type f | head -1)

if [ -z "$DYLIB_FILE" ]; then
    echo "Error: libzvec_c_api.dylib build artifact not found"
    echo "CMake build directory contents:"
    find "$MACOS_BUILD_DIR" -name "*.dylib" -type f 2>/dev/null || true
    exit 1
fi

# Keep a plain dylib for Dart/FFI tests with ZVEC_LIBRARY_PATH.
cp "$DYLIB_FILE" "$MACOS_OUTPUT_DIR/libzvec.dylib"

# Package a framework for Flutter macOS/CocoaPods builds.
rm -rf "$FRAMEWORK_BUILD_DIR" "$FRAMEWORK_PLUGIN_DIR"
mkdir -p "$FRAMEWORK_BUILD_DIR/Headers"
cp "$DYLIB_FILE" "$FRAMEWORK_BUILD_DIR/zvec"
install_name_tool -id @rpath/zvec.framework/zvec "$FRAMEWORK_BUILD_DIR/zvec"

GENERATED_HEADER="$MACOS_BUILD_DIR/src/generated/zvec/c_api.h"
if [ -f "$GENERATED_HEADER" ]; then
    cp "$GENERATED_HEADER" "$FRAMEWORK_BUILD_DIR/Headers/"
else
    cp "$ZVEC_SRC/src/include/zvec/c_api.h" "$FRAMEWORK_BUILD_DIR/Headers/"
fi

FRAMEWORK_VERSION=$(awk '/^version:/ {print $2; exit}' "$PROJECT_ROOT/pubspec.yaml")
cat > "$FRAMEWORK_BUILD_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>zvec</string>
    <key>CFBundleIdentifier</key>
    <string>com.alibaba.zvec</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>zvec</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${FRAMEWORK_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${FRAMEWORK_VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>${MACOS_DEPLOYMENT_TARGET}</string>
</dict>
</plist>
EOF

cp -R "$FRAMEWORK_BUILD_DIR" "$FRAMEWORK_PLUGIN_DIR"

echo "[3/3] Done"

echo ""
echo "============================================"
echo "  Build successful!"
echo "  Output: build/macos/libzvec.dylib"
echo "          build/macos/zvec.framework/zvec"
echo "          macos/zvec.framework/zvec"
echo "  Size:   $(du -h "$MACOS_OUTPUT_DIR/libzvec.dylib" | cut -f1)"
echo "  Type:   $(file "$MACOS_OUTPUT_DIR/libzvec.dylib" | sed 's|.*: ||')"
echo "============================================"
echo ""
echo "  Run tests with:"
echo "    DYLD_LIBRARY_PATH=build/macos flutter test"
echo "  or:"
echo "    bash scripts/run_tests.sh"

# ---------------------------------------------------------------------------
# Step 4: Package as zip (for uploading to GitHub Releases)
# ---------------------------------------------------------------------------
RELEASE_DIR="$PROJECT_ROOT/build/release"
mkdir -p "$RELEASE_DIR"
ZIP_NAME="zvec-framework-macos-${RELEASE_ARCH}.zip"
cd "$MACOS_OUTPUT_DIR" && zip -r "$RELEASE_DIR/$ZIP_NAME" zvec.framework/
echo "  Release zip: build/release/$ZIP_NAME"
