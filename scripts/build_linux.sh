#!/bin/bash
# =============================================================================
# build_linux.sh — Build zvec native dynamic library for Linux
#
# Usage:
#   bash scripts/build_linux.sh [BUILD_TYPE]
#
# Parameters:
#   BUILD_TYPE - Release (default) | Debug
#
# Output:
#   build/linux/libzvec.so
#   linux/lib/libzvec.so
#   build/release/libzvec-linux-<arch>.zip
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZVEC_SRC="$PROJECT_ROOT/third_party/zvec"

BUILD_TYPE=${1:-"Release"}
MACHINE="$(uname -m)"

case "$MACHINE" in
    x86_64|amd64) RELEASE_ARCH="x64" ;;
    aarch64|arm64) RELEASE_ARCH="arm64" ;;
    *)
        echo "Error: Unsupported Linux architecture '$MACHINE'"
        exit 1 ;;
esac

if [ ! -d "$ZVEC_SRC/src" ]; then
    echo "Error: third_party/zvec does not exist or is not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

echo "============================================"
echo "  Zvec Linux Build"
echo "  Build Type: $BUILD_TYPE"
echo "  Arch:       $MACHINE ($RELEASE_ARCH)"
echo "============================================"

NPROC="$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)"

echo ""
echo "[1/3] Building host protoc..."

HOST_BUILD_DIR="$PROJECT_ROOT/build/host"
PROTOC_EXECUTABLE="$HOST_BUILD_DIR/bin/protoc"

if [ -x "$PROTOC_EXECUTABLE" ]; then
    echo "  Already exists, skipping: $PROTOC_EXECUTABLE"
else
    pushd "$ZVEC_SRC" > /dev/null
    git submodule foreach --recursive 'git stash --include-untracked 2>/dev/null || true' > /dev/null 2>&1
    popd > /dev/null

    mkdir -p "$HOST_BUILD_DIR"
    pushd "$HOST_BUILD_DIR" > /dev/null
    cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" "$ZVEC_SRC"
    cmake --build . --target protoc --parallel "$NPROC"
    popd > /dev/null
fi

echo "[1/3] Done"

echo ""
echo "[2/3] Building zvec_c_api for Linux..."

pushd "$ZVEC_SRC" > /dev/null
git submodule foreach --recursive 'git stash --include-untracked 2>/dev/null || true' > /dev/null 2>&1
popd > /dev/null

LINUX_BUILD_DIR="$PROJECT_ROOT/build/linux_build"
mkdir -p "$LINUX_BUILD_DIR"
pushd "$LINUX_BUILD_DIR" > /dev/null

cmake \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_C_BINDINGS=ON \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DBUILD_TOOLS=OFF \
    -DCMAKE_INSTALL_PREFIX="./install" \
    -DGLOBAL_CC_PROTOBUF_PROTOC="$PROTOC_EXECUTABLE" \
    "$ZVEC_SRC"

cmake --build . --target zvec_c_api --parallel "$NPROC"
popd > /dev/null

echo "[2/3] Done"

echo ""
echo "[3/3] Copying libzvec.so ..."

LINUX_OUTPUT_DIR="$PROJECT_ROOT/build/linux"
LINUX_PLUGIN_LIB_DIR="$PROJECT_ROOT/linux/lib"
mkdir -p "$LINUX_OUTPUT_DIR" "$LINUX_PLUGIN_LIB_DIR"

SO_FILE=$(find "$LINUX_BUILD_DIR" -name "libzvec_c_api.so" -type f | head -1)

if [ -z "$SO_FILE" ]; then
    echo "Error: libzvec_c_api.so build artifact not found"
    echo "CMake build directory contents:"
    find "$LINUX_BUILD_DIR" -name "*.so" -type f 2>/dev/null || true
    exit 1
fi

cp "$SO_FILE" "$LINUX_OUTPUT_DIR/libzvec.so"
cp "$SO_FILE" "$LINUX_PLUGIN_LIB_DIR/libzvec.so"

echo "[3/3] Done"

echo ""
echo "============================================"
echo "  Build successful!"
echo "  Output: build/linux/libzvec.so"
echo "          linux/lib/libzvec.so"
echo "  Size:   $(du -h "$LINUX_OUTPUT_DIR/libzvec.so" | cut -f1)"
echo "  Type:   $(file "$LINUX_OUTPUT_DIR/libzvec.so" | sed 's|.*: ||')"
echo "============================================"

RELEASE_DIR="$PROJECT_ROOT/build/release"
mkdir -p "$RELEASE_DIR"
ZIP_NAME="libzvec-linux-${RELEASE_ARCH}.zip"
cd "$LINUX_OUTPUT_DIR" && zip -j "$RELEASE_DIR/$ZIP_NAME" libzvec.so
echo "  Release zip: build/release/$ZIP_NAME"
