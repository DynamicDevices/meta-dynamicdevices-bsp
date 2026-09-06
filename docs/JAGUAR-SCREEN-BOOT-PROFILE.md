# Jaguar Screen boot profile baseline

Date: 2026-09-06

## Identity and method

- Board: `imx8mm-jaguar-screen-2210a09dab86563`
- Foundries target: 2874 (`Linux-microPlatform Dynamic Devices 5.0.11-2874-95.2`)
- Boot firmware: `2026090601`
- U-Boot: `2024.04+fio+gbb07913571e`
- Kernel: `6.6.52-lmp-standard`
- Kernel command line includes `quiet loglevel=3`, serial console and earlycon;
  framebuffer-console emulation is disabled.
- UART: DPX ser2net `192.168.2.10:2324`, physically reported as
  `/dev/ttyUSB0` at 115200 baud. No `minicom` or `screen` owner was present.
- Host receive timestamps used `Time::HiRes`. They measure complete UART lines,
  not a hardware reset pin; kernel and systemd figures use monotonic target
  timestamps.
- Three forced reboots excluded the separate slow shutdown/system-watchdog
  fault. Final cold-power and OTA acceptance remain required.
- Persistent `bootdelay` was returned from the prior debug value `3` to the
  product value `0`. One-shot network changes were restored after each test.

## Stable bootloader milestones

Times start at the first post-reset UART byte. Values are seconds.

| Milestone | Run 1 | Run 2 | Run 3 | Median |
| --- | ---: | ---: | ---: | ---: |
| SPL banner | 0.039 | 0.034 | 0.037 | 0.037 |
| U-Boot proper banner | 2.124 | 2.081 | 2.110 | 2.110 |
| U-Boot splash displayed | 3.021 | 2.985 | 3.004 | 3.004 |
| `Starting kernel` | 3.792 | 3.802 | 3.821 | 3.802 |
| First Linux line | 3.875 | 3.890 | 3.906 | 3.890 |

The bootloader's repeatable path is therefore approximately 3.9 seconds from
reset to kernel entry. The measured sub-intervals are:

- SPL, signed boot-container verification, BL31, OP-TEE and SE05x:
  approximately 2.1 seconds.
- U-Boot proper initialization, video link and splash: approximately 0.9
  seconds after the U-Boot banner.
- Splash to kernel entry: approximately 0.9 seconds. This includes loading and
  verifying the 24.4 MiB FIT and approximately 0.4 seconds of gzip kernel
  decompression.

The splash load itself is only about 30 ms. Removing its artwork would not be a
meaningful boot-speed optimisation.

## Linux baseline

The target does not install `systemd-analyze`; measurements use the boot
journal and unit monotonic properties.

| Milestone from kernel entry | Baseline |
| --- | ---: |
| Kernel phase reported by systemd | 2.513 s |
| `systemd-udevd` running | 3.64 s |
| Early Linux splash active | 4.46 s |
| `sysinit.target` | 4.93 s |
| Serial getty active | 6.28 s |
| Wi-Fi address usable | approximately 13.2 s |
| Docker active | 67.56 s |
| `multi-user.target` | 67.56 s |

The serial login banner was received approximately 12.6 seconds after kernel
entry, although the getty was active at 6.28 seconds. The stock getty uses
`Type=idle`, deliberately delaying visible prompt output to avoid interleaving
with boot messages. Thus reset-to-shell is about 10.2 seconds by service
readiness, or about 16.5 seconds to the visibly printed serial banner.

No product containers were installed on target 2874, so Docker readiness is a
runtime proxy rather than an application-first-frame measurement.

## Critical-path cause

`NetworkManager-wait-online.service` runs `nm-online -s -q` with a 60-second
timeout. Wi-Fi succeeds, but the disconnected `end0` profile has
`autoconnect=yes` and repeatedly waits for DHCP. NetworkManager therefore does
not declare all startup profiles settled. The service fails at 66.22 seconds,
after which Docker starts and becomes active at 67.56 seconds.

