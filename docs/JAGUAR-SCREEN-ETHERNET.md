# Jaguar Screen wired Ethernet invariant

The `imx8mm-jaguar-screen` carrier uses the i.MX8MM FEC with a Microchip
KSZ9131RNX PHY. A link indication and successful 1 Gbit/s negotiation are not
enough to prove this path: the PHY can receive frames while its RGMII transmit
clock DLL remains disabled, preventing DHCP and all other transmitted traffic.

## Required behaviour

Every Screen kernel branch must carry commit `70b8b30` (`net: fix KSZ9131
RGMII TX delay on Screen`) or an equivalent/upstream fix. The change reapplies
and verifies the KSZ9131 RGMII DLL configuration at the end of PHY
`config_init()`. Do not drop it while consolidating display or boot branches.

This is not a VLAN configuration issue. The Screen uses an ordinary Ethernet
NetworkManager profile and has no VLAN node or VLAN property in its DTS.

## Regression signature

- `end0` is `UP,LOWER_UP` and negotiates 1000baseT/full duplex.
- NetworkManager remains at `connecting (getting IP configuration)`.
- `end0` RX counters increase while TX counters remain unchanged.
- Wi-Fi may hide the failure by providing the board's reachable IP address.

Target 2878 reproduced this signature on 2026-09-06. The target used the
current Screen branch, which did not contain `70b8b30`; the fix had been left
on `fix/screen-uboot-dsi-handoff` during branch consolidation.

## Merge and release gate

Before building or releasing a Screen target, confirm that the Screen kernel
recipe includes the KSZ9131 delay patch (or record the upstream replacement):

```sh
git merge-base --is-ancestor 70b8b30 HEAD
rg -n "ksz9131.*rgmii.*delay" recipes-kernel/linux
```

Bench proof requires more than carrier:

```sh
nmcli device show end0
ip -s link show end0
```

Pass only when `end0` receives a DHCP IPv4 address and both RX and TX counters
increase. Test with Wi-Fi disconnected or explicitly inspect the `end0`
address so Wi-Fi cannot mask an Ethernet failure.
