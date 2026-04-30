#!/bin/ash

SCRIPT_DIR="$(readlink -f $(dirname $0))"

if [ ! -f /etc/dropbear/authorized_keys ] || [ "$(grep -c "^ssh" /etc/dropbear/authorized_keys 2>/dev/null)" -eq 0 ]; then
    echo "ERROR: no authorized keys found in /etc/dropbear/authorized_keys"
    echo "       Add an SSH key first (e.g. ssh-copy-id from your PC),"
    echo "       then re-run this install. Without keys this would lock you out."
    exit 1
fi

echo "Updating dropbear init script to disable password authentication ..."
cp -f "${SCRIPT_DIR}/dropbear.init" /etc/init.d/dropbear
chmod +x /etc/init.d/dropbear

echo "Restarting dropbear..."
/etc/init.d/dropbear restart

echo "Done"

echo "I: you need to log back in for changes to take effect!"
echo "I: logging you out now!"
echo "I: please reconnect to continue"
# terminate the SSH session
pgrep dropbear | grep -v "^$(pgrep -o dropbear)$" | xargs kill -9
