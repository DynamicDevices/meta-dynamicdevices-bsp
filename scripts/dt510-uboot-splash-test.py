#!/usr/bin/env python3
"""Native actual-source regressions; not a U-Boot hardware/handover test."""
import hashlib
import argparse
import importlib.util
from pathlib import Path
import re
import subprocess
import tempfile
import textwrap
from types import SimpleNamespace

BSP = Path(__file__).resolve().parents[1]
FILES = BSP / 'recipes-bsp/u-boot/u-boot-fio/imx8mm-jaguar-dt510'
GIT = '/home/ajlennon/.local/bin/harness-git'


def run(args):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(f'{args[0]} failed: {(result.stderr or result.stdout)[:2000]}')
    return result.stdout


def native(work):
    source = (FILES / 'lt9611-dt510.c').read_text()
    source = re.sub(r'^#include.*\n', '', source, flags=re.M)
    source = source.split('static const struct panel_ops')[0]
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
typedef uint8_t u8; typedef uint16_t u16;
#define ARRAY_SIZE(x) (sizeof(x)/sizeof((x)[0]))
#define DISPLAY_FLAGS_HSYNC_HIGH 1
#define DISPLAY_FLAGS_VSYNC_HIGH 2
#define MIPI_DSI_FMT_RGB888 3
#define MIPI_DSI_MODE_VIDEO 1
#define MIPI_DSI_MODE_VIDEO_SYNC_PULSE 2
#define MIPI_DSI_MODE_VIDEO_HSE 4
#define GPIOD_IS_OUT 1
#define dev_err(...) ((void)0)
#define dev_info(...) ((void)0)
struct gpio_desc { int value; };
struct timing_entry { unsigned int min,typ,max; };
struct display_timing {
 struct timing_entry pixelclock,hactive,hfront_porch,hback_porch,hsync_len;
 struct timing_entry vactive,vfront_porch,vback_porch,vsync_len; unsigned int flags;
};
struct mipi_dsi_device { int lanes,format,mode_flags; };
struct mipi_dsi_panel_plat { struct mipi_dsi_device *device; };
struct udevice { void *priv,*plat; };
static void *dev_get_priv(struct udevice *d) { return d->priv; }
static void *dev_get_plat(struct udevice *d) { return d->plat; }
static unsigned int lanes=4;
static int gpio_request_ret,attach_ret,bus_calls,bus_fail,gpio_calls,gpio_fail;
static int attach_calls,bank,reset_values[4],wait_values[8],wait_count;
static u8 regs[256][256];
static int dev_read_u32_default(struct udevice *d,const char *s,int def)
{ (void)d;(void)def;assert(!strcmp(s,"dsi-lanes"));return lanes; }
static int gpio_request_by_name(struct udevice *d,const char *s,int n,struct gpio_desc *g,int f)
{ (void)d;(void)g;assert(!strcmp(s,"reset-gpios") && !n && f==GPIOD_IS_OUT);return gpio_request_ret; }
static int dm_gpio_set_value(struct gpio_desc *g,int v)
{ assert(gpio_calls<4);reset_values[gpio_calls++]=v;if(gpio_calls==gpio_fail)return -EIO;g->value=v;return 0; }
static void mdelay(unsigned int ms) { assert(wait_count<8);wait_values[wait_count++]=ms; }
static int mipi_dsi_attach(struct mipi_dsi_device *d)
{ assert(d);attach_calls++;return attach_ret; }
static int dm_i2c_write(struct udevice *d,unsigned int reg,const u8 *v,int n)
{ (void)d;assert(n==1 && reg<=255);if(++bus_calls==bus_fail)return -EIO;
  if(reg==255)bank=*v;else regs[bank][reg]=*v;return 0; }
static int dm_i2c_read(struct udevice *d,unsigned int reg,u8 *v,int n)
{ (void)d;assert(n==1 && reg==2 && bank==0x80);if(++bus_calls==bus_fail)return -EIO;*v=0xe1;return 0; }
'''
    harness += source + r'''
