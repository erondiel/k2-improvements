#!/bin/sh
# K2 Plus installer bootstrap — run on the USER'S PC, not on the printer.
#
# Usage:
#   sh bootstrap.sh <printer-ip> [<password>]
#
# Single command for every user. Behavior is auto-detected:
#   - 1.1.5.2 firmware (fresh or update)        -> erondiel/k2-improvements
#   - 1.1.3.13 firmware, no existing install    -> Jacob10383/k2-improvements
#   - 1.1.3.13 firmware, existing Jacob install -> ASK whether to add only
#                                                  extras (KAMP, surface-
#                                                  selection-wrapper,
#                                                  cartographer-macros, etc.)
#                                                  on top, or re-run the
#                                                  full Jacob install
#   - other firmware                            -> ask user
#
# Extras-only mode (chosen automatically or via --extras-only) clones to
# /mnt/UDISK/k2-improvements-extras/ as a sibling so the existing install
# at /mnt/UDISK/k2-improvements/ is never touched.
#
# Power-user override flags (rarely needed, both skip the auto-detect prompt):
#   --extras-only   force extras-only mode regardless of detected state
#   --full          force full install regardless of detected state
#
# Idempotent — re-run any time to update.

set -eu

# When this script is invoked via `curl -sSL ... | sh`, stdin is the curl
# pipe — not a terminal. The K2 Plus's dropbear SSH client (and BusyBox in
# general) reads password input from stdin if no TTY is properly attached,
# which means the SSH password prompt eats the rest of this script as
# password attempts and the bootstrap silently terminates.
#
# Self-heal by re-downloading to /tmp and re-execing from there, so the
# new sh process inherits a real TTY for stdin. Skipped when stdin is
# already a TTY (file invocation) or when we've already re-execed once
# (prevents infinite recursion via BOOTSTRAP_REEXEC marker).
if [ ! -t 0 ] && [ "${BOOTSTRAP_REEXEC:-0}" = "0" ]; then
    SCRIPT_TMP=$(mktemp /tmp/bootstrap.XXXXXX.sh 2>/dev/null || echo "/tmp/bootstrap.$$.sh")
    SCRIPT_URL="${BOOTSTRAP_URL:-https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh}"
    if command -v curl >/dev/null 2>&1 && curl -sSL "$SCRIPT_URL" -o "$SCRIPT_TMP" 2>/dev/null && [ -s "$SCRIPT_TMP" ]; then
        export BOOTSTRAP_REEXEC=1
        exec sh "$SCRIPT_TMP" "$@"
    fi
    # Re-download failed; emit a clear actionable error instead of letting
    # the curl-pipe path silently break later.
    cat >&2 <<'EOF'
ERROR: bootstrap is being piped from curl ("curl ... | sh"), but the
self-rewrite to a temp file failed (curl wasn't found, or the
re-download didn't work).

On systems with the dropbear SSH client (BusyBox / K2 Plus printer
shells) and without sshpass, the curl-pipe invocation causes silent
script termination during the SSH password prompt. The fix is to run
this script from a file instead of stdin.

Try:

  curl -sSL https://raw.githubusercontent.com/erondiel/k2-improvements/main/bootstrap.sh \
    -o /tmp/bootstrap.sh
  sh /tmp/bootstrap.sh <printer-ip>

EOF
    exit 1
fi

EXTRAS_ONLY=0
EXTRAS_OVERRIDE=0   # set when user passes --extras-only or --full; skip auto-detect prompt
PRINTER_IP=""
PASSWORD="creality_2024"

# Parse args (positional + flags in any order)
while [ $# -gt 0 ]; do
    case "$1" in
        --extras-only)
            EXTRAS_ONLY=1
            EXTRAS_OVERRIDE=1
            shift
            ;;
        --full)
            EXTRAS_ONLY=0
            EXTRAS_OVERRIDE=1
            shift
            ;;
        -h|--help)
            cat <<'USAGE'
usage: sh bootstrap.sh <printer-ip> [password] [--extras-only|--full]

Single command for every user. Bootstrap auto-detects firmware and
existing-install state and does the right thing — no flag needed for
the common cases.

Override flags (rare, both skip the auto-detect prompt):
  --extras-only  Force extras-only mode. Clones to /mnt/UDISK/
                 k2-improvements-extras/ and shows only KAMP / Extras
                 / Status / Update in the menu. Useful for CI or for
                 advanced users who know they want this.

  --full         Force full install. Skips the auto-detect prompt and
                 re-runs the firmware-routed flow. Useful if you want
                 to reinstall over an existing install.
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
    echo "usage: sh bootstrap.sh <printer-ip> [password] [--extras-only|--full]"
    echo "  default password: creality_2024"
    echo "  sh bootstrap.sh --help for details"
    exit 1
