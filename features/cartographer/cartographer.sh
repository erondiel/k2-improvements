#!/bin/ash
set -e

SCRIPT_DIR=$(readlink -f $(dirname ${0}))
ACTION=${1}

usage() {
    echo ""
    echo "${0} ACTION"
    echo ""
    echo "ACTION:"
    echo "  enable  -- enables the cartographer probe, disabling prtouch"
    echo "  disable -- disables the cartographer probe, enabling prtouch"
    echo "  restart -- restarts the cartographer serial bridge"
    echo ""
}

case ${ACTION} in
    enable)
        echo "I: enabling cartographer"
        cat > ~/klipper/klippy/extras/cartographer.py << 'EOF'
import sys
sys.path.insert(0, '/mnt/UDISK/root/cartographer3d-plugin/src')
from cartographer.extra import *
EOF

        ln -sf ${SCRIPT_DIR}/patches/mcu.py ~/klipper/klippy/mcu.py
        ln -sf ${SCRIPT_DIR}/patches/serialhdl.py ~/klipper/klippy/serialhdl.py
        ln -sf ${SCRIPT_DIR}/patches/clocksync.py ~/klipper/klippy/clocksync.py
        ln -sf ${SCRIPT_DIR}/patches/configfile.py ~/klipper/klippy/configfile.py
        ln -sf ${SCRIPT_DIR}/patches/homing.py ~/klipper/klippy/extras/homing.py
        ln -sf ${SCRIPT_DIR}/patches/temperature_mcu.py ~/klipper/klippy/extras/temperature_mcu.py
        rm -f ~/klipper/klippy/extras/bed_mesh.py*
        ln -sf ${SCRIPT_DIR}/patches/bed_mesh.py ~/klipper/klippy/extras/bed_mesh.py
        sed -i 's/self\.use_offsets = False/self.use_offsets = True/g' \
            ~/klipper/klippy/extras/probe.py || true

        if ! zcat /proc/config.gz 2>/dev/null | grep -q "CONFIG_USB_ACM=y"; then
            ln -sf ${SCRIPT_DIR}/cartographer.init /etc/init.d/cartographer
            ln -sf ${SCRIPT_DIR}/cartographer.init /opt/etc/init.d/S50cartographer
            /etc/init.d/cartographer start
        fi

        sed -E -i \
            -e 's/^([^#].*prtouch.*)/#\1/' \
            -e 's/^#(.*carto.*)/\1/' \
            ~/printer_data/config/custom/main.cfg

        echo "I: restarting klipper"
        /etc/init.d/klipper restart
        echo ""
        echo "*** ENSURE Y SPACERS ARE INSTALLED ***"
        echo ""
        ;;
    disable)
        echo "I: disabling cartographer"
        KLIPPER_OVERLAY=/overlay/upper$(readlink ~/klipper)

        rm -f ${KLIPPER_OVERLAY}/klippy/extras/cartographer.py
        rm -f ${KLIPPER_OVERLAY}/klippy/extras/homing.py
        rm -f ${KLIPPER_OVERLAY}/klippy/extras/temperature_mcu.py
        rm -f ${KLIPPER_OVERLAY}/klippy/extras/bed_mesh.py
        rm -f ${KLIPPER_OVERLAY}/klippy/extras/probe.py
        rm -f ${KLIPPER_OVERLAY}/klippy/mcu.py
        rm -f ${KLIPPER_OVERLAY}/klippy/serialhdl.py
        rm -f ${KLIPPER_OVERLAY}/klippy/clocksync.py
        rm -f ${KLIPPER_OVERLAY}/klippy/configfile.py
        /etc/init.d/cartographer stop 2>/dev/null || true
        rm -f /overlay/upper/etc/init.d/cartographer
        rm -f /overlay/upper/opt/etc/init.d/S50cartographer
        sync
        mount -o remount /

        sed -E -i \
            -e 's/^#(.*prtouch.*)/\1/' \
            -e 's/^([^#].*carto.*)/#\1/' \
            ~/printer_data/config/custom/main.cfg

        echo "I: restarting klipper"
        /etc/init.d/klipper restart
        echo ""
        echo "*** ENSURE Y SPACERS ARE NOT INSTALLED ***"
        echo ""
        ;;
    restart)
        /etc/init.d/cartographer restart
        ;;
    *)
        usage
        ;;
esac
