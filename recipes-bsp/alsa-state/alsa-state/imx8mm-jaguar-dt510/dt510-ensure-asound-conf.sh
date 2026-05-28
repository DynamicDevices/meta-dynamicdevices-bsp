#!/bin/bash
# DT510: ensure /etc/asound.conf is a regular file on the host.
#
# If Docker bind-mounts a missing host path, it creates an empty directory and breaks
# host ALSA (aplay/amixer/tas*-init) until repaired. Canonical content lives in the
# alsa-state package at /usr/share/dynamicdevices/dt510-asound.conf (package-owned file).
#
# systemd-tmpfiles "f" can create a missing file but cannot remove an existing directory.

set -euo pipefail

CANON=/usr/share/dynamicdevices/dt510-asound.conf
DEST=/etc/asound.conf

if [ ! -f "$CANON" ]; then
    echo "dt510-ensure-asound-conf: missing canonical file $CANON" >&2
    exit 1
fi

if [ -d "$DEST" ] && [ ! -L "$DEST" ]; then
    echo "dt510-ensure-asound-conf: $DEST is a directory; removing and restoring from $CANON"
    rm -rf "$DEST"
fi

if [ ! -e "$DEST" ]; then
    install -m 0644 "$CANON" "$DEST"
    echo "dt510-ensure-asound-conf: installed $DEST from $CANON"
fi

exit 0