fi

# If sshpass is missing, offer to install it via the host's package manager.
# Without sshpass, every SSH call in this bootstrap fires its own password
# prompt — ~10 prompts per run, which is annoying. Most hosts have a known
# package manager (opkg on K2 Plus / Entware, apt on Debian/Ubuntu/WSL,
# brew on macOS, etc.). If we can't detect one, fall through to the
# existing warning and proceed with prompts.
maybe_install_sshpass() {
    command -v sshpass >/dev/null 2>&1 && return 0

    local pm="" cmd=""
    if command -v opkg >/dev/null 2>&1 && [ -d /opt/etc ]; then
        pm="opkg"
        cmd="opkg update >/dev/null 2>&1; opkg install sshpass"
    elif command -v apt-get >/dev/null 2>&1; then
        pm="apt"
        cmd="sudo apt-get update >/dev/null 2>&1 && sudo apt-get install -y sshpass"
    elif command -v dnf >/dev/null 2>&1; then
        pm="dnf"
        cmd="sudo dnf install -y sshpass"
    elif command -v yum >/dev/null 2>&1; then
        pm="yum"
        cmd="sudo yum install -y sshpass"
    elif command -v pacman >/dev/null 2>&1; then
        pm="pacman"
        cmd="sudo pacman -S --noconfirm sshpass"
    elif command -v brew >/dev/null 2>&1; then
        pm="brew"
        cmd="brew install hudochenkov/sshpass/sshpass"
    fi

    if [ -z "$pm" ]; then
        return 1
    fi

    echo ""
    echo "I: sshpass is not installed."
    echo "I:   Without it, the SSH password prompt fires for every command (~10 prompts per run)."
    echo "I:   Detected package manager: $pm"
    echo "I:   Would run: $cmd"
    echo ""
    printf "Install sshpass now? [Y/n] "
    read SSHPASS_INSTALL_CHOICE
    case "$SSHPASS_INSTALL_CHOICE" in
        n|N|no|NO)
            echo "I:   declined — continuing with password prompts"
            return 1
            ;;
    esac

    echo "I: installing sshpass..."
    if sh -c "$cmd"; then
        # Refresh PATH in case sshpass landed in a dir not yet in PATH
        # (e.g., /opt/bin from opkg, /home/linuxbrew/.linuxbrew/bin from brew).
        export PATH="/opt/bin:/opt/sbin:/usr/local/bin:$PATH"
        if command -v sshpass >/dev/null 2>&1; then
            echo "I: sshpass installed successfully"
            return 0
        else
            echo "W: install command succeeded but sshpass not in PATH — falling back to password prompts"
            return 1
        fi
    else
        echo "W: sshpass install failed — falling back to password prompts"
        return 1
    fi
}

maybe_install_sshpass || true
echo ""

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

if command -v sshpass >/dev/null 2>&1; then
    SSH="sshpass -p $PASSWORD ssh $SSH_OPTS -o ConnectTimeout=10"
    SCP="sshpass -p $PASSWORD scp -O $SSH_OPTS"
else
    cat <<EOF
NOTE: 'sshpass' is not available — SSH will prompt for the printer
      password ($PASSWORD by default) on every step. Manual install:
        Linux/WSL: apt install sshpass
        Mac:       brew install hudochenkov/sshpass/sshpass
        K2 Plus:   opkg install sshpass
        Other:     https://github.com/kevinburke/sshpass#installation
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

