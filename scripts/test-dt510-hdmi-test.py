#!/usr/bin/env python3
"""Host-only asset and framebuffer safety regression; no board operations."""
import gzip
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import MagicMock, Mock
from PIL import Image

BSP = Path(__file__).resolve().parents[1]
FILES = BSP / 'recipes-bsp/dt510-hdmi-test/files'
API = runpy.run_path(str(FILES / 'dt510-hdmi-test'))


class HdmiTest(unittest.TestCase):
    def geometry(self):
        words = [0] * 40
        words[:7] = [1920, 1080, 1920, 1080, 0, 0, 32]
        words[8:17] = [16, 8, 0, 8, 8, 0, 0, 8, 0]
        return words

    def test_geometry(self):
        API['validate_geometry'](self.geometry(), 7680)
        for index, value in [(0, 1280), (1, 720), (2, 2048), (3, 900),
                             (4, 1), (5, 1), (6, 16), (8, 0), (10, 1)]:
            with self.subTest(index=index):
                words = self.geometry()
                words[index] = value
                with self.assertRaises(RuntimeError):
                    API['validate_geometry'](words, 7680)
        with self.assertRaises(RuntimeError):
            API['validate_geometry'](self.geometry(), 8192)

    def test_assets(self):
        raw = API['read_pattern'](FILES / 'overscan-1920x1080.bgrx.gz')
        with Image.open(FILES / 'overscan-1920x1080.png') as image:
            self.assertEqual(image.size, (1920, 1080))
            self.assertEqual(raw, image.convert('RGB').tobytes('raw', 'BGRX'))
            colours = ['ffffff', 'ff3030', 'ff9600', 'ffff00', '20ff20', '00ffff', '2080ff', 'df40ff']
            for n, colour in enumerate(colours):
                expected = tuple(bytes.fromhex(colour))
                # Check all four native edge rulers away from text/leader lines.
                p = n*16+8
                for point in [(p, 200), (1919-p, 200), (300, p), (300, 1079-p)]:
                    self.assertEqual(image.getpixel(point), expected)

    def test_corrupt_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            asset = Path(directory) / 'bad.gz'
            for size in (0, 100, API['FRAME_BYTES']+1):
                asset.write_bytes(gzip.compress(b'\0'*size, mtime=0))
                with self.assertRaises(RuntimeError):
                    API['read_pattern'](asset)

    def test_console_edges(self):
        for rows, cols in ((67, 240), (25, 80), (3, 16)):
            lines = API['console_rows'](rows, cols)
            self.assertEqual(len(lines), rows)
            self.assertTrue(all(len(line) == cols and line.isascii() for line in lines))
            self.assertTrue(lines[0].startswith('TL|') and lines[0].endswith('|TR'))
            self.assertTrue(lines[-1].startswith('BL|') and lines[-1].endswith('|BR'))
            self.assertTrue(lines[1].startswith('L001|') and lines[1].endswith('|R001'))
            old = bytes((rows, cols, 0, 0))+b'\x20\x07'*(rows*cols)
            payload = API['console_payload'](old)
            self.assertEqual(len(payload), len(old))
            self.assertEqual(payload[4::2], ''.join(lines).encode('ascii'))
            self.assertEqual(payload[5::2], b'\x0f'*(rows*cols))
        for dimensions in ((0, 80), (25, 0), (25, 256)):
            with self.assertRaises(RuntimeError):
                API['console_rows'](*dimensions)
        with self.assertRaises(RuntimeError):
            API['console_payload'](b'\x19\x50\0\0')

    def test_dt510_only_manual_install(self):
        recipe = (FILES.parent / 'dt510-hdmi-test_1.0.bb').read_text()
        self.assertIn('COMPATIBLE_MACHINE = "^imx8mm-jaguar-dt510$"', recipe)
        self.assertNotIn('systemd', recipe)
        self.assertIn('file://overscan-1920x1080.bgrx.gz;unpack=0', recipe)
        self.assertIn('${WORKDIR}/overscan-1920x1080.bgrx.gz', recipe)
        image = (BSP / 'recipes-samples/images/lmp-factory-image.bbappend').read_text()
        self.assertIn('CORE_IMAGE_BASE_INSTALL:append:imx8mm-jaguar-dt510', image)
        for package in ('dt510-hdmi-test', 'gstreamer1.0-plugins-bad-kms',
                        'gstreamer1.0-libav', 'gstreamer1.0-plugins-good-isomp4',
                        'gstreamer1.0-plugins-base-playback', 'gstreamer1.0-plugins-good-soup'):
            self.assertIn(package, image)
        for dependency in ('python3-core', 'python3-fcntl', 'python3-mmap', 'python3-json', 'python3-compression'):
            self.assertIn(dependency, recipe)

    def test_interrupted_backup_rolls_back_without_partial_file_read(self):
        for phase in ('backup', 'state', 'apply'):
            with self.subTest(phase=phase):
                backup, state = MagicMock(), MagicMock()
                apply, rollback = Mock(), Mock()
                if phase == 'backup':
                    backup.open.return_value.__enter__.return_value.write.side_effect = InterruptedError()
                elif phase == 'state':
                    state.open.return_value.__enter__.return_value.write.side_effect = InterruptedError()
                else:
                    apply.side_effect = InterruptedError()
                with self.assertRaises(InterruptedError):
                    API['save_and_apply'](backup, state, b'complete snapshot', {}, apply, rollback)
                rollback.assert_called_once_with()
                backup.unlink.assert_called_once_with(missing_ok=True)
                state.unlink.assert_called_once_with(missing_ok=True)
                backup.read_bytes.assert_not_called()
                if phase != 'apply':
                    apply.assert_not_called()

    def test_failed_rollback_retains_recovery_files(self):
        backup, state = MagicMock(), MagicMock()
        with self.assertRaisesRegex(RuntimeError, 'rollback failed'):
            API['save_and_apply'](backup, state, b'snapshot', {},
                                  Mock(side_effect=InterruptedError()),
                                  Mock(side_effect=RuntimeError('rollback failed')))
        backup.unlink.assert_not_called()
        state.unlink.assert_not_called()


if __name__ == '__main__':
    unittest.main()
