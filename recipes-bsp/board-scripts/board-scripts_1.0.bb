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
}

# Runtime dependencies for all machines (board-info.sh and production-test.sh use bash)
RDEPENDS:${PN} = "bash"

# Additional dependencies for specific machines
RDEPENDS:${PN}:imx8mm-jaguar-sentai = "bash dtmf2num"
