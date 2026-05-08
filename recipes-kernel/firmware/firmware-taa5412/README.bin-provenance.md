# TAA5412-Q1 — register / coefficient firmware (`taa5412-i2c-*-1dev.bin`)

## Can we “just download” the `.bin`?

**No public drop** for `taa5412-i2c-1-1dev.bin` was found (kernel.org **linux-firmware**, Debian **linux-firmware** pool, TI **ti-linux-firmware** GitHub mirror — no matching path; `git.ti.com` plain URLs for guessed paths return **404**).

The **authoritative source** is TI’s **pcmdevice** drop: register image is **generated** from JSON + **Non_Integrated_Bin_Tool** (Windows NW.js app inside the same repo’s `tool/` zip), not committed as a finished `.bin`.

This BSP directory therefore vendors the **GPL-2.0-only** TI JSON (**`taa5412-1dev-reg.json`**) plus **`TI-PCMJSN-ORIGIN.txt`** so you can reproduce or diff the input. You still have to **export the `.bin`** once (Windows GUI below), then add it beside this README and **enable** the recipe (see **Yocto / BSP** below). In git the recipe is **`firmware-taa5412_1.0.bb.disabled`** so CI does not parse **`SRC_URI`** without the blob.

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
- For the **`.bin` the kernel loads**, still use **`jsn/taa5412-1dev-reg.json`** → **Non_Integrated_Bin_Tool** (steps in **§ A** below), unless TI documents a PPC3 export that byte-matches that format—then rename to **`taa5412-i2c-1-1dev.bin`** and confirm **`request_firmware`** succeeds on hardware.

### A. Generate from TI repo (`Non_Integrated_Bin_Tool`)

**Why “TAA5412” is not in the first-screen dropdown:** The wizard’s **Device 1 / amplifier** list is hard-coded to **TAS2558 / TAS2560 / TAS2562 / TAS2564** (plus **TAS2783** in Integrated-only mode) in the tool’s **`configData.json`** — it is aimed at those smart amps, **not** PCM6240-family ADC parts. **Do not wait for TAA5412 there.**

**What to do instead:** After **`nw.exe`** starts, open the top-left **menu (≡)** → **Open**, and pick **`taa5412-1dev-reg.json`** from the pcmdevice clone (**`jsn/taa5412-1dev-reg.json`**). That loads the register script **directly** and skips the bogus amp picker. (The JSON may carry a legacy **`amplifierType`** value such as **`TAS2564`** inside **`settings`** — TI ships it that way; it does **not** mean you should pick a different part on the wizard.)

1. Clone **`https://git.ti.com/git/lpaa-android-drivers/pcmdevice-linux-driver.git`** (shallow is fine).
2. On **Windows**, unzip **`tool/Non_Integrated_Bin_Tool_1.3.7.zip`** and run **`nw.exe`** (NW.js shell).
3. **Menu → Open** **`jsn/taa5412-1dev-reg.json`** (or the BSP copy **`taa5412-1dev-reg.json`** beside this README — same content).
4. **Export / save** the **register binary** using the tool’s UI so the output file name matches what Linux requests on your board — for DT510 **`&i2c2` → `i2c-1`** and a single device that is:
   - **`taa5412-i2c-1-1dev.bin`**
5. Copy that file next to this README, **`cp firmware-taa5412_1.0.bb.disabled firmware-taa5412_1.0.bb`** in this directory, and enable **`firmware-taa5412`** on the machine (see **`imx8mm-jaguar-dt510.conf`** **`MACHINE_EXTRA_RDEPENDS`**). Do **not** commit **`firmware-taa5412_1.0.bb`** or the **`.bin`** without redistribution clearance.

The tool’s embedded layout uses **`configData.json`** `headerSize` **292** and **`binaryVersion` [0,0,1,5]** — aligned with the mainline kernel parser (`binary_version_num >= 0x105` enables 64-byte config names, etc.).

### B. Other places people used to look (often empty for this part)

1. **TI PCM6240-family Linux driver package** — **PCMXXXX-DRIVERS** on ti.com. May bundle or link the git repo above; rarely ships a ready-made `taa5412-i2c-1-1dev.bin` by itself.
2. **`ti-linux-firmware`** — worth a quick `git clone --depth 1` + `find . -iname '*taa5412*'` on each release; historically **no** hit for this exact filename.
3. **Upstream `linux-firmware`** — same; re-check when bumping OE pins.

## Yocto / BSP

**Tracked recipe (disabled — not parsed):** **`meta-dynamicdevices-bsp/recipes-kernel/firmware/firmware-taa5412_1.0.bb.disabled`**

**Enable (local / private layer fork only, after vendoring the `.bin`):**

1. Place **`taa5412-i2c-1-1dev.bin`** next to this README (for the common DT510 **`i2c-1`** + single-device case).
2. **`cp firmware-taa5412_1.0.bb.disabled firmware-taa5412_1.0.bb`** in the same directory (**`.bb`** is gitignored or kept out of public branches if policy requires).
3. Uncomment **`MACHINE_EXTRA_RDEPENDS`** for **`firmware-taa5412`** in **`imx8mm-jaguar-dt510.conf`** when ready.

Without step 1–2, BitBake would fail checksum on **`file://taa5412-i2c-1-1dev.bin`** — hence the **`.bb.disabled`** suffix in the BSP repo.

**License:** treat the **`.bin`** as **TI / proprietary** unless WHENCE or TI redistribution terms say otherwise; do not publish the blob in a public repo without clearance.