# Auto-detect an existing Jacob10383 install and ask whether the user
# wants to add only extras, if the case is ambiguous. Only fires for
# 1.1.3.13 when neither override flag was passed. Everyone else flows
# through to current behavior.
#
# Detection probes both common install paths:
#   /mnt/UDISK/k2-improvements/             (our convention; symlink target)
#   /mnt/UDISK/root/k2-improvements/        (Jacob's ~/k2-improvements/ after
#                                            better-root sets HOME=/mnt/UDISK/root)
# Plus a fallback: a moonraker.conf [update_manager k2-improvements] block
# is registered by Jacob's cartographer/install.sh and points at the actual
# install directory regardless of which path convention was used.
if [ "$EXTRAS_OVERRIDE" = "0" ] && [ "$PRINTER_FW" = "1.1.3.13" ]; then
    echo "I: checking for existing install"
    DETECTED_PATH=$(remote '
        # Try the two canonical paths first
        for d in /mnt/UDISK/k2-improvements /mnt/UDISK/root/k2-improvements; do
            if [ -d "$d/.git" ] && grep -q "Jacob10383" "$d/.git/config" 2>/dev/null; then
                # Resolve symlinks to the real path
                resolved=$(readlink -f "$d" 2>/dev/null || echo "$d")
                echo "$resolved"
                exit 0
            fi
        done
        # Fallback: parse moonraker.conf for k2-improvements update_manager block
        cfg=/mnt/UDISK/printer_data/config/moonraker.conf
        if [ -f "$cfg" ]; then
            mr_path=$(awk "/\\[update_manager k2-improvements\\]/,/\\[/" "$cfg" 2>/dev/null \
                | grep -E "^\\s*path:" | head -1 | sed -E "s/^\\s*path:\\s*//; s/\\s+$//")
            if [ -n "$mr_path" ]; then
                # Expand ~ if present
                case "$mr_path" in
                    "~"|"~/"*) mr_path="$HOME/${mr_path#~/}" ;;
                esac
                if [ -d "$mr_path/.git" ] && grep -q "Jacob10383" "$mr_path/.git/config" 2>/dev/null; then
                    resolved=$(readlink -f "$mr_path" 2>/dev/null || echo "$mr_path")
                    echo "$resolved"
                    exit 0
                fi
            fi
        fi
        echo none
    ')
    if [ -n "$DETECTED_PATH" ] && [ "$DETECTED_PATH" != "none" ]; then
        echo ""
        echo "I: detected existing Cartographer install at $DETECTED_PATH"
        echo "I:   (cloned from Jacob10383 — likely a working setup you want to keep)"
        echo ""
        echo "  You can either:"
        echo "    1) Add only the K2-Plus extras (KAMP, surface-selection-wrapper,"
        echo "       cartographer-macros, etc.) WITHOUT touching the existing install."
        echo "       Recommended — safe, additive, leaves Cartographer working."
        echo "    2) Re-run Jacob10383's full install (idempotent, but updates"
        echo "       Klipper patches and may require a Klipper restart afterwards)."
        echo ""
        printf "Add extras only? [Y/n] "
        read EXTRAS_CHOICE
        case "$EXTRAS_CHOICE" in
            n|N|no|NO)
                EXTRAS_ONLY=0
                echo "I:   continuing with full Jacob10383 re-install"
                ;;
            *)
                EXTRAS_ONLY=1
                echo "I:   extras-only mode — existing install will not be touched"
                ;;
        esac
        echo ""
    fi
fi

# If user explicitly forced --extras-only (EXTRAS_OVERRIDE=1 with EXTRAS_ONLY=1),
# verify a [cartographer] section exists in the printer config. Most extras
# (surface-selection-wrapper, cartographer-offset-setup, cartographer-macros)
# require Cartographer to already be installed. KAMP and motor-state-guard
# work standalone, but flagging this up-front avoids confusion when the
# extras' own install scripts bail on the same precondition.
#
# Skip this check when EXTRAS_ONLY was set by the auto-detect prompt
# (EXTRAS_OVERRIDE=0) — that path already confirmed an install exists.
if [ "$EXTRAS_OVERRIDE" = "1" ] && [ "$EXTRAS_ONLY" = "1" ]; then
    echo "I: checking for [cartographer] section (extras precondition)"
    HAS_CARTO=$(remote 'grep -lqE "^\[cartographer\]" /mnt/UDISK/printer_data/config/printer.cfg /mnt/UDISK/printer_data/config/custom/*.cfg 2>/dev/null && echo yes || echo no')
    if [ "$HAS_CARTO" = "no" ]; then
        echo ""
        echo "W: --extras-only forced but no [cartographer] section found in printer config."
        echo "W:"
        echo "W:   Most extras require Cartographer to already be installed:"
        echo "W:     - surface-selection-wrapper  (patches START_PRINT to call CARTOGRAPHER_*)"
        echo "W:     - cartographer-offset-setup  (edits [cartographer] x_offset / y_offset)"
        echo "W:     - cartographer-macros        (CARTO_* macros wrap CARTOGRAPHER_*)"
        echo "W:"
        echo "W:   These extras work standalone:"
        echo "W:     - KAMP (adaptive purge)"
        echo "W:     - motor-state-guard (UNTESTED)"
        echo "W:     - prtouch-cleanup"
        echo ""
        printf "Continue anyway? [y/N] "
        read CONT_CHOICE
        case "$CONT_CHOICE" in
            y|Y|yes|YES) echo "I: proceeding — Cartographer-dependent extras will refuse to install" ;;
            *) echo "I: cancelled. Drop --extras-only for the firmware-routed flow."; exit 0 ;;
        esac
        echo ""
    fi
fi

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
