# DT510 I²C map and runtime status (lab tracking)

**Purpose:** Single place for **SoC I²C controller ↔ Linux bus ↔ 7-bit address ↔ DT node** and **what is actually working** on hardware. Update after each **meaningful** BSP image (e.g. factory build) or schematic change.

**Last bench pass:** build **173** (IMAGE_VERSION=173, `6.6.52-lmp-standard`), `imx8mm-jaguar-dt510` — spot-check via SSH; **re-validate** on a cold boot if drivers look stuck.

**Related:** [`DT510-HARDWARE-AUDIT-CHECKLIST.md`](DT510-HARDWARE-AUDIT-CHECKLIST.md) · Ethernet/switch: [`DT510-ETHERNET-KSZ9896.md`](DT510-ETHERNET-KSZ9896.md)

---

## 1. i.MX8MM I²C ↔ device-tree ↔ Linux `i2c-N`

| SoC **MMIO**   | DTC label (imx8mm) | Typical DT fragment | **Linux adapter** (observed) |
|----------------|--------------------|------------------------|------------------------------|
| `0x30a20000`   | I2C1               | `&i2c1`                | `i2c-0`                      |
| `0x30a30000`   | I2C2               | `&i2c2`                | `i2c-1`                      |
| `0x30a40000`   | I2C3               | `&i2c3`                | `i2c-2`                      |
| I2C4 (SE050)   | `&i2c4`            | see SE050 / OpTEE      | (often **no** `i2c-3` in Linux) |

`i2cdetect -l` may list only `i2c-1` and `i2c-2` by **name**, while `i2c-0` still exists under **sysfs** (`/sys/class/i2c-dev/`, `30a20000.i2c`).

**Kernel note:** I²C client nodes use **`N-00aa`** in sysfs, e.g. `0-0044` = adapter 0, address `0x44`. **KSZ9896** DSA management is **`switch@5f`** on **`&i2c2`** in DTS (**placeholder bus/addr** until EE confirms straps + pinout).

---

## 2. Device table (SSOT / BSP) + **observed** status (build 173 lab)

| Bus (`i2c-N`) | 7-bit addr | Part / function | `imx8mm-jaguar-dt510.dts` | Driver / subsystem | **Lab status (↗)** |
|----------------|------------|------------------|-----------------------------|------------------------|--------------------|
| **0** | `0x25` | **NXP PCA9450** PMIC | imx8mm-evkb (`&i2c1`) | regulator / pinctrl | **OK** (PMIC core; DTC/DT bind) |
| **0** | — | **Sensirion SHT4x** | **not on DT510** — **`sht40@44`** removed from **`imx8mm-jaguar-dt510.dts`** | — | **N/A** |
| **2** | `0x5f` | **Microchip KSZ9896** (DSA / switch mgmt) | **`switch@5f`** under **`&i2c2`** (**confirm** bus + addr vs straps) | `microchip,ksz9896` | **Pending (↗)**: probe succeeds only after **I²C strap** + routing match DTS; see [`DT510-ETHERNET-KSZ9896.md`](DT510-ETHERNET-KSZ9896.md). |
| **1** | `0x3d` | **ADV7535** (DSI→HDMI) | EVK carry-over | `adv7533` (optional) | **On bus (↗)**: not DT510 end-product focus; **display stack disabled** in DT510. |
| **1** | `0x4c` | **TI TAS2563** | `tas2563@4c` | ASoC / `snd_soc_tas2563` | **Driver bound (↗)** — validate audio path separately. |
| **1** | `0x50` | **TI TAC5301-Q1** | `tac5301@50`, `ti,tac5301` | ASoC TAC5x1x family (**kernel `CONFIG_*` TBD**) | **DT wired (↗)** — codec driver must match kernel image; verify probe after enabling module. |
| **1** | `0x6a` | **TI TAS6424** | `tas6424@6a` | ASoC | **Driver bound (↗)** — SAI1 clock reparent `(-EINVAL)` seen in dmesg on same image; full audio TBD. |
| **1** | `0x48`, `0x51` | (scan hits) | **not** described in **`imx8mm-jaguar-dt510.dts`** | — | **Unknown (↗)** — confirm **BOM** / schematic (e.g. companion IC next to TAC5301, EEPROM). |
| **2** | — | **TI LP5024** | **not on DT510** — EVK carry-over removed from **`imx8mm-jaguar-dt510.dts`** | — | **N/A** |
| **2** | `0x3f` | **ST STTS22H** temp | `stts22h@3f` | `stts22` (IIO/hwmon) | **Not working (↗)**: `i2cget` **read error**; **no** `driver` on `2-003f`. |
| **2** | `0x6b` | **TI BQ25792** charger | `bq25792@6b` | `bq257xx` MFD, charger, regulator | **Partial (↗)**: **`bq257xx` bound** to `2-006b`, **`bq257xx-charger.*`** / **`bq257xx-regulator.*`** present; **no** `power_supply` entries in `/sys/class/power_supply/` on that check — verify **Kconfig** / **MFD** child probe / `simple-battery` and **CHGR_INT#** (GPIO4_IO9) handling. |
| **—** | I2C4 `0x48` | NXP **SE050** | OpTEE / no Linux child | TEE / crypto | **By design (↗)**: not listed as normal Linux I²C userland device. |

**Legend (↗):** **OK** = behaviour matches expectation for this bring-up stage · **Not working** = bus or driver not delivering data · **Partial** = bind exists, userspace/child incomplete · **Unknown** = extra addresses on bus.

---

## 3. How to re-verify (commands on device)

- **Adapters:** `sudo i2cdetect -l` then `sudo i2cdetect -y 0` … `2` (use **adapter index** 0,1,2 = **&i2c1…3** as above).  
- **KSZ (MIIM, not I²C):** `dmesg | grep -iE 'fec|mdio'`, `ethtool` on the primary netdev — see Ethernet doc.  
- **STTS22H:** `sudo i2cget -y 2 0x3f` (or WHOAMI per datasheet).  
- **BQ25792:** `ls /sys/bus/i2c/devices/2-006b/`; `ls /sys/class/power_supply/`; `dmesg | grep bq25`.

---

## 4. DT / implementation notes (ongoing work)

- **LP5024:** **not** populated on DT510 — **`led-controller@28`** removed from **`imx8mm-jaguar-dt510.dts`** (was EVK carry-over).  
- **TAC5301:** **`tac5301@50`** on **`&i2c2`**, **`&sai6`** + **`sound-tac5301`** — enable **ASoC TAC5x1x / `ti,tac5301`** in the kernel when that driver is integrated; **`reset-gpios`** uses **GPIO4_IO14** (mux in **`pinctrl_tac5301_gpio`**).  
- **STTS22H** has **interrupt** on GPIO4_IO8; if pin wrong or not routed, keep poll-only until SSOT.  
- **BQ25792** + **`monitored-battery`**: B1 model in DT; if **power_supply** does not appear, debug **MFD** probe order, **GPI** `CHGR_INT#`, and kernel `CONFIG_CHARGER_BQ257XX` / bq25xx feature flags for this image.  
- **TAS6424** / **SAI1:** `sai1_root_clk` reparent error in kernel log is a **separate** bring-up from I²C presence.

Update this file when you have a **new build number** and a **short** one-line outcome per row.
