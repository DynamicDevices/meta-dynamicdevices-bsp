# Vix DT510 — progress report

**For:** Vix programme / project management  
**From:** Dynamic Devices  
**Product:** DT510 (in-vehicle Linux platform)  
**Status date:** May 2026  
**Hardware reference:** Vix DT510 pinout specification (Ollie Hull)

---

## At a glance

| | |
|---|---|
| **Overall** | **On track** — core platform is running in the lab; major interfaces are proven or in active close-out. |
| **Factory software** | Reproducible builds via Foundries; over-the-air updates and remote access working on bench units. |
| **Risk posture** | We are validating hardware early on real boards, documenting factory steps, and fixing issues in software before prototype volume — not waiting for “everything at once.” |

---

## What this means for delivery

Dynamic Devices is bringing the **DT510 board up against Vix’s hardware definition** so Vix can ship on a **known-good Linux image**, not ad-hoc bench hacks.

**Already de-risked:**

- **Platform foundation** — Boards boot, update, and are debuggable in the lab (April 2026).
- **Connectivity** — Wi‑Fi and Bluetooth proven; cellular modem and SIM recognised (data session still to close).
- **Location** — GNSS receives a valid fix with antenna (May 2026).
- **Vehicle I/O** — Digital inputs/outputs exercised on hardware (May 2026).
- **Field buses** — CAN interface up in software; RS‑485 ports working with correct timing for the transceiver, including a **documented one-time factory programming step** per unit (May 2026).
- **Audio (major paths)** — Cabin loop and public-address (Tannoy) paths validated on bench; driver microphone path in progress.
- **Power / radio bring-up** — PMIC, Wi‑Fi, and Ethernet switch reported working together on lab image (early May 2026).

**Still to close for production confidence:**

- Final sign-off on **prototype** boards when Vix hardware matches released BOM.
- **Driver microphone** — end-to-end capture on factory images.
- **Zigbee** — firmware on the image and real over-the-air test (software stack starts; product proof pending).
- **Ethernet** — basic connectivity proven; advanced switch features only if the product needs them.
- **HDMI display** — not started (held until display path is confirmed on BOM).
- **Battery charging** — hardware described in software; full driver integration with factory kernel release.
- **Cellular** — move from “modem seen” to reliable data connectivity.

We are **not** blocked on a single unknown; remaining work is **scoped, ordered, and already partially implemented** in the factory pipeline.

---

## Progress by capability

Plain-language status on **current lab DT510 units** (interim boards; full re-test planned on prototype hardware).

| Capability | Status | Notes for PM |
|------------|--------|----------------|
| Boot, updates, remote support | **Done** | Factory image pipeline in use. |
| Board-specific software baseline | **Done** | DT510-only configuration; wrong inherited design blocks removed. |
| Wi‑Fi / Bluetooth | **Proven in lab** | Devices discoverable; suitable for app bring-up. |
| GNSS | **Proven in lab** | Fix with antenna; stable device name for applications. |
| Digital I/O | **Proven in lab** | Inputs and outputs confirmed with hardware team. |
| RS‑232 / RS‑485 serial | **Proven in lab** | All four USB-serial channels characterised; RS‑485 factory step written down. |
| CAN bus | **Software proven** | Interface up; full vehicle bus test with partner ECU still to schedule. |
| Cabin audio loop | **Proven in lab** | Playback/capture path for loop audio. |
| Tannoy / PA audio | **Proven in lab** | Amplifier path validated for announcement use case. |
| Driver microphone | **In progress** | Chip talks on the bus; stable “record from mic” on production image is next gate. |
| Driver speaker | **In software** | Less bench narrative than Tannoy; acoustic sign-off TBD. |
| Cellular LTE | **Partial** | Modem and SIM OK; mobile data path TBD. |
| Ethernet | **Partial** | Link-level bring-up reported; product-specific switch features phased. |
| Zigbee | **Partial** | Stack starts; product firmware and air test remain. |
| HDMI | **Not started** | Waiting on product/display decision. |
| Battery charger | **Partial** | Described for hardware; driver completion tied to kernel release. |
| Companion PMU MCU | **In progress** | Update workflow being aligned with factory process. |

---

## How we are de-risking delivery (process)

1. **Single hardware truth** — Software tracked against Vix’s pinout document; gaps logged in a living checklist, not email.
2. **Lab before volume** — Each capability is bench-tested on real DT510 boards as soon as software lands; failures are fixed before the next factory build.
3. **Repeatable factory builds** — Every test references a **pinned factory image** so Vix and Dynamic Devices see the same behaviour.
4. **Manufacturing hooks early** — Example: RS‑485 needs a **one-time programming step** on the production line; procedure and check script exist before line trial.
5. **Phased complexity** — Ethernet and audio are brought up in **simple-first** order (link and main use cases before optional features).
6. **Transparent backlog** — Open items are prioritised (product-blocking vs nice-to-have); engineering detail is maintained separately for the technical team.

---

## Timeline (milestones)

| When | What Vix can rely on |
|------|---------------------|
| **Apr 2026** | Programme plan and hardware checklist in place; DT510 boots and updates on factory images; platform baseline complete. |
| **Early May 2026** | Power, Wi‑Fi, Bluetooth, and basic Ethernet switch path on bench; GNSS fix; Zigbee stack starts. |
| **Mid May 2026** | Tannoy audio, CAN, cabin loop audio, cellular SIM recognition; driver mic work advanced in software. |
| **8 May 2026** | Digital I/O signed off with hardware. |
| **16 May 2026** | RS‑485 ports signed off (including factory programming instruction). |
| **Next** | Prototype-board pass; close driver mic, Zigbee air test, cellular data; factory image with latest line tools. |

---

## Recommended focus for the programme

| Priority | Action | Why it matters |
|----------|--------|----------------|
| 1 | Confirm **prototype board** availability and BOM freeze date | Unlocks final electrical sign-off. |
| 2 | Agree **must-have vs phase-2** for HDMI, advanced Ethernet, Auracast | Avoids scope creep on the critical path. |
| 3 | Schedule **driver mic** and **Zigbee** acceptance tests when next factory image is flashed | Closes two partial items with clear pass/fail. |
| 4 | Plan **RS‑485 factory step** on pilot build | Already documented; low effort, high impact if RS‑485 is in MVP. |

---

## Contacts

| Role | Name |
|------|------|
| Hardware (Vix DT510) | Ollie Hull |
| Software / platform | Alex Lennon |
| Programme / factory | *as assigned by Vix and Dynamic Devices* |

---

*Engineering detail (schematics, drivers, test commands): see `DT510-BSP-PROJECT-PLAN.md` and `DT510-HARDWARE-AUDIT-CHECKLIST.md` in the same repository — not required for programme review.*
