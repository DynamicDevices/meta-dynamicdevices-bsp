#!/usr/bin/env python3
"""Focused source checks; no BitBake tasks or hardware access."""

from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FakeData:
    def __init__(self, features, dev_mode="0"):
        self.values = {
            "MACHINE_FEATURES": features,
            "DEV_MODE": dev_mode,
            "TAS2555_I2C_ADDRESS": "0x4c",
        }

    def getVar(self, name):
        return self.values.get(name)


class FakeBB:
    class utils:
        @staticmethod
        def contains(variable, item, yes, no, data):
            return yes if item in (data.getVar(variable) or "").split() else no

    @staticmethod
    def fatal(message):
        raise ValueError(message)


class ScreenAudioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = (ROOT / "classes/jaguar-screen-tas2555.bbclass").read_text()
        if 'TAS2555_I2C_ADDRESS ??= "0x4c"' not in source:
            raise AssertionError("Update the fixture to match the class address default")
        function = source[source.index("def jaguar_screen_tas2555_header_content") :]
        function = function.split("\npython jaguar_screen_tas2555_header()", 1)[0]
        namespace = {"bb": FakeBB}
        exec(compile(function, "jaguar-screen-tas2555.bbclass", "exec"), namespace)
        cls.header = staticmethod(namespace["jaguar_screen_tas2555_header_content"])

    def test_screen_selects_base_feature_and_gates_rom1_on_dev_mode(self):
        machine = (ROOT / "conf/machine/imx8mm-jaguar-screen.conf").read_text()
        self.assertIn('MACHINE_FEATURES:append:imx8mm-jaguar-screen = " tas2555"', machine)
        expression = re.search(r'^MACHINE_FEATURES:append:imx8mm-jaguar-screen = "\$\{@(.+)\}"$', machine, re.MULTILINE).group(1)
        self.assertEqual(eval(expression, {"d": FakeData("", "0")}), "")
        self.assertEqual(eval(expression, {"d": FakeData("", "1")}), " tas2555-rom1-dev")

    def test_enabled_header_keeps_rom1_disabled(self):
        header = self.header(FakeData("tas2555"))
        self.assertIn("#define TAS2555_ENABLED 1", header)
        self.assertIn("#define TAS2555_I2C_ADDRESS 0x4c", header)
        self.assertIn("#define TAS2555_ROM1_DEV 0", header)

    def test_unselected_feature_stays_disabled(self):
        header = self.header(FakeData(""))
        self.assertIn("#define TAS2555_ENABLED 0", header)
        self.assertIn("#define TAS2555_ROM1_DEV 0", header)

    def test_rom1_cannot_bypass_development_gate(self):
        for features in ("tas2555-rom1-dev", "tas2555 tas2555-rom1-dev"):
            with self.subTest(features=features), self.assertRaises(ValueError):
                self.header(FakeData(features))

    def test_development_rom1_header_and_clock(self):
        header = self.header(FakeData("tas2555 tas2555-rom1-dev", "1"))
        self.assertIn("#define TAS2555_ENABLED 1", header)
        self.assertIn("#define TAS2555_ROM1_DEV 1", header)
        dtsi = (ROOT / "recipes-bsp/device-tree/lmp-device-tree/imx8mm-jaguar-screen-tas2555.dtsi").read_text()
        self.assertIn("assigned-clock-rates = <12288000>", dtsi)
        self.assertIn("simple-audio-card,mclk-fs = <256>", dtsi)
        self.assertIn("ti,rom1-dev;", dtsi)

    def test_schematic_connections_and_card(self):
        directory = ROOT / "recipes-bsp/device-tree/lmp-device-tree"
        dtsi = (directory / "imx8mm-jaguar-screen-tas2555.dtsi").read_text()
        for connection in (
            'simple-audio-card,name = "tas2555audio"',
            "sound-dai = <&sai2>",
            "&i2c1 {",
            "ti,cdc-reset-gpio = <&gpio3 19 GPIO_ACTIVE_LOW>",
            "ti,irq-gpio = <&gpio3 25 GPIO_ACTIVE_HIGH>",
        ):
            self.assertIn(connection, dtsi)
        dts = (directory / "imx8mm-jaguar-screen.dts").read_text()
        self.assertIn("/delete-node/ sound-wm8524;", dts)
        alsa = (ROOT / "recipes-bsp/alsa-state/alsa-state/imx8mm-jaguar-screen/asound.conf").read_text()
        self.assertIn('pcm "hw:tas2555audio,0"', alsa)
        self.assertIn('card "tas2555audio"', alsa)

    def test_production_firmware_gate_remains(self):
        source = (ROOT / "conf/machine/include/tas2555.inc").read_text()
        self.assertIn('if [ ! -s "${IMAGE_ROOTFS}${TAS2555_FIRMWARE_FILE}" ]; then', source)
        self.assertIn('bbfatal "tas2555 is enabled but', source)
        self.assertIn("jaguar_screen_tas2555_validate_rootfs;", source)

    def test_feature_dependencies_match_built_module_and_firmware(self):
        source = (ROOT / "conf/machine/include/tas2555.inc").read_text()
        expressions = re.findall(r'^MACHINE_EXTRA_RDEPENDS:append = "\$\{@(.+)\}"$', source, re.MULTILINE)
        self.assertEqual(len(expressions), 2)
        for features, expected in (
            ("", set()),
            ("tas2555", {"kernel-module-tas2555", "tas2555-firmware"}),
            ("tas2555 tas2555-rom1-dev", {"kernel-module-tas2555"}),
        ):
            with self.subTest(features=features):
                data = FakeData(features)
                dependencies = " ".join(eval(expression, {"bb": FakeBB, "d": data}) for expression in expressions)
                self.assertEqual(set(dependencies.split()), expected)
        makefile = (ROOT / "recipes-kernel/kernel-modules/kernel-module-tas2555/Makefile").read_text()
        self.assertIn("obj-m += snd-soc-tas2555.o", makefile)
        recipe = (ROOT / "recipes-kernel/kernel-modules/kernel-module-tas2555_git.bb").read_text()
        self.assertIn("inherit module features_check", recipe)

    def test_module_autoload_is_feature_gated(self):
        source = (ROOT / "conf/machine/include/tas2555.inc").read_text()
        expression = re.search(r'^KERNEL_MODULE_AUTOLOAD:append = "\$\{@(.+)\}"$', source, re.MULTILINE).group(1)
        self.assertEqual(eval(expression, {"bb": FakeBB, "d": FakeData("tas2555")}), " snd-soc-tas2555")
        self.assertEqual(eval(expression, {"bb": FakeBB, "d": FakeData("")}), "")

    def test_firmware_recipe_is_screen_only_and_requires_input(self):
        source = (ROOT / "recipes-bsp/tas2555-firmware/tas2555-firmware_1.0.bb").read_text()
        self.assertIn('COMPATIBLE_MACHINE = "^imx8mm-jaguar-screen$"', source)
        self.assertIn('REQUIRED_MACHINE_FEATURES = "tas2555"', source)
        self.assertIn('CONFLICT_MACHINE_FEATURES = "tas2555-rom1-dev"', source)
        expression = re.search(r'^SRC_URI = "\$\{@(.+)\}"$', source, re.MULTILINE).group(1)
        self.assertEqual(eval(expression, {"bb": FakeBB, "d": FakeData("tas2555")}), "file://tas2555_uCDSP.bin")
        self.assertEqual(eval(expression, {"bb": FakeBB, "d": FakeData("tas2555 tas2555-rom1-dev", "1")}), "")
        self.assertIn('if [ ! -s "${WORKDIR}/tas2555_uCDSP.bin" ]; then', source)
        self.assertIn('FILES:${PN} = "${nonarch_base_libdir}/firmware/tas2555_uCDSP.bin"', source)


if __name__ == "__main__":
    unittest.main()
