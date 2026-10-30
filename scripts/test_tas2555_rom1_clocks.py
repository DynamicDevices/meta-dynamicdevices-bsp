#!/usr/bin/env python3
"""Check the recipe-patched TI source, without BitBake or hardware access.

Usage: python3 scripts/test_tas2555_rom1_clocks.py PATCHED_DRIVER_DIRECTORY
Apply every recipe patch to SRCREV before running this test.
"""

from pathlib import Path
import re
import sys
import unittest


DRIVER = Path(sys.argv.pop(1)) if len(sys.argv) > 1 else None
ROOT = Path(__file__).resolve().parents[1]


class Rom1ClockTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if DRIVER is None:
            raise RuntimeError("Supply the recipe-patched TI driver directory")
        cls.core = (DRIVER / "tas2555-core.c").read_text()
        header = (DRIVER / "tas2555.h").read_text()
        cls.registers = {
            name: tuple(map(int, values))
            for name, *values in re.findall(
                r"#define\s+(TAS2555_\w+)\s+TAS2555_REG\((\d+),\s*(\d+),\s*(\d+)\)",
                header,
            )
        }
        cls.registers["TAS2555_UDELAY"] = "delay"

    def sequence(self, name):
        body = re.search(
            r"static unsigned int " + re.escape(name) + r"\[\] = \{(.*?)\};",
            self.core, re.S,
        ).group(1)
        entries = []
        for register, value in re.findall(
            r"(TAS2555_REG\(\d+,\s*\d+,\s*\d+\)|TAS2555_\w+),\s*(0x[0-9a-fA-F]+|\d+),",
            body,
        ):
            address = self.registers.get(register)
            if register.startswith("TAS2555_REG("):
                address = tuple(map(int, re.findall(r"\d+", register)[1:]))
            self.assertIsNotNone(address, register)
            entries.append((address, int(value, 0)))
        return entries

    def test_exact_measured_clock_block_and_power_order(self):
        expected = [
            ((0, 0, 44), 0), ((0, 0, 4), 0),
            ((0, 1, 115), 15), ((0, 1, 116), 13),
            ((100, 0, 27), 1), ((100, 0, 28), 7),
            ((100, 0, 29), 0), ((100, 0, 30), 0),
            ((100, 0, 32), 7), ((100, 0, 34), 8),
            ((100, 0, 2), 16), ((100, 0, 33), 4),
            ((100, 0, 1), 8), ((100, 0, 43), 0),
            ((100, 0, 44), 32), ((100, 0, 31), 32),
            ((100, 0, 42), 64), ((0, 0, 5), 128),
            ((0, 0, 4), 248), ("delay", 2000), ((0, 0, 44), 11),
        ]
        self.assertEqual(self.sequence("p_tas2555_rom1_dev_startup_data"), expected)
        self.assertEqual(12288000 * 7 // 7 // 4, 48000 * 64)

    def test_shutdown_and_restart_restore_mclk_not_internal_oscillator(self):
        startup = self.sequence("p_tas2555_rom1_dev_startup_data")
        shutdown = self.sequence("p_tas2555_shutdown_data")
        state = dict(startup)
        self.assertIn(((0, 1, 116), 15), shutdown)
        self.assertLess(shutdown.index(((0, 0, 7), 3)), shutdown.index(((0, 1, 116), 15)))
        self.assertIn(((0, 0, 4), 0), shutdown)
        state.update(shutdown)
        self.assertEqual(state[(0, 1, 116)], 15)
        state.update(startup)
        self.assertEqual(state[(0, 1, 116)], 13)
        self.assertEqual(state[(0, 0, 4)], 248)
        self.assertEqual(state[(0, 0, 5)], 128)

    def test_dev_guard_and_unmute_only_after_successful_startup(self):
        enable = self.core.split("static int tas2555_enable_rom1_dev(", 1)[1].split("static int tas2555_pwr_startup(", 1)[0]
        self.assertRegex(enable, r"p_tas2555_rom1_dev_startup_data\);\s*if \(nResult < 0\)\s*return nResult;\s*nResult = tas2555_dev_load_data\(pTAS2555,\s*p_tas2555_unmute_data\)")
        self.assertIn("p_tas2555_shutdown_data", enable)
        self.assertIn("if (pTAS2555->mbRom1Dev)\n\t\treturn tas2555_enable_rom1_dev", self.core)
        self.assertIn("TAS2555_DSP_MODE_SELECT_REG, 0x21", self.core)

    def test_recipe_orders_fix_after_rom1_mode(self):
        recipe = (ROOT / "recipes-kernel/kernel-modules/kernel-module-tas2555_git.bb").read_text()
        self.assertLess(recipe.index("0006-tas2555"), recipe.index("0007-tas2555"))
        self.assertIn('SRCREV = "0468cf54e49f57163e17998846b62dc941130929"', recipe)


if __name__ == "__main__":
    unittest.main()
