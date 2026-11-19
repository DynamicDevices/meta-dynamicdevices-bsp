# Fixed scratch address already used by the EVK splash configuration.
# Failure is non-fatal: always continue into the original signed boot flow.
# Prefer the current OSTree boot-firmware deployment (also delivered by OTA).
# Keep FAT-root fallback for previously provisioned images.
if ext4load ${devtype} ${devnum}:${ostree_bootpart} 0x50000000 "${image_dir_path}/active-edge-splash-1280x720.bmp" 0x2a3036 || load ${devtype} ${devnum}:${bootpart} 0x50000000 active-edge-splash-1280x720.bmp 0x2a3036; then
    if test "${filesize}" = "2a3036" && hash -v sha256 0x50000000 0x2a3036 64b2f36f6305a8012d9dbab4ec2a266aba9f023bb4f4294eb30754dd37573da3; then
        if bmp display 0x50000000 m m; then
            echo "AESL U-Boot HDMI splash displayed"
            # Temporary visibility diagnostic: allow the TV to lock before
            # Linux resets/reconfigures the display. Never delay skip paths.
            echo "AESL splash diagnostic: holding for 10 seconds"
            sleep 10
            echo "AESL splash diagnostic: continuing Linux boot"
        else
            echo "AESL splash skipped: display unavailable"
        fi
    else
        echo "AESL splash skipped: artwork integrity check failed"
    fi
else
    echo "AESL splash skipped: artwork unavailable"
fi
