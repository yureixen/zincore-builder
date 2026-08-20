#!/bin/bash
set -e

cd "$KERNEL_DIR"
DEFCONFIG="arch/arm64/configs/${KERNEL_DEFCONFIG}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [patches] Variant: $VARIANT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Disable -Werror
echo ""
echo "→ Disabling -Werror..."
cat >> "$DEFCONFIG" << 'EOF'
CONFIG_CC_WERROR=n
CONFIG_WERROR=n
EOF
echo "✓ Werror disabled"

# LTO + ThinLTO
echo ""
echo "→ Enabling LTO_CLANG + ThinLTO..."
cat >> "$DEFCONFIG" << 'EOF'
CONFIG_LTO_CLANG=y
CONFIG_THINLTO=y
# CONFIG_LTO_NONE is not set
EOF
echo "✓ LTO enabled"

# Disable MODVERSIONS
echo ""
echo "→ Disabling MODVERSIONS (incompatible with LTO_CLANG + ld.lld)..."
cat >> "$DEFCONFIG" << 'EOF'
# CONFIG_MODVERSIONS is not set
EOF
echo "✓ MODVERSIONS disabled"

# ReSukiSU + SuSFS
if [[ "$VARIANT" == "ksu" ]]; then
    source "$GITHUB_WORKSPACE/scripts/goodies/kernelsu.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " [patches] Done ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
