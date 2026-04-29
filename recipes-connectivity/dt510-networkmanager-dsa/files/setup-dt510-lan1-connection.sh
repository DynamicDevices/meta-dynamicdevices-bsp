#!/bin/sh
# DT510 — KSZ9896 DSA: request DHCP on a switch user port, not the DSA master (end0).
# Default front-panel mapping from device tree labels: lan1 … lan4.
set -e
IFACE="${DT510_DSA_WIRED_IFACE:-lan1}"
if [ ! -d "/sys/class/net/${IFACE}" ]; then
	exit 0
fi
CON_NAME="DT510-${IFACE}-dhcp"
sleep 2
if nmcli -t -f NAME connection show "${CON_NAME}" >/dev/null 2>&1; then
	nmcli connection up "${CON_NAME}" 2>/dev/null || true
	exit 0
fi
nmcli connection add type ethernet con-name "${CON_NAME}" ifname "${IFACE}" \
	ipv4.method auto ipv6.method auto \
	connection.autoconnect yes \
	connection.autoconnect-priority 100
nmcli connection up "${CON_NAME}" 2>/dev/null || true
