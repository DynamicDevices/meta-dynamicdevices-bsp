# TAA5412-Q1 — register / coefficient firmware (`taa5412-i2c-*-1dev.bin`)

## Can we “just download” the `.bin`?

**No public drop** for `taa5412-i2c-1-1dev.bin` was found (kernel.org **linux-firmware**, Debian **linux-firmware** pool, TI **ti-linux-firmware** GitHub mirror — no matching path; `git.ti.com` plain URLs for guessed paths return **404**).

The **authoritative source** is TI’s **pcmdevice** drop: register image is **generated** from JSON + **Non_Integrated_Bin_Tool** (Windows NW.js app inside the same repo’s `tool/` zip), not committed as a finished `.bin`.

This BSP directory therefore vendors the **GPL-2.0-only** TI JSON (**`taa5412-1dev-reg.json`**) plus **`TI-PCMJSN-ORIGIN.txt`** so you can reproduce or diff the input. Add **`taa5412-i2c-1-1dev.bin`** beside this README (**Linux `node` export** below or Windows GUI **§ A**). See **Yocto / BSP** for **`firmware-taa5412`**; a template **`firmware-taa5412_1.0.bb.disabled`** exists alongside **`firmware-taa5412_1.0.bb`** for comparison.

## Why this file is not in the kernel backport

Mainline **`sound/soc/codecs/pcm6240.c`** (imported as `imx8mm-jaguar-dt510/pcm6240-lmp/0001-asoc-pcm6240-import-from-mainline-v6.10.patch`) calls **`request_firmware()`** for a vendor register-block binary. The **C driver** is open source; the **`.bin`** is a **Texas Instruments** deliverable (same pattern as other TI audio parts that ship coefficient / register images outside the kernel git tree).

The driver builds the filename when there is **no** `name-prefix` on the ASoC component:

- **`{dev_name}-i2c-{adapter_nr}-{ndev}dev.bin`**
- For **`ti,taa5412`**, **`dev_name`** is **`taa5412`** (see `pcmdevice_i2c_id[]` in `pcm6240.c`).
- On DT510, **`&i2c2`** is usually Linux adapter **`i2c-1`** → expect **`taa5412-i2c-1-1dev.bin`** under **`/lib/firmware/`** (confirmed by on-target `dmesg`).

If you add **`ti,name-prefix`** in DTS, the driver uses **`<name-prefix>.bin`** instead — only do that if you intentionally rename the blob.

## Where to obtain the blob (engineering sources)

### PurePath Console 3 (bench / tuning)

**PPC3** is the normal place to **design** mic path, gains, and metadata for **TAA5412** (EVM collateral, **SLAU903**). It is **not** interchangeable with the Linux `request_firmware()` blob unless TI’s export explicitly produces the **pcmdevice register binary** format (same family as **Non_Integrated_Bin_Tool** output — see kernel parser comments in `pcm6240.c`).

Practical split:

- Use **PPC3** to decide *what* registers/coefficients you want.
- For the **`.bin` the kernel loads**, still use **`jsn/taa5412-1dev-reg.json`** → **Non_Integrated_Bin_Tool** (**§ A** Windows or **§ A′** Linux **`node`** below), unless TI documents a PPC3 export that byte-matches that format—then rename to **`taa5412-i2c-1-1dev.bin`** and confirm **`request_firmware`** succeeds on hardware.

### A. Generate from TI repo (`Non_Integrated_Bin_Tool`)

**Why “TAA5412” is not in the first-screen dropdown:** The wizard’s **Device 1 / amplifier** list is hard-coded to **TAS2558 / TAS2560 / TAS2562 / TAS2564** (plus **TAS2783** in Integrated-only mode) in the tool’s **`configData.json`** — it is aimed at those smart amps, **not** PCM6240-family ADC parts. **Do not wait for TAA5412 there.**

**What to do instead:** After **`nw.exe`** starts, open the top-left **menu (≡)** → **Open**, and pick **`taa5412-1dev-reg.json`** from the pcmdevice clone (**`jsn/taa5412-1dev-reg.json`**). That loads the register script **directly** and skips the bogus amp picker. (The JSON may carry a legacy **`amplifierType`** value such as **`TAS2564`** inside **`settings`** — TI ships it that way; it does **not** mean you should pick a different part on the wizard.)

