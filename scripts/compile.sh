#!/bin/bash

set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [compile] Variant: $VARIANT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$KERNEL_DIR"

# PATH setup
export PATH="${CLANG_DIR}/bin:/usr/bin:$PATH"
export KBUILD_BUILD_USER="$KBUILD_BUILD_USER"
export KBUILD_BUILD_HOST="$KBUILD_BUILD_HOST"

JOBS=$(nproc --all)

# Make arguments
MAKE_ARGS=(
    ARCH=arm64
    SUBARCH=arm64
    LLVM=1
    LLVM_IAS=1
    CC=clang
    LD=ld.lld
    AR=llvm-ar
    AS=llvm-as
    NM=llvm-nm
    OBJCOPY=llvm-objcopy
    OBJDUMP=llvm-objdump
    STRIP=llvm-strip
    HOSTCC=clang
    HOSTCXX=clang++
    HOSTLD=ld.lld
    HOSTAR=llvm-ar
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_ARM32=arm-linux-gnueabi-
    CLANG_TRIPLE=aarch64-linux-gnu-
)

echo ""
echo "  Clang  : $(clang --version | head -1)"
echo "  LLD    : $(ld.lld --version | head -1)"
echo "  Jobs   : $JOBS"
echo "  Out    : $KERNEL_OUT"

# defconfig
echo ""
echo "→ [1/3] Generating defconfig..."
make -j"$JOBS" O="$KERNEL_OUT" "${MAKE_ARGS[@]}" "$KERNEL_DEFCONFIG"
echo "✓ Defconfig generated"

# compile
echo ""
echo "→ [2/3] Compiling kernel (this will take a while)..."
START=$(date +%s)

set +e
make -j"$JOBS" O="$KERNEL_OUT" "${MAKE_ARGS[@]}" 2>&1 | tee /tmp/build.log
BUILD_EXIT=${PIPESTATUS[0]}
set -e

END=$(date +%s)
ELAPSED=$(( END - START ))
echo ""
echo "  Build time: $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"

# Verify output - fallback: Image.gz-dtb, else Image.gz
BOOT_DIR="$KERNEL_OUT/arch/arm64/boot"
IMAGE=""
if [ -f "$BOOT_DIR/Image.gz-dtb" ]; then
    IMAGE="$BOOT_DIR/Image.gz-dtb"
    IMAGE_NAME="Image.gz-dtb"
elif [ -f "$BOOT_DIR/Image.gz" ]; then
    IMAGE="$BOOT_DIR/Image.gz"
    IMAGE_NAME="Image.gz"
fi
DTBO="$BOOT_DIR/dtbo.img"

if [ "$BUILD_EXIT" -ne 0 ] || [ -z "$IMAGE" ]; then
    echo ""
    echo "✗ Build FAILED — no kernel image found in $BOOT_DIR!"
    echo ""
    echo "  Last 50 lines of build log:"
    echo "  ────────────────────────────"
    tail -50 /tmp/build.log
    exit 1
fi

echo "✓ Kernel compiled successfully"
echo "  $IMAGE_NAME : $(du -h "$IMAGE" | cut -f1)"
[ -f "$DTBO" ] && echo "  dtbo.img    : $(du -h "$DTBO" | cut -f1)"

# AnyKernel3 packaging
echo ""
echo "→ [3/3] Packaging AnyKernel3 zip..."
cd "$AK3_DIR"

rm -f Image.gz-dtb Image.gz dtbo.img *.zip
cp "$IMAGE" "$AK3_DIR/$IMAGE_NAME"
[ -f "$DTBO" ] && cp "$DTBO" "$AK3_DIR/dtbo.img"

VARIANT_LABEL="nsu"
[[ "$VARIANT" == "ksu" ]] && VARIANT_LABEL="ksu"

BUILD_DATE=$(date +'%Y%m%d-%H%M')
ZIP_NAME="zincore-sweet-${VARIANT_LABEL}-${BUILD_DATE}.zip"
zip -rq9 "$ZIP_NAME" . \
    -x ".git/*" \
    -x "*.zip"

echo "✓ Zip created: $ZIP_NAME ($(du -h "$ZIP_NAME" | cut -f1))"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [compile] Build complete ✓  →  $AK3_DIR/$ZIP_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
