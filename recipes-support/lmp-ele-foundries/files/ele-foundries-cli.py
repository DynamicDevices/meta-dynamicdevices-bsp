#!/usr/bin/python3
# SPDX-License-Identifier: MIT
#
# ELE-Foundries CLI - Command line interface for ELE-based Foundries.io operations

import os
import sys
import json
import argparse
import subprocess
from pathlib import Path

def check_ele_status():
    """Check EdgeLock Enclave status"""
    print("🔐 EdgeLock Enclave Status:")
    
    # Check ELE device
    if os.path.exists("/dev/ele_mu"):
        print("  ✅ ELE device: /dev/ele_mu (present)")
    else:
        print("  ❌ ELE device: /dev/ele_mu (missing)")
        return False
    
    # Check ELE firmware
    firmware_dir = "/lib/firmware/imx/ele"
    if os.path.exists(firmware_dir):
        print(f"  ✅ ELE firmware: {firmware_dir} (present)")
        firmware_files = list(Path(firmware_dir).glob("*"))
        for fw in firmware_files:
            print(f"    📦 {fw.name}")
    else:
        print(f"  ❌ ELE firmware: {firmware_dir} (missing)")
    
    return True

def check_foundries_config():
    """Check Foundries.io configuration"""
    print("\n🏭 Foundries.io Configuration:")
    
    repo_id = os.environ.get("REPOID", "")
    if repo_id:
        print(f"  ✅ Factory ID: {repo_id}")
    else:
        print("  ❌ Factory ID: Not configured (set REPOID)")
        return False
    
    # Check factory CA certificate
    ca_path = "/usr/share/lmp-ele-foundries/root.crt"
    if os.path.exists(ca_path):
        print(f"  ✅ Factory CA: {ca_path}")
    else:
        print(f"  ⚠️  Factory CA: {ca_path} (missing)")
    
    return True

def check_provisioning_status():
    """Check device provisioning status"""
    print("\n📋 Device Provisioning Status:")
    
    sota_dir = "/var/sota"
    sota_db = os.path.join(sota_dir, "sql.db")
    sota_toml = os.path.join(sota_dir, "sota.toml")
    
    if os.path.exists(sota_db):
        print("  ✅ Device provisioned: OTA database exists")
        
        # Check aktualizr-lite status
        try:
            result = subprocess.run(
                ["systemctl", "is-active", "aktualizr-lite"],
                capture_output=True, text=True
            )
            if result.returncode == 0:
                print("  ✅ OTA service: aktualizr-lite (active)")
            else:
                print("  ⚠️  OTA service: aktualizr-lite (inactive)")
        except:
            print("  ❓ OTA service: status unknown")
    else:
        print("  ❌ Device not provisioned: No OTA database")
    
    if os.path.exists(sota_toml):
        print(f"  ✅ OTA config: {sota_toml}")
    else:
        print(f"  ❌ OTA config: {sota_toml} (missing)")

def get_device_info():
    """Get device information"""
    print("\n💻 Device Information:")
    
    # Device UUID
    try:
        with open("/sys/devices/soc0/soc_uid", "r") as f:
            soc_uid = f.read().strip()
            device_uuid = f"imx93-eink-{soc_uid}"
            print(f"  🆔 Device UUID: {device_uuid}")
            print(f"  🔧 SoC UID: {soc_uid}")
    except:
        print("  ❓ Device UUID: Could not determine")
    
    # Hardware info
    try:
        with open("/proc/version", "r") as f:
            kernel = f.read().strip().split()[2]
            print(f"  🐧 Kernel: {kernel}")
    except:
        pass
    
    # OS release info
    try:
        with open("/etc/os-release", "r") as f:
            for line in f:
                if line.startswith("PRETTY_NAME="):
                    os_name = line.split("=", 1)[1].strip().strip('"')
                    print(f"  🖥️  OS: {os_name}")
                elif line.startswith("LMP_FACTORY_TAG="):
                    tag = line.split("=", 1)[1].strip().strip('"')
                    print(f"  🏷️  Factory Tag: {tag}")
    except:
        pass

def register_device():
    """Trigger device registration"""
    print("\n🚀 Triggering Device Registration:")
    
    if os.path.exists("/var/sota/sql.db"):
        print("  ℹ️  Device already provisioned")
        return
    
    try:
        print("  ⏳ Starting registration process...")
        result = subprocess.run(["/usr/bin/lmp-ele-auto-register"], 
                              capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0:
            print("  ✅ Registration completed successfully")
        else:
            print(f"  ❌ Registration failed: {result.stderr}")
    except subprocess.TimeoutExpired:
        print("  ⏰ Registration timed out (may continue in background)")
    except Exception as e:
        print(f"  ❌ Registration error: {e}")

def show_logs():
    """Show registration service logs"""
    print("\n📜 Registration Service Logs:")
    try:
        subprocess.run([
            "journalctl", "-u", "lmp-ele-auto-register", 
            "--no-pager", "-n", "20"
        ])
    except Exception as e:
        print(f"  ❌ Could not retrieve logs: {e}")

def main():
    parser = argparse.ArgumentParser(
        description="ELE-Foundries CLI - EdgeLock Enclave integration with Foundries.io"
    )
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Status command
    subparsers.add_parser("status", help="Show system status")
    
    # Device info command
    subparsers.add_parser("info", help="Show device information")
    
    # Register command
    subparsers.add_parser("register", help="Register device with factory")
    
    # Logs command
    subparsers.add_parser("logs", help="Show registration service logs")
    
    # Check command (comprehensive check)
    subparsers.add_parser("check", help="Run comprehensive system check")
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    print("🔐 ELE-Foundries CLI - i.MX93 Jaguar E-Ink")
    print("==========================================")
    
    if args.command == "status":
        check_ele_status()
        check_foundries_config()
        check_provisioning_status()
    
    elif args.command == "info":
        get_device_info()
    
    elif args.command == "register":
        register_device()
    
    elif args.command == "logs":
        show_logs()
    
    elif args.command == "check":
        print("🔍 Comprehensive System Check:")
        print("=" * 40)
        
        ele_ok = check_ele_status()
        foundries_ok = check_foundries_config()
        check_provisioning_status()
        get_device_info()
        
        print("\n📊 Summary:")
        if ele_ok and foundries_ok:
            print("  ✅ System ready for Foundries.io registration")
        else:
            print("  ⚠️  System configuration issues detected")
            if not ele_ok:
                print("    - Check ELE hardware and firmware")
            if not foundries_ok:
                print("    - Configure REPOID and factory certificates")

if __name__ == "__main__":
    main()
