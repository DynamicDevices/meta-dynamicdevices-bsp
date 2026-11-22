#!/usr/bin/env python3
"""Execute the shipped kernel admission/mode policy in native C fixtures.

Hardware, clocks, PM ownership and visual continuity still require integration
review, the target kernel build and a watched DT510 boot. These are not a
kernel build or a simulated TV.
"""
from pathlib import Path
import os
import re
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
    def test_compiled_uboot_removal_keeps_admitted_power_domain(self):
        part = UBOOT.read_text().split('+++ b/drivers/core/device-remove.c\n', 1)[1]
        part = part.split('\ndiff --git ', 1)[0]
        source = '\n'.join(line[1:] for line in part.splitlines()
                           if line.startswith(('+', ' ')))
        condition = source[source.index('if (!(flags & DM_REMOVE_NO_PD)'):]
        fixture = r'''
#include <assert.h>
#define DM_REMOVE_NO_PD 2
#define DM_FLAG_DEFAULT_PD_CTRL_OFF (1 << 11)
#define DM_FLAG_LEAVE_PD_ON (1 << 13)
struct device { unsigned int flags; } device, serial;
struct driver { unsigned int flags; } driver;
struct { struct device *cur_serial_dev; } globals, *gd = &globals;
static int powers_off;
static unsigned int dev_get_flags(struct device *d) { return d->flags; }
static void dev_power_domain_off(struct device *d) { powers_off++; }
static void remove_device(unsigned int flags) {
    struct device *dev = &device;
    struct driver *drv = &driver;
    /* ACTUAL_CORE_CONDITION */
}
int main(void) {
    remove_device(0); assert(powers_off == 1);
    /* Only the validated firmware-ABI commit sets the runtime flag. */
    device.flags = DM_FLAG_LEAVE_PD_ON;
    remove_device(0); assert(powers_off == 1 && !driver.flags);
    /* Failed/absent/old-image handover clears it: normal removal remains. */
    device.flags = 0; remove_device(0); assert(powers_off == 2);
    remove_device(DM_REMOVE_NO_PD); assert(powers_off == 2);
    driver.flags = DM_FLAG_LEAVE_PD_ON;
    remove_device(0); assert(powers_off == 2);
    driver.flags = DM_FLAG_DEFAULT_PD_CTRL_OFF;
    remove_device(0); assert(powers_off == 2);
    driver.flags = 0; gd->cur_serial_dev = &device;
    remove_device(0); assert(powers_off == 2);
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'remove.c').write_text(fixture.replace('/* ACTUAL_CORE_CONDITION */', condition))
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'remove.c'),
                            '-o', str(root / 'remove')], check=True)
            subprocess.run([str(root / 'remove')], check=True)

    def test_compiled_dsim_reset_clock_release(self):
        source = added_file(PATCH, 'drivers/pmdomain/imx/imx8m-blk-ctrl.c')
        helper = 'int dt510_boot_display_drop_dsim_clocks(' + source.split(
            'int dt510_boot_display_drop_dsim_clocks(', 1)[1].split(
                'EXPORT_SYMBOL_GPL', 1)[0]
        fixture = r'''
