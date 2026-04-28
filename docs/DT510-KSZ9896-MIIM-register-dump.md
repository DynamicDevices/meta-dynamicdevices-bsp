# DT510 — KSZ9896 MIIM Clause 22 register dump (review)

**Purpose:** Snapshot of **standard MIIM registers (0–31)** on FEC MDIO bus **`30be0000.ethernet-1`** for PHY addresses **@0–@5**, for hardware/software review (e.g. with EE).

**Device:** `imx8mm-jaguar-dt510` — captured remotely via SSH (`mdio` from **mdio-tools**).

**Datasheet:** Microchip **KSZ9896C** DS00002390C — **§4.9.3 MIIM**, **Table 4‑27** (standard MIIM register map to internal **Port N** PHY space).

---

## How this was captured

```bash
BUS=30be0000.ethernet-1
sudo mdio "$BUS"                                    # probe
for p in 0 1 2 3 4 5; do
  for r in $(seq 0 31); do
    sudo mdio "$BUS" phy $p raw $r
  done
done
```

Register numbers **0–31** are **decimal** in the `mdio` CLI (= **0h–1Fh** in Table 4‑27). Values are **16‑bit hex** as printed by `mdio`.

**Not included here:** Clause **45** `mmd PRTAD:DEVAD raw …` (requires addresses from **§5.4**); switch global / **Port 6 RGMII** CSRs (**§5.2.3**, e.g. **0x6300** range) — those are **outside** Clause 22 `phy raw 0–31`.

---

## MDIO probe (same capture session)

| DEV   | PHY-ID     | LINK |
|-------|------------|------|
| 0x00  | 0x004540fe | down |
| 0x01  | 0x00221631 | up   |
| 0x02  | 0x00221631 | up   |
| 0x03  | 0x00221631 | down |
| 0x04  | 0x00221631 | down |
| 0x05  | 0x00221631 | down |

---

## PHY @0 — Clause 22 regs 0–31

*PHY-ID **0x004540fe** — not **0x00221631**; treat as internal / CPU-path MIIM object per datasheet; Table 4‑27 decodes may not align with copper ports.*

| Reg | hex | Value |
|-----|-----|-------|
| 0 | 0x00 | 0x9200 |
| 1 | 0x01 | 0x0202 |
| 2 | 0x02 | 0x0045 |
| 3 | 0x03 | 0x40fe |
| 4 | 0x04 | 0x0000 |
| 5 | 0x05 | 0x0000 |
| 6 | 0x06 | 0x0062 |
| 7 | 0x07 | 0x3000 |
| 8–21 | 0x08–0x15 | 0x0000 |
| 22 | 0x16 | 0x0318 |
| 23–31 | 0x17–0x1f | 0x0000 |

---

## PHY @1 — Clause 22 regs 0–31 (LINK **up**)

| Reg | hex | Value |
|-----|-----|-------|
| 0 | 0x00 | 0x1140 |
| 1 | 0x01 | 0x796d |
| 2 | 0x02 | 0x0022 |
| 3 | 0x03 | 0x1631 |
| 4 | 0x04 | 0x0de1 |
| 5 | 0x05 | 0xcde1 |
| 6 | 0x06 | 0x000f |
| 7 | 0x07 | 0x2001 |
| 8 | 0x08 | 0x6801 |
| 9 | 0x09 | 0x0700 |
| 10 | 0x0a | 0x7800 |
| 11 | 0x0b | 0x0000 |
| 12 | 0x0c | 0x0000 |
| 13 | 0x0d | 0x4007 |
| 14 | 0x0e | 0x0006 |
| 15 | 0x0f | 0x3000 |
| 16 | 0x10 | 0x0000 |
| 17 | 0x11 | 0x00f4 |
| 18 | 0x12 | 0x0000 |
| 19 | 0x13 | 0x0406 |
| 20 | 0x14 | 0x5cfe |
| 21 | 0x15 | 0x0000 |
| 22 | 0x16 | 0x0000 |
| 23 | 0x17 | 0x0200 |
| 24–27 | 0x18–0x1b | 0x0000 |
| 28 | 0x1c | 0x2400 |
| 29–30 | 0x1d–0x1e | 0x0000 |
| 31 | 0x1f | 0x014c |

