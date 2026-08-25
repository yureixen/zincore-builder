#!/usr/bin/env bash
set -euo pipefail

DEVICE="${1:?Usage: goodies.sh <device> <variant>}"
VARIANT="${2:?Usage: goodies.sh <device> <variant>}"

GOODIES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/goodies" && pwd)"

case "$VARIANT" in
    nsu)
        echo "→ NSU (stock) variant — no goodies to apply"
        ;;
    ksu)
        echo "→ KSU variant — applying ReSukiSU + SuSFS"
        bash "${GOODIES_DIR}/kernelsu.sh" "$DEVICE"
        ;;
    *)
        echo "✗ Unknown variant '$VARIANT' — expected nsu or ksu"
        exit 1
        ;;
esac

echo "→ goodies.sh done for variant: $VARIANT"
