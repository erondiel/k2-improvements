#!/bin/sh
# K2 Plus installer bootstrap — run on the USER'S PC, not on the printer.
#
# Usage:
#   sh bootstrap.sh <printer-ip> [<password>] [--extras-only]
#
# What it does (default mode):
#   1. SSH-tests the printer (needs root-SSH enabled via the on-screen disclaimer)
#   2. Installs Entware on the printer if missing (piped over SSH from your PC,
#      because stock K2 Plus has no wget or curl)
#   3. Installs git/dialog/ca-bundle via opkg
#   4. Detects firmware: 1.1.5.2 → erondiel/k2-improvements, 1.1.3.13 → Jacob10383
#   5. git-clones the chosen installer into /mnt/UDISK/k2-improvements
#   6. Tells you the next command to run
#
# --extras-only mode (for 1.1.3.13 users with Cartographer already installed
# via Jacob10383, who want to add KAMP / surface-selection-wrapper /
# cartographer-macros / etc. without touching the existing install):
#   - Always uses erondiel/k2-improvements (the extras live there)
#   - Clones to /mnt/UDISK/k2-improvements-extras/ (separate path; does not
#     disturb any existing /mnt/UDISK/k2-improvements/ install)
#   - Skips patch-jacob-fixes (those are for fresh 1.1.3.13 installs only)
#   - Launches menu.sh with K2_EXTRAS_ONLY=1 so it shows only the safe items
#     (Status, Extras, KAMP, Update) and hides Install-essentials / Features
#     which would overwrite working Klipper patches
#
# Idempotent — re-run any time to update.

set -eu

EXTRAS_ONLY=0
PRINTER_IP=""
PASSWORD="creality_2024"

# Parse args (positional + --extras-only flag in any order)
while [ $# -gt 0 ]; do
    case "$1" in
        --extras-only)
            EXTRAS_ONLY=1
            shift
            ;;
        -h|--help)
            cat <<'USAGE'
usage: sh bootstrap.sh <printer-ip> [password] [--extras-only]

  --extras-only  Install only the K2-Plus extras (KAMP, surface-selection-
                 wrapper, cartographer-macros, etc.) on top of an existing
                 Cartographer install. Recommended for 1.1.3.13 users who
                 already installed via Jacob10383/k2-improvements and want
                 to add features without touching the working install.
USAGE
            exit 0
            ;;
        -*)
            echo "ERROR: unknown flag: $1"
            echo "       sh bootstrap.sh --help"
            exit 1
            ;;
        *)
            if [ -z "$PRINTER_IP" ]; then
                PRINTER_IP="$1"
            else
                PASSWORD="$1"
            fi
            shift
            ;;
    esac
done

REPO_URL_152="${REPO_URL_152:-https://github.com/erondiel/k2-improvements.git}"
REPO_BRANCH_152="${REPO_BRANCH_152:-main}"
REPO_URL_1313="${REPO_URL_1313:-https://github.com/Jacob10383/k2-improvements.git}"
REPO_BRANCH_1313="${REPO_BRANCH_1313:-main}"
# REPO_URL / REPO_BRANCH / CLONE_DIR / LAUNCH_CMD are picked after firmware detection below
REPO_URL=""
REPO_BRANCH=""
CLONE_DIR=""
LAUNCH_CMD=""

if [ -z "$PRINTER_IP" ]; then
    echo "usage: sh bootstrap.sh <printer-ip> [password] [--extras-only]"
    echo "  default password: creality_2024"
    exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

if command -v sshpass >/dev/null 2>&1; then
    SSH="sshpass -p $PASSWORD ssh $SSH_OPTS -o ConnectTimeout=10"
    SCP="sshpass -p $PASSWORD scp -O $SSH_OPTS"
else
    cat <<EOF
NOTE: 'sshpass' is not installed on this PC, so SSH will prompt for the
      printer password ($PASSWORD by default) on each step. Install sshpass
      to skip the prompts:
        Linux/WSL: apt install sshpass
        Mac:       brew install hudochenkov/sshpass/sshpass
EOF
    SSH="ssh $SSH_OPTS -o ConnectTimeout=10"
    SCP="scp -O $SSH_OPTS"
fi

remote() { $SSH "root@$PRINTER_IP" "$@"; }

echo "I: SSH probe to $PRINTER_IP"
remote "true" || {
    echo "ERROR: SSH to root@$PRINTER_IP failed."
    echo "       1. Enable root SSH on the printer's screen (the 'open root' disclaimer)"
    echo "       2. Confirm IP and password"
    exit 1
}

