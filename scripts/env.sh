#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: env.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

if [ ! -f "$DEVICE_JSON" ]; then
    echo "✗ No device config found at $DEVICE_JSON"
    exit 1
fi

# Read device config
read_field() {
    python3 -c "
import json, sys
d = json.load(open('$DEVICE_JSON'))['$DEVICE']
print(d.get('$1', ''))
"
}

KERNEL_REPO=$(read_field kernel_repo)
KERNEL_BRANCH=$(read_field kernel_branch)
KERNEL_DEFCONFIG=$(read_field defconfig)
KERNEL_ARCH=$(read_field arch)
CLANG_VERSION=$(read_field clang_version)

if [ -z "$CLANG_VERSION" ]; then
    echo "✗ No clang_version set in $DEVICE_JSON for device '$DEVICE'"
    exit 1
fi

export KERNEL_REPO KERNEL_BRANCH KERNEL_DEFCONFIG KERNEL_ARCH CLANG_VERSION

echo "→ Device: $DEVICE"
echo "→ Kernel: $KERNEL_REPO ($KERNEL_BRANCH)"
echo "→ Clang:  clang-$CLANG_VERSION"

# Resolve Clang toolchain
CLANG_DIR="$(pwd)/toolchain/clang-${CLANG_VERSION}"

if [ ! -d "$CLANG_DIR/bin" ]; then
    echo "→ Fetching clang-${CLANG_VERSION} from googlesource..."
    mkdir -p "$(dirname "$CLANG_DIR")"
    TMP_CLANG_REPO="$(pwd)/toolchain/.clang-src"
    rm -rf "$TMP_CLANG_REPO"

    git clone --filter=blob:none --no-checkout --depth 1 \
        https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
        "$TMP_CLANG_REPO"

    cd "$TMP_CLANG_REPO"
    git sparse-checkout init --cone
    git sparse-checkout set "clang-${CLANG_VERSION}"
    git checkout master 2>/dev/null || git checkout main
    cd - >/dev/null

    if [ ! -d "$TMP_CLANG_REPO/clang-${CLANG_VERSION}" ]; then
        echo "✗ clang-${CLANG_VERSION} not found in googlesource prebuilts repo."
        echo "  Check devices/${DEVICE}.json — clang_version may be wrong/renamed."
        exit 1
    fi

    mv "$TMP_CLANG_REPO/clang-${CLANG_VERSION}" "$CLANG_DIR"
    rm -rf "$TMP_CLANG_REPO"
fi

export PATH="${CLANG_DIR}/bin:${PATH}"
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CLANG_TRIPLE=aarch64-linux-gnu-
export CROSS_COMPILE=aarch64-linux-gnu-
export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

echo "→ Toolchain ready: $(clang --version | head -1)"