---

## PHY @2 — Clause 22 regs 0–31 (LINK **up**)

Same as **@1** except:

| Reg | Value @1 | Value @2 |
|-----|----------|----------|
| 5 | 0xcde1 | **0xc1e1** |
| 8 | 0x6801 | **0x6001** |

All other registers **0–31** matched **@1** at capture time.

---

## PHY @3 — Clause 22 regs 0–31 (LINK **down**)

| Reg | hex | Value |
|-----|-----|-------|
| 0 | 0x00 | 0x1140 |
| 1 | 0x01 | 0x7949 |
| 2 | 0x02 | 0x0022 |
| 3 | 0x03 | 0x1631 |
| 4 | 0x04 | 0x0de1 |
| 5 | 0x05 | 0x0000 |
| 6 | 0x06 | 0x0004 |
| 7 | 0x07 | 0x2001 |
| 8 | 0x08 | 0x0000 |
| 9 | 0x09 | 0x0700 |
| 10 | 0x0a | 0x0000 |
| 11 | 0x0b | 0x0000 |
| 12 | 0x0c | 0x0000 |
| 13 | 0x0d | 0x4007 |
| 14 | 0x0e | 0x0006 |
| 15 | 0x0f | 0x3000 |
| 16 | 0x10 | 0x0000 |
| 17 | 0x11 | 0x00f4 |
| 18 | 0x12 | 0x0000 |
| 19–22 | 0x13–0x16 | 0x0000 |
| 23 | 0x17 | 0x0200 |
| 24–27 | 0x18–0x1b | 0x0000 |
| 28 | 0x1c | 0x2400 |
| 29–30 | 0x1d–0x1e | 0x0000 |
| 31 | 0x1f | 0x0100 |

---

## PHY @4 — Clause 22 regs 0–31 (LINK **down**)

Notable: **BMCR (reg 0) = 0x1100** vs **0x1140** on other ports; **reg 4** auto-neg advertisement differs.

| Reg | hex | Value |
|-----|-----|-------|
| 0 | 0x00 | **0x1100** |
| 1 | 0x01 | 0x7949 |
| 2 | 0x02 | 0x0022 |
| 3 | 0x03 | 0x1631 |
| 4 | 0x04 | **0x0c01** |
| 5 | 0x05 | 0x0000 |
| 6 | 0x06 | 0x0004 |
| 7 | 0x07 | 0x2001 |
| 8 | 0x08 | 0x0000 |
| 9 | 0x09 | **0x0400** |
| 10–22 | 0x0a–0x16 | mostly 0; **reg 20 = 0x1000** |
| 23 | 0x17 | 0x0200 |
| 28 | 0x1c | 0x2400 |
| 31 | 0x1f | 0x0100 |

---

## PHY @5 — Clause 22 regs 0–31 (LINK **down**)

| Reg | hex | Value |
|-----|-----|-------|
| 0 | 0x00 | **0x1140** |
| 1 | 0x01 | 0x7949 |
| 2 | 0x02 | 0x0022 |
| 3 | 0x03 | 0x1631 |
| 4 | 0x04 | **0x0de1** |
| 5 | 0x05 | 0x0000 |
| 6 | 0x06 | 0x0004 |
| 7 | 0x07 | 0x2001 |
| 8 | 0x08 | 0x0000 |
| 9 | 0x09 | **0x0700** |
| 10–22 | 0x0a–0x16 | similar to @3/@4; **reg 20 = 0x1000** |
| 23 | 0x17 | 0x0200 |
| 28 | 0x1c | 0x2400 |
| 31 | 0x1f | 0x0100 |

---

## Cross-reference — Table 4‑27 (MIIM → meaning)

| MIIM (hex) | Typical name (DS Table 4‑27) |
|------------|------------------------------|
| 0h–Fh | IEEE: BMCR, BMSR, PHY ID, AN, 1000BASE-T control/status, MMD setup/data, extended status |
| 11h | Vendor: PHY remote loopback |
| 12h | Vendor: PHY LinkMD |
| 13h | Vendor: digital PMA/PCS status |
| 15h | Vendor: port RXER count |
| 1Bh | Vendor: port interrupt ctrl/status |
| 1Ch | Vendor: PHY Auto MDI/MDI-X |
| 1Fh | Vendor: PHY control |