#include <assert.h>
#include <stdbool.h>
#include <errno.h>
#define EPROBE_DEFER 517
#define IMX8MM_DISPBLK_PD_MIPI_DSI 2
struct device { void *of_node; } device;
struct of_phandle_args { void *np; int args_count; unsigned int args[1]; } topology;
struct platform_device { struct device dev; } provider;
struct domain_data { int num_clks; } data = {2};
struct imx8m_blk_ctrl_domain {
    struct { int mlock; } genpd;
    bool boot_clocks; struct domain_data *data; void *clks;
};
struct imx8m_blk_ctrl {
    struct { unsigned int num_domains; } onecell_data;
    struct imx8m_blk_ctrl_domain domains[3];
} bc;
static bool machine, compatible, found, ready;
static int parse_error, node_refs, device_refs, releases, locked;
static bool of_machine_is_compatible(const char *s) { return machine; }
static int of_parse_phandle_with_args(void *n, const char *p, const char *c,
                                      int index, struct of_phandle_args *a) {
    if (parse_error) return parse_error;
    *a = topology; node_refs++; return 0;
}
static bool of_device_is_compatible(void *n, const char *s) { return compatible; }
static void of_node_put(void *n) { node_refs--; }
static struct platform_device *of_find_device_by_node(void *n) {
    if (!found) return 0; device_refs++; return &provider;
}
static struct imx8m_blk_ctrl *platform_get_drvdata(struct platform_device *p) {
    return ready ? &bc : 0;
}
static void put_device(struct device *d) { device_refs--; }
static void mutex_lock(int *p) { assert(!locked); locked++; }
static void mutex_unlock(int *p) { assert(locked); locked--; }
static void clk_bulk_disable_unprepare(int count, void *clks) {
    assert(locked && count == 2); releases++;
}
/* ACTUAL_RELEASE */
static void reset(void) {
    machine = compatible = found = ready = true;
    parse_error = node_refs = device_refs = releases = locked = 0;
    topology.args_count = 1; topology.args[0] = 2;
    bc.onecell_data.num_domains = 3;
    bc.domains[2].boot_clocks = true; bc.domains[2].data = &data;
}
static void balanced(void) { assert(!node_refs && !device_refs && !locked); }
int main(void) {
    reset(); assert(!dt510_boot_display_drop_dsim_clocks(&device)); balanced();
    assert(releases == 1 && !bc.domains[2].boot_clocks);
    assert(!dt510_boot_display_drop_dsim_clocks(&device)); balanced();
    assert(releases == 1);
    reset(); machine = false;
    assert(!dt510_boot_display_drop_dsim_clocks(&device) && !releases); balanced();
    reset(); parse_error = -EINVAL;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EINVAL); balanced();
    reset(); topology.args[0] = 0;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EINVAL); balanced();
    reset(); compatible = false;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EINVAL); balanced();
    reset(); found = false;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EPROBE_DEFER); balanced();
    reset(); ready = false;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EPROBE_DEFER); balanced();
    reset(); bc.onecell_data.num_domains = 2;
    assert(dt510_boot_display_drop_dsim_clocks(&device) == -EPROBE_DEFER); balanced();
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'release.c').write_text(fixture.replace('/* ACTUAL_RELEASE */', helper))
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'release.c'),
                            '-o', str(root / 'release')], check=True)
            subprocess.run([str(root / 'release')], check=True)

    def test_dt510_fallback_clock_is_named_oscillator(self):
        dts = (ROOT / 'recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-dt510.dts').read_text()
        node = dts.split('&mipi_dsi {', 1)[1]
        clocks = node.split('clocks =', 1)[1].split(';', 1)[0]
        names = node.split('clock-names =', 1)[1].split(';', 1)[0]
        self.assertEqual(re.findall(r'<&clk (\w+)>', clocks), [
            'IMX8MM_CLK_DSI_CORE', 'IMX8MM_CLK_DSI_PHY_REF',
            'IMX8MM_CLK_DISP_APB_ROOT', 'IMX8MM_CLK_24M'])
        self.assertEqual(re.findall(r'"([^"]+)"', names),
                         ['cfg', 'pll-ref', 'apb-root', 'fallback-pll-ref'])

    def test_compiled_lcdif_snapshot_detector(self):
        source = added_file(PATCH, 'drivers/gpu/imx/lcdif/lcdif-common.c')
        detector = source.split('static bool lcdif_boot_running(', 1)[1]
        detector = 'static bool lcdif_boot_running(' + detector.split(
            '\nstatic void lcdif_boot_put', 1)[0]
        fixture = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
