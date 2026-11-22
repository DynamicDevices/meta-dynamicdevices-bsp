# Display-feature splash handover

## Intended behaviour

Interactive display boards should show the bootloader's splash, keep it during
Linux startup and transfer to an accelerated desktop with the same artwork.
Suppress the TV console, not serial diagnostics. Reuse existing display/product
feature composition, common artwork packaging and explicit headless opt-out.
Static/e-ink products are not automatically interactive Weston targets.

Use retained firmware scanout where the hardware and drivers support it; adding
PSplash is not a substitute for preserving the running display. If PSplash or a
similar service is already used, prevent it from clearing or taking ownership
prematurely, and release it only after compositor readiness. A service becoming
active is not proof its first frame reached the TV. Match artwork, mode and
placement where pixel-identical presentation is required; continuous signal and
pixel-identical content are different acceptance claims.

## Follow the whole display path

Inspect bootloader video, Linux clock/power providers, LCDIF/scanout, DSIM/DSI,
the external bridge and compositor together. A bridge driver can be correct
while an upstream provider destroys the inherited display before probe.

1. Admit firmware state only after validating the final framebuffer descriptor:
   version/layout, reserved-memory bounds, stride/format, mode, actual scanout
   buffer and the required live hardware state. Keep the framebuffer reserved
   through ownership transfer. Reject invalid state into normal native startup.
2. Commit handover only after validation succeeds. Keep the bootloader's display
   power and clocks across video removal **and device-core removal**. On DT510,
   skipping the video driver's shutdown alone still let device core power it off.
   Use the narrow per-device retained-power flag, not global driver flags. This
   NXP U-Boot has overlapping driver flag bits for LEAVE_PD_ON and
   IGNORE_DEFAULT_CLKS; changing driver flags also changed probe clock policy.
3. Inspect upstream clock-provider defaults as well as the display node. DT510's
   inherited CCM assigned rate changed VIDEO_PLL1 from594MHz to1039.5MHz, taking
   the pixel clock from74.25MHz to129.9375MHz and DSI reference from27MHz to47.25MHz.
   Successful firmware admission now suppresses **only** that PLL's assigned-rate
   cell. Validate provider tuple layout and rate counts before writing; restore
   the original value if final handover commit fails. Do not zero all defaults
   or alter unrelated CPU/audio clocks. Other boards need their own clock proof.
4. Retain the required power domains while valid adoption is pending, including
   deferred probe. DT510's GPC dispmix/mipi and blk LCDIF/DSI callbacks must not
   power down between initial inheritance and native bind. The pending hold
   returns EBUSY to premature power-off; it is not a permanent always-on policy.
5. Preserve EPROBE_DEFER, but reject pending adoption before dropping boot PM
   references on terminal bind/probe failure or removal. Cover failures before
   a reference was acquired too. Native takeover ends pending retention before
   bootstrap PM refs are released, returning control to ordinary runtime PM.
   Cleanup must be idempotent, release temporary reset-clock holds under the
   correct genpd lock, and respect gated clock reparenting/reference ownership.
6. On a valid native takeover, retain LCDIF timings, locked DSIM and LT9611 output
   rather than resetting, disabling or reprogramming the live path. On rejection,
   keep ordinary native initialization and headless behaviour working. Suspend
   bookkeeping must not assume clocks are active after restoration failure.
7. Verify the actual accelerated renderer. DT510 uses G2D; do not hide access or
   startup failures with Pixman or a root compositor. Preserve existing access
   controls; a security-posture change needs separate specific approval.

## Diagnose and verify without blind rebuilds

- Distinguish hardware faults from software retention. Michael proved DT510's
  crystal was not oscillating before fitting a1MΩ feedback resistor; it then
  started on repeated boots. Do not reintroduce old delay/reload experiments to
  compensate for that repaired hardware fault. Other boards need their own
  electrical evidence rather than a copied resistor prescription.
- Capture exact source/build/image identities and the boot ID. Read live final
  DT, upstream clocks, power-off/adoption messages and compositor renderer.
  DT510's `aesl_boot_display=retained` is useful, but not visual proof by itself.
- Test admitted handover, rejection/fallback, defer-to-terminal failure,
  pre-acquisition failure, cleanup idempotence and native takeover. Apply-check
  full patches and test final DT admission. Kernel fixtures must expose relevant
  kernel macros: the identifier `current` caused a real compile failure here.
  Preserve required exact-candidate review and CI before publishing a build.
- Use the installed `ui-camera-testing` skill (host-local guidance, not a
  repository link)
  for fresh passive UART, live decoded-camera preview and a bounded recording
  before a user-ready reboot. Capture long enough for bootloader holds and a
  settled desktop. On DT510 a180sec recording succeeded;90sec was insufficient
  when preparation consumed its early part. Do not reboot on failed capture.
- Inspect actual transition frames, not just a contact sheet or brightness
  threshold. Separate shutdown/pre-splash blackout from U-Boot-to-Linux handover.
  Camera occlusion/exposure and TV overlays can resemble display faults.
  Report physical camera cadence separately from window-recorder fps; Cap26fps
  did not improve a5fps Cheese camera feed. Alex accepted that cadence for the
  recorded DT510 warm-reboot checks; this is not a universal sampling waiver.
- Do not claim cold-power, suspend/resume, other-board or pixel-identical
  acceptance from warm reboot evidence. Do not turn a software test, CI pass,
  retained flag or successful SSH connection into physical display acceptance.

## DT510 known-good reference

Foundries vixdt718, trigger `platform-main-imx8mm-jaguar-dt510`:
<https://app.foundries.io/factories/vixdt/targets/718/>.
Manifest `f181ced27d53b2d20beb5c159c604c19f0ddcd40`;
BSP `291b2188e2e096d06283efef0ed4cba98677382d`.
Image5.0.9-718-96, OSTree
`6c4d108f7575ddc595c1145647011593082826db80134e938f81d9f5b44caf41`.

Kernel implementation:
`meta-dynamicdevices-bsp/recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/0036-drm-imx-dt510-preserve-boot-scanout.patch`.
U-Boot implementation:
`meta-dynamicdevices-bsp/recipes-bsp/u-boot/u-boot-fio/imx8mm-jaguar-dt510/03-dt510-reserved-display-handover.patch`.
Regression fixtures: BSP`scripts/test-dt510-display-handover.py` and
`scripts/test-dt510-dtb-admission.py` (18native +4DTB tests at this baseline).

Three complete recorded warm reboots on22November2026 showed the same splash
remaining visible from U-Boot into G2D Weston, without observed black/white
handover or TV console. Logo scale changed at desktop takeover; this is not a
claim of pixel-identical content. Alex subsequently reports a suspected black
period during handover; this remains unresolved, with investigation deferred
at his request. The sampled observations do not establish fully seamless
acceptance. Cold-power and suspend/resume remain unproved. Keep private footage,
serial evidence and the project checkpoint's artifact locations private.
This reference grants no authority to operate devices, publish, build, alter
boot selection/storage/update paths or change security controls.
