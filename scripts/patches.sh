#!/bin/bash

set -e

cd "$KERNEL_DIR"
DEFCONFIG="arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [patches] Variant: $VARIANT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Patch helper
apply_patch_url() {
    local url="$1"
    local name
    name=$(basename "$url")
    curl -sL --fail --retry 3 "$url" -o /tmp/_patch.patch || {
        echo "  ✗ Failed to download: $name"
        exit 1
    }
    if patch -s -p1 --fuzz=5 < /tmp/_patch.patch 2>/dev/null; then
        echo "  ✓ $name"
    else
        echo "  ⚠ $name (minor reject or already applied, continuing)"
    fi
}

# LN8K charging IC patches
echo ""
echo "→ [1] Applying LN8K charging IC patches..."
XIAOMI_SM6150="https://github.com/crdroidandroid/android_kernel_xiaomi_sm6150/commit"
TBYOOL="https://github.com/tbyool/android_kernel_xiaomi_sm6150/commit"

apply_patch_url "${XIAOMI_SM6150}/7b73f853977d2c016e30319dffb1f49957d30b40.patch"
apply_patch_url "${XIAOMI_SM6150}/63dddc108d57dc43e1cd0da0f1445875f760cf97.patch"
apply_patch_url "${XIAOMI_SM6150}/95816dff2ecc7ddd907a56537946b5cf1e864953.patch"
apply_patch_url "${XIAOMI_SM6150}/330c60abc13530bd05287f9e5395d283ebfd6d0b.patch"
apply_patch_url "${XIAOMI_SM6150}/0477c7006b41a1763b3314af9eb300491b91fc25.patch"
apply_patch_url "${TBYOOL}/aa5ddad5be03aa7436e7ce6e84d46b280849acae.patch"
apply_patch_url "${TBYOOL}/857638b0da6f80830122b8d1b45c7842970e76c3.patch"
apply_patch_url "${TBYOOL}/3a68adff14cbedd09ce2a735d575c3bf92dd696f.patch"
apply_patch_url "${TBYOOL}/30fcc15d5dcf2cfc3b83a5a7d4a77e2880639fa5.patch"
apply_patch_url "${TBYOOL}/1a17a6fbbf59d901c4b3aec66c06a1c96cd89c7e.patch"
echo "CONFIG_CHARGER_LN8000=y" >> "$DEFCONFIG"
echo "✓ LN8K patches done"

# DTBO patches
echo ""
echo "→ [2] Applying DTBO patches..."
XIAOMI_DTBO="https://github.com/xiaomi-sm6150/android_kernel_xiaomi_sm6150/commit"
apply_patch_url "${XIAOMI_DTBO}/e517bc363a19951ead919025a560f843c2c03ad3.patch"
apply_patch_url "${XIAOMI_DTBO}/a62a3b05d0f29aab9c4bf8d15fe786a8c8a32c98.patch"
apply_patch_url "${XIAOMI_DTBO}/4b89948ec7d610f997dd1dab813897f11f403a06.patch"
apply_patch_url "${XIAOMI_DTBO}/fade7df36b01f2b170c78c63eb8fe0d11c613c4a.patch"
apply_patch_url "${XIAOMI_DTBO}/2628183db0d96be8dae38a21f2b09cb10978f423.patch"
apply_patch_url "${XIAOMI_DTBO}/31f4577af3f8255ae503a5b30d8f68906edde85f.patch"
echo "✓ DTBO patches done"

# LTO + KPATCH
echo ""
echo "→ [3] Applying LTO + KPATCH patches..."
LS_PATCHES="https://github.com/TheSillyOk/kernel_ls_patches/raw/refs/heads/master"
apply_patch_url "${LS_PATCHES}/fix_lto.patch"
apply_patch_url "${LS_PATCHES}/kpatch_fix.patch"
cat >> "$DEFCONFIG" << 'EOF'
CONFIG_LTO_CLANG=y
CONFIG_THINLTO=y
# CONFIG_LTO_NONE is not set
EOF
echo "✓ LTO + KPATCH done"

# QCA WiFi driver enum type fix
echo ""
echo "→ [4] Fixing QCA WiFi driver enum type mismatch..."
QCA_CE_DIR="drivers/staging/qcacld-3.0/../qca-wifi-host-cmn/hif/src/ce"
if [ -d "$QCA_CE_DIR" ]; then
    find "$QCA_CE_DIR" -name "*.c" | while read -r f; do
        sed -i 's/\breturn A_ERROR;/return QDF_STATUS_E_FAILURE;/g' "$f"
        sed -i 's/\breturn A_OK;/return QDF_STATUS_SUCCESS;/g' "$f"
    done
    echo "✓ QCA enum fix applied"
else
    echo "  ⚠ QCA CE dir not found, skipping"
fi

# Common defconfig entries
echo ""
echo "→ [5] Adding common defconfig entries..."
cat >> "$DEFCONFIG" << 'EOF'
# vDSO32 disabled — lld cannot link 32-bit ARM vDSO
# CONFIG_VDSO32 is not set
CONFIG_EROFS_FS=y
CONFIG_SECURITY_SELINUX_DEVELOP=y
EOF
echo "✓ Common defconfig done"

# SELinux static export + ReSukiSU + SuSFS
if [[ "$VARIANT" == "ksu" ]]; then

    echo ""
    echo "→ [6] Exporting SELinux static symbols for ReSukiSU..."
    unstatic() {
        local file="$1"
        local regex="$2"
        if [ -f "$file" ] && grep -q "static $regex" "$file" 2>/dev/null; then
            sed -i "s/static $regex/$regex/" "$file"
            echo "  ✓ Exported: $regex"
        else
            echo "  ⚠ Not found or already exported: $regex"
        fi
    }
    unstatic "security/selinux/selinuxfs.c"   "ssize_t (\*write_op\[\])"
    unstatic "security/selinux/selinuxfs.c"   "const struct file_operations sel_handle_status_ops"
    unstatic "security/selinux/selinuxfs.c"   "DEFINE_MUTEX(sel_mutex);"
    unstatic "security/selinux/ss/services.c" "struct page \*selinux_status_page;"
    unstatic "security/selinux/ss/services.c" "DEFINE_MUTEX(selinux_status_lock);"
    unstatic "security/selinux/ss/services.c" "DEFINE_RWLOCK(policy_rwlock);"
    unstatic "security/selinux/hooks.c"       "struct security_operations selinux_ops"
    echo "✓ SELinux static exports done"

    source "$GITHUB_WORKSPACE/scripts/goodies/kernelsu.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [patches] All patches applied ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