static void reset_model(void)
{ bus_calls=bus_fail=gpio_calls=gpio_fail=attach_calls=attach_ret=wait_count=0;memset(regs,0,sizeof(regs)); }
int main(void)
{
 struct lt9611_priv priv={0};struct mipi_dsi_device dsi={0};
 struct mipi_dsi_panel_plat plat={.device=&dsi};
 struct udevice dev={.priv=&priv,.plat=&plat};struct display_timing t;
 assert(!lt9611_probe(&dev) && priv.page==-1);
 lanes=2;assert(lt9611_probe(&dev)==-EINVAL);lanes=4;
 gpio_request_ret=-EBUSY;assert(lt9611_probe(&dev)==-EBUSY);gpio_request_ret=0;
 assert(!lt9611_get_timing(&dev,&t));
 assert(t.pixelclock.typ==74250000 && t.hactive.typ==1280 && t.vactive.typ==720);
 assert(t.hactive.typ+t.hfront_porch.typ+t.hback_porch.typ+t.hsync_len.typ==1650);
 assert(t.vactive.typ+t.vfront_porch.typ+t.vback_porch.typ+t.vsync_len.typ==750);
 assert(dsi.lanes==4 && dsi.format==MIPI_DSI_FMT_RGB888 && dsi.mode_flags==7);
 reset_model();assert(lt9611_set_backlight(&dev,100)==-EPIPE && !bus_calls);
 assert(lt9611_set_backlight(&dev,50)==-EINVAL && !bus_calls);
 assert(!lt9611_enable(&dev) && priv.configured && !priv.enabled);
 assert(gpio_calls==3 && reset_values[0]==0 && reset_values[1]==1 && reset_values[2]==0);
 assert(wait_count==3 && wait_values[0]==100 && wait_values[1]==20 && wait_values[2]==100);
 assert(regs[0x81][1]==0x18 && regs[0x83][0]==0 && regs[0x83][0xa]==0);
 assert(regs[0x83][0xd]*256+regs[0x83][0xe]==750);
 assert(regs[0x83][0x11]*256+regs[0x83][0x12]==1650);
 assert(regs[0x83][0x13]*256+regs[0x83][0x14]==1280);
 assert(regs[0x83][0xf]*256+regs[0x83][0x10]==720);
 assert(regs[0x81][0x2d]==0x99 && regs[0x83][0x26]==74250*5*2/27000);
 assert(regs[0x82][0xe3]==(74250>>17) && regs[0x82][0xe4]==((74250>>9)&255) && regs[0x82][0xe5]==((74250>>1)&255));
 unsigned int sum=0;for(int n=0;n<17;n++)sum+=regs[0x84][0x40+n];assert(!(sum&255));
 assert(regs[0x84][0x40]==0x82 && regs[0x84][0x47]==4 && regs[0x81][0x30]==0x6a);
 int count=bus_calls;assert(!lt9611_enable(&dev) && bus_calls==count && attach_calls==1);
 for(int n=1;n<=count;n++) {
   reset_model();priv.configured=priv.enabled=false;priv.page=-1;bus_fail=n;
   assert(lt9611_enable(&dev)==-EIO && !priv.configured && !priv.enabled && bus_calls==n && priv.page==-1);
 }
 for(int n=1;n<=3;n++) {
   reset_model();priv.configured=priv.enabled=false;gpio_fail=n;
   assert(lt9611_enable(&dev)==-EIO && !priv.enabled && !bus_calls);
 }
 reset_model();priv.configured=priv.enabled=false;attach_ret=-EAGAIN;
 assert(lt9611_enable(&dev)==-EAGAIN && !gpio_calls && !bus_calls);
 attach_ret=0;plat.device=0;assert(lt9611_enable(&dev)==-ENODEV && !bus_calls);
 assert(!lt9611_get_timing(&dev,&t));
 /* Final TX enable is a distinct, fault-checked post-stream operation. */
 plat.device=&dsi;assert(!lt9611_enable(&dev));
 count=bus_calls;
 assert(!lt9611_set_backlight(&dev,100) && priv.enabled && regs[0x81][0x30]==0xea);
 assert(wait_values[3]==500);
 int tx_count=bus_calls-count;
 assert(tx_count==2);
 count=bus_calls;assert(!lt9611_set_backlight(&dev,100) && bus_calls==count);
 assert(!lt9611_set_backlight(&dev,0) && !priv.enabled && regs[0x81][0x30]==0x6a);
 for(int n=1;n<=tx_count;n++) {
   reset_model();priv.page=-1;bus_fail=n;
   assert(lt9611_set_backlight(&dev,100)==-EIO && !priv.enabled && priv.page==-1 && bus_calls==n);
 }
 return 0;
}
'''
    src, binary = work/'lt9611-native.c', work/'lt9611-native'
    src.write_text(harness)
    run(['cc','-std=c11','-Wall','-Wextra','-Werror','-fsanitize=address,undefined',str(src),'-o',str(binary)])
    run([str(binary)])
    print('PASS actual driver: every I2C/GPIO/attach fault, first-error exit, reset polarity, cached enable, 720p timing/PLL/PCR, four-lane portA and AVI checksum; ASan/UBSan. Not hardware proof.')


def packaging(work, boot_header=None):
    path = BSP/'recipes-bsp/u-boot/u-boot-ostree-scr-fit/imx8mm-jaguar-dt510/boot.cmd'
    template = path.read_text()
    marker = '@@DT510_HDMI_SPLASH@@\n'
    assert template.count(marker) == 1
    baseline = run([GIT,'-C',str(BSP),'show','643330e2fcc343fbfe26836d782345715851e94b:'+str(path.relative_to(BSP))])
    assert template.replace(marker,'') == baseline
    fragment = path.with_name('hdmi-splash.cmd').read_text()
    assert 'setenv' not in fragment and 'saveenv' not in fragment and 'bootargs' not in fragment
    run(['sh','-n',str(path.with_name('hdmi-splash.cmd'))])
    assert template.replace(marker,fragment).endswith('@@INCLUDE_COMMON_IMX@@\n@@INCLUDE_COMMON@@\n')
    recipe = BSP/'recipes-bsp/u-boot/u-boot-ostree-scr-fit.bbappend'
    hook = re.search(r'python do_unpack:append:imx8mm-jaguar-dt510\(\) \{\n(.*?)\n\}', recipe.read_text(), re.S)
    assert hook
    hook = compile(textwrap.dedent(hook[1]), str(recipe), 'exec')
    class Data:
        enabled = False
        def getVar(self, name):
            return str(work) if name == 'WORKDIR' else ('hdmi-boot-splash' if self.enabled else '')
    def fatal(message):
        raise ValueError(message)
    data = Data()
    bb = SimpleNamespace(fatal=fatal, utils=SimpleNamespace(contains=lambda var, item, yes, no, d: yes if item in d.getVar(var).split() else no))
    (work/'hdmi-splash.cmd').write_text(fragment)
    header = boot_header.read_text() if boot_header else '# unchanged common header\n'
    if boot_header:
        assert hashlib.sha256(boot_header.read_bytes()).hexdigest() == 'a07b08ee9b9689103ad0f2bfe6f407ef7d943400c93acf44315450fc163ec104'
        assert 'setenv image_dir_path' in header
    for enabled in (False, True, False):
        data.enabled = enabled
        (work/'boot.cmd').write_text(template)  # Each unpack refreshes the template.
        (work/'boot-header.cmd.in').write_text(header)
        exec(hook, {'d': data, 'bb': bb})
        assert (work/'boot.cmd').read_text() == baseline
        assert (work/'boot-header.cmd.in').read_text() == header + ('\n'+fragment if enabled else '')
        if enabled and boot_header:
            body = (work/'boot-header.cmd.in').read_text()
            assert body.index('setenv image_dir_path') < body.index('# Prefer the current OSTree')
    for bad in (baseline, template + marker):
        (work/'boot.cmd').write_text(bad)
        try:
            exec(hook, {'d': data, 'bb': bb})
        except ValueError:
            pass
        else:
            raise AssertionError('Missing/duplicate marker accepted')
    uboot_recipe = (BSP/'recipes-bsp/u-boot/u-boot-fio_%.bbappend').read_text()
    assert uboot_recipe.count('SRC_URI:append:imx8mm-jaguar-dt510 =') == 1
    firmware = (BSP/'recipes-bsp/lmp-boot-firmware/lmp-boot-firmware.bbappend').read_text()
    assert firmware.count('LMP_BOOT_FIRMWARE_FILES:append:imx8mm-jaguar-dt510 =') == 1
    assert 'zephyr.bin ${@bb.utils.contains' in firmware
    assert "'active-edge-splash-1280x720.bmp'" in firmware
    assert 'dt510-hdmi-splash:do_deploy' in firmware
    asset = BSP/'recipes-bsp/dt510-hdmi-splash/files'
    png = asset/'active-edge-splash-1920x1200.png'
    assert hashlib.sha256(png.read_bytes()).hexdigest() == '70469b3d038df99f829b0ed0fc3f09b8a16ed05a85f6d03ad2a382418a5bd67e'
    module = importlib.util.spec_from_file_location('dt510_art',asset/'make-splash.py')
    renderer = importlib.util.module_from_spec(module)
    module.loader.exec_module(renderer)
    target = work/'test.bmp'
    renderer.render(png,target)
    from PIL import Image
    with Image.open(target) as im:
        assert im.size==(1280,720) and im.mode=='RGB' and im.format=='BMP'
    data=target.read_bytes()
    assert data[:2]==b'BM' and int.from_bytes(data[28:30],'little')==24
    assert len(data)==1280*720*3+54
    assert hashlib.sha256(data).hexdigest() == '64b2f36f6305a8012d9dbab4ec2a266aba9f023bb4f4294eb30754dd37573da3'
    wrong = work/'wrong.png'
    Image.new('RGB',(1920,1200),'red').save(wrong)
    try:
        renderer.render(wrong,work/'wrong.bmp')
    except ValueError:
        pass
    else:
        raise AssertionError('Artwork drift must fail generation, not ship a rejected BMP')
    # Exercise the actual hush-compatible fragment with successful/failed commands.
    cases = ((0,1,0,0,'2a3036','displayed'), (1,0,0,0,'2a3036','displayed'), (1,1,0,0,'2a3036','skipped'), (0,0,0,1,'2a3036','skipped'), (0,0,1,0,'2a3036','skipped'), (0,0,0,0,'abc','skipped'))
    for ext_ok, fat_ok, hash_ok, bmp_ok, size, expected in cases:
        script = f'filesize={size}\next4load() {{ return {ext_ok}; }}\nload() {{ return {fat_ok}; }}\nhash() {{ return {hash_ok}; }}\nbmp() {{ return {bmp_ok}; }}\n' + fragment + '\necho LINUX_BOOT_CONTINUES\n'
        result = run(['sh','-c',script])
        assert expected in result and 'LINUX_BOOT_CONTINUES' in result
    # Check real load arguments and fallback order for both firmware locations.
    for image_dir in ('/ostree/deploy/lmp/deploy/current.0/usr/lib/firmware', '/boot/ostree/lmp-test'):
        for ext_ok in (0,1):
            prefix = f'devtype=mmc; devnum=2; ostree_bootpart=2; bootpart=1; image_dir_path={image_dir}; filesize=2a3036\n'
            prefix += f'ext4load() {{ printf "EXT:%s,%s,%s,%s,%s\\n" "$1" "$2" "$3" "$4" "$5"; return {ext_ok}; }}\n'
            prefix += 'load() { printf "FAT:%s,%s,%s,%s,%s\\n" "$1" "$2" "$3" "$4" "$5"; return 0; }\nhash() { return 0; }\nbmp() { return 0; }\n'
            result = run(['sh','-c',prefix+fragment])
            assert f'EXT:mmc,2:2,0x50000000,{image_dir}/active-edge-splash-1280x720.bmp,0x2a3036' in result
            assert ('FAT:mmc,2:1,0x50000000,active-edge-splash-1280x720.bmp,0x2a3036' in result) == bool(ext_ok)
    print('PASS actual unpack hook: boot body/header prefix unchanged, feature toggle/marker guards, splash after deployment-path resolution; OTA firmware delivery selection, ext4/FAT precedence, hash/size/display failures non-fatal and canonical BMP. Full recipe remains a Foundries gate.')


def host_order(work, source_root):
    """Compile the real patched NXP callback, not a parallel implementation."""
    source = (source_root/'drivers/video/nxp/imx/sec_dsim_imx.c').read_text()
    callback = source.split('static int imx_sec_dsim_set_backlight(')[1].split('\nstatic int imx_sec_dsim_probe')[0]
    callback = 'static int imx_sec_dsim_set_backlight(' + callback
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#define IS_ENABLED(x) (x)
#define CONFIG_VIDEO_LT9611_DT510 FEATURE
#define dev_err(...) ((void)0)
struct udevice { void *priv; const char *name; };
struct imx_sec_dsim_priv { struct udevice *panel, *dsi_host; };
static void *dev_get_priv(struct udevice *d) { return d->priv; }
static int stage, panel_ret, host_ret, tx_ret, disabled;
static bool compatible;
static int device_is_compatible(struct udevice *d, const char *s)
{ (void)d; assert(!strcmp(s,"lontium,lt9611")); return compatible; }
static int panel_enable_backlight(struct udevice *d)
{ (void)d; assert(stage++==0); return panel_ret; }
static int dsi_host_enable(struct udevice *d)
{ (void)d; assert(stage++==1); return host_ret; }
static int panel_set_backlight(struct udevice *d, int p)
{ (void)d; assert(p==100 && stage++==2); return tx_ret; }
static int dsi_host_disable(struct udevice *d)
{ (void)d; assert(stage==3); disabled++; return -EBUSY; }
'''
    harness += callback + r'''
int main(void) {
 struct udevice panel={0}, host={0};
 struct imx_sec_dsim_priv priv={.panel=&panel,.dsi_host=&host};
 struct udevice dev={.priv=&priv};
 compatible=true;
 assert(!imx_sec_dsim_set_backlight(&dev,100) && stage==(FEATURE?3:2));
 stage=0;compatible=false;
 assert(!imx_sec_dsim_set_backlight(&dev,100) && stage==2);
 stage=0;compatible=true;panel_ret=-EIO;
 assert(imx_sec_dsim_set_backlight(&dev,100)==-EIO && stage==1);
 stage=0;panel_ret=0;host_ret=-ETIMEDOUT;
 assert(imx_sec_dsim_set_backlight(&dev,100)==-ETIMEDOUT && stage==2);
 stage=0;host_ret=0;tx_ret=-ENXIO;
 int ret=imx_sec_dsim_set_backlight(&dev,100);
 assert(ret==(FEATURE?-ENXIO:0) && disabled==FEATURE);
 return 0;
}
'''
    src = work/'host-order.c'
    src.write_text(harness)
    for enabled in (0,1):
        binary = work/f'host-order-{enabled}'
        run(['cc','-Wall','-Wextra','-Wno-unused-parameter','-Werror',f'-DFEATURE={enabled}','-fsanitize=address,undefined',str(src),'-o',str(binary)])
        run([str(binary)])
    print('PASS actual NXP final callback: TX faults and cleanup preserve first error; feature-off/other-panel paths unchanged. Pixel-start ordering tested with LCDIF below.')


