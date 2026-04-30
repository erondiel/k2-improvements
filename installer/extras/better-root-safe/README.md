# better-root-safe

Drop-in replacement for `features/better-root/install.sh` that fixes the
two issues that caused `Install all` to fail on a fresh K2 Plus:

1. **Refuses to symlink over real directories.** Upstream uses
   `ln -sfn /usr/share/moonraker moonraker` after rsync has moved the
   stock `/root/moonraker` dir into the new home — `-sfn` doesn't help
   when the destination is a real directory (ln tries to create the
   link INSIDE it: `moonraker/moonraker: File exists`). This wrapper
   skips and warns instead of failing the whole install.

2. **Skips moonraker symlinks entirely.** The moonraker feature install
   later sets up its own paths; we don't need to pre-link them, and
   leaving stock Creality's `moonraker` dir in place avoids the
   conflict above.

3. **Never kills SSH.** Upstream calls `pgrep dropbear | xargs kill -9`
   on the assumption a human will reconnect. In an automated
   `Install all` flow that breaks the entire run.

## What it does

1. If root's home in `/etc/passwd` is already `/mnt/UDISK/root`, exits
   cleanly (idempotent).
2. `mkdir /mnt/UDISK/root`, rsyncs `/root/` content into it (with
   `--remove-source-files`), removes `/overlay/upper/root/*`.
3. `sed -i` updates `/etc/passwd` so root's home is `/mnt/UDISK/root`.
4. Creates these symlinks IF the destination is empty or already a
   symlink (otherwise warns and skips):
   - `/mnt/UDISK/root/klipper`       → `/usr/share/klipper`
   - `/mnt/UDISK/root/klippy-env`    → `/usr/share/klippy-env`
   - `/mnt/UDISK/root/printer_data`  → `/mnt/UDISK/printer_data`
5. Does NOT touch `moonraker` / `moonraker-env`.

## When you might still want the upstream version

If you have a custom moonraker install path that requires pre-linking
into the home dir, the upstream `features/better-root/install.sh` will
do that — at the cost of needing to delete the existing `moonraker`
directory first. For most users on a stock K2 Plus, this safe wrapper
is the right choice.
