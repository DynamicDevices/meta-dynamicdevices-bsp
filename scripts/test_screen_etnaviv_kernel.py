"""Exercise the final-kernel configuration gate without running BitBake."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RECIPE = ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx_%.bbappend'
FRAGMENT = ROOT / 'recipes-kernel/linux/linux-lmp-fslc-imx/imx8mm-jaguar-screen/etnaviv-gpu.cfg'


class ScreenEtnavivKernelTests(unittest.TestCase):
    def gate(self, config):
        text = RECIPE.read_text()
        body = re.search(r'do_compile:prepend:imx8mm-jaguar-screen:dd-graphics-etnaviv\(\) \{\n(.*?)^\}', text, re.M | re.S)[1]
        with tempfile.TemporaryDirectory() as directory:
            Path(directory, '.config').write_text(config)
            return subprocess.run(['sh', '-eu', '-c',
                'bbfatal() { echo "$*" >&2; exit 1; }\n' + body.replace('${B}', directory)],
                capture_output=True, text=True, timeout=5).returncode

    def test_selected_fragment_passes_gate(self):
        self.assertEqual(self.gate(FRAGMENT.read_text()), 0)

    def test_current_broken_configuration_fails(self):
        self.assertNotEqual(self.gate('CONFIG_DRM_ETNAVIV=m\nCONFIG_MXC_GPU_VIV=y\n'), 0)

    def test_galcore_cannot_remain_builtin_or_module(self):
        for value in ('y', 'm'):
            with self.subTest(value=value):
                self.assertNotEqual(self.gate('CONFIG_DRM_ETNAVIV=y\nCONFIG_MXC_GPU_VIV=' + value + '\n'), 0)

    def test_missing_config_fails(self):
        self.assertNotEqual(self.gate(''), 0)

    def test_backend_and_machine_scope_not_dev_mode(self):
        assignment = next(line for line in RECIPE.read_text().splitlines() if 'file://imx8mm-jaguar-screen/etnaviv-gpu.cfg' in line)
        self.assertTrue(assignment.startswith('SRC_URI:append:imx8mm-jaguar-screen:dd-graphics-etnaviv ='))
        self.assertNotIn('DEV_MODE', assignment)
        self.assertNotIn('DEV_MODE', FRAGMENT.read_text())


if __name__ == '__main__':
    unittest.main()