Bit-level interpretation requires **DS00002390C** register field tables.

---

## Comprehensive analysis (IEEE + KSZ context)

This section walks **Clause 22** registers **0–31** using **IEEE Std 802.3™** Clause **22** naming for regs **0–15**, plus **Table 4‑27** vendor naming for **16–31**. Exact bit meanings for **vendor** registers **11h–1Fh** are defined only in **Microchip DS00002390C** (± chip revision); use this as a **bring-up guide**, not a substitute for the datasheet **register diagrams**.

### Legend — IEEE registers **0h–Fh**

| Reg (hex) | Name | Role |
|-----------|------|------|
| **0** | **BMCR** | PHY control: reset, loopback, power-down, isolate, **autoneg enable**, duplex/speed selection (exact interpretation depends on PHY type and vendor extensions). |
| **1** | **BMSR** | PHY status: **link**, capabilities, **remote fault**, **autoneg complete**, extended-status capability. |
| **2–3** | **PHY ID** | **PHY Identifier** — combined **`0xWWXX`** / **`0xYYZZ`** form **`OUI + model + revision`** (IEEE registration). |
| **4** | **AN advertisement** | Capabilities this PHY **advertises** during **autonegotiation** (selector + technology ability fields). |
| **5** | **AN LP ability** | Last received **link-partner** advertisement (**zeros** ⇒ no partner seen / no AN exchange). |
| **6** | **AN expansion** | Parallel detection fault flags, **next-page** ability, etc. |
| **7–8** | **AN next page** | Next-page TX/RX (often idle unless multi-gig next pages used). |
| **9** | **1000BASE-T control** | **1000BASE-T** master/slave manual cfg, test modes (IEEE Table **40–** family — confirm bits in **802.3** Clause **40**). |
| **10** | **1000BASE-T status** | Resolution of master/slave, idle/error indications after gigabit AN. |
| **13–14** | **MMD indirect** | Load address (**13**) / read-write data (**14**) for **MMD** access paths (**§5.4** / PHY-specific sequencing). |
| **15** | **Extended status** | Presence/capability bits for **1000BASE-T** half/full (among others). |

### BMCR (**reg 0**) — values observed

| PHYAD | Value | Analysis |
|-------|-------|----------|
| **@1–@3, @5** | **0x1140** | Typical **gigabit PHY with autoneg enabled**: commonly decoded by tools as **1000BASE-T full-duplex intent** with **AN enabled**. Not reset/isolate/power-down in the usual sense (**bits 15/10/11** patterns differ when those are active). |
| **@4** | **0x1100** | **Differs from 0x1140 by PHY-specific speed/select bits** (often **bit 6** / selector combinations). `mdio`’s text decoder previously showed **10 Mbps-class** interpretation for this BMCR pattern — treat as **“this port’s advertised/control path differs”**, not necessarily physical **10 M** on wire until correlated with **regs 4–5–9–10** and **link partner**. **Compare after stable cable** on that jack; resolve against **Table 4‑27** PHY-control chapter. |
| **@0** | **0x9200** | **Not** the same **`0x00221631`** core as copper PHYs. High byte **`0x92`** suggests **different reset/control semantics** (possibly **reset-related bit**, vendor staging). **Do not** apply copper PHY BMCR decoding blindly — correlate with **§4.11 / Port 6** if this STA truly maps CPU-side path. |

### BMSR (**reg 1**) — **0x796d** (linked) vs **0x7949** (no link)

| Pattern | Typical meaning |
|---------|-----------------|
| **0x796d** (**@1**, **@2**) | Probe **LINK up**. In Clause **22**, commonly indicates **extended capabilities**, **autoneg capable**, **link OK**, **autoneg complete**, **remote fault clear**, **extended status register present** — consistent with **healthy negotiated copper**. |
| **0x7949** (**@3–@5**) | Probe **LINK down**. Same family as above but **without** completed link/autoneg snapshot typical of **idle/disconnected** RJ45 ( **`reg 5` all-zero** reinforces **no partner**). |

