#!/bin/sh
set -e

move_homedir() {
    # only want to do this once
    if ! grep -qE 'root.*UDISK' /etc/passwd; then
        if [ ! -d /mnt/UDISK/root ]; then
            mkdir /mnt/UDISK/root
        fi
        rsync --remove-source-files -a /root/ /mnt/UDISK/root/
        # just remove any overlays for the original root location
        rm -fr /overlay/upper/root/*
        # change root homedir
        sed -i 's,/root,/mnt/UDISK/root,' /etc/passwd
        sync
    fi
}

link_up() {
    cd /mnt/UDISK/root
    # link up the various printer bits in their normal location.
    # `ln -sfn` is idempotent: re-running this script (or running it after
    # moonraker has already been installed by a feature pack) won't fail
    # with "File exists" the way bare `ln -s` does.
    ln -sfn /usr/share/klipper       klipper
    ln -sfn /usr/share/klippy-env    klippy-env
    ln -sfn /mnt/UDISK/printer_data  printer_data
    [ -d /usr/share/moonraker ]     && ln -sfn /usr/share/moonraker     moonraker
    [ -d /usr/share/moonraker-env ] && ln -sfn /usr/share/moonraker-env moonraker-env
}

aliases() {
    # update aliases
    cat > /etc/profile.d/aliases << EOF
alias grep='grep --color=always'
EOF
}

if grep -qE 'root.*UDISK' /etc/passwd; then
    exit 0
fi
move_homedir
link_up
#aliases

echo "I: you need to log back in for changes to take effect!"
# Only force-disconnect the SSH session in interactive runs. When this
# script is invoked from an automated installer or another script,
# killing dropbear processes prevents the parent script from continuing
# (the dropbear that owns the SSH session may itself host the parent's
# stdout). Detect interactivity via a TTY on stdin.
if [ -t 0 ]; then
    echo "I: logging you out now!"
    echo "I: please reconnect to continue"
    # terminate the SSH session
    pgrep dropbear | grep -v "^$(pgrep -o dropbear)$" | xargs kill -9
else
    echo "I: non-interactive run detected; not killing SSH. The caller"
    echo "I: must reconnect (or re-source /etc/passwd in the parent shell)"
    echo "I: for the new \$HOME to take effect."
fi