def patch_stack(work, cache):
    pin = 'adbe53791d8f3cc2d7ecf2a3f308494d561def9e'
    patches = [FILES/'01-customise-dtb.patch', FILES/'02-dt510-lt9611-splash.patch']
    target = work/'patch-stack'
    target.mkdir()
    for patch in patches:
        for name in re.findall(r'^--- a/(.+)$', patch.read_text(), re.M):
            path = target/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(run([GIT,'--git-dir='+str(cache),'show',pin+':'+name]))
        result = subprocess.run(['patch','--fuzz=0','-p1','-d',str(target)], input=patch.read_text(), capture_output=True, text=True)
        assert result.returncode == 0, result.stdout + result.stderr
        assert 'offset' not in result.stdout and 'fuzz' not in result.stdout
    print('PASS both U-Boot patches apply without offsets/fuzz to exact recipe source '+pin)


def lcdif_order(work, source_root):
    host = (source_root/'drivers/video/nxp/imx/sec_dsim_imx.c').read_text()
    host = 'static int imx_sec_dsim_set_backlight(' + host.split('static int imx_sec_dsim_set_backlight(')[1].split('\nstatic int imx_sec_dsim_probe')[0]
    lcdif = (source_root/'drivers/video/mxsfb.c').read_text()
    lcdif = 'static int mxs_video_probe(' + lcdif.split('static int mxs_video_probe(')[1].split('\nstatic int mxs_video_bind')[0]
    harness = r'''
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <errno.h>
typedef uint32_t u32;
#define CONFIG_VIDEO_LT9611_DT510 FEATURE
#define CONFIG_VIDEO_BRIDGE 1
#define CONFIG_DISPLAY 0
#define IS_ENABLED(x) (x)
#define CONFIG_IS_ENABLED(x) 0
#define DISPLAY_FLAGS_DE_HIGH 1
#define UCLASS_VIDEO_BRIDGE 1
#define UCLASS_PANEL 2
#define UCLASS_DISPLAY 3
#define MODULE_LCDIF 0
#define VIDEO_BPP32 5
#define VIDEO_BPP16 4
#define VIDEO_BPP8 3
#define DM_REMOVE_NORMAL 0
#define DCACHE_WRITEBACK 0
#define FDT_ADDR_T_NONE (~0UL)
#define debug(...) ((void)0)
#define dev_err(...) ((void)0)
#define printf(...) ((void)0)
struct driver { const char *name; };
struct video_uc_plat { unsigned long base; unsigned int size; };
struct video_priv { int bpix,xsize,ysize; };
struct udevice { void *priv,*plat,*uc_priv; const char *name,*compatible; struct driver *driver; };
struct display_timing { unsigned int flags; struct { int typ; } hactive,vactive; };
struct mxsfb_priv { unsigned long reg_base; struct udevice *disp_dev; };
struct imx_sec_dsim_priv { struct udevice *panel,*dsi_host; };
static struct { unsigned long fb_base; } gd_data,*gd=&gd_data;
static bool stream; static int tx_calls,common_calls,removed,stopped,host_calls;
static int common_ret,tx_ret,host_ret;
static void *dev_get_priv(struct udevice *d) { return d->priv; }
static void *dev_get_uclass_plat(struct udevice *d) { return d->plat; }
static void *dev_get_uclass_priv(struct udevice *d) { return d->uc_priv; }
static unsigned long dev_read_addr(struct udevice *d) { (void)d; return 1; }
static int mxs_of_get_timings(struct udevice *d,struct display_timing *t,u32 *bpp)
{ (void)d; memset(t,0,sizeof(*t));t->hactive.typ=1280;t->vactive.typ=720;*bpp=24;return 0; }
static int check_module_fused(int n) { (void)n;return 0; }
static int device_get_uclass_id(struct udevice *d) { (void)d;return UCLASS_VIDEO_BRIDGE; }
static bool device_is_compatible(struct udevice *d,const char *s)
{ return !strcmp(d->compatible,s); }
static int panel_enable_backlight(struct udevice *d) { (void)d;return 0; }
/* The real SEC DSIM host enable is a no-op, NOT stream start. */
static int dsi_host_enable(struct udevice *d) { (void)d;host_calls++;return host_ret; }
static int panel_set_backlight(struct udevice *d,int p)
{ (void)d;assert(stream && p==100);tx_calls++;return tx_ret; }
static int dsi_host_disable(struct udevice *d) { (void)d;return 0; }
static struct udevice *video_link_get_next_device(struct udevice *d)
{ struct imx_sec_dsim_priv *p=d->priv;return p->panel; }
static int video_bridge_attach(struct udevice *d) { (void)d;return 0; }
static int video_bridge_set_backlight(struct udevice *d,int p);
static int mxs_probe_common(struct udevice *d,struct display_timing *t,u32 bpp,unsigned long fb,bool bridge)
{ (void)d;(void)t;(void)fb;assert(bpp==24 && bridge && !stream && !tx_calls);common_calls++;if(!common_ret)stream=true;return common_ret; }
static int device_remove(struct udevice *d,int f) { (void)d;(void)f;removed++;return -EBUSY; }
static void mxs_remove_common(unsigned long reg,unsigned long fb)
{ (void)reg;(void)fb;stopped++;stream=false; }
static void mmu_set_region_dcache_behaviour(u32 a,u32 b,int c) { (void)a;(void)b;(void)c; }
static void video_set_flush_dcache(struct udevice *d,bool b) { (void)d;(void)b; }
'''
    harness += host + r'''
static int video_bridge_set_backlight(struct udevice *d,int p)
{ assert(p==80 || stream);return imx_sec_dsim_set_backlight(d,p); }
''' + lcdif + r'''
static void reset(void)
{ stream=false;tx_calls=common_calls=removed=stopped=host_calls=common_ret=tx_ret=host_ret=0; }
int main(void) {
 struct driver driver={.name="imx_sec_dsim"};
 struct udevice panel={.compatible="lontium,lt9611"},host={0};
 struct imx_sec_dsim_priv hp={.panel=&panel,.dsi_host=&host};
 struct udevice bridge={.priv=&hp,.driver=&driver,.compatible="fsl,imx8mm-mipi-dsim"};
 struct mxsfb_priv lp={.disp_dev=&bridge};
 struct video_uc_plat plat={.base=0x80000000,.size=0x1000000};struct video_priv vp={0};
 struct udevice dev={.priv=&lp,.plat=&plat,.uc_priv=&vp};
 reset();assert(!mxs_video_probe(&dev) && stream && tx_calls==FEATURE && common_calls==1);
 assert(host_calls==(FEATURE?2:1));
 reset();common_ret=-ETIMEDOUT;
 assert(mxs_video_probe(&dev)==-ETIMEDOUT && !stream && !tx_calls);
 reset();host_ret=-ENXIO;
 assert(mxs_video_probe(&dev)==-ENXIO && !common_calls && !tx_calls);
 reset();tx_ret=-EIO;int ret=mxs_video_probe(&dev);
 assert(ret==(FEATURE?-EIO:0) && removed==FEATURE && stopped==FEATURE);
 reset();panel.compatible="other,panel";
 assert(!mxs_video_probe(&dev) && stream && !tx_calls && host_calls==1);
 return 0;
}
'''
    src = work/'lcdif-order.c'
    src.write_text(harness)
    for enabled in (0,1):
        binary = work/f'lcdif-order-{enabled}'
        run(['cc','-Wall','-Wextra','-Werror',f'-DFEATURE={enabled}','-fsanitize=address,undefined',str(src),'-o',str(binary)])
        run([str(binary)])
    print('PASS actual LCDIF + NXP callbacks: host enable is a no-op; TX only after mxs_probe_common starts pixels; LCDIF/host/TX faults, cleanup, feature-off and other panels.')