**Practice:** always correlate **`mdio` probe LINK column** with **`reg 1`** + **`reg 5`** + **`reg 6`** (expansion).

### PHY identifier (**regs 2–3**)

| PHYAD | regs **2+3** | Analysis |
|-------|--------------|----------|
| **@1–@5** | **0x0022** / **0x1631** → combined **`0x00221631`** | Matches **Microchip / legacy Kendin** PHY identity commonly seen on KSZ integrated PHYs; confirms **same PHY silicon family** across ports **1–5**. |
| **@0** | **0x0045** / **0x40fe** → combined **`0x004540fe`** | **Different** identity — corresponds to **different MDIO-visible block** (often internal **switch CPU / non-RJ45** face per KSZ docs). |

### Autonegotiation (**regs 4–6**) — copper ports

| PHYAD | Reg **4** | Reg **5** | Reg **6** | Analysis |
|-------|-----------|-----------|-----------|----------|
| **@1** | **0x0de1** | **0xcde1** | **0x000f** | **Non-zero partner (`reg 5`)** ⇒ **AN exchange occurred** with link partner; **`reg 6`** expansion shows **next-page capable** paths per IEEE when bits assert — cable/link partner is **real**. |
| **@2** | **0x0de1** | **0xc1e1** | **0x000f** | Same **advertisement** as **@1**; **partner code differs** only in **technology ability bitfield** (`cde1` vs `c1e1`) — normal **partner-dependent** variation (different NIC switch advertisement). |
| **@3–@5** | **0x0de1** or **0x0c01** | **0x0000** | **0x0004** typical | **`reg 5 = 0`** ⇒ **no link partner** reached stable AN — matches **no cable / no far-end PHY**. |
| **@4** | **0x0c01** | **0x0000** | **0x0004** | **Advertisement differs** from **`0x0de1`** pattern — combined with **BMCR 0x1100** ⇒ flag **@4** as **“different programmed advertise path”** vs **@1** until datasheet bits confirmed. |

### 1000BASE-T (**regs 9–10**) — highlights

| PHYAD | Reg **9** | Reg **10** | Analysis |
|-------|-----------|------------|----------|
| **@1**, **@2** | **0x0700** | **0x7800** | Typical **gigabit control/status** pattern when **1000BASE-T** negotiation path active — **`reg 10` non-zero** supports **gig resolution / idle** indicators per Clause **40**. |
| **@3**, **@5** | **0x0700** | **0x0000** | Control word present; **status idle/zero** until partner — consistent **no-link**. |
| **@4** | **0x0400** | **0x0000** | **Differs** from **@1/@2** — aligns with **BMCR/advertisement anomaly** on **@4**; verify **single cable** / **port remap** / **strap**. |

### Extended status (**reg 15**) — **ESTATUS**

All copper PHYs show **`0x3000`** here in this dump — consistent with **extended status pages present** and **1000BASE-T** capability bits (**interpret via IEEE ESTATUS bit definitions**).

### MMD indirect (**regs 13–14**)

Values **`0x4007`** / **`0x0006`** (when seen) reflect **MMD addressing machinery**, not user intent by themselves — **only meaningful after** a defined **write `reg 13` → access `reg 14`** sequence per **PHY/MMD** programming guide.

### Vendor registers (**16–31** / **10h–1Fh**) — Table 4‑27 names

**Index convention:** `mdio phy N raw R` uses **decimal** `R`; **Table 4‑27** uses **hex** MIIM addresses (**11h** = decimal **17**, **1Bh** = decimal **27**, etc.). Several registers read **0** in this capture (**10h**, **16h**, **18h–1Ah**, **1Bh**, **1Dh–1Eh** on **@1**); the table below focuses on **non-zero** or **review-critical** values.

**Do not confuse** IEEE **Clause 22** registers **13–14** (decimal), which implement **MMD indirect** (`0x4007` / `0x0006` in this dump), with **Microchip** MIIM address **13h**, which is **decimal register 19** (**PMA/PCS status**, `0x0406` below).

