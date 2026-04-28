#!/bin/ash

set -xe

SCRIPT_DIR=$(readlink -f $(dirname ${0}))

# Ensure Entware (/opt/bin) and any UDISK-installed binaries are on PATH
# so feature install scripts can find git/curl/jq/unzip etc. Several
# feature scripts (e.g. cartographer/install.sh) call `git clone`
# directly without an absolute path; on stock K2 Plus the default PATH
# does not include /opt/bin, so the call silently fails.
export PATH="/opt/bin:/opt/sbin:/mnt/UDISK/bin:$PATH"

install_feature() {
    FEATURE=${1}
    if [ ! -f /tmp/${FEATURE} ]; then
        ${SCRIPT_DIR}/features/${FEATURE}/install.sh
        touch /tmp/${FEATURE}
    fi
}

install_feature better-init
install_feature skip-setup
install_feature moonraker
install_feature fluidd
install_feature screws_tilt_adjust
install_feature cartographer
install_feature abort_homing
mkdir -p /tmp/macros
install_feature macros/bed_mesh
install_feature macros/m191
install_feature macros/start_print
install_feature macros/overrides
