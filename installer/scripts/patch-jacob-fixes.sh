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
#   2. moonraker — install.sh removes /etc/rc.d/S*moonraker but never
#      re-enables. After reboot, moonraker doesn't auto-start.
#   3. better-root — link_up() does `ln -sfn /usr/share/moonraker
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

# ---- Fix 2: moonraker auto-start on boot (rc.d enable + rc.local hook) ----
# Upstream removes /etc/rc.d/S*moonraker. We re-enable, AND we add a hook
# in /etc/rc.local because procd's processing of rc.d/S* doesn't reliably
# fire moonraker on K2 Plus boot (Klipper auto-starts fine, moonraker
# doesn't — even with the symlink in place).
MR="$D/features/moonraker/install.sh"
if [ -f "$MR" ] && ! grep -q '/etc/init.d/moonraker enable' "$MR"; then
    cat >> "$MR" <<'EOF'

# erondiel-fix: ensure moonraker auto-starts on boot. Two-pronged:
# 1) Re-enable rc.d/S56moonraker (upstream removed it earlier).
# 2) Add a hook to /etc/rc.local (run at S95 by /etc/init.d/done) as
#    a belt-and-braces fallback — procd's S56 firing is unreliable on
#    K2 Plus.
if [ -x /etc/init.d/moonraker ] && [ ! -e /etc/rc.d/S56moonraker ]; then
    /etc/init.d/moonraker enable
    echo "I: moonraker auto-start enabled (rc.d/S56moonraker)"
fi
if [ -f /etc/rc.local ] && ! grep -q 'erondiel-fix: moonraker auto-start' /etc/rc.local 2>/dev/null; then
    python3 - <<'PYHOOK'
path = '/etc/rc.local'
with open(path) as f: content = f.read()
hook = (
    '\n# erondiel-fix: moonraker auto-start (procd boot of S56moonraker\n'
    '# does not fire reliably on K2 Plus). Idempotent: only starts if not running.\n'
    '[ -x /etc/init.d/moonraker ] && [ -z "$(pidof -x moonraker.py 2>/dev/null)" ] && /etc/init.d/moonraker start &\n'
)
if 'erondiel-fix: moonraker auto-start' not in content:
    if '\nexit 0\n' in content:
        content = content.replace('\nexit 0\n', hook + '\nexit 0\n', 1)
    else:
        content = content + hook
    with open(path, 'w') as f: f.write(content)
    print('I: moonraker auto-start hook added to /etc/rc.local')
PYHOOK
fi
EOF
    echo "I: patched moonraker auto-start (rc.d + rc.local hook)"
fi

# ---- Fix 3: better-root moonraker-symlink trap ----
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