# Detect printer firmware to pick the right installer source.
# Our cartographer Klipper patches are rebased for 1.1.5.2; on 1.1.3.13 we
# route to Jacob10383 upstream (which has the original 1.1.3.13 patches and
# its own one-shot gimme-the-jamin.sh).
echo "I: detecting printer firmware version"
PRINTER_FW=$(remote "grep -oE 'sys = [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /mnt/UDISK/creality/userdata/log/upgrade-server.log 2>/dev/null | tail -1 | awk '{print \$3}'")

if [ "$EXTRAS_ONLY" = "1" ]; then
    # Extras-only mode: always use erondiel's repo, clone to a sibling path
    # so we don't disturb any existing /mnt/UDISK/k2-improvements/ install.
    echo "I:   extras-only mode — using erondiel/k2-improvements regardless of firmware"
    case "$PRINTER_FW" in
        1.1.3.13)
            echo "I:   firmware 1.1.3.13 detected — extras menu will load on top of"
            echo "I:   your existing Jacob10383 Cartographer install"
            ;;
        1.1.5.2)
            echo "I:   firmware 1.1.5.2 detected — extras-only mode is unusual here;"
            echo "I:   you can run the full installer (drop --extras-only) and pick"
            echo "I:   only the items you want from the menu instead"
            ;;
    esac
    REPO_URL="$REPO_URL_152"
    REPO_BRANCH="$REPO_BRANCH_152"
    CLONE_DIR="/mnt/UDISK/k2-improvements-extras"
    LAUNCH_CMD="K2_EXTRAS_ONLY=1 sh ${CLONE_DIR}/menu.sh"
else
    case "$PRINTER_FW" in
        1.1.5.2)
            echo "I:   firmware: 1.1.5.2 — using erondiel/k2-improvements (verified on this version)"
            REPO_URL="$REPO_URL_152"
            REPO_BRANCH="$REPO_BRANCH_152"
            CLONE_DIR="/mnt/UDISK/k2-improvements"
            LAUNCH_CMD="sh ${CLONE_DIR}/menu.sh"
            ;;
        1.1.3.13)
            echo "I:   firmware: 1.1.3.13 — switching to Jacob10383/k2-improvements upstream"
            echo "I:   (this fork's installer is rebased for 1.1.5.2; on 1.1.3.13 use the original)"
            echo "I:   Tip: if you already installed via Jacob10383 and just want to add extras"
            echo "I:        (KAMP, surface-selection-wrapper, cartographer-macros), re-run with"
            echo "I:        --extras-only"
            REPO_URL="$REPO_URL_1313"
            REPO_BRANCH="$REPO_BRANCH_1313"
            CLONE_DIR="/mnt/UDISK/k2-improvements"
            LAUNCH_CMD="sh ${CLONE_DIR}/gimme-the-jamin.sh"
            ;;
        "")
            echo "W:   firmware: could not detect (upgrade-server.log empty or absent)"
            echo "W:   defaulting to erondiel/k2-improvements; if this is a 1.1.3.13 printer,"
            echo "W:   cancel now and re-run with REPO_URL_152= and REPO_BRANCH_152= overrides"
            REPO_URL="$REPO_URL_152"
            REPO_BRANCH="$REPO_BRANCH_152"
            CLONE_DIR="/mnt/UDISK/k2-improvements"
            LAUNCH_CMD="sh ${CLONE_DIR}/menu.sh"
            ;;
        *)
            echo "W:   firmware: $PRINTER_FW — not 1.1.5.2 or 1.1.3.13"
            echo "W:   This installer is verified only on those two versions. Pick how to proceed:"
            echo ""
            echo "  1) Use erondiel/k2-improvements (rebased for 1.1.5.2; might work on 1.1.4.x)"
            echo "  2) Use Jacob10383/k2-improvements upstream (1.1.3.13 patches)"
            echo "  3) Cancel"
            printf "Choose [1-3]: "
            read FW_CHOICE
            case "$FW_CHOICE" in
                1) REPO_URL="$REPO_URL_152"; REPO_BRANCH="$REPO_BRANCH_152"; CLONE_DIR="/mnt/UDISK/k2-improvements"; LAUNCH_CMD="sh ${CLONE_DIR}/menu.sh" ;;
                2) REPO_URL="$REPO_URL_1313"; REPO_BRANCH="$REPO_BRANCH_1313"; CLONE_DIR="/mnt/UDISK/k2-improvements"; LAUNCH_CMD="sh ${CLONE_DIR}/gimme-the-jamin.sh" ;;
                3) echo "I: cancelled"; exit 0 ;;
                *) echo "ERROR: invalid choice"; exit 1 ;;
            esac
            ;;
    esac
fi

