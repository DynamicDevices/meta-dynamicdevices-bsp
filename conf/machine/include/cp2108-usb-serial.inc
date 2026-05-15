# Silicon Labs CP2108 USB UART bridge — kernel fragment `cp2108-usb-serial.cfg` from
# linux-lmp-fslc-imx_%.bbappend when MACHINE_FEATURES contains `cp2108-usb-serial`.

MACHINE_FEATURES_BACKFILL_CONSIDERED:append = " cp2108-usb-serial"

# Userspace EEPROM tool (PyUSB); same MACHINE_FEATURES gate as the kernel driver fragment.
# DT510 UART port map vs RS‑232/RS‑485 → docs/DT510-HARDWARE-AUDIT-CHECKLIST.md (CP2108 U13 subsection).
MACHINE_EXTRA_RDEPENDS:append = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'cp2108-usb-serial', 'cp210x-program', '', d)} \
"
