#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: kernelsu.sh <device>}"
DEVICE_JSON="devices/${DEVICE}.json"

: "${KSU_SETUP_URL:?KSU_SETUP_URL not set — source config.env first}"
: "${KSU_SETUP_ARG:?KSU_SETUP_ARG not set — source config.env first}"
: "${SUSFS_HOOK_URL:?SUSFS_HOOK_URL not set — source config.env first}"
: "${SUSFS_PATCH_BASE:?SUSFS_PATCH_BASE not set — source config.env first}"

KERNEL_VERSION=$(python3 -c "
import json
print(json.load(open('$DEVICE_JSON'))['$DEVICE'].get('kernel_version',''))
")

if [ -z "$KERNEL_VERSION" ]; then
    echo "✗ kernel_version missing in $DEVICE_JSON"
    exit 1
fi

FRAGMENT_DIR="zincore_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/kernelsu.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"
add() { echo "$1" >> "$FRAGMENT_FILE"; }

echo "→ Installing ReSukiSU (setup.sh arg: $KSU_SETUP_ARG)"
curl -fsSL "$KSU_SETUP_URL" | bash -s "$KSU_SETUP_ARG"

echo "→ Fetching SuSFS patch for kernel $KERNEL_VERSION"

if grep -q "CONFIG_KSU_SUSFS" "fs/namespace.c" 2>/dev/null; then
    echo "→ SuSFS already patched in this tree, skipping patch step"
else
    SUSFS_PATCH_URL="${SUSFS_PATCH_BASE}/susfs_patch_to_${KERNEL_VERSION}.patch"
    SUSFS_PATCH_FILE="susfs_patch_to_${KERNEL_VERSION}.patch"

    if ! curl -fsSL -o "$SUSFS_PATCH_FILE" "$SUSFS_PATCH_URL"; then
        echo "✗ Could not download $SUSFS_PATCH_URL"
        echo "  Check that a susfs_patch_to_${KERNEL_VERSION}.patch exists upstream for this kernel version."
        exit 1
    fi

    echo "→ Applying SuSFS patch"
    patch -p1 --fuzz=3 < "$SUSFS_PATCH_FILE" || true

    REJ_FILES=$(find . -name "*.rej" 2>/dev/null || true)
    if [ -n "$REJ_FILES" ]; then
        echo "✗ SuSFS patch produced rejected hunks — build stopped, NOT continuing silently:"
        echo "$REJ_FILES"
        echo ""
        echo "  Each .rej file above shows the exact hunk that failed to apply."
        echo "  These must be resolved manually against this kernel tree before a KSU build can be trusted."
        exit 1
    fi
    echo "→ SuSFS patch applied cleanly, no rejects"
fi

# Manual hook script
echo "→ Applying SuSFS manual hook patches"
curl -fsSL "$SUSFS_HOOK_URL" | bash

# Core config fragment (structural — merged into out/.config by compile.sh)
add "-e CONFIG_KSU"
add "-e CONFIG_KSU_MANUAL_HOOK"
add "-e CONFIG_KSU_SUSFS"
add "-e CONFIG_KSU_SUSFS_SUS_PATH"
add "-e CONFIG_KSU_SUSFS_SUS_MOUNT"
add "-e CONFIG_KSU_SUSFS_SUS_KSTAT"
add "-e CONFIG_KSU_SUSFS_SPOOF_UNAME"
add "-e CONFIG_KSU_SUSFS_ENABLE_LOG"
add "-e CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS"
add "-e CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG"
add "-e CONFIG_KSU_SUSFS_OPEN_REDIRECT"
add "-e CONFIG_KSU_SUSFS_SUS_MAP"

# THREAD_INFO_IN_TASK is conditionally required
if grep -q "THREAD_INFO_IN_TASK" "drivers/kernelsu/Kconfig" 2>/dev/null; then
    add "-e CONFIG_THREAD_INFO_IN_TASK"
    echo "→ THREAD_INFO_IN_TASK required by this KernelSU Kconfig, added"
fi

echo "→ Fragment written: $FRAGMENT_FILE"
cat "$FRAGMENT_FILE"
