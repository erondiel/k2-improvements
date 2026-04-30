#!/bin/sh
# Safe better-root wrapper. Does the move_homedir + selective symlinks
# from gotcha #3 — explicitly skips moonraker (the cause of the
# "File exists" error in upstream better-root), and never kills SSH.
#
# Idempotent — re-running is a no-op if root home is already on UDISK.

set -eu

DEST=/mnt/UDISK/root

if grep -qE '^root:[^:]*:[^:]*:[^:]*:[^:]*:'"$DEST"':' /etc/passwd; then
    echo "I: root home is already $DEST — better-root already applied"
    exit 0
fi

# 1. Move home content
mkdir -p "$DEST"
if [ -n "$(ls -A /root 2>/dev/null)" ]; then
    rsync -a --remove-source-files /root/ "$DEST"/
    [ -d /overlay/upper/root ] && rm -rf /overlay/upper/root/* 2>/dev/null || true
fi

# 2. Update /etc/passwd
sed -i 's|^\(root:[^:]*:[^:]*:[^:]*:[^:]*\):/root:|\1:'"$DEST"':|' /etc/passwd
sync

# 3. Selective symlinks. Skip if destination is a real (non-symlink) dir;
# log a note so the user knows what's left untouched.
ln_safe() {
    local src=$1
    local dst=$2
    [ -e "$src" ] || [ -L "$src" ] || return 0
    if [ -L "$dst" ] || [ ! -e "$dst" ]; then
        ln -sfn "$src" "$dst"
        echo "I: linked $dst -> $src"
    else
        echo "W: $dst exists as a non-symlink; leaving alone (not a fatal — feature installs that need it usually create their own)"
    fi
}

ln_safe /usr/share/klipper       "$DEST/klipper"
ln_safe /usr/share/klippy-env    "$DEST/klippy-env"
ln_safe /mnt/UDISK/printer_data  "$DEST/printer_data"
# Intentionally NOT linking /usr/share/moonraker — Creality may already ship it
# at the destination as a real directory, and the moonraker feature install
# handles its own paths anyway.

echo "I: better-root applied — \$HOME for root is now $DEST"
echo "I: running shells need to log out and back in to see new \$HOME"
echo "I: NOT killing SSH — the menu installer needs to keep running"