`systemd-time-wait-sync.service` is also enabled from `sysinit.target` and
finishes at approximately 35 seconds. It delays the formal
`multi-user.target` milestone but does not block the early splash, serial
getty, network manager or Docker after the network wait is corrected.

## Reversible A/B evidence

### A: disable unused wired autoconnect

- Single change: `Wired connection 1` `connection.autoconnect=no`.
- Network wait finished at 11.24 seconds.
- Docker became active at 12.56 seconds, a 55.0-second improvement.
- Wired autoconnect was restored to `yes` after the test.

This proves the wired startup profile causes the long wait, but permanently
disabling it would remove expected Ethernet behavior.

### B: wait for any usable connection

A temporary systemd drop-in replaced `nm-online -s -q` with:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/nm-online -q -t 20
```

With wired autoconnect still enabled:

- network wait finished at 11.14 seconds;
- Docker became active at 12.45 seconds;
- `end0` continued attempting DHCP in the background;
- Wi-Fi and SSH remained usable.

The drop-in was removed after the test. The board was left with no untracked
service override, wired autoconnect enabled and `bootdelay=0`.

## Risk-ranked optimisation backlog

### 1. Very low risk / highest return

1. Ship a Screen-machine override that waits for any usable network connection
   rather than every startup profile. Bench delta: approximately 55 seconds to
   Docker/runtime readiness. Preserve the 20-second bounded failure path and
   prove offline, Wi-Fi and wired boots.
2. Keep the compiled and persistent `bootdelay=0`. The documented debug
   hotpatch may restore `3` temporarily.
3. Remove the harmless U-Boot `Unknown command 'fiovb'` path after confirming
   it is not a verified-boot recovery hook. Expected timing gain is negligible;
   this is console/error hygiene.

### 2. Low risk / diagnostic-only benefit

1. Override serial-getty from `Type=idle` only if a prompt must be visibly
   printed earlier. Expected gain is about five seconds to the visible prompt,
   with the trade-off that boot output can interleave with login text. It does
   not improve product UI readiness.
2. Disable ModemManager for this machine if the product has no modem. The boot
   saving is small, but it removes unnecessary startup/shutdown work.

### 3. Medium risk

1. Stop enabling `systemd-time-wait-sync` globally for registered devices and
   pull it only for operations that require verified wall-clock time. This can
   move formal `multi-user.target` from about 35 seconds to the 12–13 second
   runtime point, but OTA/TUF/TLS, certificate validation and offline-clock
   behavior must be tested.
2. Trim the 11.7 MiB initramfs and unused built-in kernel features. Kernel
   initramfs unpacking alone occupies roughly 0.6 seconds. Recovery and OSTree
   boot requirements must remain intact.
3. Defer non-product services rather than removing them, then measure actual
   application first-frame contention.

### 4. High risk / low immediate value

1. Compare gzip with a faster kernel/FIT compression only through signed
   one-shot FITs. Current decompression costs about 0.4 seconds; larger payloads
   and recovery compatibility may outweigh the gain.
2. Moving first light into SPL would show pixels before the current 3.0-second
   U-Boot splash, but duplicates the DSI/panel stack in a more constrained and
   recovery-critical stage.
3. Do not remove signed image verification, rollback, watchdog recovery,
   OP-TEE, SE05x or SCP03 for boot timing.

## Next proof gates

1. Capture the network readiness override in the owning Yocto layer and run a
   reversible board boot with Ethernet unplugged, Ethernet connected, Wi-Fi
   connected and fully offline.
2. Measure the actual compositor/application first frame once the product
   container is installed; Docker active is not final product readiness.
3. Repeat three warm boots and one cold-power boot with no bench overrides.
4. Confirm the optimisation through the manifest-pinned Foundries/OTA image and
   exercise rollback/recovery.
