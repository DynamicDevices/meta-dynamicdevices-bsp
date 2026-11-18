# BSP-specific additions to lmp-factory-image
# Hardware-specific packages for Dynamic Devices boards

# Variable flags do not support override-style suffixes. Both conditions keep
# this dependency out of every other machine and the feature-off path.
do_image_wic[depends] += "${@'dt510-hdmi-splash:do_deploy' if d.getVar('MACHINE') == 'imx8mm-jaguar-dt510' and bb.utils.contains('MACHINE_FEATURES', 'hdmi-boot-splash', True, False, d) else ''}"

# Manual diagnostic only: no boot service or automatic display takeover.
CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-dt510 = " \
    dt510-hdmi-test \
    gstreamer1.0 \
    gstreamer1.0-plugins-base-playback \
    gstreamer1.0-plugins-base-typefindfunctions \
    gstreamer1.0-plugins-base-videoconvertscale \
    gstreamer1.0-plugins-base-videotestsrc \
    gstreamer1.0-plugins-good-isomp4 \
    gstreamer1.0-plugins-good-soup \
    gstreamer1.0-plugins-bad-kms \
    gstreamer1.0-plugins-bad-videoparsersbad \
    gstreamer1.0-libav \
"

# XM125 Radar Module Support (Sentai board)
# Include XM125 firmware and tools when xm125-radar machine feature is enabled
CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-sentai = " \
    ${@bb.utils.contains('MACHINE_FEATURES', 'xm125-radar', 'xm125-firmware', '', d)} \
"
