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
