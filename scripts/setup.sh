#!/bin/bash
set -e

BUILDER_ROOT="$GITHUB_WORKSPACE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [setup] Starting environment setup"
echo " [setup] Target Android version: $ANDROID_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Load config
source "$BUILDER_ROOT/config.env"

# Resolve Clang branch/tag from Android version
case "$ANDROID_VERSION" in
    13)
        CLANG_BRANCH="android13-qpr3-release"
        CLANG_TAG="clang-r450784d"
        ;;
    14)
        CLANG_BRANCH="android14-qpr3-release"
        CLANG_TAG="clang-r487747c"
        ;;
    15)
        CLANG_BRANCH="android15-qpr2-release"
        CLANG_TAG="clang-r536225"
        ;;
    16)
        CLANG_BRANCH="android16-qpr2-release"
        CLANG_TAG="clang-r563880c"
        ;;
    *)
        echo "✗ Unknown ANDROID_VERSION: $ANDROID_VERSION (expected 13-16)"
        exit 1
        ;;
esac

# Export paths
export KERNEL_DIR="$BUILDER_ROOT/kernel"
export AK3_DIR="$BUILDER_ROOT/AnyKernel3"
export CLANG_DIR="$BUILDER_ROOT/clang"
export KERNEL_OUT="$KERNEL_DIR/out"

# Persist for subsequent steps
{
  echo "KERNEL_DIR=$KERNEL_DIR"
  echo "AK3_DIR=$AK3_DIR"
  echo "CLANG_DIR=$CLANG_DIR"
  echo "KERNEL_OUT=$KERNEL_OUT"
  echo "KERNEL_REPO=$KERNEL_REPO"
  echo "KERNEL_BRANCH=$KERNEL_BRANCH"
  echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "AK3_REPO=$AK3_REPO"
  echo "AK3_BRANCH=$AK3_BRANCH"
  echo "KSU_SETUP_URL=$KSU_SETUP_URL"
  echo "KSU_SETUP_ARG=$KSU_SETUP_ARG"
  echo "SUSFS_HOOK_URL=$SUSFS_HOOK_URL"
  echo "SUSFS_PATCH_BASE=$SUSFS_PATCH_BASE"
  echo "KBUILD_BUILD_USER=$KBUILD_BUILD_USER"
  echo "KBUILD_BUILD_HOST=$KBUILD_BUILD_HOST"
} >> "$GITHUB_ENV"

# Toolchain: AOSP mainline Clang
echo ""
echo "→ Downloading Clang for Android $ANDROID_VERSION..."
echo "  Branch: $CLANG_BRANCH"
echo "  Tag   : $CLANG_TAG"
mkdir -p "$CLANG_DIR"

CLANG_URL="https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/${CLANG_BRANCH}/${CLANG_TAG}.tar.gz"
curl -LSs "$CLANG_URL" -o /tmp/clang.tar.gz || {
    echo "✗ Failed to download Clang from $CLANG_URL"
    exit 1
}
tar -xzf /tmp/clang.tar.gz -C "$CLANG_DIR"
rm -f /tmp/clang.tar.gz

if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo "✗ Clang binary not found after extraction!"
    exit 1
fi
echo "✓ Clang ready: $(${CLANG_DIR}/bin/clang --version | head -1)"

# Kernel Source
echo ""
echo "→ Cloning kernel source..."
echo "  Repo  : $KERNEL_REPO"
echo "  Branch: $KERNEL_BRANCH"
git clone --depth=1 -b "$KERNEL_BRANCH" "$KERNEL_REPO" "$KERNEL_DIR" &>/dev/null
echo "✓ Kernel cloned → $KERNEL_DIR"

# AnyKernel3
echo ""
echo "→ Cloning AnyKernel3..."
git clone --depth=1 -b "$AK3_BRANCH" "$AK3_REPO" "$AK3_DIR" &>/dev/null
echo "✓ AnyKernel3 cloned → $AK3_DIR"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [setup] Done ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