1. Clone **`https://git.ti.com/git/lpaa-android-drivers/pcmdevice-linux-driver.git`** (shallow is fine).
2. On **Windows**, unzip **`tool/Non_Integrated_Bin_Tool_1.3.7.zip`** and run **`nw.exe`** (NW.js shell).
3. **Menu → Open** **`jsn/taa5412-1dev-reg.json`** (or the BSP copy **`taa5412-1dev-reg.json`** beside this README — same content).
4. **Export / save** the **register binary** using the tool’s UI so the output file name matches what Linux requests on your board — for DT510 **`&i2c2` → `i2c-1`** and a single device that is:
   - **`taa5412-i2c-1-1dev.bin`**
5. Install the blob as **`recipes-kernel/firmware/firmware-taa5412/taa5412-i2c-1-1dev.bin`** and build with **`MACHINE_FEATURES`** **`taa5412`** ( **`firmware-taa5412`** is enabled in **`imx8mm-jaguar-dt510.conf`**). Confirm TI redistribution terms before publishing the **`.bin`** in a public fork.

**Export error `PRE_SHUTDOWN … Device not selected`:** TI’s **`jsn/taa5412-1dev-reg.json`** historically left **`PRE_SHUTDOWN`** with empty **`deviceName`** / **`deviceValue: null`**; **Non_Integrated_Bin_Tool** rejects that (`Block.prototype.isValid` requires both). Use the **BSP copy** **`taa5412-1dev-reg.json`** in this folder ( **`PRE_SHUTDOWN - Dev 1`** + **`Dev 1 - TAS2564`** / **`deviceValue`** **0**) or patch your JSON to match **`PRE_POWER_UP`**’s device fields before export.

The tool’s embedded layout uses **`configData.json`** `headerSize` **292** and **`binaryVersion` [0,0,1,5]** — aligned with the mainline kernel parser (`binary_version_num >= 0x105` enables 64-byte config names, etc.).

### A′. Linux headless export (`node`) — same format as **`nw.exe`**

TI’s **`Non_Integrated_Bin_Tool`** ships **`source/js/datastructure.js`** + **`CRC32.js`**; those implement **`Binary.prototype.toBinary()`** (header + payload + **`CRC32.buf`**), i.e. the same bytes as the GUI export.

For DT510 / BSP workflow we keep a tiny Node CLI **outside** this BSP tree (vendor code licence/origin = TI tool / SheetJS CRC):

- Place **`vendor-taa5412-non-integrated-encoder/`** next to the **`vixdt`** checkout root (**same parent directory** as this repo).
- From that folder:

```bash
cd ../vendor-taa5412-non-integrated-encoder
node export-regbin.js
```

Defaults write **`taa5412-i2c-1-1dev.bin`** into **`meta-dynamicdevices-bsp/recipes-kernel/firmware/firmware-taa5412/`** (paths resolved relative to **`…/vixdt`** inside **`export-regbin.js`**). Override paths:

```bash
node export-regbin.js path/to/taa5412-1dev-reg.json path/to/out.bin
```

The blob embeds a **Unix timestamp** in the header (same idea as the GUI); hashes change between runs even when JSON is unchanged.

### B. Other places people used to look (often empty for this part)

1. **TI PCM6240-family Linux driver package** — **PCMXXXX-DRIVERS** on ti.com. May bundle or link the git repo above; rarely ships a ready-made `taa5412-i2c-1-1dev.bin` by itself.
2. **`ti-linux-firmware`** — worth a quick `git clone --depth 1` + `find . -iname '*taa5412*'` on each release; historically **no** hit for this exact filename.
3. **Upstream `linux-firmware`** — same; re-check when bumping OE pins.

## Editing **`taa5412-1dev-reg.json`** and rebuilding **`taa5412-i2c-1-1dev.bin`**

The JSON mirrors TI **`pcmdevice`** PPC-style scripts under **`settings.configurationList`** → **`blocksList`** → **`commands`**.

