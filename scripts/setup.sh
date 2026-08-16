#!/bin/bash

set -e

BUILDER_ROOT="$GITHUB_WORKSPACE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [setup] Starting environment setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Load config
source "$BUILDER_ROOT/config.env"

# Export paths
export KERNEL_DIR="$BUILDER_ROOT/kernel"
export AK3_DIR="$BUILDER_ROOT/AnyKernel3"
export CLANG_DIR="$BUILDER_ROOT/clang"
export GCC64_DIR="$BUILDER_ROOT/gcc64"
export GCC32_DIR="$BUILDER_ROOT/gcc32"
export KERNEL_OUT="$KERNEL_DIR/out"

# Persist for subsequent steps
{
  echo "KERNEL_DIR=$KERNEL_DIR"
  echo "AK3_DIR=$AK3_DIR"
  echo "CLANG_DIR=$CLANG_DIR"
  echo "GCC64_DIR=$GCC64_DIR"
  echo "GCC32_DIR=$GCC32_DIR"
  echo "KERNEL_OUT=$KERNEL_OUT"
  echo "KERNEL_REPO=$KERNEL_REPO"
  echo "KERNEL_BRANCH=$KERNEL_BRANCH"
  echo "KERNEL_DEFCONFIG=$KERNEL_DEFCONFIG"
  echo "KERNEL_VERSION=$KERNEL_VERSION"
  echo "KERNELSU_BRANCH=$KERNELSU_BRANCH"
  echo "AK3_REPO=$AK3_REPO"
  echo "AK3_BRANCH=$AK3_BRANCH"
  echo "KBUILD_BUILD_USER=$KBUILD_BUILD_USER"
  echo "KBUILD_BUILD_HOST=$KBUILD_BUILD_HOST"
} >> "$GITHUB_ENV"

# Toolchain: LineageOS Clang r416183b
echo ""
echo "→ Cloning LineageOS Clang r416183b..."
git clone --depth=1 \
  https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b.git \
  "$CLANG_DIR" &>/dev/null
echo "✓ Clang ready: $(${CLANG_DIR}/bin/clang --version | head -1)"

# Toolchain: GCC
echo ""
echo "→ Cloning GCC64..."
git clone --depth=1 \
  https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git \
  "$GCC64_DIR" &>/dev/null
echo "✓ GCC64 ready"

echo "→ Cloning GCC32..."
git clone --depth=1 \
  https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git \
  "$GCC32_DIR" &>/dev/null
echo "✓ GCC32 ready"

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
