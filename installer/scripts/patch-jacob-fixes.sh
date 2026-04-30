#!/bin/sh
# Apply portable bug-fixes to a freshly-cloned Jacob10383/k2-improvements
# checkout by overlaying a small set of fixed files. Idempotent — re-running
# is a no-op if the overlay's content already matches.
#
# Files mirror four open PRs against Jacob10383/k2-improvements (so as
# upstream merges them, the overlay's matching file becomes identical to
# upstream and the cp is a silent no-op) plus one fix not yet PR'd:
#
#   1. gimme-the-jamin.sh — PR #6: PATH export so feature scripts find
#      Entware tools (git/curl/jq/unzip).
#   2. features/better-root/install.sh — PR #7: idempotent link_up +
#      don't kill SSH on non-interactive runs.
#   3. features/better-init/install.sh — PR #8: mkdir -p /etc/profile.d
#      before writing better-init.sh.
#   4. features/cartographer/install.sh — PR #9: strip orphan
#      `#*# [prtouch_v3]` SAVE_CONFIG header on install.
#   5. features/secure-auth/install.sh — not in any PR yet: fix broken
#      `grep -c PATTERN FILE -eq 0` syntax that bypasses the safety
#      check (would otherwise disable password SSH on a printer with
#      no authorized_keys → user lockout).
#
# The overlay tree is shipped alongside this script in the same directory
# under jacob-overlay/. bootstrap.sh SCPs both before running this script.

set -eu

D="${1:-/mnt/UDISK/k2-improvements}"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

SCRIPT_DIR="$(readlink -f "$(dirname "$0")")"
OVERLAY="$SCRIPT_DIR/jacob-overlay"
[ -d "$OVERLAY" ] || { echo "ERROR: overlay dir not found at $OVERLAY"; exit 1; }

echo "I: applying erondiel portable bug-fixes (overlay) to $D"

apply_overlay() {
    local src="$1"
    local dst="$2"
    if [ ! -f "$src" ]; then
        echo "W:   overlay missing $src — skipping"
        return 0
    fi
    if [ ! -f "$dst" ]; then
        echo "W:   target missing $dst — skipping"
        return 0
    fi
    if cmp -s "$src" "$dst"; then
        echo "I:   $dst already matches overlay (no-op)"
        return 0
    fi
    cp "$dst" "${dst}.before-erondiel-overlay" 2>/dev/null || true
    cp "$src" "$dst"
    echo "I:   patched $dst"
}

apply_overlay "$OVERLAY/gimme-the-jamin.sh"                   "$D/gimme-the-jamin.sh"
apply_overlay "$OVERLAY/features/better-root/install.sh"      "$D/features/better-root/install.sh"
apply_overlay "$OVERLAY/features/better-init/install.sh"      "$D/features/better-init/install.sh"
apply_overlay "$OVERLAY/features/cartographer/install.sh"     "$D/features/cartographer/install.sh"
apply_overlay "$OVERLAY/features/secure-auth/install.sh"      "$D/features/secure-auth/install.sh"

echo "I: erondiel portable fixes applied to $D"
