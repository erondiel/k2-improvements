#!/bin/sh
# Apply erondiel portable bug-fixes to a freshly-cloned
# Jacob10383/k2-improvements checkout, before the user runs
# gimme-the-jamin.sh.
#
# Idempotent — re-running is a no-op if the patches are already applied,
# and a no-op if upstream has fixed the bugs themselves (the matchers won't
# find the broken patterns).
#
# Three known upstream issues this patches:
#   1. secure-auth — broken `grep -c PATTERN FILE -eq 0` syntax bypasses
#      the safety check, disables password auth on printers without any
#      authorized_keys -> user lockout.
#   2. better-root — link_up() does `ln -sfn /usr/share/moonraker
#      moonraker` after rsync moves the real /root/moonraker dir into
#      /mnt/UDISK/root/. ln fails ("File exists") because dest is a real
#      directory, not a symlink. Cascades into a failed install.

set -eu

D="${1:-/mnt/UDISK/k2-improvements}"
[ -d "$D" ] || { echo "ERROR: $D not found"; exit 1; }

# ---- Fix 1: secure-auth safety check ----
SA="$D/features/secure-auth/install.sh"
if [ -f "$SA" ] && grep -q "grep -c '\^ssh' /etc/dropbear/authorized_keys -eq 0" "$SA"; then
    python3 - "$SA" <<'PYEOF'
import sys
p = sys.argv[1]
with open(p) as f: content = f.read()
old = "if grep -c '^ssh' /etc/dropbear/authorized_keys -eq 0; then"
new = 'if [ ! -f /etc/dropbear/authorized_keys ] || [ "$(grep -c "^ssh" /etc/dropbear/authorized_keys 2>/dev/null)" -eq 0 ]; then'
if old in content:
    with open(p, 'w') as f: f.write(content.replace(old, new))
PYEOF
    echo "I: patched secure-auth safety check"
fi

# Note: there's no auto-start patch needed for the 1.1.3.13 path —
# Jacob's features/entware/install.sh correctly installs the unslung
# boot hook (lines 85-88: cp unslung.init /etc/init.d/unslung +
# rc.d/S99unslung symlink). On reboot, unslung runs all
# /opt/etc/init.d/S* services including S56moonraker and S50cartographer.
# Our installer (this repo) had to add the hook because we use a
# streamlined Python-based Entware bootstrap that bypasses Jacob's
# entware feature install.

# ---- Fix 2: better-root moonraker-symlink trap ----
BR="$D/features/better-root/install.sh"
if [ -f "$BR" ] && grep -q 'ln -sfn /usr/share/moonraker' "$BR" && ! grep -q 'erondiel-fix:' "$BR"; then
    python3 - "$BR" <<'PYEOF'
import sys
p = sys.argv[1]
with open(p) as f: content = f.read()
patches = {
    "    [ -d /usr/share/moonraker ]     && ln -sfn /usr/share/moonraker     moonraker":
        "    # erondiel-fix: skip moonraker symlinks (real-dir conflict on K2 Plus —\n"
        "    # rsync moves /root/moonraker into the new home; then ln -sfn fails)\n"
        "    # [ -d /usr/share/moonraker ]     && ln -sfn /usr/share/moonraker     moonraker",
    "    [ -d /usr/share/moonraker-env ] && ln -sfn /usr/share/moonraker-env moonraker-env":
        "    # [ -d /usr/share/moonraker-env ] && ln -sfn /usr/share/moonraker-env moonraker-env",
}
out = content
for old, new in patches.items():
    if old in out: out = out.replace(old, new)
if out != content:
    with open(p, 'w') as f: f.write(out)
PYEOF
    echo "I: patched better-root to skip moonraker symlinks"
fi

echo "I: erondiel portable fixes applied to $D"