typedef uint32_t u32;
/* Linux's task macro must remain visible to the shipped detector. */
#define current get_current()
#define ARRAY_SIZE(a) (sizeof(a) / sizeof((a)[0]))
#define LCDIF_CTRL 0
#define LCDIF_CUR_BUF 0x40
#define CTRL_RUN 1
#define CTRL_GET_WORD_LENGTH(x) (((x) >> 8) & 3)
struct dt510_boot_display { uint64_t address; u32 lcdif[10]; } snapshot;
struct lcdif_soc { void *base, *dev; } display;
#define dev_info(...) ((void)0)
static u32 registers[0xc0 / sizeof(u32)];
static bool valid;
static unsigned int reads;
static bool dt510_boot_display_read(struct dt510_boot_display *p) {
    *p = snapshot; return valid;
}
static u32 readl(void *p) { reads++; return *(u32 *)p; }
/* ACTUAL_DETECTOR */
static void reset(void) {
    const unsigned int offsets[] = {0, 0x10, 0x30, 0x40, 0x50,
                                   0x70, 0x80, 0x90, 0xa0, 0xb0};
    const u32 values[] = {0xa0f21, 0x70300, 0x2d00500, 0xbce00000,
        0xbce00000, 0x10300005, 0x2ee, 0xa00674, 0x1040019, 0x40500};
    snapshot.address = 0xbce00000;
    memcpy(snapshot.lcdif, values, sizeof(values));
    memset(registers, 0, sizeof(registers));
    for (unsigned int i = 0; i < ARRAY_SIZE(offsets); i++)
        registers[offsets[i] / sizeof(u32)] = values[i];
    display.base = registers; valid = true; reads = 0;
}
int main(void) {
    reset(); assert(lcdif_boot_running(&display));
    const unsigned int checked[] = {0x30, 0x70, 0x80, 0x90, 0xa0, 0xb0};
    for (unsigned int i = 0; i < ARRAY_SIZE(checked); i++) {
        reset(); registers[checked[i] / sizeof(u32)] ^= 1;
        assert(!lcdif_boot_running(&display));
    }
    reset(); registers[0] &= ~CTRL_RUN; assert(!lcdif_boot_running(&display));
    reset(); registers[0] &= ~(3 << 8); assert(!lcdif_boot_running(&display));
    reset(); registers[LCDIF_CUR_BUF / sizeof(u32)] += 4096;
    assert(!lcdif_boot_running(&display));
    reset(); valid = false;
    assert(!lcdif_boot_running(&display) && !reads);
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'snapshot.c').write_text(fixture.replace('/* ACTUAL_DETECTOR */', detector))
            subprocess.run(['cc', '-std=gnu11', '-Werror', str(root / 'snapshot.c'),
                            '-o', str(root / 'snapshot')], check=True)
            subprocess.run([str(root / 'snapshot')], check=True)

    def test_compiled_blk_ctrl_reads_only_after_bus_resume(self):
        part = PATCH.read_text().split('+++ b/drivers/pmdomain/imx/imx8m-blk-ctrl.c\n', 1)[1]
        part = part.split('\ndiff --git ', 1)[0]
        hunk = part.split('@@ -131,', 1)[1].split('\n', 1)[1]
        hunk = hunk.split('@@', 1)[0]
        body = '\n'.join(line[1:] for line in hunk.splitlines()
                         if line.startswith(('+', ' ')))
        body = body.split('/* enable upstream and blk-ctrl clocks', 1)[0]
        fixture = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
