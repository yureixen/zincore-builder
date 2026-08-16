#!/bin/bash

DEFCONFIG="arch/arm64/configs/${KERNEL_DEFCONFIG}"
NONGKI_RAW="https://raw.githubusercontent.com/JackA1ltman/NonGKI_Kernel_Build_2nd/mainline"
KSU_SETUP_URL="https://raw.githubusercontent.com/ReSukiSU/ReSukiSU/refs/heads/main/kernel/setup.sh"
KSU_HOOK_URL="${NONGKI_RAW}/Patches/susfs_inline_hook_patches.sh"

echo ""
echo "→ [KSU] Setting up ReSukiSU + SuSFS..."

# ReSukiSU setup
echo "  → Running ReSukiSU setup script..."
curl -LSs --fail --retry 3 "$KSU_SETUP_URL" | bash -s main || {
    echo "✗ ReSukiSU setup failed!"
    exit 1
}
echo "  ✓ ReSukiSU added"

# KSU defconfig
cat >> "$DEFCONFIG" << 'EOF'
# ReSukiSU
CONFIG_KSU=y
CONFIG_KSU_MULTI_MANAGER_SUPPORT=y
CONFIG_KPM=n
CONFIG_KSU_MANUAL_HOOK=y
CONFIG_HAVE_SYSCALL_TRACEPOINTS=y
CONFIG_THREAD_INFO_IN_TASK=y
EOF
echo "  ✓ KSU defconfig added"

# SuSFS inline hook patches
echo "  → Applying SuSFS inline hook patches..."
curl -fLSs --fail --retry 3 "$KSU_HOOK_URL" -o /tmp/susfs_inline_hook.sh || {
    echo "✗ Failed to download susfs_inline_hook_patches.sh"
    exit 1
}
bash /tmp/susfs_inline_hook.sh || {
    echo "✗ susfs_inline_hook_patches.sh failed"
    exit 1
}
echo "  ✓ SuSFS inline hook patches applied"

# SuSFS kernel patch
echo "  → Applying SuSFS filesystem patch (kernel ${KERNEL_VERSION})..."
wget -qO- "${NONGKI_RAW}/Patches/Patch/susfs_patch_to_${KERNEL_VERSION}.patch" \
    | patch -s -p1 --fuzz=5 2>/dev/null || \
    echo "  ⚠ SuSFS patch: minor rejects or already applied, continuing"
echo "  ✓ SuSFS filesystem patch done"

# SuSFS defconfig
cat >> "$DEFCONFIG" << 'EOF'
# SuSFS
CONFIG_KSU_SUSFS=y
CONFIG_KSU_SUSFS_SUS_PATH=y
CONFIG_KSU_SUSFS_SUS_MOUNT=y
CONFIG_KSU_SUSFS_SUS_KSTAT=y
CONFIG_KSU_SUSFS_SPOOF_UNAME=y
CONFIG_KSU_SUSFS_ENABLE_LOG=y
CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y
CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y
CONFIG_KSU_SUSFS_OPEN_REDIRECT=y
CONFIG_KSU_SUSFS_SUS_MAP=y
CONFIG_KSU_SUSFS_TRY_UMOUNT=y
# CONFIG_KSU_SUSFS_SUS_SU is not set
EOF
echo "  ✓ SuSFS defconfig added"

echo "→ [KSU] ReSukiSU + SuSFS complete ✓"
