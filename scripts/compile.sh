#!/bin/bash

set -e

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [compile] Variant: $VARIANT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$KERNEL_DIR"

# PATH setup
export PATH="${CLANG_DIR}/bin:${GCC64_DIR}/bin:${GCC32_DIR}/bin:/usr/bin:$PATH"
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
    CROSS_COMPILE=aarch64-linux-android-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
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
make -j"$JOBS" O="$KERNEL_OUT" "${MAKE_ARGS[@]}" Image.gz-dtb dtbo.img 2>&1 | tee /tmp/build.log
BUILD_EXIT=${PIPESTATUS[0]}
set -e

END=$(date +%s)
ELAPSED=$(( END - START ))
echo ""
echo "  Build time: $(( ELAPSED / 60 ))m $(( ELAPSED % 60 ))s"

# Verify output
IMAGE="$KERNEL_OUT/arch/arm64/boot/Image.gz-dtb"
DTBO="$KERNEL_OUT/arch/arm64/boot/dtbo.img"

if [ "$BUILD_EXIT" -ne 0 ] || [ ! -f "$IMAGE" ]; then
    echo ""
    echo "✗ Build FAILED — Image.gz-dtb not found!"
    echo ""
    echo "  Last 50 lines of build log:"
    echo "  ────────────────────────────"
    tail -50 /tmp/build.log
    exit 1
fi

echo "✓ Kernel compiled successfully"
echo "  Image.gz-dtb : $(du -h "$IMAGE" | cut -f1)"
[ -f "$DTBO" ] && echo "  dtbo.img     : $(du -h "$DTBO" | cut -f1)"

# AnyKernel3 packaging
echo ""
echo "→ [3/3] Packaging AnyKernel3 zip..."
cd "$AK3_DIR"

# Clean stale files
rm -f Image.gz-dtb Image.gz dtb dtbo.img *.zip

# Copy kernel artifacts
cp "$IMAGE" "$AK3_DIR/Image.gz-dtb"
[ -f "$DTBO" ] && cp "$DTBO" "$AK3_DIR/dtbo.img"

# Write a clean anykernel.sh for sweet
cat > "$AK3_DIR/anykernel.sh" << 'AKEOF'
# AnyKernel3 — Sweet Kernel
# by osm0sis @ xda-developers

properties() { '
kernel.string=Sweet Kernel by yurixen
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=sweet
device.name2=sweetin
supported.versions=12-16
supported.patchlevels=
'; }

block=/dev/block/bootdevice/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;
patch_vbmeta_flag=auto;

. tools/ak3-core.sh;

# Flash Image.gz-dtb
split_boot;
flash_boot;
AKEOF

echo "✓ anykernel.sh written for sweet"

# Build zip
BUILD_DATE=$(date +'%Y%m%d-%H%M')
ZIP_NAME="sweet-kernel-${VARIANT}-${BUILD_DATE}.zip"
zip -rq9 "$ZIP_NAME" . \
    -x ".git/*" \
    -x "*.zip"

echo "✓ Zip created: $ZIP_NAME ($(du -h "$ZIP_NAME" | cut -f1))"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [compile] Build complete ✓  →  $AK3_DIR/$ZIP_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
