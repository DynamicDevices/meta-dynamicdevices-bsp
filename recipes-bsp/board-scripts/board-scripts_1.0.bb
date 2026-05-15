SUMMARY = "Board testing and configuration scripts"
DESCRIPTION = "Collection of shell scripts for board testing, configuration, and production validation"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

LICENSE = "GPL-3.0-only"
LIC_FILES_CHKSUM ?= "file://${COMMON_LICENSE_DIR}/GPL-3.0-only;md5=c79ff39f19dfec6d293b95dea7b07891"

SRC_URI:append:imx8mm-jaguar-sentai = " \
  file://board-info.sh \
  file://test-leds-hb.sh \
  file://test-leds-rc.sh \
  file://set-fio-passwd.sh \
  file://enable-firewall.sh \
  file://record-audio.sh \
  file://test-audio-hw.sh \
  file://test-audio-play-and-record.sh \
  file://production-test.sh \
  file://pipeline_monitor.sh \
  file://extract_channel.py \
  file://mono_to_stereo.py \
  file://dtmf-182846.wav \
  file://board-testing-now-starting-up.wav \
  file://board-testing-now-starting-up-stereo.wav \
  file://board-testing-now-starting-up-stereo-48k.wav \
  file://tests-all-completed.wav \
  file://tests-all-completed-stereo.wav \
  file://tests-all-completed-stereo-48k.wav \
  file://AudioTest-Microphone-One.wav \
  file://AudioTest-Microphone-Two.wav \
  file://AudioTest-Recording-Will-Now-Play-Back.wav \
  file://AudioTest-Recording-Should-Have-Played.wav \
"

SRC_URI:append:imx8mm-jaguar-inst = " \
  file://board-info.sh \
  file://set-fio-passwd.sh \
  file://enable-firewall.sh \
"

# imx8mm-jaguar-dt510 — minimal scripts always; optional scripts via MACHINE_FEATURES (keeps RDEPENDS lean).
SRC_URI:append:imx8mm-jaguar-dt510 = " \
  file://board-info.sh \
  file://set-fio-passwd.sh \
  file://enable-firewall.sh \
  file://emmc-wipe-boot-partitions.sh \
"
# Leading space required: SRC_URI:append concatenates without inserting separators.
SRC_URI:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'taa5412', ' file://dt510-taa5412-capture-check.sh', '', d)}"
SRC_URI:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'auracast', ' file://dt510-auracast-image-check.sh file://dt510-auracast-hci-check.sh', '', d)}"
SRC_URI:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'dt510-digital-io', ' file://dt510-dio-toggle-outputs file://dt510-dio-toggle-outputs.sh file://dt510-dio-poll-inputs.sh', '', d)}"
SRC_URI:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'cp2108-usb-serial', ' file://rs485_tx_bytes.py file://dt510-cp2108-read-config.sh', '', d)}"

SRC_URI:append:imx93-jaguar-eink = " \
  file://board-info.sh \
  file://set-fio-passwd.sh \
  file://enable-firewall.sh \
"

do_install() {
    install -d ${D}${sbindir}
    if [ -n "$(ls -A ${WORKDIR}/*.sh 2>/dev/null)" ]; then
        install -m 0755 ${WORKDIR}/*.sh ${D}${sbindir}
    fi
}

do_install:append:imx8mm-jaguar-sentai() {
    install -d ${D}${datadir}/${PN}
    install -m 0755 ${WORKDIR}/*.wav ${D}${datadir}/${PN}
    install -m 0755 ${WORKDIR}/extract_channel.py ${D}${datadir}/${PN}
    install -m 0755 ${WORKDIR}/mono_to_stereo.py ${D}${datadir}/${PN}
}

do_install:append:imx8mm-jaguar-dt510() {
    if ${@bb.utils.contains('MACHINE_FEATURES', 'cp2108-usb-serial', 'true', 'false', d)}; then
        install -m 0755 ${WORKDIR}/rs485_tx_bytes.py ${D}${sbindir}/rs485_tx_bytes
    fi
    if ${@bb.utils.contains('MACHINE_FEATURES', 'dt510-digital-io', 'true', 'false', d)}; then
        install -m 0755 ${WORKDIR}/dt510-dio-toggle-outputs ${D}${sbindir}/dt510-dio-toggle-outputs
    fi
}

# Runtime dependencies for all machines (board-info.sh and production-test.sh use bash)
RDEPENDS:${PN} = "bash"

# Additional dependencies for specific machines
RDEPENDS:${PN}:imx8mm-jaguar-sentai = "bash dtmf2num"

# DT510: pull deps only when matching MACHINE_FEATURES (see imx8mm-jaguar-dt510.conf).
RDEPENDS:${PN}:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'taa5412', ' alsa-utils', '', d)}"
RDEPENDS:${PN}:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'auracast', ' bluez5', '', d)}"
RDEPENDS:${PN}:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'cp2108-usb-serial', ' cp210x-program', '', d)}"
RDEPENDS:${PN}:append:imx8mm-jaguar-dt510 = "${@' python3' if bb.utils.contains('MACHINE_FEATURES', 'auracast', True, False, d) or bb.utils.contains('MACHINE_FEATURES', 'cp2108-usb-serial', True, False, d) else ''}"
RDEPENDS:${PN}:append:imx8mm-jaguar-dt510 = "${@bb.utils.contains('MACHINE_FEATURES', 'dt510-digital-io', ' libgpiod-tools', '', d)}"