1. Locate block **`PRE_POWER_UP - Dev 1`** (and **`POST_POWER_UP`** / **`PRE_SHUTDOWN`** if you touch power sequencing).
2. Each **`commands`** entry uses **`book`**, **`page`**, **`register`** (hex **strings without `0x`**), **`mask`** (**`ff`** for full-byte writes), **`data`** (hex byte string), optional **`delay`**.
3. **Example — analogue coupling (`ADC_CHx_CFG0`):** On **book `0`**, **page `0`**, TI docs (**SLASF37**) encode **CM_TOL** in **`ADC_CHx_CFG0`**. For registers **`50`**, **`55`**, **`5a`**, **`5e`** (channels **1–4**), set **`"data": "00"`** when the mic path is **AC-coupled** on the PCB. **`"04"`** corresponds to DC-oriented tolerance bits and has been observed when captures stay flatlined on AC hardware—always reconcile with the schematic *before* copying settings across boards.
4. Run **§ A′** **`node export-regbin.js`** or **§ A** Windows export.
5. Install **`taa5412-i2c-1-1dev.bin`** on the target under **`/lib/firmware/`** with the exact name **`pcm6240`** **`request_firmware()`** expects (**§ Why this file…** above). **Remount read-write** if the rootfs is **ro**, then **`sync`**. **Reboot** (or full driver reprobe) so firmware loads again.

## Reading codec registers on DT510 (**`regmap`** debugfs)

Use this after deploy/reboot to confirm the silicon matches what you encoded (without fighting **`i2c`** busy).

1. **Sysfs device:** DTS **`taa5412@51`** on **`&i2c2`** → Linux **`/sys/bus/i2c/devices/1-0051`** (**adapter `i2c-1`**, addr **`0x51`**). **`cat name`** → **`taa5412`**; driver **`pcmdevice-codec`** (**`pcm6240`** family).
2. **Addressing:** Kernel **`regmap`** uses **8‑bit** registers with **page select** at logical **`0x00`** (**`PCMDEVICE_PAGE_SELECT`** in **`pcm6240.c`**); **`0x50`** … **`0x5e`** are linear offsets on **page 0** as seen by **`regmap`**.
3. **Dump (preferred):**

```bash
sudo grep -E '^(0050|0055|005a|005e):' /sys/kernel/debug/regmap/1-0051/registers
sudo cat /sys/kernel/debug/regmap/1-0051/registers   # full map if needed
```

Lines look like **`0050: 00`** (hex value). Match JSON **`PRE_POWER_UP`** writes after firmware runs.

4. **`i2ctransfer` / `i2cget`:** Often **permission denied** as non-root on **`/dev/i2c-*`**; as root on a bound codec, **`Device or resource busy`** is normal—the **`pcm6240`** driver owns the adapter. Prefer **`debugfs`** above.
5. If **`/sys/kernel/debug/regmap/`** is missing, the kernel build may lack **`CONFIG_DEBUG_FS`** / regmap visibility—enable on your **`linux-lmp`** config for bring-up images.

## Yocto / BSP

**Recipe enabled (DT510):** **`firmware-taa5412`** is active as **`recipes-kernel/firmware/firmware-taa5412_1.0.bb`**; **`MACHINE_EXTRA_RDEPENDS`** installs it when **`MACHINE_FEATURES`** includes **`taa5412`**. The **`taa5412-i2c-1-1dev.bin`** file lives in **`firmware-taa5412/`** (TI terms — confirm redistribution for your channel).

**Historical / template:** **`recipes-kernel/firmware/firmware-taa5412_1.0.bb.disabled`** (identical recipe text for diffing).

**Ship the blob in the rootfs when `taa5412` feature is on:**

1. Place **`taa5412-i2c-1-1dev.bin`** in **`recipes-kernel/firmware/firmware-taa5412/`** (see **`firmware-taa5412_1.0.bb`** **`SRC_URI`**).
2. **`MACHINE_FEATURES`** on **`imx8mm-jaguar-dt510`** must include **`taa5412`** (already typical for DT510 codec bring-up).

Without the **`.bin`**, **`bitbake firmware-taa5412`** fails at fetch — **`file://`** requires the blob beside the recipe.

**License:** treat the **`.bin`** as **TI / proprietary** unless WHENCE or TI redistribution terms say otherwise; do not publish the blob in a public repo without clearance.
