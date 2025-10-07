SUMMARY = "NXP EdgeLock Enclave (ELE) Test Suite for i.MX93"
DESCRIPTION = "Simple ELE test utility for i.MX93 EdgeLock Enclave functionality testing"
LICENSE = "BSD-3-Clause"
LIC_FILES_CHKSUM = "file://LICENSE;md5=8636bd68fc00cc6a3809b7b58b45f982"

FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI = "file://simple-ele-test.c \
           file://LICENSE"

DEPENDS = "openssl"
RDEPENDS:${PN} = "openssl-bin"

S = "${WORKDIR}"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} ${WORKDIR}/simple-ele-test.c \
        -o ${S}/simple-ele-test || bbfatal "Failed to compile simple ELE test"
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/simple-ele-test ${D}${bindir}/
    
    # Create test runner script
    cat > ${D}${bindir}/run-ele-tests << 'EOF'
#!/bin/bash
echo "=== EdgeLock Enclave Test Suite ==="
echo "Target: i.MX93 EdgeLock Enclave"
simple-ele-test all
echo "=== ELE Test Suite Complete ==="
EOF
    chmod +x ${D}${bindir}/run-ele-tests
}

FILES:${PN} = "${bindir}/simple-ele-test ${bindir}/run-ele-tests"
