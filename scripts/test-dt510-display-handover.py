#!/usr/bin/env python3
"""Execute the shipped kernel admission/mode policy in native C fixtures.

Hardware, clocks, PM ownership and visual continuity still require integration
review, the target kernel build and a watched DT510 boot. These are not a
kernel build or a simulated TV.
"""
from pathlib import Path
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATCH = ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-dt510/0036-drm-imx-dt510-preserve-boot-scanout.patch'
UBOOT = ROOT / 'recipes-bsp/u-boot/u-boot-fio/imx8mm-jaguar-dt510/03-dt510-reserved-display-handover.patch'


def added_file(patch, name):
    part = patch.read_text().split('+++ b/' + name + '\n', 1)[1]
    part = part.split('\ndiff --git ', 1)[0]
    return ''.join(line[1:] + '\n' for line in part.splitlines()
                   if line.startswith('+') and not line.startswith('+++'))


class HandoverTest(unittest.TestCase):
    def test_git_index_applies_new_header_and_rejects_missing_metadata(self):
        patch = PATCH.read_text()
        header_diff = patch[patch.index('diff --git a/include/video/dt510-handover.h '):]
        broken = header_diff.replace('new file mode 100644\n', '')
        self.assertNotEqual(header_diff, broken)
        git = os.environ.get('GIT', 'git')
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            subprocess.run([git, '-C', temp, 'init', '-q'], check=True)
            command = [git, '-C', temp, 'apply', '--check', '--index', '-']
            rejected = subprocess.run(command, input=broken, text=True, capture_output=True)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn('dev/null', rejected.stderr)
            subprocess.run(command, input=header_diff, text=True, check=True)
            subprocess.run([git, '-C', temp, 'apply', '--index', '-'],
                           input=header_diff, text=True, check=True)
            actual = (root / 'include/video/dt510-handover.h').read_text()
            self.assertEqual(actual, added_file(PATCH, 'include/video/dt510-handover.h'))
            corrected = root / 'corrected.patch'
            corrected.write_text(patch)
            lint = [sys.executable, str(ROOT / 'scripts/kernel-patch-lint.py')]
            subprocess.run(lint + [str(corrected)], check=True, capture_output=True)
            malformed = root / 'missing-metadata.patch'
            malformed.write_text(broken)
            result = subprocess.run(lint + [str(malformed)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('new file mode', result.stderr)

    def test_compiled_dsim_irq_lifetime(self):
        part = PATCH.read_text().split('+++ b/drivers/gpu/drm/bridge/sec-dsim.c\n', 1)[1]
        part = part.split('\ndiff --git ', 1)[0]
        current = '\n'.join(line[1:] for line in part.splitlines()
                            if line.startswith(('+', ' ')))

        def function(name):
            if name == 'sec_mipi_dsim_resume':
                start = current.index('if (dsim->irq_requested && !dsim->irq_enabled)')
                opening = current.index('{', start)
                end = current.index('\n\t}', opening) + len('\n\t}')
                return ('void sec_mipi_dsim_resume(struct device *dev) {\n'
                        'struct sec_mipi_dsim *dsim = dev_get_drvdata(dev);\n'
                        'sec_mipi_dsim_irq_init(dsim);\n' + current[start:end] + '\n}')
            start = current.index('void ' + name + '(struct device *dev)')
            opening = current.index('{', start)
            depth, end = 1, opening + 1
            while depth:
                depth += (current[end] == '{') - (current[end] == '}')
                end += 1
            return current[start:end]

        bind = current[current.index('dsim->encoder = encoder;'):]
        self.assertIn('IRQF_NO_AUTOEN, dev_name(dev), dsim', bind)
        self.assertLess(bind.index('ret = pm_runtime_resume_and_get(dev)'),
                        bind.index('sec_mipi_dsim_irq_init(dsim)'))
        self.assertLess(bind.index('enable_irq(dsim->irq)'),
                        bind.rindex('pm_runtime_put_sync(dev)'))
        fixture = r'''
#include <assert.h>
#include <stdbool.h>
struct device { int unused; } dev;
struct sec_mipi_dsim { int irq; bool irq_enabled, irq_requested; } state;
static bool present = true, powered;
static int enables, disables, initializations;
static void *dev_get_drvdata(struct device *dev) { return present ? &state : 0; }
static void enable_irq(int irq) { assert(powered); enables++; }
static void disable_irq(int irq) { assert(powered); disables++; }
static void sec_mipi_dsim_irq_init(struct sec_mipi_dsim *dsim) {
    assert(powered); initializations++;
}
/* ACTUAL_IRQ_LIFETIME */
int main(void) {
    powered = true;
    sec_mipi_dsim_resume(&dev); /* first resume, no registered handler */
    assert(initializations == 1 && enables == 0);
    state.irq_requested = true;
    sec_mipi_dsim_resume(&dev);
    assert(enables == 1 && state.irq_enabled);
    sec_mipi_dsim_resume(&dev);
    assert(enables == 1);
    sec_mipi_dsim_suspend(&dev);
    assert(disables == 1 && !state.irq_enabled);
    powered = false;
    sec_mipi_dsim_suspend(&dev); /* no unpowered IRQ operation */
    assert(disables == 1);
    powered = true;
    sec_mipi_dsim_resume(&dev);
    assert(enables == 2 && state.irq_enabled);
    sec_mipi_dsim_suspend(&dev);
    present = false; powered = false;
    sec_mipi_dsim_suspend(&dev); /* failed/deferred bind cleanup */
    assert(disables == 2);
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            code = fixture.replace('/* ACTUAL_IRQ_LIFETIME */',
                function('sec_mipi_dsim_suspend') + '\n' + function('sec_mipi_dsim_resume'))
            (root / 'irq.c').write_text(code)
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'irq.c'),
                            '-o', str(root / 'irq')], check=True)
            subprocess.run([str(root / 'irq')], check=True)

    def test_compiled_power_preflight_rejects_commit_without_a_reference(self):
        crtc = added_file(PATCH, 'drivers/gpu/drm/imx/lcdif/lcdif-crtc.c')
        start = crtc.index('if (crtc_state->active && !lcdif_crtc_is_active(crtc))')
        opening = crtc.index('{', start)
        depth, end = 1, opening + 1
        while depth:
            depth += (crtc[end] == '{') - (crtc[end] == '}')
            end += 1
        block = crtc[start:end]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = r'''
#include <assert.h>
#include <stdbool.h>
struct device { struct device *parent; } device;
struct driver { struct device *dev; } driver = { &device };
struct state { bool active; } state;
static bool powered;
static int error, refs, gets, commits;
static bool lcdif_crtc_is_active(void *crtc) { return powered; }
static int pm_runtime_resume_and_get(void *dev) {
    gets++; if (error) return error; refs++; return 0;
}
static void pm_runtime_put(void *dev) { assert(refs > 0); refs--; }
static int check(void) {
    void *crtc = 0;
    struct state *crtc_state = &state;
    struct driver *lcdif_crtc = &driver;
    /* ACTUAL_PREFLIGHT */
    commits++; return 0;
}
int main(void) {
    state.active = true; error = -5;
    assert(check() == -5 && refs == 0 && commits == 0);
    error = 0; assert(check() == 0 && refs == 0 && commits == 1);
    refs = 1; assert(check() == 0 && refs == 1 && commits == 2);
    powered = true; error = -5; int before = gets;
    assert(check() == 0 && refs == 1 && gets == before);
    powered = false; state.active = false;
    assert(check() == 0 && refs == 1 && gets == before);
}
'''
            (root / 'preflight.c').write_text(source.replace('/* ACTUAL_PREFLIGHT */', block))
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'preflight.c'),
                            '-o', str(root / 'preflight')], check=True)
            subprocess.run([str(root / 'preflight')], check=True)

    def test_deferred_dsim_bind_keeps_one_bootstrap_reference(self):
        patch = PATCH.read_text()
        self.assertIn('if (!dsim_dev->boot_pm_ref && dt510_boot_display_read(&boot))', patch)
        self.assertIn('if (ret != -EPROBE_DEFER)', patch)
        self.assertIn('devres_release_group(dev, bind_group)', patch)
        self.assertIn('devres_close_group(dev, bind_group)', patch)
        self.assertIn('if (!lcdif_crtc_is_active(new_plane_state->crtc))', patch)
        self.assertIn('static DEVICE_ATTR_RO(aesl_boot_display)', patch)
        self.assertIn('if (!dt510_boot_display_retained())', patch)

    def test_compiled_kernel_admission_and_mode_policy(self):
        header = added_file(PATCH, 'include/video/dt510-handover.h')
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            for name in ['linux/of.h', 'linux/of_reserved_mem.h', 'linux/limits.h',
                         'linux/string.h', 'video/videomode.h']:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text('/* Native fixture provides the API. */\n')
            (root / 'policy.h').write_text(header)
            fixture = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <stdio.h>
typedef uint32_t u32;
typedef uint64_t u64;
#define U32_MAX UINT32_MAX
#define BIT(x) (1U << (x))
#define DISPLAY_FLAGS_HSYNC_HIGH 1
#define DISPLAY_FLAGS_VSYNC_HIGH 2
#define DISPLAY_FLAGS_INTERLACED 4
#define DISPLAY_FLAGS_DOUBLESCAN 8
struct videomode { unsigned long pixelclock; u32 hactive, hfront_porch,
    hsync_len, hback_porch, vactive, vfront_porch, vsync_len, vback_porch, flags; };
struct device_node { int id; } node = {1}, memory = {2};
struct reserved_mem { u64 base, size; } region;
static bool machine, available, compatible, map, exists, phandle, region_exists;
static u64 address;
static u32 width, height, stride, regs[10];
static const char *format;
static int refs, missing;
typedef struct { int counter; } atomic_t;
#define ATOMIC_INIT(v) { v }
#define EXPORT_SYMBOL_GPL(name)
static int atomic_read(const atomic_t *p) { return p->counter; }
static void atomic_set(atomic_t *p, int v) { p->counter = v; }
static void atomic_or(unsigned int v, atomic_t *p) { p->counter |= v; }
static bool of_machine_is_compatible(const char *s) { return machine; }
static struct device_node *of_find_node_by_path(const char *s) {
    if (!exists) return NULL; refs++; return &node;
}
static bool of_device_is_available(struct device_node *n) { return available; }
static bool of_device_is_compatible(struct device_node *n, const char *s) { return compatible; }
static int of_property_read_u64(struct device_node *n, const char *s, u64 *v) {
    *v = address; return missing == 1;
}
static int of_property_read_u32(struct device_node *n, const char *s, u32 *v) {
    *v = !strcmp(s, "width") ? width : !strcmp(s, "height") ? height : stride;
    return missing == 2;
}
static int of_property_read_string(struct device_node *n, const char *s, const char **v) {
    *v = format; return missing == 3;
}
static int of_property_read_u32_array(struct device_node *n, const char *s, u32 *v, int count) {
    assert(count == 10); memcpy(v, regs, sizeof(regs)); return missing == 4;
}
static struct device_node *of_parse_phandle(struct device_node *n, const char *s, int i) {
    if (!phandle) return NULL; refs++; return &memory;
}
static struct reserved_mem *of_reserved_mem_lookup(struct device_node *n) {
    return region_exists ? &region : NULL;
}
static bool of_property_read_bool(struct device_node *n, const char *s) { return map; }
static void of_node_put(struct device_node *n) { refs--; }
#include "policy.h"
/* ACTUAL_SHARED_OUTCOME */
static void defaults(void) {
    machine = available = compatible = map = exists = phandle = region_exists = true;
    atomic_set(&dt510_boot_failed, 0); atomic_set(&dt510_boot_claims, 0);
    address = 0xbf000000; region.base = address; region.size = 16 * 1024 * 1024;
    width = 1280; height = 720; stride = 5120; format = "x8r8g8b8";
    memset(regs, 0, sizeof(regs)); regs[0] = 1; regs[3] = address; missing = 0;
    regs[2] = (720U << 16) | 1280; regs[5] = 5; regs[6] = 750;
    regs[7] = (40U << 18) | 1650; regs[8] = (260U << 16) | 25; regs[9] = 1280;
    assert(refs == 0);
}
static void check(bool expected) {
    struct dt510_boot_display boot;
    assert(dt510_boot_display_read(&boot) == expected); assert(refs == 0);
}
int main(void) {
    defaults(); check(true);
    assert(!dt510_boot_display_retained());
    dt510_boot_display_claim(DT510_BOOT_LCDIF | DT510_BOOT_DSIM);
    assert(!dt510_boot_display_retained());
    dt510_boot_display_claim(DT510_BOOT_LT9611);
    assert(dt510_boot_display_retained());
    dt510_boot_display_reject(); assert(!dt510_boot_display_retained());
    check(false); defaults();
    machine = false; check(false); defaults();
    available = false; check(false); defaults();
    compatible = false; check(false); defaults();
    exists = false; check(false); defaults();
    phandle = false; check(false); defaults();
    map = false; check(false); defaults();
    region_exists = false; check(false); defaults();
    for (int i = 1; i <= 4; i++) { missing = i; check(false); defaults(); }
    width++; check(false); defaults(); height--; check(false); defaults();
    stride++; check(false); defaults(); format = "r5g6b5"; check(false); defaults();
    address = 0; check(false); defaults();
    address = UINT32_MAX - 100; regs[3] = address; check(false); defaults();
    regs[0] = 0; check(false); defaults(); regs[3]++; check(false); defaults();
    regs[7]--; check(false); defaults();
    region.size = 1280 * 720 * 4 - 1; check(false); defaults();
    region.base++; check(false); defaults();
    region.base = address - 4096; region.size = 1280 * 720 * 4; check(false); defaults();
    region.base = address - 4096; region.size = 1280 * 720 * 4 + 4096; check(true);
    struct videomode vm = {74250000, 1280, 110, 40, 220, 720, 5, 5, 20, 3};
    assert(dt510_boot_mode_matches(&vm));
    for (u32 f = 0; f < 16; f++) { vm.flags = f; assert(dt510_boot_mode_matches(&vm) == (f == 3)); }
    vm.flags = 3; vm.pixelclock--; assert(!dt510_boot_mode_matches(&vm));
    vm.pixelclock++; vm.hfront_porch--; assert(!dt510_boot_mode_matches(&vm));
    puts("kernel handover admission/mode policy PASS");
}
'''
            common = added_file(PATCH, 'drivers/gpu/imx/lcdif/lcdif-common.c')
            shared = common[common.index('static atomic_t dt510_boot_failed'):]
            end = 'EXPORT_SYMBOL_GPL(dt510_boot_display_retained);'
            shared = shared[:shared.index(end) + len(end)]
            (root / 'test.c').write_text(fixture.replace('/* ACTUAL_SHARED_OUTCOME */', shared))
            subprocess.run(['cc', '-std=c11', '-Werror', '-I', temp,
                            str(root / 'test.c'), '-o', str(root / 'test')], check=True)
            subprocess.run([str(root / 'test')], check=True)

    def test_kernel_patch_follows_existing_safety_repairs(self):
        recipe = (ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend').read_text()
        self.assertLess(recipe.index('0034-drm-'), recipe.index('0036-drm-'))
        self.assertLess(recipe.index('0035-drm-'), recipe.index('0036-drm-'))
        patch = PATCH.read_text()
        self.assertIn('lcdif_set_boot_fb_compatible', patch)
        self.assertIn('fb->pitches[0] == 5120', patch)
        self.assertIn('pm_runtime_resume_and_get', patch)
        self.assertIn('pm_runtime_put_sync', patch)
        self.assertNotIn('dma_free', patch)

    def test_uboot_reservation_precedes_commit_and_os_preservation(self):
        patch = UBOOT.read_text()
        self.assertLess(patch.index('fdtdec_add_reserved_memory'),
                        patch.index('"status", "okay"'))
        self.assertLess(patch.index('video_sync(dev, true)'),
                        patch.index('"status", "okay"'))
        self.assertIn('FDTDEC_RESERVED_MEMORY_NO_MAP', patch)
        self.assertIn('"status", "disabled"', patch)
        self.assertIn('aesl,continuous-display-v1', patch)
        self.assertIn('priv->os_handover = false', patch)
        self.assertIn('if (priv->os_handover)', patch)
        self.assertIn('"assigned-clock-parents"', patch)
        self.assertIn('"assigned-clock-rates"', patch)
        self.assertIn('memcpy(parents, saved_parents, parents_len)', patch)

    def test_headless_and_recovery_do_not_advertise_handover(self):
        recipe = (ROOT / 'recipes-bsp/device-tree/lmp-device-tree.bbappend').read_text()
        self.assertIn("'display-boot-splash', '-DAESL_CONTINUOUS_DISPLAY', ''", recipe)
        dts = (ROOT / 'recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts').read_text()
        self.assertIn('#ifdef AESL_CONTINUOUS_DISPLAY', dts)
        self.assertIn('aesl,continuous-display-v1;', dts)


if __name__ == '__main__':
    unittest.main()
