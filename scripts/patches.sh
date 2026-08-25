#!/usr/bin/env bash
set -euo pipefail

FRAGMENT_DIR="zincore_fragments"
FRAGMENT_FILE="${FRAGMENT_DIR}/generic.config"
mkdir -p "$FRAGMENT_DIR"
: > "$FRAGMENT_FILE"

add() { echo "$1" >> "$FRAGMENT_FILE"; }

echo "→ Building generic config fragment..."

# Werror
add "-d CONFIG_CC_WERROR"

# MODVERSIONS: not needed for a monolithic non-modular boot setup on this
add "-d CONFIG_MODVERSIONS"

# LTO mode, driven by config.env
: "${LTO_MODE:?LTO_MODE is not set — source config.env before running patches.sh}"

case "$LTO_MODE" in
    thin)
        add "-d CONFIG_LTO_NONE"
        add "-e CONFIG_LTO_CLANG_THIN"
        add "-d CONFIG_LTO_CLANG_FULL"
        ;;
    full)
        add "-d CONFIG_LTO_NONE"
        add "-d CONFIG_LTO_CLANG_THIN"
        add "-e CONFIG_LTO_CLANG_FULL"
        ;;
    none)
        add "-e CONFIG_LTO_NONE"
        add "-d CONFIG_LTO_CLANG_THIN"
        add "-d CONFIG_LTO_CLANG_FULL"
        ;;
    *)
        echo "✗ Unknown LTO_MODE '$LTO_MODE' — expected thin|full|none"
        exit 1
        ;;
esac

echo "→ Fragment written: $FRAGMENT_FILE (LTO_MODE=$LTO_MODE)"
cat "$FRAGMENT_FILE"