def control_dt(build):
    new = build/'arch/arm/dts/imx8mm-jaguar-dt510-uboot.dtb'
    old = build/'arch/arm/dts/imx8mm-evk.dtb'
    def get(dtb, path, prop):
        return run(['fdtget', str(dtb), path, prop]).strip()
    # Preserve console, storage numbering and all original MMC properties.
    for node in ('/aliases','/chosen','/soc@0/bus@30800000/mmc@30b40000','/soc@0/bus@30800000/mmc@30b50000','/soc@0/bus@30800000/mmc@30b60000'):
        properties = run(['fdtget','-p',str(old),node]).splitlines()
        assert properties == run(['fdtget','-p',str(new),node]).splitlines()
        for prop in properties:
            # phandles may be renumbered; compare referenced node paths separately.
            if prop not in ('phandle','pinctrl-0','pinctrl-1','pinctrl-2','mmc-pwrseq','vmmc-supply','vqmmc-supply'):
                assert get(old,node,prop) == get(new,node,prop), (node,prop)
    bus = '/soc@0/bus@30800000/i2c@30a40000'
    bridge = bus+'/lt9611@39'
    assert get(new, bridge, 'compatible') == 'lontium,lt9611'
    assert get(new, bridge, 'dsi-lanes') == '4'
    reset = get(new, bridge, 'reset-gpios').split()
    assert reset[1:] == ['11','1']  # fdtget decimal default: GPIO2_IO11, active low.
    assert get(new,bus,'clock-frequency') == '100000'
    dsi = '/soc@0/bus@32c00000/mipi_dsi@32e10000'
    endpoint = dsi+'/port@1/endpoint'
    panel_endpoint = bridge+'/port/endpoint'
    assert get(new,endpoint,'remote-endpoint') == get(new,panel_endpoint,'phandle')
    assert get(new,panel_endpoint,'remote-endpoint') == get(new,endpoint,'phandle')
    config = (build/'.config').read_text()
    for key in ('VIDEO_LT9611_DT510','FIT_SIGNATURE_STRICT','SPL_FIT_SIGNATURE_STRICT','SYS_CONSOLE_IS_IN_ENV','CMD_HASH','HASH_VERIFY','SHA256'):
        assert f'CONFIG_{key}=y\n' in config, key
    assert 'CONFIG_SPL_VIDEO=y' not in config
    print('PASS compiled control DT: I2C3/0x39, 4 lanes, active-low reset, reciprocal DSIM graph; chosen/aliases/non-phandle MMC properties preserved; FIT checks/serial/hash enabled, no SPL video.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--uboot-source', type=Path, help='Patched pinned U-Boot source for actual host callback tests')
    parser.add_argument('--uboot-git', type=Path, help='Original Foundries U-Boot Git cache for strict pinned patch tests')
    parser.add_argument('--uboot-build', type=Path, help='Cross-build directory for compiled control DT/config tests')
    parser.add_argument('--boot-header', type=Path, help='Exact pinned Foundries common boot-header input')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='dt510-uboot-native-') as tmp:
        native(Path(tmp))
        packaging(Path(tmp), args.boot_header)
        if args.uboot_source:
            host_order(Path(tmp), args.uboot_source)
            lcdif_order(Path(tmp), args.uboot_source)
        if args.uboot_git:
            patch_stack(Path(tmp), args.uboot_git)
        if args.uboot_build:
            control_dt(args.uboot_build)
