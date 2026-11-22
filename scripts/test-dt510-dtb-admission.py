#!/usr/bin/env python3
"""Execute the shipped compiled-DTB guard using native dtc/fdtget, not BitBake."""
from pathlib import Path
import subprocess
import tempfile
import textwrap
import types
import unittest


ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / "recipes-bsp/device-tree/lmp-device-tree.bbappend"


class DtbAdmissionTest(unittest.TestCase):
    def run_guard(self, features, property_present):
        source = RECIPE.read_text()
        body = source.split('python do_compile:append:imx8mm-jaguar-dt510() {\n', 1)[1].split('\n}', 1)[0]
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            prop = 'aesl,continuous-display-v1;' if property_present else ''
            subprocess.run(
                ['dtc', '-I', 'dts', '-O', 'dtb', '-o', str(root / 'imx8mm-jaguar-dt510.dtb')],
                input='/dts-v1/; / { ' + prop + ' };', text=True, check=True,
                capture_output=True)
            values = {'B': temp, 'DISTRO_FEATURES': features}

            def fatal(message):
                raise RuntimeError(message)

            namespace = {'d': types.SimpleNamespace(getVar=values.get),
                         'bb': types.SimpleNamespace(fatal=fatal)}
            exec(compile(textwrap.dedent(body), str(RECIPE), 'exec'), namespace)

    def test_headed_admits_opt_in(self):
        self.run_guard('wayland opengl display-boot-splash', True)

    def test_headed_rejects_missing_opt_in(self):
        with self.assertRaisesRegex(RuntimeError, 'compiled DTB'):
            self.run_guard('display-boot-splash', False)

    def test_headless_admits_absence(self):
        self.run_guard('opengl', False)

    def test_headless_rejects_unexpected_opt_in(self):
        with self.assertRaisesRegex(RuntimeError, 'compiled DTB'):
            self.run_guard('', True)


if __name__ == '__main__':
    unittest.main()
