#!/usr/bin/env python3
"""Check DT510 HDMI patches, native helper behaviour and compiled DT; no Yocto build."""

import argparse
import io
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile


PIN = "e0f9e2afd4cff3f02d71891244b4aa5899dfc786"
DRIVER = "drivers/gpu/drm/bridge/lontium-lt9611.c"
CONNECTOR = "drivers/gpu/drm/drm_bridge_connector.c"
BSP = Path(__file__).resolve().parents[1]
FILES = BSP / "recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510"
PATCHES = (
    "0031-drm-bridge-lt9611-fix-dt510-active-low-reset.patch",
    "0032-drm-bridge-lt9611-dt510-host-and-irq.patch",
    "0033-drm-bridge-lt9611-preserve-i2c-address-in-sleep.patch",
)


def run(args, **kwargs):
    result = subprocess.run(args, capture_output=True, **kwargs)
    if result.returncode:
        error = result.stderr or result.stdout
        if isinstance(error, bytes):
            error = error.decode(errors="replace")
        raise RuntimeError(f"{args[0]} failed ({result.returncode}): {error[:2000]}")
    return result


def function(source, name):
    match = re.search(r"(?:static )?(?:void |int |struct mipi_dsi_device \*)" + name + r"\(.*?\n\}", source, re.S)
    if not match:
        raise RuntimeError(f"Missing function: {name}")
    return match.group(0)


def check_sleep_address(source, work):
    # Compile the actual sleep function against a model of the documented
    # software address registers. The old hardcoded address must fail the model.
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
struct i2c_client { unsigned short addr; };
struct reg_sequence { unsigned int reg, def; };
struct regmap { unsigned int client_addr, device_addr, soft_addr, writes; int error; };
struct lt9611 { struct i2c_client *client; struct regmap *regmap; bool sleep; };
static int regmap_multi_reg_write(struct regmap *m, const struct reg_sequence *s, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        if (m->client_addr != m->device_addr) return m->error = -6;
        m->writes++;
        if (s[i].reg == 0x8024) m->soft_addr = s[i].def;
        if (s[i].reg == 0x8023 && (s[i].def & 1)) m->device_addr = m->soft_addr >> 1;
    }
    return 0;
}
'''
    sleep = function(source, "lt9611_sleep_setup")
    legacy = sleep.replace("lt9611_sleep_setup(", "legacy_sleep_setup(").replace(
        "lt9611->client->addr << 1", "0x76")
    assert legacy != sleep
    harness += sleep + "\n" + legacy + r'''
int main(void)
{
    const unsigned int addresses[] = {0x39, 0x3b};
    for (size_t i = 0; i < ARRAY_SIZE(addresses); i++) {
        struct i2c_client c = { .addr = addresses[i] };
        struct regmap m = { .client_addr = c.addr, .device_addr = c.addr };
        struct lt9611 d = { .client = &c, .regmap = &m };
        for (int cycle = 0; cycle < 3; cycle++) {
            d.sleep = false;
            lt9611_sleep_setup(&d);
            assert(d.sleep && !m.error && m.device_addr == c.addr);
            assert(m.soft_addr == (unsigned int)c.addr << 1);
            assert(m.writes == 8 * (unsigned int)(cycle + 1));
        }
    }
    struct i2c_client c = { .addr = 0x39 };
    struct regmap m = { .client_addr = c.addr, .device_addr = c.addr };
    struct lt9611 d = { .client = &c, .regmap = &m };
    legacy_sleep_setup(&d);
    assert(m.error == -6 && m.writes == 2 && m.device_addr == 0x3b);
    return 0;
}
'''
    path = work / "sleep-address-test.c"
    path.write_text(harness)
    binary = work / "sleep-address-test"
    run(["cc", "-Wall", "-Wextra", "-Werror", "-std=c11", str(path), "-o", str(binary)])
    run([str(binary)])
    print("PASS: compiled actual sleep sequence preserves 0x39/0x3b across three modelled cycles; old sequence reproduces address loss after two writes. Model test, not hardware validation.")


def check_functions(source, work):
    # Compile the actual patched functions, with mocks only for kernel/DRM APIs.
    harness = r'''