enum { BLK_SFT_RSTN, BLK_CLK_EN, BLK_MIPI_RESET_DIV };
struct dt510_boot_display { int unused; };
struct generic_pm_domain { int unused; };
struct imx8m_blk_ctrl_domain_data {
    const char *name; u32 rst_mask, clk_mask, mipi_phy_rst_mask;
};
struct imx8m_blk_ctrl { void *bus_power_dev, *regmap, *dev; } bc;
struct imx8m_blk_ctrl_domain {
    const struct imx8m_blk_ctrl_domain_data *data;
    struct imx8m_blk_ctrl *bc; void *power_dev; bool boot_seen;
} domain_state;
static bool awake, descriptor;
static int resume_result, resumes, puts, reads, clears, read_error;
static u32 values[3];
static struct imx8m_blk_ctrl_domain *to_imx8m_blk_ctrl_domain(void *p) {
    return &domain_state;
}
static int pm_runtime_get_sync(void *p) {
    resumes++; awake = resume_result >= 0; return resume_result;
}
static void pm_runtime_put_noidle(void *p) { puts++; }
#define dev_err(...) ((void)0)
#define dev_info(...) ((void)0)
static bool dt510_boot_display_read(struct dt510_boot_display *p) { return descriptor; }
static int regmap_read(void *p, int offset, u32 *value) {
    assert(awake); reads++; *value = values[offset]; return read_error;
}
static void regmap_clear_bits(void *p, int offset, u32 mask) {
    assert(awake); clears++;
}
static int power_on(struct generic_pm_domain *genpd) {
    struct imx8m_blk_ctrl_domain *domain = to_imx8m_blk_ctrl_domain(genpd);
    /* ACTUAL_PREFIX */
    return inherit;
}
static void reset(void) {
    awake = false; descriptor = true; resume_result = 0;
    resumes = puts = reads = clears = read_error = 0;
    domain_state.boot_seen = false; domain_state.power_dev = &bc;
    values[0] = 1; values[1] = 2; values[2] = 4;
}
int main(void) {
    struct imx8m_blk_ctrl_domain_data data = { "dispblk-lcdif", 1, 2, 4 };
    domain_state.data = &data; domain_state.bc = &bc;
    reset(); domain_state.power_dev = 0;
    assert(power_on(0) == -ENODEV && !resumes && !reads && !domain_state.boot_seen);
    reset(); resume_result = -EIO;
    assert(power_on(0) == -EIO && resumes == 1 && puts == 1);
    assert(!reads && !clears && !domain_state.boot_seen);
    reset(); assert(power_on(0) == 1 && reads == 3 && !clears);
    assert(domain_state.boot_seen);
    assert(power_on(0) == 0 && reads == 3 && clears == 2);
    reset(); data.name = "dispblk-mipi-dsi";
    assert(power_on(0) == 1 && reads == 3 && !clears);
    reset(); values[2] = 0;
    assert(power_on(0) == 0 && reads == 3 && clears == 2);
    reset(); read_error = -EIO;
    assert(power_on(0) == 0 && reads == 1 && clears == 2);
    reset(); descriptor = false;
    assert(power_on(0) == 0 && !reads && clears == 2);
    reset(); data.name = "unrelated-domain";
    assert(power_on(0) == 0 && !reads && clears == 2);
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'power.c').write_text(fixture.replace('/* ACTUAL_PREFIX */', body))
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'power.c'),
                            '-o', str(root / 'power')], check=True)
            subprocess.run([str(root / 'power')], check=True)

    def test_uboot_four_lane_timing_matches_retained_mode(self):
        bridge = (ROOT / 'recipes-bsp/u-boot/u-boot-fio/imx8mm-jaguar-dt510/lt9611-dt510.c').read_text()
        timing = bridge.split('static const struct display_timing lt9611_timing = {', 1)[1].split('};', 1)[0]
        fields = {name: int(value) for name, value in re.findall(
            r'\.(hactive|hfront_porch|hsync_len|hback_porch) = \{ (\d+),', timing)}
        self.assertEqual(fields['hfront_porch'], 112)
        self.assertEqual(sum(fields.values()), 1652)

    def test_compiled_dsim_reference_adoption_does_not_set_rate(self):
        # Execute the complete shipped function, including strict fallback.
        part = PATCH.read_text().split('+++ b/drivers/gpu/drm/imx/sec_mipi_dsim-imx.c\n', 1)[1]
        part = part.split('\ndiff --git ', 1)[0]
        part = part.split(' static int sec_dsim_determine_pll_ref_rate(', 1)[1]
        part = part.split('\n@@', 1)[0]
        adoption = 'static int sec_dsim_determine_pll_ref_rate(u32 *rate, u32 min, u32 max)\n' + '\n'.join(
            line[1:] for line in part.splitlines() if line.startswith(('+', ' ')))
        suspend_part = PATCH.read_text().split('@@ -523,', 1)[1]
        suspend_part = suspend_part.split('\n', 1)[1].split('@@', 1)[0]
        suspend = '\n'.join(line[1:] for line in suspend_part.splitlines()
                            if line.startswith(('+', ' ')))
        suspend = suspend.split('sec_mipi_dsim_suspend(dev);', 1)[0] + 'return 0;\n}'
        fixture = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <errno.h>