echo "I: checking Entware on printer"
HAS_OPKG=$(remote "[ -x /opt/bin/opkg ] && echo yes || echo no")

if [ "$HAS_OPKG" = "no" ]; then
    echo "I: bootstrapping Entware (printer's python3 + wget shim, since stock K2 Plus has no wget/curl)"

    echo "I:   creating /opt structure and fetching opkg + opkg.conf"
    remote "set -e
mkdir -p /opt/bin /opt/sbin /opt/etc /opt/lib/opkg/info /opt/lib/opkg/lists /opt/var/lock /opt/tmp /opt/share /etc/profile.d
python3 -c 'import urllib.request; urllib.request.urlretrieve(\"http://bin.entware.net/armv7sf-k3.2/installer/opkg\", \"/opt/bin/opkg\")'
chmod +x /opt/bin/opkg
python3 -c 'import urllib.request; urllib.request.urlretrieve(\"http://bin.entware.net/armv7sf-k3.2/installer/opkg.conf\", \"/opt/etc/opkg.conf\")'"
fi

# Ensure real wget is installed. Independent from entware bootstrap so a
# partial install can be repaired by re-running the script.
HAS_REAL_WGET=$(remote "/opt/bin/opkg list-installed 2>/dev/null | grep -qE '^wget(-ssl|-nossl)? ' && echo yes || echo no")

if [ "$HAS_REAL_WGET" = "no" ]; then
    echo "I: installing wget (uses python shim for the bootstrap download, then opkg overwrites it)"

    # Stage a Python-based wget shim locally — opkg uses wget internally to
    # fetch packages. The real wget package then overwrites this shim.
    SHIM_TMP=$(mktemp)
    cat > "$SHIM_TMP" <<'WGET_SHIM_EOF'
#!/usr/bin/env python3
# Minimal wget shim — used only during Entware bootstrap.
# Supports `wget URL` and `wget -O FILE URL`; ignores other flags.
import urllib.request, sys
args = sys.argv[1:]
url = None
out = None
while args:
    a = args.pop(0)
    if a == '-O':
        out = args.pop(0)
    elif a.startswith('-'):
        pass
    else:
        url = a
if not url:
    sys.exit(1)
try:
    if out and out != '-':
        urllib.request.urlretrieve(url, out)
    else:
        sys.stdout.buffer.write(urllib.request.urlopen(url).read())
except Exception as e:
    print(f'wget-shim error: {e}', file=sys.stderr)
    sys.exit(1)
WGET_SHIM_EOF

    $SCP "$SHIM_TMP" "root@$PRINTER_IP:/opt/bin/wget" >/dev/null
    rm -f "$SHIM_TMP"

    remote "set -e
chmod +x /opt/bin/wget
PATH=/opt/bin:/opt/sbin:\$PATH /opt/bin/opkg update >/dev/null 2>&1 || true
PATH=/opt/bin:/opt/sbin:\$PATH /opt/bin/opkg install --force-overwrite entware-opt 2>&1 | tail -3
PATH=/opt/bin:/opt/sbin:\$PATH /opt/bin/opkg install --force-overwrite wget"
fi

echo "I: ensuring opkg packages (git, dialog, ca-bundle)"
remote "PATH=/opt/bin:/opt/sbin:\$PATH; opkg update >/dev/null 2>&1 || true; \
        for p in git git-http ca-bundle dialog; do \
            opkg list-installed 2>/dev/null | grep -q \"^\$p \" || opkg install \$p || echo W: \$p install failed; \
        done"

echo "I: ensuring /opt on PATH for future logins"
remote "[ -f /etc/profile.d/k2-installer-path.sh ] || \
        printf 'export PATH=/opt/bin:/opt/sbin:\$PATH\n' > /etc/profile.d/k2-installer-path.sh"

echo "I: cloning installer to ${CLONE_DIR} (branch: $REPO_BRANCH)"
remote "PATH=/opt/bin:/opt/sbin:\$PATH; \
        D=${CLONE_DIR}; \
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

# In default mode, also create the canonical /mnt/UDISK/root/k2-improvements
# symlink so $HOME-relative scripts find the install. Skip in extras-only
# mode — there, the user likely has an existing Jacob10383 install already
# pointed at by that symlink, and we don't want to clobber it.
if [ "$EXTRAS_ONLY" = "0" ]; then
    remote "mkdir -p /mnt/UDISK/root && ln -sfn ${CLONE_DIR} /mnt/UDISK/root/k2-improvements"
fi

