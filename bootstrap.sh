#!/bin/sh
# K2 Plus installer bootstrap — run on the USER'S PC, not on the printer.
#
# Usage:
#   sh bootstrap.sh <printer-ip> [<password>]
#
# What it does:
#   1. SSH-tests the printer (needs root-SSH enabled via the on-screen disclaimer)
#   2. Installs Entware on the printer if missing (piped over SSH from your PC,
#      because stock K2 Plus has no wget or curl)
#   3. Installs git/dialog/ca-bundle via opkg
#   4. git-clones the installer-v1 branch into /mnt/UDISK/k2-improvements
#   5. Tells you the next command to run
#
# Idempotent — re-run any time to update.

set -eu

PRINTER_IP="${1:-}"
PASSWORD="${2:-creality_2024}"
REPO_URL="${REPO_URL:-https://github.com/erondiel/k2-improvements.git}"
REPO_BRANCH="${REPO_BRANCH:-installer-v1}"
ENTWARE_URL="https://bin.entware.net/armv7sf-k3.2/installer/generic.sh"

if [ -z "$PRINTER_IP" ]; then
    echo "usage: sh bootstrap.sh <printer-ip> [password]"
    echo "  default password: creality_2024"
    exit 1
fi

if command -v sshpass >/dev/null 2>&1; then
    SSH="sshpass -p $PASSWORD ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
else
    cat <<EOF
NOTE: 'sshpass' is not installed on this PC, so SSH will prompt for the
      printer password ($PASSWORD by default) on each step. Install sshpass
      to skip the prompts:
        Linux/WSL: apt install sshpass
        Mac:       brew install hudochenkov/sshpass/sshpass
EOF
    SSH="ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10"
fi

remote() { $SSH "root@$PRINTER_IP" "$@"; }

echo "I: SSH probe to $PRINTER_IP"
remote "true" || {
    echo "ERROR: SSH to root@$PRINTER_IP failed."
    echo "       1. Enable root SSH on the printer's screen (the 'open root' disclaimer)"
    echo "       2. Confirm IP and password"
    exit 1
}

echo "I: checking Entware on printer"
HAS_ENTWARE=$(remote "[ -x /opt/bin/opkg ] && echo yes || echo no")

if [ "$HAS_ENTWARE" = "no" ]; then
    echo "I: installing Entware (piping installer from your PC)"
    if command -v curl >/dev/null 2>&1; then
        DL="curl -sfL"
    elif command -v wget >/dev/null 2>&1; then
        DL="wget -qO-"
    else
        echo "ERROR: this PC needs curl or wget to fetch the Entware installer."
        exit 1
    fi
    $DL "$ENTWARE_URL" \
      | remote "mkdir -p /etc/profile.d && cat > /tmp/entware-install.sh && sh /tmp/entware-install.sh"
fi

echo "I: ensuring opkg packages (git, dialog, ca-bundle)"
remote "PATH=/opt/bin:/opt/sbin:\$PATH; opkg update >/dev/null 2>&1 || true; \
        for p in git git-http ca-bundle dialog; do \
            opkg list-installed 2>/dev/null | grep -q \"^\$p \" || opkg install \$p || echo W: \$p install failed; \
        done"

echo "I: ensuring /opt on PATH for future logins"
remote "[ -f /etc/profile.d/k2-installer-path.sh ] || \
        printf 'export PATH=/opt/bin:/opt/sbin:\$PATH\n' > /etc/profile.d/k2-installer-path.sh"

echo "I: cloning installer (branch: $REPO_BRANCH)"
remote "PATH=/opt/bin:/opt/sbin:\$PATH; \
        D=/mnt/UDISK/k2-improvements; \
        if [ -d \$D/.git ]; then \
            git -C \$D fetch origin $REPO_BRANCH; \
            git -C \$D checkout $REPO_BRANCH; \
            git -C \$D pull --ff-only; \
        else \
            if [ -d \$D ] && [ ! -d \$D/.git ]; then \
                mv \$D \${D}.flat-\$(date +%s); \
                echo I: existing flat tree moved aside; \
            fi; \
            git clone --branch $REPO_BRANCH $REPO_URL \$D; \
        fi"

cat <<EOF

==================================================================
 Bootstrap complete.

 To open the installer menu, SSH in and run menu.sh:

   ssh root@$PRINTER_IP
   sh /mnt/UDISK/k2-improvements/menu.sh

 Or one-line:

   ssh root@$PRINTER_IP 'sh /mnt/UDISK/k2-improvements/menu.sh'
==================================================================
EOF
