FILESEXTRAPATHS:prepend := "${THISDIR}/../../recipes-graphics/aesl-display-splash/files:${THISDIR}/../../recipes-bsp/dt510-hdmi-splash/files:"
PACKAGE_ARCH = "${MACHINE_ARCH}"

# Do not change non-headed products' existing splash image or build options.
SRC_URI:append = "${@bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', ' file://active-edge-splash-1920x1200.png file://make-splash.py file://make-linux-splash.py', '', d)}"
DEPENDS:append = "${@bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', ' python3-pillow-native', '', d)}"
PACKAGECONFIG:remove = "${@bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', 'progress-bar startup-msg', '', d)}"
inherit python3native

python do_compile:prepend() {
    if bb.utils.contains('DISTRO_FEATURES', 'display-boot-splash', True, False, d):
        import subprocess
        from pathlib import Path
        work = Path(d.getVar('WORKDIR'))
        subprocess.check_call([d.getVar('PYTHON'), str(work / 'make-linux-splash.py'),
                               d.getVar('MACHINE'),
                               str(work / 'active-edge-splash-1920x1200.png'),
                               str(work / 'aesl-desktop.png'),
                               str(work / 'aesl-splash.png')])
        # This prepend and the upstream Python do_compile share task-local data.
        d.setVar('SPLASH_LOCALPATHS', 'aesl-splash.png')
}