# Install the Entware unslung boot hook. Our streamlined Python-based
# Entware install bypasses the official generic.sh installer, which is
# what creates /etc/init.d/unslung (the script that runs all
# /opt/etc/init.d/S* services at boot). Without this hook,
# S56moonraker and S50cartographer never fire on boot and the printer
# comes up with no API server and no probe — even though the services
# are otherwise correctly installed.
#
# Use the same unslung.init that Jacob10383's features/entware/install.sh
# uses, now that our cloned repo has it on the printer.
echo "I: installing Entware unslung boot hook (so /opt/etc/init.d/S* fires on boot)"
remote "set -e
UNSLUNG_SRC=/mnt/UDISK/k2-improvements/features/entware/unslung.init
if [ ! -f \$UNSLUNG_SRC ]; then
    echo 'W:   unslung.init not found in cloned repo — skipping (Jacob10383 path supplies its own)'
    exit 0
fi
cp \$UNSLUNG_SRC /etc/init.d/unslung
chmod +x /etc/init.d/unslung
ln -sf /etc/init.d/unslung /etc/rc.d/S99unslung
ln -sf /etc/init.d/unslung /etc/rc.d/K01unslung
echo 'I:   /etc/init.d/unslung installed; rc.d/S99unslung + K01unslung symlinked'"

# If we routed to Jacob10383 upstream for a 1.1.3.13 install, apply our
# portable bug-fixes BEFORE the user runs gimme-the-jamin.sh.
#
# The patcher overlays 5 fixed files onto Jacob's checkout — 4 of them
# correspond to open PRs against Jacob's repo (#6 PATH, #7 better-root,
# #8 better-init, #9 cartographer) plus a secure-auth grep-syntax fix
# not yet PR'd. Idempotent: if upstream merges any PR, the corresponding
# overlay file becomes byte-identical to upstream and the cp is a no-op.
#
# Skipped in --extras-only mode: those fixes are for fresh 1.1.3.13 installs.
# An extras-only user already has a working Cartographer setup; overlaying
# Jacob's installer scripts at this point is unnecessary and could regress
# whatever they have.
if [ "$EXTRAS_ONLY" = "0" ] && [ "$REPO_URL" = "$REPO_URL_1313" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
    PATCH_DIR="$SCRIPT_DIR/installer/scripts"
    if [ -f "$PATCH_DIR/patch-jacob-fixes.sh" ] && [ -d "$PATCH_DIR/jacob-overlay" ]; then
        echo "I: applying erondiel portable bug-fixes to upstream installer"
        # Copy patcher + overlay tree to printer
        remote "rm -rf /tmp/erondiel-jacob-fixes && mkdir -p /tmp/erondiel-jacob-fixes"
        $SCP -r "$PATCH_DIR/patch-jacob-fixes.sh" "$PATCH_DIR/jacob-overlay" \
            "root@$PRINTER_IP:/tmp/erondiel-jacob-fixes/" >/dev/null
        remote "sh /tmp/erondiel-jacob-fixes/patch-jacob-fixes.sh /mnt/UDISK/k2-improvements && rm -rf /tmp/erondiel-jacob-fixes"
    else
        echo "W: patch-jacob-fixes.sh + overlay not found locally — your 1.1.3.13 install"
        echo "   will hit known upstream bugs (secure-auth lockout, better-root moonraker"
        echo "   trap, gimme-the-jamin PATH, prtouch SAVE_CONFIG residue, etc.)"
    fi
fi

if [ "$EXTRAS_ONLY" = "1" ]; then
    cat <<EOF

==================================================================
 Bootstrap complete (extras-only mode).

 Source:           $REPO_URL ($REPO_BRANCH branch)
 Cloned to:        $CLONE_DIR
 Detected firmware: ${PRINTER_FW:-unknown}

 Your existing Cartographer install at /mnt/UDISK/k2-improvements/
 (if any) was NOT touched.

 To start the extras menu, SSH in and run:

   ssh root@$PRINTER_IP
   $LAUNCH_CMD

 Or one-line:

   ssh root@$PRINTER_IP '$LAUNCH_CMD'

 The menu shows only Status / Extras / KAMP / Update — items that
 are safe cross-firmware. Install-essentials and the Features menu
 are hidden because they would overwrite Klipper patches.
==================================================================
EOF
else
    cat <<EOF

==================================================================
 Bootstrap complete.

 Source: $REPO_URL ($REPO_BRANCH branch)
 Cloned to: $CLONE_DIR
 Detected firmware: ${PRINTER_FW:-unknown}

 To start the installer, SSH in and run:

   ssh root@$PRINTER_IP
   $LAUNCH_CMD

 Or one-line:

   ssh root@$PRINTER_IP '$LAUNCH_CMD'
==================================================================
EOF
fi
