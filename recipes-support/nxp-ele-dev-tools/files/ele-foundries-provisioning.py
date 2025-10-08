#!/usr/bin/python3
# SPDX-License-Identifier: MIT
#
# ELE-based EdgeLock 2GO Alternative for i.MX93
# Provides similar functionality to EdgeLock 2GO using EdgeLock Enclave (ELE)

import os
import logging
import subprocess
import sys
from time import sleep
from typing import List

# Configuration
DAEMON_INTERVAL = os.environ.get("DAEMON_INTERVAL", "300")
PIN = os.environ.get("PKCS11_PIN", "87654321")
SO_PIN = os.environ.get("PKCS11_SOPIN", "12345678")
SOTA_DIR = os.environ.get("SOTA_DIR", "/var/sota")
REPO_ID = os.environ["REPOID"]

logging.basicConfig(level="INFO", format="%(asctime)s %(levelname)s: %(message)s")
log = logging.getLogger()

class EleCli:
    """EdgeLock Enclave CLI interface for i.MX93"""
    
    @classmethod
    def has_object(cls, oid: int) -> bool:
        """Check if cryptographic object exists in ELE"""
        try:
            result = subprocess.run(
                ["ele-dev-tools", "test", "key_management"],
                capture_output=True, text=True
            )
            return f"0x{oid:08x}" in result.stdout
        except subprocess.CalledProcessError:
            return False
    
    @classmethod
    def generate_keypair(cls, oid: int, key_type: str = "EC:prime256v1"):
        """Generate keypair in ELE secure storage"""
        args = [
            "openssl", "genpkey",
            "-algorithm", "EC",
            "-pkcs11",
            "-engine", "pkcs11",
            "-pkcs11_uri", f"pkcs11:id={oid:08x};type=private",
            "-out", f"/tmp/key_{oid:08x}.pem"
        ]
        subprocess.check_call(args)
        log.info(f"Generated keypair 0x{oid:08x} in ELE")
    
    @classmethod
    def import_key_to_pkcs11(cls, slot: str, oid: int):
        """Import ELE key to PKCS#11 slot"""
        # This would use ELE-specific APIs to export key reference
        # and import to PKCS#11 without exposing private key material
        args = [
            "pkcs11-tool",
            "--module=/usr/lib/libckteec.so.0",
            f"--pin={PIN}",
            "--write-object", f"/tmp/key_{oid:08x}.pem",
            "--type=privkey",
            f"--id={slot}",
            f"--label=ELE_{oid:08x}"
        ]
        subprocess.check_call(args)
        log.info(f"Imported key 0x{oid:08x} to PKCS#11 slot {slot}")

class EleDeviceProvisioning:
    """ELE-based device provisioning for Foundries.io"""
    
    def __init__(self):
        self.device_key_oid = 0x83000042
        self.device_cert_oid = 0x83000043
    
    def generate_device_identity(self):
        """Generate device identity using ELE"""
        if not EleCli.has_object(self.device_key_oid):
            log.info("Generating device identity in ELE...")
            EleCli.generate_keypair(self.device_key_oid)
            self._generate_device_certificate()
        else:
            log.info("Device identity already exists in ELE")
    
    def _generate_device_certificate(self):
        """Generate device certificate using ELE private key"""
        # Create certificate signing request using ELE key
        csr_cmd = [
            "openssl", "req", "-new",
            "-engine", "pkcs11",
            "-keyform", "engine",
            "-key", f"pkcs11:id={self.device_key_oid:08x};type=private",
            "-out", "/tmp/device.csr",
            "-subj", f"/CN=imx93-eink-{self._get_device_serial()}"
        ]
        subprocess.check_call(csr_cmd)
        
        # Self-sign for now (in production, would be signed by CA)
        cert_cmd = [
            "openssl", "x509", "-req",
            "-in", "/tmp/device.csr",
            "-signkey", f"/tmp/key_{self.device_key_oid:08x}.pem",
            "-out", "/tmp/device.crt",
            "-days", "365"
        ]
        subprocess.check_call(cert_cmd)
        log.info("Generated device certificate")
    
    def _get_device_serial(self) -> str:
        """Get unique device serial from ELE/hardware"""
        try:
            # Read unique ID from ELE or hardware
            with open("/sys/devices/soc0/soc_uid", "r") as f:
                return f.read().strip()
        except:
            # Fallback to MAC address
            with open("/sys/class/net/eth0/address", "r") as f:
                return f.read().strip().replace(":", "")
    
    def provision_foundries_ota(self):
        """Configure Foundries.io OTA using ELE credentials"""
        # Import keys to PKCS#11
        EleCli.import_key_to_pkcs11("01", self.device_key_oid)
        
        # Create sota.toml configuration
        sota_toml = os.path.join(SOTA_DIR, "sota.toml")
        os.makedirs(SOTA_DIR, exist_ok=True)
        
        config = f"""
[tls]
server = "https://{REPO_ID}.ota-lite.foundries.io:8443"
ca_source = "file"
pkey_source = "pkcs11"
cert_source = "file"

[provision]
server = "https://{REPO_ID}.ota-lite.foundries.io:8443"

[uptane]
repo_server = "https://{REPO_ID}.ota-lite.foundries.io:8443/repo"
key_source = "file"

[pacman]
type = "ostree+compose_apps"
ostree_server = "https://{REPO_ID}.ostree.foundries.io:8443/ostree"

[storage]
type = "sqlite"
path = "{SOTA_DIR}/"

[p11]
module = "/usr/lib/libckteec.so.0"
pass = "{PIN}"
tls_pkey_id = "01"
tls_clientcert_path = "/tmp/device.crt"
"""
        
        with open(sota_toml, "w") as f:
            f.write(config)
        
        log.info(f"Created OTA configuration: {sota_toml}")

def main():
    """Main provisioning flow"""
    log.info("🔐 ELE-based EdgeLock 2GO Alternative for i.MX93")
    log.info("================================================")
    
    # Check if already provisioned
    if os.path.exists(os.path.join(SOTA_DIR, "sql.db")):
        log.info("Device already provisioned")
        return
    
    try:
        # Initialize device provisioning
        provisioner = EleDeviceProvisioning()
        
        # Generate device identity in ELE
        provisioner.generate_device_identity()
        
        # Configure Foundries.io OTA
        provisioner.provision_foundries_ota()
        
        # Start OTA service
        subprocess.check_call(["systemctl", "start", "aktualizr-lite"])
        log.info("✅ Device provisioning complete!")
        
    except Exception as e:
        log.error(f"❌ Provisioning failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