#include <assert.h>
#include <stdint.h>
#include <stddef.h>
#define EPROBE_DEFER 517
#define ERR_PTR(n) ((void *)(intptr_t)(n))
#define IS_ERR(p) ((uintptr_t)(p) >= (uintptr_t)-4095)
#define PTR_ERR(p) ((int)(intptr_t)(p))
#define MIPI_DSI_FMT_RGB888 1
#define MIPI_DSI_MODE_VIDEO 1
#define MIPI_DSI_MODE_VIDEO_SYNC_PULSE 2
#define MIPI_DSI_MODE_VIDEO_HSE 4
#define dev_err(dev, ...) ((void)(dev))
#define dev_err_probe(dev, err, ...) ((void)(dev), (err))
enum drm_bridge_attach_flags { DRM_BRIDGE_ATTACH_NO_CONNECTOR = 1 };
struct drm_connector;
struct drm_connector_funcs { void (*destroy)(struct drm_connector *); };
struct mutex { int locked; };
struct drm_device { struct { struct mutex mutex; } mode_config; };
struct drm_connector {
    const struct drm_connector_funcs *funcs;
    struct drm_device *dev;
    int refs, polled;
};
struct drm_bridge { void *encoder, *dev, *driver_private; };
struct drm_bridge_connector {
    struct drm_connector base;
    void *encoder;
    struct drm_bridge *bridge_hpd, *bridge_detect, *bridge_edid, *bridge_modes;
};
#define to_drm_bridge_connector(p) ((struct drm_bridge_connector *)(p))
struct gpio_desc { int active_low; };
struct device_node { int id; };
struct device { struct device_node *of_node; };
struct mipi_dsi_device_info { const char *type; int channel; struct device_node *node; };
struct mipi_dsi_host { int unused; };
struct mipi_dsi_device { int lanes, format, mode_flags, live, attached; };
struct lt9611 {
    struct drm_bridge *next_bridge;
    struct gpio_desc *reset_gpio;
    struct drm_connector *connector;
    struct device *dev;
    struct device_node *dsi0_node, *dsi1_node;
    struct mipi_dsi_device *dsi0, *dsi1;
};
static struct mipi_dsi_host host;
static struct mipi_dsi_device devices[2];
static struct device_node *missing_node;
static int host_ready, register_error, attach_error, live, attached, registrations;
static struct mipi_dsi_host *of_find_mipi_dsi_host_by_node(struct device_node *n)
{ return host_ready && n != missing_node ? &host : NULL; }
static struct mipi_dsi_device *mipi_dsi_device_register_full(
    struct mipi_dsi_host *h, const struct mipi_dsi_device_info *info)
{
    (void)h; (void)info;
    if (register_error) return ERR_PTR(register_error);
    for (int i = 0; i < 2; i++) if (!devices[i].live) {
        devices[i].live = 1; live++; registrations++; return &devices[i];
    }
    assert(0); return NULL;
}
static int mipi_dsi_attach(struct mipi_dsi_device *d)
{
    assert(d->live && !d->attached);
    assert(d->lanes == 4 && d->format == MIPI_DSI_FMT_RGB888 && d->mode_flags == 7);
    if (attach_error) return attach_error;
    d->attached = 1; attached++; return 0;
}
static void mipi_dsi_detach(struct mipi_dsi_device *d)
{ assert(d->live && d->attached); d->attached = 0; attached--; }
static void mipi_dsi_device_unregister(struct mipi_dsi_device *d)
{ assert(d->live && !d->attached); d->live = 0; live--; }
static int levels[3], delays[3], count, waits;
static int bridge_error, init_error, encoder_error, inits, destroys, seen_flags;
static struct drm_device drm;
static int hpd_mutex_destroyed, hpd_disables;
static void mutex_lock(struct mutex *m) { assert(!m->locked); m->locked = 1; }
static void mutex_unlock(struct mutex *m) { assert(m->locked); m->locked = 0; }
static void drm_connector_unregister(struct drm_connector *p) { (void)p; }
static void drm_bridge_hpd_disable(struct drm_bridge *p)
{ (void)p; assert(!hpd_mutex_destroyed && !drm.mode_config.mutex.locked); hpd_disables++; }
static void destroy(struct drm_connector *p)
{
    struct drm_bridge_connector *b = to_drm_bridge_connector(p);
    assert(!p->refs && !b->bridge_hpd && !b->bridge_detect && !b->bridge_edid);
    assert(!b->bridge_modes && !b->encoder);
    destroys++;
}
static void drm_connector_get(struct drm_connector *p) { assert(p->refs > 0); p->refs++; }
static void drm_connector_put(struct drm_connector *p)
{ assert(p->refs > 0); if (!--p->refs) p->funcs->destroy(p); }
static const struct drm_connector_funcs funcs = { destroy };
static struct drm_bridge hpd_bridge;
static struct drm_bridge_connector bc = { .base = { .funcs = &funcs, .dev = &drm } };
static struct lt9611 *bridge_to_lt9611(struct drm_bridge *p)
{ return p->driver_private; }
static int drm_bridge_attach(void *encoder, struct drm_bridge *next,
                             struct drm_bridge *previous, int flags)
{ (void)encoder; (void)next; (void)previous; seen_flags = flags; return bridge_error; }
static struct drm_connector *drm_bridge_connector_init(void *dev, void *encoder)
{
    (void)dev; (void)encoder; inits++;
    if (init_error) return ERR_PTR(init_error);
    assert(!bc.base.refs);
    bc.base.refs = 1; bc.base.polled = 1;
    bc.bridge_hpd = bc.bridge_detect = bc.bridge_edid = bc.bridge_modes = &hpd_bridge;
    bc.encoder = &hpd_bridge;
    return &bc.base;
}
static int drm_connector_attach_encoder(struct drm_connector *p, void *encoder)
{ (void)p; (void)encoder; return encoder_error; }
static void gpiod_set_value_cansleep(struct gpio_desc *p, int value)
{ assert(count < 3); levels[count++] = value ^ p->active_low; }
static void msleep(int delay)
{ assert(waits < 3 && waits + 1 == count); delays[waits++] = delay; }
'''
    connector_source = (work / CONNECTOR).read_text()
    harness += function(connector_source, "drm_bridge_connector_disconnect") + "\n"
    harness += function(source, "lt9611_reset") + "\n"
    harness += function(source, "lt9611_attach_dsi") + "\n"
    harness += function(source, "lt9611_bridge_detach") + "\n"
    harness += function(source, "lt9611_bridge_attach") + "\n"
    harness += r'''
