# Validate the contract shared by Linux and U-Boot screen integration.
# Recipes may inherit this class globally; machines without a panel profile
# are intentionally ignored.
python display_panel_profile_validate() {
    profile = d.getVar("DISPLAY_PANEL_PROFILE") or ""
    if not profile:
        return

    required = (
        "DISPLAY_PANEL_NATIVE_WIDTH",
        "DISPLAY_PANEL_NATIVE_HEIGHT",
        "DISPLAY_PANEL_PIXELCLOCK_KHZ",
        "DISPLAY_PANEL_DSI_LANES",
        "DISPLAY_PANEL_DSI_FORMAT",
        "DISPLAY_PANEL_LINUX_COMPATIBLE",
        "DISPLAY_PANEL_UBOOT_DRIVER",
        "DISPLAY_PANEL_UBOOT_CONFIG",
    )
    missing = [name for name in required if not (d.getVar(name) or "").strip()]
    if missing:
        bb.fatal("Display panel profile %s is incomplete: %s" %
                 (profile, ", ".join(missing)))

    if d.getVar("DISPLAY_PANEL_ROTATION") not in ("0", "90", "180", "270"):
        bb.fatal("DISPLAY_PANEL_ROTATION must be 0, 90, 180 or 270")
    if d.getVar("DISPLAY_FBCON_ROTATE") not in ("0", "1", "2", "3"):
        bb.fatal("DISPLAY_FBCON_ROTATE must be 0, 1, 2 or 3")
}

addtask display_panel_profile_validate after do_patch before do_configure