| MIIM (hex) | Dec. | Value @1 (typ.) | Purpose (DS Table 4‑27 title / note) |
|------------|------|-----------------|--------------------------------------|
| **11h** | 17 | **0x00f4** | PHY **remote loopback** — confirm **normal forwarding** vs test modes (**DS** bitfields). |
| **12h** | 18 | **0x0000** | PHY **LinkMD** — idle unless **cable diagnostic** is running. |
| **13h** | 19 | **0x0406** | Digital **PMA/PCS** status — **sync / lock / fault** class per **Microchip** (**DS**). |
| **14h** | 20 | **0x5cfe** | Vendor extension block — **decode only from DS** (not IEEE). |
| **15h** | 21 | **0x0000** | **Port RXER** / error-count class — **zero** at snapshot (confirm under **traffic**). |
| **17h** | 23 | **0x0200** | Vendor-specific control/status — **not** the same address as **1Bh**; map to **DS** fields for this **MIIM** offset. |
| **1Bh** | 27 | **0x0000** | Port **interrupt** ctrl/status (**Table 4‑27**) — **all-zero** here ⇒ **no sticky IRQ bits** set at capture (if this is the correct port map). |
| **1Ch** | 28 | **0x2400** | PHY **Auto MDI/MDI‑X** — **crossover** handling on copper. |
| **1Fh** | 31 | **0x014c** (linked) / **0x0100** (idle) | PHY **control** — differs **link vs no-link** (expected). |

Ports **@3–@5** zero many vendor-status registers — consistent with **no-link** power/state machines.

### PHY **@0** (special STA)

Treat **`@0`** as **management exposure** that is **not** the copper **`0x00221631`** PHY core:

- **PHY-ID** does not match **@1–@5**.
- **BMCR/BMSR** patterns (**0x9200** / **0x0202**) do **not** present like a stable idle copper PHY.
- **Use case:** correlate **`@0`** with **§4.11 MAC Interface (Port 6)** / **CPU port** chapters — **not** for RJ45 bring-up.

### What this dump **cannot** settle (RGMII / CPU port)

These **Clause 22** blocks describe **embedded PHY / PHY-management** objects at **MDIO STAs**. They **do not** replace:

- **Port 6 RGMII MAC** register file (**§5.2.3**, **`0x6300`–`0x63FF`** range in memory map),
- **Actual LVTTL/TMDS pad behavior**, **clock skew**, or **PCB** issues on **RGMII TX**.

If the symptom is **“frames exit Linux `end0` but fail on wire toward laptop,”** combine this PHY analysis with **`ethtool -S end0`**, **scope**, and **Port 6** CSR access per strap (**SPI/I2C** may be required for full switch view — **MIIM-only** designs sometimes expose **PHY-side only** through **`fec` MDIO**).

---

## Interpretation notes (high level)

1. **@1 / @2** show **link up** in probe; **reg 1** **0x796d** and non-zero **reg 5** on **@1** are consistent with **autoneg complete + partner**.
2. **@3–@5** **down**: **reg 1** **0x7949**, **reg 5** **0x0000** — no partner / no cable.
3. **@4** stands out (**BMCR 0x1100**, **reg 4** **0x0c01**, **reg 9** **0x0400**) vs typical **0x1140** / **0x0de1** / **0x0700** on linked ports — worth correlating with **strap**, cable, or **forced mode** per datasheet.
4. **PHY @0** is **not** the same core ID as **@1–@5**; do not assume identical bitfields.
5. **RGMII CPU port (Port 6)** configuration is **not fully described** by this Clause 22 dump — see **§5.2.3** Port 6 RGMII control and lab checks if issues are **MAC-to-MAC** rather than **RJ45 PHY**.

---

## Related docs (same BSP repo)

- `docs/DT510-ETHERNET-KSZ9896.md` — topology, `mdio` vs `phytool`, Table 4‑27 usage.
- `docs/GPIO-HOG-ACTIVE-POLARITY.md` — KSZ9896 sideband reset / PME / INTR.

---

## Revision

| Date       | Notes |
|------------|--------|
| 2026-04-28 | Initial dump and tables from live `mdio` session on DT510. |
| 2026-04-28 | Added comprehensive IEEE/KSZ analysis (BMCR/BMSR/AN/1G/vendor) for EE review. |