static void attach_case(int flags, int downstream, int init, int encoder,
                        int expected, int expected_inits, int expected_destroys)
{
    struct device dev = {0};
    struct device_node node = {0};
    struct lt9611 chip = { .dev = &dev, .dsi0_node = &node };
    struct drm_bridge bridge = { .driver_private = &chip };
    bridge_error = downstream; init_error = init; encoder_error = encoder;
    inits = destroys = 0;
    host_ready = 1;
    assert(lt9611_bridge_attach(&bridge, flags) == expected);
    assert(seen_flags & DRM_BRIDGE_ATTACH_NO_CONNECTOR);
    assert(inits == expected_inits && destroys == expected_destroys);
    assert(live == (expected == 0) && attached == (expected == 0));
    lt9611_bridge_detach(&bridge);
    assert(live == 0 && attached == 0 && !chip.connector && !chip.dsi0);
    lt9611_bridge_detach(&bridge); /* repeated cleanup must be harmless */
    if (expected == 0 && !(flags & DRM_BRIDGE_ATTACH_NO_CONNECTOR)) {
        assert(bc.base.refs == 1); /* initial reference still owned by DRM */
        drm_connector_get(&bc.base); /* simulate an outstanding reader */
        drm_connector_put(&bc.base); /* DRM mode_config releases its reference */
        hpd_mutex_destroyed = 1; /* bridge removed before reader releases */
        drm_connector_put(&bc.base);
        hpd_mutex_destroyed = 0;
        assert(destroys == 1);
    }
}
static void retry_cases(void)
{
    struct device dev = {0};
    struct device_node node = {0}, secondary = {1};
    struct lt9611 chip = { .dev = &dev, .dsi0_node = &node };
    struct drm_bridge bridge = { .driver_private = &chip };
    bridge_error = init_error = encoder_error = 0;
    host_ready = 0; /* bridge probes before host is registered */
    assert(lt9611_bridge_attach(&bridge, 0) == -EPROBE_DEFER);
    assert(live == 0 && attached == 0);
    host_ready = 1; /* component bind now registers host */
    assert(lt9611_bridge_attach(&bridge, 0) == 0);
    lt9611_bridge_detach(&bridge);
    drm_connector_put(&bc.base); /* core cleanup */
    /* Host-first order plus repeated downstream deferrals must not leak. */
    for (int i = 0; i < 3; i++) {
        bridge_error = -EPROBE_DEFER;
        assert(lt9611_bridge_attach(&bridge, 0) == -EPROBE_DEFER);
        assert(live == 0 && attached == 0);
    }
    bridge_error = 0;
    register_error = -12;
    assert(lt9611_bridge_attach(&bridge, 0) == -12 && live == 0);
    register_error = 0; attach_error = -22;
    assert(lt9611_bridge_attach(&bridge, 0) == -22 && live == 0);
    attach_error = 0;
    chip.dsi1_node = &secondary;
    missing_node = &secondary;
    assert(lt9611_bridge_attach(&bridge, 0) == -EPROBE_DEFER);
    assert(live == 0 && attached == 0 && !chip.dsi0 && !chip.dsi1);
    missing_node = NULL;
    assert(lt9611_bridge_attach(&bridge, 0) == 0 && live == 2 && attached == 2);
    lt9611_bridge_detach(&bridge);
    drm_connector_put(&bc.base); /* core cleanup */
    assert(live == 0 && attached == 0 && !chip.dsi1);
    assert(registrations > 0);
    assert(hpd_disables > 0 && !bc.base.refs);
}
int main(void)
{
    struct gpio_desc gpio = { .active_low = 1 };
    struct lt9611 chip = { .reset_gpio = &gpio };
    lt9611_reset(&chip);
    assert(count == 3 && waits == 3);
    assert(levels[0] == 1 && levels[1] == 0 && levels[2] == 1);
    assert(delays[0] == 20 && delays[1] == 20 && delays[2] == 100);
    attach_case(0, 0, 0, 0, 0, 1, 0);
    attach_case(DRM_BRIDGE_ATTACH_NO_CONNECTOR, 0, 0, 0, 0, 0, 0);
    attach_case(0, -5, 0, 0, -5, 0, 0);
    attach_case(0, 0, -12, 0, -12, 1, 0);
    attach_case(0, 0, 0, -22, -22, 1, 1);
    retry_cases();
    return 0;
}
'''
    executable = str(work / "lt9611-helper-test")
    run(["cc", "-std=c11", "-Wall", "-Wextra", "-Werror", "-x", "c", "-", "-o", executable],
        input=harness, text=True)
    run([executable])
    probe = function(source, "lt9611_probe")
    assert "lt9611_attach_dsi(" not in probe
    assert "of_find_mipi_dsi_host_by_node(" not in probe
    assert probe.index("lt9611_audio_init(") < probe.index("drm_bridge_add(")
    assert "devm_mipi_dsi_" not in source
    assert ".detach = lt9611_bridge_detach" in source
    assert "connector->funcs->destroy" not in source
    remove = function(source, "lt9611_remove")
    assert remove.index("lt9611_bridge_detach(") < remove.index("drm_bridge_remove(")
    polarity = "regmap_update_bits(lt9611->regmap, 0x8210, 0x01, 0x01)"
    assert probe.index(polarity) < probe.index("devm_request_threaded_irq")
    assert "if (ret)\n\t\tgoto err_disable_regulators;" in probe.split(polarity, 1)[1]
    print("PASS: compiled reset/DSI/attach/detach/disconnect helpers; deferred retries, host orders, DSI errors, connector references, delayed destruction, HPD teardown and IRQ ordering.")


def check_dt(work):
    # Match the existing BSP do_patch prerequisite before compiling the EVKB base.
    base_patch = BSP / "recipes-kernel/linux/linux-lmp-fslc-imx/0004-dts-imx8mm-evkb-fix-duplicate-label.patch"
    run(["patch", "--fuzz=0", "--batch", "-p1", "-i", str(base_patch)], cwd=work)
    dt = BSP / "recipes-bsp/device-tree/lmp-device-tree"
    preprocessed = run([
        "cpp", "-nostdinc", "-undef", "-D__DTS__", "-x", "assembler-with-cpp",
        "-I", str(work / "include"), "-I", str(work / "arch/arm64/boot/dts"),
        "-I", str(dt), str(dt / "imx8mm-jaguar-dt510.dts"),
    ]).stdout
    dtb = str(work / "dt510.dtb")
    compiled = run(["dtc", "-@", "-I", "dts", "-O", "dtb", "-o", dtb, "-"], input=preprocessed)

    def get(node, prop, kind="s"):
        return run(["fdtget", "-t" + kind, dtb, node, prop], text=True).stdout.strip()

    def symbol(label):
        return get("/__symbols__", label)

    for label in ("lt9611", "mipi_dsi", "lcdif"):
        assert get(symbol(label), "status") == "okay", label
    for left, right in (("lcdif_to_dsim", "dsim_from_lcdif"),
                        ("mipi_dsi_out", "lt9611_in"),
                        ("lt9611_out", "hdmi_connector_in")):
        assert get(symbol(left), "remote-endpoint", "x") == get(symbol(right), "phandle", "x")
        assert get(symbol(right), "remote-endpoint", "x") == get(symbol(left), "phandle", "x")
    assert get(symbol("mipi_dsi_out"), "data-lanes", "x") == "1 2 3 4"
    get(symbol("mipi_dsi_out"), "attach-bridge")
    assert get(symbol("lt9611"), "reset-gpios", "x").split()[1:] == ["b", "1"]
    assert get(symbol("lt9611"), "interrupts", "x") == "6 4"
    assert get(symbol("lt9611"), "vdd-supply", "x") == get(symbol("reg_lt9611_vdd_1v8"), "phandle", "x")
    assert get(symbol("lt9611"), "vcc-supply", "x") == get(symbol("reg_vddext_3v3"), "phandle", "x")
    children = run(["fdtget", "-l", dtb, symbol("i2c2")], text=True).stdout.splitlines()
    assert "adv7535@3d" not in children and "hdmi@3d" not in children
    children = run(["fdtget", "-l", dtb, symbol("mipi_dsi")], text=True).stdout.splitlines()
    assert "ports" in children and "port@0" not in children and "port@1" not in children
    warnings = compiled.stderr.decode(errors="replace")
    hdmi_warnings = [line for line in warnings.splitlines()
                     if "Warning" in line and any(term in line for term in
                        ("lt9611", "hdmi-connector", "mipi_dsi", "dsim_", "lcdif"))]
    assert not hdmi_warnings, "\n".join(hdmi_warnings)[:2000]
    print(f"PASS: compiled DTB and checked enabled LCDIF/DSI/LT9611, graph, lanes, GPIOs, supplies and EVK removal; {warnings.count('Warning')} other DT warnings.")
    for line in warnings.splitlines():
        if "Warning" in line:
            print(line.split(": Warning", 1)[-1][:400])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--kernel-git", required=True, help="Existing local kernel Git repository/git-dir")
    parser.add_argument("--only-dt", action="store_true", help="Recheck only a failed device-tree prerequisite/check")
    args = parser.parse_args()
    paths = [DRIVER, CONNECTOR, "include/drm/drm_bridge_connector.h",
             "include/dt-bindings", "include/uapi/linux/input-event-codes.h"]
    paths += ["arch/arm64/boot/dts/freescale/" + name for name in
              ("imx8mm-evkb.dts", "imx8mm-evk.dtsi", "imx8mm.dtsi", "imx8mm-pinfunc.h")]
    archive = run(["harness-git", "--git-dir=" + args.kernel_git, "archive", PIN, *paths]).stdout
    with tempfile.TemporaryDirectory(prefix="dt510-hdmi-preflight-") as directory:
        work = Path(directory)
        with tarfile.open(fileobj=io.BytesIO(archive)) as bundle:
            bundle.extractall(work, filter="data")
        if not args.only_dt:
            for name in PATCHES:
                patch = str(FILES / name)
                run(["harness-git", "-C", directory, "apply", "--check", "--whitespace=error", patch])
                checked = run(["patch", "--dry-run", "--fuzz=0", "--batch", "-p1", "-i", patch], cwd=work, text=True)
                assert not checked.stderr and "offset" not in checked.stdout and "fuzz" not in checked.stdout, checked.stdout + checked.stderr
                run(["patch", "--fuzz=0", "--batch", "-p1", "-i", patch], cwd=work)
            print(f"PASS: all {len(PATCHES)} DT510-only patches apply in order to the pinned kernel without offsets/fuzz.")
            source = (work / DRIVER).read_text()
            check_sleep_address(source, work)
            check_functions(source, work)
        check_dt(work)
    recipe = (BSP / "recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend").read_text()
    blocks = re.findall(r'SRC_URI:append:([^ =]+)\s*=\s*"(.*?)"', recipe, re.S)
    for name in PATCHES:
        assert [machine for machine, body in blocks if name in body] == ["imx8mm-jaguar-dt510"]
    config = (FILES / "lt9611-hdmi.cfg").read_text()
    assert "CONFIG_DRM_LONTIUM_LT9611=y" in config
    assert "CONFIG_DRM_DISPLAY_CONNECTOR=y" in config
    print("PASS: DT510-only recipe selection and built-in bridge/connector config. No full kernel build or hardware test performed.")


if __name__ == "__main__":
    main()
