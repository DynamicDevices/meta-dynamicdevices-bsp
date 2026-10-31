"""Compile controlled legacy/Etnaviv DT fixtures with the real cpp and dtc."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / 'recipes-bsp/device-tree/lmp-device-tree'
CLASS = ROOT / 'classes/jaguar-screen-graphics.bbclass'
namespace = {}
exec(CLASS.read_text().split('\npython jaguar_screen_graphics_header()')[0], namespace)
header = namespace['jaguar_screen_graphics_header_content']

FIXTURE = r'''
#define GIC_SPI 0
#define IRQ_TYPE_LEVEL_HIGH 4
#define IMX8MM_CLK_GPU_AHB 0x5a
#define IMX8MM_CLK_GPU_BUS_ROOT 0xc8
#define IMX8MM_CLK_GPU3D_ROOT 0xc1
#define IMX8MM_CLK_GPU2D_ROOT 0xd9
/dts-v1/;
/ {
    #address-cells = <2>;
    #size-cells = <2>;
    interrupt-parent = <&gic>;
    clk: clock-controller { #clock-cells = <1>; };
    gic: interrupt-controller { interrupt-controller; #interrupt-cells = <3>; #address-cells = <0>; };
    pgc_gpu: power-domain { #power-domain-cells = <0>; };
    gpu: gpu@38000000 {
        compatible = "fsl,imx8mm-gpu", "fsl,imx6q-gpu";
        reg = <0 0x38000000 0 0x8000>, <0 0x38008000 0 0x8000>;
        reg-names = "iobase_3d", "iobase_2d";
        interrupts = <0 3 4>, <0 25 4>;
        interrupt-names = "irq_3d", "irq_2d";
        clocks = <&clk 0xc1>, <&clk 0>;
        clock-names = "gpu3d_clk", "gpu3d_shader_clk";
        assigned-clock-rates = <0 0 0 400000000 1000000000>;
        power-domains = <&pgc_gpu>;
        throttle,max_state = <1>;
        status = "okay";
    };
};
#include "imx8mm-jaguar-screen-graphics.h"
#if JAGUAR_SCREEN_ETNAVIV
#include "imx8mm-jaguar-screen-etnaviv.dtsi"
#endif
'''


class Data:
    def __init__(self, overrides, dev='1'):
        self.values = {'OVERRIDES': overrides, 'DEV_MODE': dev}

    def getVar(self, name):
        return self.values.get(name)


class ScreenEtnavivDTTests(unittest.TestCase):
    def compile(self, overrides='imx8mm-jaguar-screen:dd-graphics-etnaviv', dev='1'):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        directory = Path(temp.name)
        (directory / 'imx8mm-jaguar-screen-graphics.h').write_text(header(Data(overrides, dev)))
        source = directory / 'fixture.dts'
        source.write_text(FIXTURE)
        preprocessed = subprocess.run(['cpp', '-nostdinc', '-undef', '-x', 'assembler-with-cpp', '-P',
            '-I', str(directory), '-I', str(SOURCES), str(source)], capture_output=True, text=True, check=True, timeout=5)
        dtb = directory / 'fixture.dtb'
        subprocess.run(['dtc', '-I', 'dts', '-O', 'dtb', '-o', str(dtb), '-'], input=preprocessed.stdout,
                       capture_output=True, text=True, check=True, timeout=5)
        return dtb

    def prop(self, dtb, node, name, type='s'):
        return subprocess.run(['fdtget', '-t', type, str(dtb), node, name],
                              capture_output=True, text=True, timeout=5)

    def test_both_cores_use_etnaviv_binding(self):
        dtb = self.compile()
        for address in ('38000000', '38008000'):
            self.assertEqual(self.prop(dtb, '/gpu@' + address, 'compatible').stdout.strip(), 'vivante,gc')
        self.assertEqual(self.prop(dtb, '/gpu@38000000', 'reg', 'x').stdout.strip(), '0 38000000 0 8000')
        self.assertEqual(self.prop(dtb, '/gpu@38008000', 'reg', 'x').stdout.strip(), '0 38008000 0 8000')
        self.assertEqual(self.prop(dtb, '/gpu@38000000', 'interrupts', 'x').stdout.strip(), '0 3 4')
        self.assertEqual(self.prop(dtb, '/gpu@38008000', 'interrupts', 'x').stdout.strip(), '0 19 4')

    def test_clock_names_and_legacy_property_removal(self):
        dtb = self.compile()
        self.assertEqual(self.prop(dtb, '/gpu@38000000', 'clock-names').stdout.strip(), 'reg bus core shader')
        self.assertEqual(self.prop(dtb, '/gpu@38008000', 'clock-names').stdout.strip(), 'reg bus core')
        for name in ('reg-names', 'interrupt-names', 'throttle,max_state'):
            self.assertNotEqual(self.prop(dtb, '/gpu@38000000', name).returncode, 0)

    def test_existing_clock_rates_and_shared_power_domain_preserved(self):
        dtb = self.compile()
        self.assertEqual(self.prop(dtb, '/gpu@38000000', 'assigned-clock-rates', 'u').stdout.strip(), '0 0 0 400000000 1000000000')
        self.assertEqual(self.prop(dtb, '/gpu@38000000', 'power-domains', 'x').stdout,
                         self.prop(dtb, '/gpu@38008000', 'power-domains', 'x').stdout)

    def test_non_etnaviv_backend_unchanged(self):
        for overrides in ('imx8mm-jaguar-screen', 'imx8mm-jaguar-screen:dd-graphics-imxg2d'):
            with self.subTest(overrides=overrides):
                dtb = self.compile(overrides)
                self.assertEqual(self.prop(dtb, '/gpu@38000000', 'compatible').stdout.strip(), 'fsl,imx8mm-gpu fsl,imx6q-gpu')
                self.assertNotEqual(self.prop(dtb, '/gpu@38008000', 'compatible').returncode, 0)

    def test_same_selection_for_dev_and_production(self):
        for dev in ('0', '1'):
            self.assertEqual(self.prop(self.compile(dev=dev), '/gpu@38000000', 'compatible').stdout.strip(), 'vivante,gc')

    def test_both_device_tree_build_routes_include_and_generate_header(self):
        for source in (SOURCES / 'imx8mm-jaguar-screen.dts', ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-screen.dts'):
            self.assertIn('#if JAGUAR_SCREEN_ETNAVIV\n#include "imx8mm-jaguar-screen-etnaviv.dtsi"\n#endif', source.read_text())
        for recipe in (ROOT / 'recipes-bsp/device-tree/lmp-device-tree.bbappend', ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend'):
            content = recipe.read_text()
            self.assertIn('inherit jaguar-screen-graphics', content)
            self.assertIn('file://imx8mm-jaguar-screen-graphics.h', content)
            self.assertIn('file://imx8mm-jaguar-screen-etnaviv.dtsi', content)


if __name__ == '__main__':
    unittest.main()
