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
SUSFS_PATCH_URL="${SUSFS_PATCH_BASE}/susfs_patch_to_${KERNEL_VERSION}.patch"
SUSFS_PATCH_FILE="susfs_patch_to_${KERNEL_VERSION}.patch"

if ! curl -fsSL -o "$SUSFS_PATCH_FILE" "$SUSFS_PATCH_URL"; then
    echo "✗ Could not download $SUSFS_PATCH_URL"
    echo "  Check that a susfs_patch_to_${KERNEL_VERSION}.patch exists upstream for this kernel version."
    exit 1
fi

echo "→ Applying SuSFS patch"
patch -p1 --fuzz=3 < "$SUSFS_PATCH_FILE"

# Hard rej-check: fail loud, never silently continue on a rejected hunk
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

# Manual hook script
echo "→ Applying SuSFS manual hook patches"
curl -fsSL "$SUSFS_HOOK_URL" | bash

# Core config fragment
add "-e CONFIG_KSU"
add "-e CONFIG_KSU_MANUAL_HOOK"
add "-e CONFIG_KSU_SUSFS"

echo "→ Fragment written: $FRAGMENT_FILE"
cat "$FRAGMENT_FILE"

echo ""
echo "⚠ NOTE: only baseline CONFIG_KSU_SUSFS is enabled here. SuSFS v2.2.0 exposes"
echo "  many granular sub-features (sus_path, sus_mount, spoof_uname, sus_kstat, etc)."
echo "  Their exact Kconfig symbol names should be verified against this kernel tree's"
echo "  Kconfig AFTER the patch is applied, then added to this fragment manually —"
echo "  guessing symbol names here risks silently enabling nothing if a name is wrong."