typedef uint32_t u32;
struct device { void *of_node; } dev;
struct { bool boot_running, clocks_active; int rpm_suspended;
    void *clk_pllref, *clk_pllref_fallback, *clk_cfg, *clk_apb;
    struct device *dev; } state, *dsim_dev = &state;
static unsigned long observed_rate;
static int parent_calls, rate_calls, parent_error, rate_error;
static int own_refs, reset_refs, drop_error, prepare_error;
static int rejections;
static bool on_oscillator;
#define PHY_REF_CLK 12000
#define clamp(v, lo, hi) ((v) < (lo) ? (lo) : (v) > (hi) ? (hi) : (v))
#define WARN_ON(v) (v)
#define unlikely(v) (v)
#define dev_warn(...) ((void)0)
#define dev_info(...) ((void)0)
#define BUS_FREQ_HIGH 1
static void release_bus_freq(int x) {}
static void atomic_set(int *p, int x) { *p = x; }
static int atomic_inc_return(int *p) { return ++*p; }
static int dt510_boot_display_drop_dsim_clocks(struct device *d) {
    if (drop_error) return drop_error;
    reset_refs = 0; return 0;
}
static void clk_disable_unprepare(void *clk) {
    if (clk == state.clk_pllref) { assert(own_refs == 1); own_refs--; }
}
static int clk_prepare_enable(void *clk) {
    assert(own_refs == 0);
    if (prepare_error) return prepare_error;
    own_refs++; return 0;
}
static void dt510_boot_display_reject(void) { rejections++; }
static int of_property_read_u32(void *n, const char *s, u32 *v) { return -ENOENT; }
static unsigned long clk_get_rate(void *clk) { return observed_rate; }
static int clk_set_parent(void *clk, void *parent) {
    parent_calls++; if (parent_error) return parent_error;
    if (own_refs || reset_refs) return -EBUSY;
    on_oscillator = true; return 0;
}
static int clk_set_rate(void *clk, unsigned long rate) {
    rate_calls++; if (rate_error) return rate_error;
    observed_rate = on_oscillator ? rate : 11948276; return 0;
}
/* ACTUAL_ADOPTION */
/* ACTUAL_SUSPEND_PREFIX */
static void reset(void) {
    state.dev = &dev; state.boot_running = true;
    state.clk_pllref_fallback = &dev;
    state.clk_pllref = &state;
    state.clocks_active = false; own_refs = 0; reset_refs = 1;
    drop_error = prepare_error = 0;
    parent_calls = rate_calls = parent_error = rate_error = 0;
    rejections = 0;
    on_oscillator = false;
}
int main(void) {
    u32 rate = 0;
    const unsigned long valid[] = {27000000, 47250000, 6000000, 300000000};
    for (unsigned int i = 0; i < sizeof(valid) / sizeof(valid[0]); i++) {
        reset(); observed_rate = valid[i];
        assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == 0);
        assert(rate == observed_rate / 1000 && !parent_calls && !rate_calls);
        assert(state.boot_running);
        assert(!rejections);
        assert(reset_refs == 1);
    }
    const unsigned long invalid[] = {0, 5999000, 300001000, 11948276};
    for (unsigned int i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
        reset(); observed_rate = invalid[i];
        assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == 0);
        assert(!state.boot_running && parent_calls == 1 && rate_calls == 1);
        assert(rejections == 1);
        assert(rate == 12000 && observed_rate == 12000000);
    }
    reset(); state.boot_running = false; observed_rate = 27000000;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == 0);
    assert(parent_calls == 1 && rate_calls == 1 && rate == 12000);
    /* Reproduce714: retained video parent cannot supply the exact default. */
    reset(); state.boot_running = false; state.clk_pllref_fallback = 0;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EINVAL);
    assert(!parent_calls && rate_calls == 1 && observed_rate == 11948276);
    reset(); state.boot_running = false; parent_error = -EIO;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EIO);
    assert(parent_calls == 1 && !rate_calls);
    reset(); state.boot_running = false; rate_error = -EIO;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EIO);
    assert(parent_calls == 1 && rate_calls == 1);
    reset(); state.boot_running = false; state.clocks_active = true; own_refs = 1;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == 0);
    assert(own_refs == 1 && !reset_refs && state.clocks_active);
    reset(); state.boot_running = false; state.clocks_active = true; own_refs = 1;
    parent_error = -EIO;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EIO);
    assert(own_refs == 1 && !reset_refs && !rate_calls);
    reset(); state.boot_running = false; drop_error = -EIO;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EIO);
    assert(reset_refs == 1 && !parent_calls && !rate_calls);
    reset(); state.boot_running = false; state.clocks_active = true; own_refs = 1;
    prepare_error = -EIO;
    assert(sec_dsim_determine_pll_ref_rate(&rate, 6000, 300000) == -EIO);
    assert(!own_refs && !state.clocks_active && state.rpm_suspended == 1);
    /* Bind failure invokes runtime suspend after clocks were already unwound. */
    assert(!imx_sec_dsim_runtime_suspend(&dev) && state.rpm_suspended == 1);
    /* The next resume must reach zero and reacquire its clock, not return early. */
    prepare_error = 0;
    assert(--state.rpm_suspended == 0);
    assert(!clk_prepare_enable(state.clk_pllref) && own_refs == 1);
}
'''
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'clock.c').write_text(fixture.replace('/* ACTUAL_ADOPTION */', adoption)
                                        .replace('/* ACTUAL_SUSPEND_PREFIX */', suspend))
            subprocess.run(['cc', '-std=c11', '-Werror', str(root / 'clock.c'),
                            '-o', str(root / 'clock')], check=True)
            subprocess.run([str(root / 'clock')], check=True)

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
#define IS_ENABLED(x) 1
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
static int atomic_xchg(atomic_t *p, int v) {
    int old = p->counter; p->counter = v; return old;
}
static int reject_logs;
#define pr_info(...) (reject_logs++)
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
    reject_logs = 0;
    atomic_set(&dt510_boot_failed, 0); atomic_set(&dt510_boot_claims, 0);
    /* Actual descriptor from image712, not an idealised CEA timing fixture. */
    address = 0xbce00000; region.base = address; region.size = 0x11e0000;
    width = 1280; height = 720; stride = 5120; format = "x8r8g8b8";
    const u32 captured[] = {0xa0f21, 0x70300, 0x2d00500, 0xbce00000,
        0xbce00000, 0x10300005, 0x2ee, 0xa00674, 0x1040019, 0x40500};
    memcpy(regs, captured, sizeof(regs)); missing = 0;
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
    dt510_boot_display_reject(); assert(reject_logs == 1);
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
    regs[7] = (40U << 18) | 1650; check(false); defaults();
    region.size = 1280 * 720 * 4 - 1; check(false); defaults();
    region.base++; check(false); defaults();
    region.base = address - 4096; region.size = 1280 * 720 * 4; check(false); defaults();
    region.base = address - 4096; region.size = 1280 * 720 * 4 + 4096; check(true);
    struct videomode vm = {74250000, 1280, 112, 40, 220, 720, 5, 5, 20, 3};
    assert(dt510_boot_mode_matches(&vm));
    for (u32 f = 0; f < 16; f++) { vm.flags = f; assert(dt510_boot_mode_matches(&vm) == (f == 3)); }
    vm.flags = 3; vm.pixelclock--; assert(!dt510_boot_mode_matches(&vm));
    vm.pixelclock++; vm.hfront_porch--; assert(!dt510_boot_mode_matches(&vm));
    vm.hfront_porch = 110; assert(!dt510_boot_mode_matches(&vm));
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
        self.assertIn('dev_bic_flags(dev, DM_FLAG_LEAVE_PD_ON)', patch)
        self.assertGreater(patch.index('dev_or_flags(dev, DM_FLAG_LEAVE_PD_ON)'),
                           patch.index('"status", "okay"'))
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
