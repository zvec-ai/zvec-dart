#!/bin/bash
# =============================================================================
# build_android.sh — Build zvec Android shared library
#
# Usage:
#   bash scripts/build_android.sh [ABI] [API_LEVEL] [BUILD_TYPE]
#
# Parameters:
#   ABI         - arm64-v8a (default) | armeabi-v7a | x86_64 | x86
#   API_LEVEL   - Minimum API level, default 21 (Android 5.0)
#   BUILD_TYPE  - Release (default) | Debug
#
# Examples:
#   bash scripts/build_android.sh                        # arm64-v8a Release
#   bash scripts/build_android.sh arm64-v8a 21 Release   # full parameters
#   bash scripts/build_android.sh armeabi-v7a            # 32-bit ARM
#
# Output:
#   android/src/main/jniLibs/<ABI>/libzvec.so
#
# Notes:
#   The upstream zvec CMake defines a zvec_c_api SHARED target. On Linux/Android
#   it uses --whole-archive to embed all internal static libs into the .so,
#   including factory registrations. No extra force-load or manual merging needed.
# =============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ZVEC_SRC="$PROJECT_ROOT/third_party/zvec"
PATCH_DIR="$PROJECT_ROOT/patches/zvec"

ABI=${1:-"arm64-v8a"}
API_LEVEL=${2:-21}
BUILD_TYPE=${3:-"Release"}

# ---------------------------------------------------------------------------
# Check prerequisites
# ---------------------------------------------------------------------------
if [ ! -d "$ZVEC_SRC/src" ]; then
    echo "Error: third_party/zvec does not exist or is not initialized"
    echo "Run: git submodule update --init --recursive"
    exit 1
fi

# Android SDK / NDK paths
export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT:-"$HOME/Library/Android/sdk"}
export ANDROID_HOME=${ANDROID_HOME:-"$ANDROID_SDK_ROOT"}

# Auto-detect NDK (prefer env var, otherwise find latest installed version)
if [ -z "$ANDROID_NDK_HOME" ]; then
    NDK_DIR="$ANDROID_SDK_ROOT/ndk"
    if [ -d "$NDK_DIR" ]; then
        ANDROID_NDK_HOME="$NDK_DIR/$(ls -1 "$NDK_DIR" | sort -V | tail -1)"
    fi
fi
export ANDROID_NDK_HOME

if [ ! -d "$ANDROID_NDK_HOME" ]; then
    echo "Error: Android NDK not found"
    echo "Set ANDROID_NDK_HOME env var, or install NDK via Android Studio"
    exit 1
fi

ANDROID_CMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"

prepare_android_zvec_source() {
    PATCHED_ZVEC_SRC="$PROJECT_ROOT/tmp/zvec_android_${ABI}_${API_LEVEL}_${BUILD_TYPE}/zvec"

    echo "  Preparing patched zvec source: $PATCHED_ZVEC_SRC"
    mkdir -p "$(dirname "$PATCHED_ZVEC_SRC")"
    rsync -a --delete --exclude=".git" "$ZVEC_SRC/" "$PATCHED_ZVEC_SRC/"
    find "$PATCHED_ZVEC_SRC" -name ".*_patched" -type f -delete

    if [ -d "$PATCH_DIR" ]; then
        local patch_file
        for patch_file in "$PATCH_DIR"/*.patch; do
            [ -e "$patch_file" ] || continue
            echo "  Applying patch: ${patch_file#$PROJECT_ROOT/}"
            patch -d "$PATCHED_ZVEC_SRC" -p1 < "$patch_file"
        done
    fi
}

echo "============================================"
echo "  Zvec Android Build"
echo "  ABI:        $ABI"
echo "  API Level:  $API_LEVEL"
echo "  Build Type: $BUILD_TYPE"
echo "  NDK:        $ANDROID_NDK_HOME"
echo "============================================"

# ---------------------------------------------------------------------------
# Step 1: Build host protoc (required for cross-compiling protobuf)
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
    env -u CMAKE_TOOLCHAIN_FILE cmake -DCMAKE_BUILD_TYPE="$BUILD_TYPE" "$ZVEC_SRC"
    make -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" protoc
    popd > /dev/null
fi

echo "[1/3] Done"

# ---------------------------------------------------------------------------
# Step 2: Cross-compile zvec_c_api shared library for Android
# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Cross-compiling zvec_c_api for Android ($ABI)..."

# Reset thirdparty submodules (patches may conflict)
pushd "$ZVEC_SRC" > /dev/null
git submodule foreach --recursive 'git stash --include-untracked 2>/dev/null || true' > /dev/null 2>&1
popd > /dev/null

prepare_android_zvec_source
ANDROID_BUILD_DIR="$PROJECT_ROOT/build/android_$ABI"
rm -rf "$ANDROID_BUILD_DIR"
mkdir -p "$ANDROID_BUILD_DIR"
pushd "$ANDROID_BUILD_DIR" > /dev/null

GIT_CEILING_DIRECTORIES="$PROJECT_ROOT/tmp" cmake \
    -DANDROID_NDK="$ANDROID_NDK_HOME" \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_CMAKE_TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ABI" \
    -DANDROID_NATIVE_API_LEVEL="$API_LEVEL" \
    -DANDROID_STL="c++_static" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DBUILD_C_BINDINGS=ON \
    -DBUILD_PYTHON_BINDINGS=OFF \
    -DBUILD_TOOLS=OFF \
    -DWITH_GFLAGS=OFF \
    -DCMAKE_INSTALL_PREFIX="./install" \
    -DGLOBAL_CC_PROTOBUF_PROTOC="$PROTOC_EXECUTABLE" \
    "$PATCHED_ZVEC_SRC"

# Build only the zvec_c_api target (compiles all deps and links into a single .so)
make -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" zvec_c_api
popd > /dev/null

echo "[2/3] Done"

# ---------------------------------------------------------------------------
# Step 3: Copy artifacts to Flutter project
# ---------------------------------------------------------------------------
echo ""
echo "[3/3] Copying libzvec.so to android/src/main/jniLibs/$ABI/ ..."

JNILIBS_DIR="$PROJECT_ROOT/android/src/main/jniLibs/$ABI"
mkdir -p "$JNILIBS_DIR"

# Find build artifact (zvec_c_api target produces libzvec_c_api.so)
SO_FILE=$(find "$ANDROID_BUILD_DIR" -name "libzvec_c_api.so" -type f | head -1)

if [ -z "$SO_FILE" ]; then
    echo "Error: libzvec_c_api.so build artifact not found"
    echo "CMake build directory contents:"
    find "$ANDROID_BUILD_DIR" -name "*.so" -type f 2>/dev/null || true
    exit 1
fi

# Rename to libzvec.so (Dart loads via DynamicLibrary.open('libzvec.so'))
cp "$SO_FILE" "$JNILIBS_DIR/libzvec.so"

echo "[3/3] Done"

echo ""
echo "============================================"
echo "  Build successful!"
echo "  Output: android/src/main/jniLibs/$ABI/libzvec.so"
echo "  Size:   $(du -h "$JNILIBS_DIR/libzvec.so" | cut -f1)"
echo "============================================"

# ---------------------------------------------------------------------------
# Step 4: Package as zip (for uploading to GitHub Releases)
# ---------------------------------------------------------------------------
RELEASE_DIR="$PROJECT_ROOT/build/release"
mkdir -p "$RELEASE_DIR"
ZIP_NAME="libzvec-android-${ABI}.zip"
cd "$JNILIBS_DIR" && zip -j "$RELEASE_DIR/$ZIP_NAME" libzvec.so
echo "  Release zip: build/release/$ZIP_NAME"
