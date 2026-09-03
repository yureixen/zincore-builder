#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: compile.sh <device> <variant>}"
VARIANT="${2:?Usage: compile.sh <device> <variant>}"
DEVICE_JSON="devices/${DEVICE}.json"
OUT_DIR="out"
WORKDIR="$(pwd)"

read_field() {
    python3 -c "
import json
print(json.load(open('$DEVICE_JSON'))['$DEVICE'].get('$1', ''))
"
}

DEFCONFIG=$(read_field defconfig)
KERNEL_ARCH=$(read_field arch)
AK3_REPO=$(read_field ak3_repo)
AK3_BRANCH=$(read_field ak3_branch)
KERNEL_NAME=$(read_field kernel_name)

: "${DEFCONFIG:?defconfig missing in $DEVICE_JSON}"
: "${AK3_REPO:?ak3_repo missing in $DEVICE_JSON}"
: "${AK3_BRANCH:?ak3_branch missing in $DEVICE_JSON}"

echo "→ Building $DEVICE ($VARIANT) — defconfig: $DEFCONFIG"

# Base defconfig
mkdir -p "$OUT_DIR"
make O="$OUT_DIR" ARCH="$KERNEL_ARCH" "$DEFCONFIG"

# Full kernel name control from builder
./scripts/config --file "${OUT_DIR}/.config" --set-str CONFIG_LOCALVERSION "-${KERNEL_NAME}-${VARIANT}-zincore"

# Merge all fragments written by patches.sh / goodies.sh into out/.config
FRAGMENT_DIR="zincore_fragments"
if [ -d "$FRAGMENT_DIR" ]; then
    for FRAGMENT in "$FRAGMENT_DIR"/*.config; do
        [ -f "$FRAGMENT" ] || continue
        echo "→ Merging fragment: $FRAGMENT"
        ./scripts/config --file "${OUT_DIR}/.config" $(cat "$FRAGMENT")
    done
fi

# Resolve dependencies after all fragment toggles
make O="$OUT_DIR" ARCH="$KERNEL_ARCH" olddefconfig

# Build (capture full log for the debug artifact)
export KCFLAGS="-O2 -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion -Wno-error=incompatible-pointer-types -Wno-error=incompatible-function-pointer-types"

BUILD_LOG="${WORKDIR}/${DEVICE}-${VARIANT}-build.log"
echo "→ Compiling (log: $BUILD_LOG)"
make -j"$(nproc)" O="$OUT_DIR" ARCH="$KERNEL_ARCH" KCFLAGS="$KCFLAGS" 2>&1 | tee "$BUILD_LOG"

# Fail loudly if the kernel image was never produced, even if make "succeeded"
IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image.gz-dtb"
[ -f "$IMAGE_PATH" ] || IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image.gz"
[ -f "$IMAGE_PATH" ] || IMAGE_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/Image"

if [ ! -f "$IMAGE_PATH" ]; then
    echo "✗ No kernel image found at expected paths under ${OUT_DIR}/arch/${KERNEL_ARCH}/boot/"
    echo "  Build did not actually produce output — check $BUILD_LOG"
    exit 1
fi
echo "→ Kernel image: $IMAGE_PATH"

if [ "$VARIANT" = "ksu" ]; then
    grep -o "ReSukiSU version name: [^ ]*" "$BUILD_LOG" | head -1 | sed -E 's/ReSukiSU version name: //; s/-[0-9a-f]{6,8}@ReSukiSU$//' > "${WORKDIR}/${DEVICE}-resukisu-version.txt" || true
fi

# Save final .config as a debug artifact
cp "${OUT_DIR}/.config" "${WORKDIR}/${DEVICE}-${VARIANT}-config"

# Package with AnyKernel3
AK3_DIR="${WORKDIR}/AnyKernel3"
rm -rf "$AK3_DIR"
git clone --depth 1 -b "$AK3_BRANCH" "$AK3_REPO" "$AK3_DIR"

cp "$IMAGE_PATH" "$AK3_DIR/"

# This kernel builds dtbo.img and dtb.img as part of the default `all` target
DTBO_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/dtbo.img"
DTB_IMG_PATH="${OUT_DIR}/arch/${KERNEL_ARCH}/boot/dtb.img"

if [ -f "$DTBO_PATH" ]; then
    cp "$DTBO_PATH" "$AK3_DIR/dtbo.img"
    echo "→ dtbo.img included"
else
    echo "✗ dtbo.img not found at $DTBO_PATH despite CONFIG_BUILD_ARM64_DT_OVERLAY=y — check $BUILD_LOG"
    exit 1
fi

if [ -f "$DTB_IMG_PATH" ]; then
    cp "$DTB_IMG_PATH" "$AK3_DIR/dtb"
    echo "→ dtb included (for vendor_boot/vendor_kernel_boot devices, harmless if unused)"
fi

DATE_TAG=$(date +%Y%m%d-%H%M)
ZIP_NAME="zincore-${DEVICE}-${VARIANT}-${DATE_TAG}.zip"

pushd "$AK3_DIR" >/dev/null
zip -r9 "${WORKDIR}/${ZIP_NAME}" . -x ".git/*" -x "*.zip"
popd >/dev/null

echo "→ Packaged: ${ZIP_NAME}"
echo "→ Debug artifacts: ${DEVICE}-${VARIANT}-build.log, ${DEVICE}-${VARIANT}-config"
echo "→ compile.sh done"
