# TAA5412 — PCM6240 driver backport plan (i.MX 6.6 factory kernel)

**Purpose:** Step-by-step plan to add **Texas Instruments PCM6240-family** ASoC support (including **`ti,taa5412`**) to the **existing** `linux-lmp-fslc-imx` / **Freescale `linux-fslc`** line **without** destabilising unrelated audio, boot, or OTA.

**Naming:** Mainline uses **`sound/soc/codecs/pcm6240.c`** and **`CONFIG_SND_SOC_PCM6240`**. If you searched for “PCM6420”, confirm part number — **TAA5412** is bound via **`ti,taa5412`** in the **PCM6240** driver family.

**Related:** [`DT510-BSP-PROJECT-PLAN.md`](DT510-BSP-PROJECT-PLAN.md) Tier C2 · Issue [#2](https://github.com/DynamicDevices/meta-dynamicdevices-bsp/issues/2)

---

## 1. Difficulty (honest summary)

| Factor | Assessment |
|--------|------------|
| **Code size** | **~2.2k lines** `pcm6240.c` + **~250 lines** `pcm6240.h` (mainline), plus **Kconfig** / **Makefile** / **DT binding** |
| **Risk** | **Medium–high** — large new driver; **merge conflicts** with NXP `linux-fslc` delta; **firmware** (`.bin`) may be required for full behaviour |
| **Skill** | ASoC + regmap + Yocto kernel bbappend experience |
| **Time** | Order of **several days** for a careful first integration + **hardware** validation (not a single afternoon) |

**Why it can break things:** incorrect Kconfig dependencies, `Makefile` ordering, or probe regressions on **I2C2** shared with **TAS2563 / TAS6424 / TAC5301** if DT enables nodes prematurely.

---

## 2. Principles (do not break the platform)

1. **Kernel ABI unchanged for existing modules** — add **`CONFIG_SND_SOC_PCM6240=m`** (module preferred); do not turn on “build all codecs” unless you accept image size and QA cost.
2. **Device tree:** start with **`status = "disabled"`** until driver loads and supplies/GPIOs are confirmed.
3. **One change vector per phase** — merge **driver + build** before **enabling** TAA5412 in DT.
4. **Always** keep a **known-good** kernel image / OTA path to roll back.
5. **Rebase** on the **exact** `SRCREV` your factory uses — document it in the PR/issue.

---

## 2.1 Interaction with existing BSP / LmP ASoC patches (important)

**DT510 already carries kernel changes under** `recipes-kernel/linux/linux-lmp-fslc-imx/` **that touch the same subsystem.** The PCM6240 import is not isolated.

| Area | What is already patched | Interaction with PCM6240 / `SND_SOC_PCM6240` |
|------|-------------------------|-----------------------------------------------|
| **`sound/soc/codecs/Makefile`** | **`0002-asoc-tas2781-add-tas2563-codec-support.patch`** adds **TAS2781 comlib-i2c** object lines in the **TAS27xx** block (~line 279 / ~658 in the pre-import tree). **TAC5x1x** uses **`07a-tac5x1x-fslc-codecs-makefile-objs.patch`** and **`07b-…-makefile-obj.patch`** in the **ST*/TAS** block (~268 / ~651). | **PCM6240** hunks sit in the **PCM512x → PEB2466** band (~199 / ~585). **No overlapping hunk in the current tree**, but **any** future Makefile edits in the BSP stack (or an **`SRCREV`** bump) can shift line numbers and cause **patch fuzz / rejects** when several series apply in one build. |
| **`sound/soc/codecs/Kconfig`** | **`0002-asoc-tas2781-…`** edits the **TAS2781** block (~1784+). **TAC5x1x** lore patches add **TAC5x1x** `Kconfig` / codec files. | **PCM6240** `Kconfig` is inserted **before `SND_SOC_PEB2466`** (~1362). **Different region** from TAS2781; still **same file** — resolve rejects carefully so you do not drop TAS or TAC symbols. |
| **`SRC_URI` apply order** (`linux-lmp-fslc-imx_%.bbappend`) | For **`imx8mm-jaguar-dt510`**, **`taa5412`** (PCM6240) patches are listed **before** **`0002-asoc-tas2781-…`** and the **TAC5x1x** series. | Order is intentional so **PCM6240 lands first**; downstream patches use **content-based** context and have applied cleanly so far. **Do not reorder** without re-running **`patch --dry-run`** on the pinned **`SRCREV`**. If BitBake reports **`.rej`** on **`sound/soc/codecs/Makefile`**, compare against **TAS2781** and **TAC5x1x** hunks and produce a **forward-port** of the failing patch rather than deleting lines blindly. |
| **Runtime / DT** | **TAS2563**, **TAS6424**, **TAC5x1x** / **TAC5301** on **shared I2C** (see plan **§1** / **Phase D**). | **Probe order**, **`-EPROBE_DEFER`**, and **DT `status`** still dominate risk; the codec driver stack only changes **how many** modules compete on the bus. |

**Takeaway:** treat PCM6240 as **one more member of an already-customised `sound/soc/codecs` tree** — kernel upgrades and **Makefile/Kconfig** edits for **any** TI/NXP codec patch can force a **manual three-way** with PCM6240.

---

## 3. Preconditions (before writing patches)

- [ ] Record **pinned** `linux-lmp-fslc-imx` **`SRCREV_machine`**, **`LINUX_VERSION`**, and **`KERNEL_BRANCH`** from **meta-lmp** (and your **lmp-manifest** pin).
- [ ] Clone **Freescale `linux-fslc`** at that **commit** locally for patch development.
- [ ] Identify **mainline commits** that introduced **`pcm6240`** (use `git log -- sound/soc/codecs/pcm6240.c` on `torvalds/linux` from first introduction through **TAA5412** / `ti,taa5412` support).
- [ ] List **dependencies**: e.g. `regmap`, `firmware` API — usually already satisfied on 6.6; watch for **ASoC API** differences between **6.6** and **6.10+** (may need small adaption in backport, not blind cherry-pick).
- [ ] Read **TI** docs for **TAA5412** — confirm **I2C address** (`0x51` 7-bit per SSOT), **MCLK**, and whether **coefficient firmware** files are mandatory for your use case.

---

## 4. Phased plan of action

### Phase A — Patch preparation (offline)

1. **Export** a minimal patch series from mainline (or a single squashed patch) adding:
   - `sound/soc/codecs/pcm6240.c`
   - `sound/soc/codecs/pcm6240.h`
   - `sound/soc/codecs/Kconfig` + `Makefile` hunks for **`SND_SOC_PCM6240`**
   - `Documentation/devicetree/bindings/sound/ti,pcm6240.yaml` (optional for kernel build; useful for DT checks)
2. **Apply** onto **linux-fslc @ factory SRCREV** in a **local git** tree; resolve conflicts **only** in new files first if possible.
3. **If** ASoC APIs differ: add small **adapt** patches (document each hunk — “for 6.6.52 imx”).

### Phase B — Yocto integration (BSP layer)

1. Add patches under **`recipes-kernel/linux/linux-lmp-fslc-imx/`** (same pattern as existing `0008-*.patch` style).
2. Extend **`linux-lmp-fslc-imx_%.bbappend`**:
   - **`SRC_URI:append:imx8mm-jaguar-dt510`** (or machine-agnostic if appropriate) with patch files **in order**.
   - Add **`imx8mm-jaguar-dt510/pcm6240-audio-codec.cfg`** with **`CONFIG_SND_SOC_PCM6240=m`** (and any required `CONFIG_*` depends — mirror mainline `Kconfig` “depends on”).
3. **Optional:** gate with **`MACHINE_FEATURES`** (e.g. **`taa5412`**) like **`tas6424`**, so factory images can omit the module until ready.

### Phase C — Build validation (no hardware enable yet)

1. **`bitbake virtual/kernel`** (or CI) — must **complete** with **no** new `QA` warnings you care about.
2. Inspect **`/proc/config.gz`** (or deployed `config`) for **`CONFIG_SND_SOC_PCM6240=m`**.
3. **Install** image on **DT510** — **boot smoke**: existing **TAS2563**, **Wi‑Fi**, **USB**, **OTA** unchanged.
4. **`modprobe snd_soc_pcm6240`** — should **fail gracefully** if no device (expected) or **not load** if DT missing — **no kernel panic**.

### Phase D — Device tree (disabled node first)

1. Add **`&i2c2`** child **`taa5412@51`** (or name per binding) with **`compatible = "ti,taa5412"`**, **`reg = <0x51>`**, **`status = "disabled"`**.
2. Add **`&sai5`** + **`pinctrl_sai5_*`** from **SSOT** / `docs/reference/dt510-ollie-tool-generated/pin_mux.dts` — **do not** hog pins that clash with **Ethernet / HDMI / other** tiers.
3. **Do not** add a full **`sound-card`** until Phase E — or add **card** with codec **disabled** to avoid premature DAI probe (team preference).

### Phase E — Enable + audio path

1. **Supplies / GPIO** (from SSOT): `AVDD`, `DVDD`, reset, etc. — match driver binding.
2. **`status = "okay"`** on codec + **`simple-audio-card`** (or fsl-asoc) **CPU `&sai5` ↔ codec**.
3. **Firmware:** if driver requests **`.bin`** files, add **`linux-firmware`** bbappend or recipe install — **verify paths** in `dmesg`.
4. **Userland:** `aplay -l`, capture/playback test at **safe** levels.

### Phase F — Regression & sign-off

- [ ] Re-run **DT510 smoke** (team script or agreed checklist).
- [ ] **OTA** one cycle with new image (if applicable).
- [ ] Update [**`DT510-HARDWARE-AUDIT-CHECKLIST.md`**](DT510-HARDWARE-AUDIT-CHECKLIST.md) and **issue #2** with **PASS** / **PARTIAL** + build id.

---

## 5. Rollback / failure criteria

**Stop and revert** if any of:

- `virtual/kernel` fails to build or **defconfig** merge breaks **unrelated** `CONFIG_*`.
- Boot **regression** (hang, USB, Wi‑Fi, existing **tas2563** card missing).
- **`dmesg`** shows **repeated I2C errors** or **probe -EPROBE_DEFER** loops affecting **other** `i2c-2` devices.

**Rollback:** revert BSP commit(s); re-flash **previous** known-good image; keep **subscriber-overrides** manifest pointer to last good build.

---

## 6. Firmware / coefficient blobs

The mainline driver uses **`request_firmware()`** for register/coefficient binaries in some flows. Before declaring “done”:

- Confirm **which** `.bin` files (if any) **TAA5412** needs on your board.
- Package under **`/lib/firmware`** (or vendor path) and verify **file names** match driver expectations.

---

## 7. Ownership

| Who | Responsibility |
|-----|----------------|
| **BSP** | Patch series, bbappend, cfg fragment, **`MACHINE_FEATURES`** gating, DT **disabled** → **okay** sequence |
| **Hardware** | SSOT pins, rails, **I2C** address, **MCLK**, speaker/mic safety for tests |
| **Lab** | Phases C–E validation on **prototype** hardware; issue **#2** results |

---

## 8. Executable sequence (operator checklist)

Use this after **§3 Preconditions** are satisfied. Order is intentional: **build driver before** turning on DT.

### Step 0 — Pin the exact kernel you patch

From the **same** build environment as Foundries / local LmP:

```bash
bitbake -e virtual/kernel | grep -E '^(SRCREV|PV|LINUX_VERSION|KERNEL_BRANCH)='
```

Record **`SRCREV`** (40-char) in the PR and in **`DT510-HARDWARE-AUDIT-CHECKLIST.md`** when you merge.

#### Step 0 — recorded snapshot (vixdt `lmp-base.xml` pin, 2026-05-06)

Resolved from **`foundriesio/meta-lmp`** commit **`4dffdff79b4df49c683c9a7faea406595cb7e9ca`** (the **`meta-lmp`** revision in **`lmp-manifest/lmp-base.xml`** at this date), file **`meta-lmp-bsp/recipes-kernel/linux/linux-lmp-fslc-imx_6.6.bb`**:

| Variable | Value |
|----------|--------|
| **`LINUX_VERSION`** | **`6.6.52`** |
| **`KERNEL_BRANCH`** | **`6.6-2.2.x-imx`** |
| **`SRCREV_machine`** | **`e0f9e2afd4cff3f02d71891244b4aa5899dfc786`** |
| **Kernel git** | **`https://github.com/Freescale/linux-fslc.git`** (see **`linux-lmp-fslc-imx.inc`**) |

**Clone for patch work:**

```bash
git clone --branch 6.6-2.2.x-imx https://github.com/Freescale/linux-fslc.git
cd linux-fslc && git checkout e0f9e2afd4cff3f02d71891244b4aa5899dfc786
```

**Caveat:** If your factory **`lmp-manifest`** moves **`meta-lmp`** to a newer commit, **re-run `bitbake -e virtual/kernel`** (or re-read **`linux-lmp-fslc-imx_6.6.bb`** on that revision) — **`SRCREV_machine`** can change between LmP releases.

### Step 1 — Mainline commit selection (do not cherry-pick blind)

1. Clone **`torvalds/linux`** (or use **GitHub** file history on `sound/soc/codecs/pcm6240.c`).
2. Find the **first** mainline release tag where **`ti,taa5412`** appears in **`pcm6240.c`** / **`Kconfig`** (expect **≥ v6.10** per earlier BSP audit).
3. From that commit **forward** to current **stable** (e.g. **v6.12.y**), list commits touching only:

   - `sound/soc/codecs/pcm6240.c`
   - `sound/soc/codecs/pcm6240.h`
   - `sound/soc/codecs/Kconfig`
   - `sound/soc/codecs/Makefile`
   - `Documentation/devicetree/bindings/sound/ti,pcm6240.yaml` (optional for build; helps `dtbs_check`)

4. For each cherry-pick onto **`linux-fslc @ SRCREV`**, expect **ASoC / regmap / module** API drift — keep **one small “imx-6.6-compat” patch** per break (same pattern as **`08-tac5x1x-linux-6.6-fslc-compat.patch`** for TAC5x1x).

**Pragmatic alternative** if cherry-picks explode: **copy** mainline **`pcm6240.c` / `.h`** at a known-good **6.12** snapshot into a **single** `0001-asoc-pcm6240-import-from-mainline-v6.12.patch`, then **one** compat patch — trade history clarity for fewer conflict rounds (document snapshot SHA in commit message).

#### Step 1 — recorded (vixdt workspace, 2026-05-06)

| Item | Result |
|------|--------|
| **Mainline baseline** | **`torvalds/linux` tag `v6.10`** — `sound/soc/codecs/pcm6240.c` (~2217 lines), `pcm6240.h` (~252 lines); **`{ .compatible = "ti,taa5412" }`** and I²C id **`taa5412`** present. |
| **`SND_SOC_PCM6240` in mainline `Kconfig`** | **`depends on I2C`** only (same block position as between **`SND_SOC_PCM512x_SPI`** and **`SND_SOC_PEB2466`**). |
| **linux-fslc @ `e0f9e2a…`** | **No** `pcm6240.c` / **no** `SND_SOC_PCM6240` — import required. |
| **Local compile smoke** | On extracted **6.6.52** tree at **`e0f9e2a…`**, after adding v6.10 sources + `Makefile` / `Kconfig` hunks: **`CC [M] sound/soc/codecs/pcm6240.o`** succeeds (**`aarch64-linux-gnu-gcc`**). Full **`M=sound/soc/codecs`** **`modpost`** expected to fail without a complete kernel **`Module.symvers`** — use **`bitbake virtual/kernel`** or a full **`modules`** build for link validation. |
| **BSP integration** | Patch **`imx8mm-jaguar-dt510/pcm6240-lmp/0001-asoc-pcm6240-import-from-mainline-v6.10.patch`** + **`pcm6240-audio-codec.cfg`**; **`SRC_URI`** gated on **`MACHINE_FEATURES`** **`taa5412`** (off by default — append in machine conf to turn on). |

### Step 2 — Local kernel tree workflow

```bash
git clone <linux-fslc-url> linux-fslc-work && cd linux-fslc-work
git checkout <SRCREV>
# create branch: taa5412-pcm6240-backport
# apply patches / cherry-picks; build with same defconfig merge as Yocto or:
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- olddefconfig
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=sound/soc/codecs modules
```

Fix compile errors **before** touching Yocto.

### Step 3 — Yocto BSP integration

1. Add ordered **`file://....patch`** files under **`recipes-kernel/linux/linux-lmp-fslc-imx/`** (or **`imx8mm-jaguar-dt510/`** subdir if you prefer).
2. **`linux-lmp-fslc-imx_%.bbappend`**: append **`SRC_URI`** for **`imx8mm-jaguar-dt510`** only (or gate with **`MACHINE_FEATURES`** **`taa5412`** — recommended until sign-off).
3. New cfg fragment **`imx8mm-jaguar-dt510/pcm6240-audio-codec.cfg`**:

   - `CONFIG_SND_SOC_PCM6240=m`
   - Mirror **mainline `Kconfig` “depends on”** lines exactly (regmap, I2C, ASoC core).

4. **`bitbake virtual/kernel`** → fix **defconfig** merge / **`CONFIG`** warnings.

### Step 4 — DT (still behind a feature flag)

1. **`taa5412@51`** on **`&i2c2`**, **`compatible = "ti,taa5412"`**, **`status = "disabled"`** initially.
2. **`&sai5`** + **`pinctrl_sai5_*`** from **`docs/reference/dt510-ollie-tool-generated/pin_mux.dts`**; add **GPIO4_IO18** only when binding documents the property name TI expects.
3. **`sound-*`** card **CPU `&sai5` ↔ `taa5412`** — enable only in the same PR/commit that flips **`status = "okay"`** after **`modprobe`** succeeds on lab hardware.

### Step 5 — Bench proof (issue #2)

| Gate | Pass criterion |
|------|----------------|
| Boot | No regression vs previous image; **`tas2563` / `tas6424` / `tac5301`** cards still appear if enabled |
| Module | **`modinfo snd_soc_pcm6240`** present; **`modprobe snd_soc_pcm6240`** no oops |
| Probe | **`dmesg`** shows **TAA5412** / **pcm6240** probe **0** with DT enabled |
| ALSA | **`arecord -l`** shows a capture PCM for the new card |
| Firmware | No stuck **`request_firmware`** in **`dmesg`**; ship blobs under **`/lib/firmware`** if required |

---

## 9. Risk summary (for planning / PM)

| Risk | Mitigation |
|------|------------|
| Large merge into **`sound/soc/codecs/Makefile`** | Minimal diff; conflict-check against NXP **`linux-fslc`** delta before PR |
| **`i2c-1`** bus contention | Bring codec **disabled** first; device already **ACKs at `0x51`** on bench — no mystery I²C |
| Firmware required for filters | Phase **§6** before “done”; package in **`linux-firmware`** or vendor recipe |
| OTA / factory risk | **`MACHINE_FEATURES`** gate **`taa5412`** until sign-off; manifest pin per usual |

---

*Last updated: 2026-05-06 — §2.1 BSP ASoC patch interactions; Step 1 baseline + compile smoke; Yocto patch/cfg + `taa5412` gate (DT Phase D).*
