---
name: "source-command-build"
description: "Build vixdt images and maintain accelerated splash-to-desktop handover for display-enabled boards."
---

# source-command-build

Use this skill when the user asks to run the migrated source command `build`.
Also use it for display-feature image composition and boot-splash handover work
in this workspace; loading it does not itself request a build.

## Command Template

## Hardware acceleration — Alex, 21 November 2026

Prefer hardware acceleration where the board supports it for display,
compositing and video. Diagnose and repair the accelerated path rather than
silently selecting CPU rendering. A CPU fallback requires Alex's explicit
choice. Verify the actual compositor renderer and, when video is tested, the
actual decoder; installed libraries alone do not prove acceleration is used.
This preference grants no permission to weaken device access, run a compositor
as root, change security policy or expand any existing authority.

For DT510, preserve the accelerated Weston configuration; repair a G2D
device-access failure rather than selecting Pixman without Alex's agreement.

## Display-feature boards: continuous splash into desktop

For boards with the product's interactive display feature, the intended default
is a bootloader splash retained into Linux, then the same artwork as the
hardware-accelerated desktop background, without intervening console, white or
black frames or signal-loss overlays. Reuse the existing product-feature
composition rather than inventing a parallel distro switch. Preserve explicit
headless opt-outs and static/e-ink behaviour; do not enable Weston everywhere.

For implementation, review or regression testing, read
[display splash handover](references/display-splash-handover.md). It records
the DT510 fixes and their limits: firmware framebuffer admission, upstream
clocks, power-domain lifetime, DRM/bridge ownership and physical boot evidence.
Port the invariants, not DT510 addresses or clock values, to another board.
Keep serial diagnostics and existing boot/update/security controls unchanged.
This guidance does not authorise builds, deployments, reboots or publication.

# /build — user-invoked build template, not authority

The following procedure applies only after Alex explicitly requests a build.
Loading or reading this skill is never a build request. An explicit build
request normally authorises **one** batched Foundries / LmP CI run within its
actual scope and existing publication controls.

Follow **`memory-foundries-vixdt-requested-build-workflow.mdc`** and **`memory-foundries-do-not-trigger-ci-unless-asked.mdc`**.
Do **not** promote UAT after this run unless I explicitly ask — **`memory-foundries-uat-manual-promotion-only.mdc`**.

## 1. Pre-build checks (must pass first)

From workspace root **`vixdt`**:

```bash
./scripts/vixdt-pre-push-checks.sh
```

Run against **every repo** that will be included in this build (BSP, subscriber, manifest, containers if touched). **If checks fail:** fix and re-run. **Do not push Foundries.**

Additionally before manifest push:

- **BSP** (and any pinned layers) must already be on **GitHub** at the SHAs you will pin.
- **`lmp-manifest/vixdt.xml`**: all `revision=` values must be **40-char** full SHAs on the correct branches.

## 2. Documentation-only BSP → stop

```bash
./scripts/vixdt-bsp-affects-factory-image.sh --since-manifest-pin
```

If this exits **1** and there are **no** other image-affecting repos to build (subscriber, containers, distro), **do not** push Foundries. Report: docs are on GitHub; factory image unchanged. Proceed only if the user explicitly wants CI anyway or other layers changed.

## 3. Batch into one CI run

1. Inventory pending SHAs (BSP `main`, subscriber, containers submodule, etc.).
2. Push **GitHub** remotes if anything is still local-only.
3. **One** commit updating **`lmp-manifest/vixdt.xml`** with **all** new `revision=` pins (**omit BSP pin** if only docs changed since current pin).
4. **One** push wave to Foundries:
   - Push **manifest** (`main-imx8mm-jaguar-dt510`).
   - Push **subscriber** only if that repo actually changed — **not** a second push only to rerun CI.

Do **not** trigger multiple builds from staggered manifest + subscriber pushes.

## 4. Report

- Repos, branches, SHAs in this build.
- Confirm **one** expected factory run for **`vixdt`** / **DT510**.
- Link or note to check Foundries dashboard (`https://app.foundries.io/factories/vixdt/`).

**Agent memory:** `memory-foundries-vixdt-dev-workflow.mdc` · **BSP docs:** `meta-dynamicdevices-bsp/docs/DT510-BSP-PROJECT-PLAN.md` §3
