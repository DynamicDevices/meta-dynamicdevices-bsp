#!/usr/bin/env python3
"""Exercise the shipped recovery helper against fake sysfs, never hardware."""
import contextlib
import importlib.machinery
import importlib.util
import io
import signal
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

SOURCE = Path(__file__).resolve().parents[1] / 'recipes-bsp/dt510-hdmi-test/files/dt510-hdmi-recover'
spec = importlib.util.spec_from_loader('recover', importlib.machinery.SourceFileLoader('recover', str(SOURCE)))
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.master = self.root/'sys/bus/platform/drivers/imx-drm'
        self.bridge = self.root/'sys/bus/i2c/drivers/lt9611'
        self.md = self.root/'sys/bus/platform/devices/display-subsystem'
        self.bd = self.root/'sys/bus/i2c/devices/2-0039'
        for p in (self.master, self.bridge, self.md, self.bd/'of_node',
                  self.root/'sys/kernel/debug/dri/0', self.root/'run/dt510-hdmi-test'):
            p.mkdir(parents=True, exist_ok=True)
        (self.md/'driver').symlink_to(self.master)
        (self.bd/'driver').symlink_to(self.bridge)
        (self.bd/'of_node/compatible').write_bytes(b'lontium,lt9611\0')
        (self.root/'sys/kernel/debug/dri/0/clients').write_text('command pid dev master a uid magic\n')
        self.events = []
        self.fail = None
        self.partial = False

    def write(self, path, value):
        kind = 'bridge' if path.parent == self.bridge else 'master'
        event = (kind, path.name)
        self.events.append(event)
        device = self.bd if kind == 'bridge' else self.md
        if self.fail == event and not self.partial:
            raise OSError('injected ' + str(event))
        if path.name == 'unbind':
            (device/'driver').unlink()
        else:
            (device/'driver').symlink_to(path.parent)
        if self.fail == event:
            raise InterruptedError('injected partial operation')

    def run_helper(self):
        with patch.object(helper.os, 'uname', return_value=SimpleNamespace(nodename='imx8mm-jaguar-dt510-test')), contextlib.redirect_stdout(io.StringIO()):
            helper.recover(self.root, self.write)

    def test_success_order_and_ownership(self):
        self.run_helper()
        self.assertEqual(self.events, [('master','unbind'),('bridge','unbind'),('bridge','bind'),('master','bind')])
        self.assertEqual((self.md/'driver').resolve(), self.master)
        self.assertEqual((self.bd/'driver').resolve(), self.bridge)

    def test_saved_test_refused_without_writes(self):
        for name in ('state.json', 'console.bin'):
            with self.subTest(name=name):
                saved = self.root/'run/dt510-hdmi-test'/name
                saved.touch()
                with self.assertRaisesRegex(RuntimeError, 'Restore the saved test'):
                    self.run_helper()
                self.assertEqual(self.events, [])
                saved.unlink()

    def test_active_or_unreadable_drm_refused(self):
        clients = self.root/'sys/kernel/debug/dri/0/clients'
        clients.write_text('header\nweston 123\n')
        with self.assertRaisesRegex(RuntimeError, 'idle DRM'):
            self.run_helper()
        clients.unlink()
        with self.assertRaisesRegex(RuntimeError, 'idle DRM'):
            self.run_helper()
        self.assertEqual(self.events, [])

    def test_wrong_chip_and_binding_refused(self):
        (self.bd/'of_node/compatible').write_bytes(b'lontium,lt9611uxc\0')
        with self.assertRaisesRegex(RuntimeError, 'plain LT9611'):
            self.run_helper()
        self.assertEqual(self.events, [])
        (self.bd/'of_node/compatible').write_bytes(b'lontium,lt9611\0')
        (self.bd/'driver').unlink()
        with self.assertRaisesRegex(RuntimeError, 'original driver binding'):
            self.run_helper()
        self.assertEqual(self.events, [])

    def test_failed_and_partial_detach_restores_actual_ownership(self):
        for kind in ('master', 'bridge'):
            for partial in (False, True):
                with self.subTest(kind=kind, partial=partial):
                    self.events = []
                    self.fail, self.partial = (kind, 'unbind'), partial
                    with self.assertRaisesRegex(RuntimeError, 'original bindings restored'):
                        self.run_helper()
                    self.assertEqual((self.md/'driver').resolve(), self.master)
                    self.assertEqual((self.bd/'driver').resolve(), self.bridge)
                    self.assertLessEqual(self.events.count(('bridge','bind')), 1)
                    self.assertLessEqual(self.events.count(('master','bind')), 1)

    def test_failed_bridge_restore_still_restores_master_once(self):
        self.fail = ('bridge', 'bind')
        with self.assertRaisesRegex(RuntimeError, 'Recovery incomplete'):
            self.run_helper()
        self.assertFalse((self.bd/'driver').exists())
        self.assertEqual((self.md/'driver').resolve(), self.master)
        self.assertEqual(self.events.count(('bridge','bind')), 1)
        self.assertEqual(self.events.count(('master','bind')), 1)

    def test_wrong_host_and_nonroot_main_refused(self):
        with patch.object(helper.os, 'uname', return_value=SimpleNamespace(nodename='other')):
            with self.assertRaisesRegex(RuntimeError, 'DT510 hostname'):
                helper.recover(self.root, self.write)
        with patch.object(helper.os, 'geteuid', return_value=1000), patch.object(helper.sys, 'argv', ['dt510-hdmi-recover']):
            with self.assertRaisesRegex(RuntimeError, 'root'):
                helper.main()
        self.assertEqual(self.events, [])

    def test_real_signals_deferred_until_both_restoration_attempts(self):
        for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
            for phase in (('master','unbind'), ('bridge','unbind'),
                          ('bridge','bind'), ('master','bind')):
                with self.subTest(signal=sig, phase=phase):
                    self.events = []
                    old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, set())
                    def interrupted(signum, frame):
                        raise InterruptedError('actual handled signal')
                    old_handler = signal.signal(sig, interrupted)
                    def writer(path, value):
                        self.write(path, value)
                        if self.events[-1] == phase:
                            signal.raise_signal(sig)
                    try:
                        with patch.object(helper.os, 'uname', return_value=SimpleNamespace(nodename='imx8mm-jaguar-dt510-test')), contextlib.redirect_stdout(io.StringIO()):
                            with self.assertRaisesRegex(InterruptedError, 'actual handled signal'):
                                helper.recover(self.root, writer)
                    finally:
                        signal.signal(sig, old_handler)
                    self.assertEqual((self.md/'driver').resolve(), self.master)
                    self.assertEqual((self.bd/'driver').resolve(), self.bridge)
                    self.assertEqual(self.events, [('master','unbind'),('bridge','unbind'),('bridge','bind'),('master','bind')])
                    self.assertEqual(signal.pthread_sigmask(signal.SIG_BLOCK, set()), old_mask)

    def test_pending_signal_does_not_hide_failed_restoration(self):
        self.fail = ('bridge','bind')
        def interrupted(signum, frame):
            raise InterruptedError('actual handled signal')
        old_handler = signal.signal(signal.SIGTERM, interrupted)
        def writer(path, value):
            try:
                self.write(path, value)
            finally:
                if self.events[-1] == ('bridge','bind'):
                    signal.raise_signal(signal.SIGTERM)
        try:
            with patch.object(helper.os, 'uname', return_value=SimpleNamespace(nodename='imx8mm-jaguar-dt510-test')), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError, 'Recovery incomplete:.*actual handled signal'):
                    helper.recover(self.root, writer)
        finally:
            signal.signal(signal.SIGTERM, old_handler)
        self.assertFalse((self.bd/'driver').exists())
        self.assertEqual((self.md/'driver').resolve(), self.master)
        self.assertEqual(self.events.count(('bridge','bind')), 1)


if __name__ == '__main__':
    unittest.main()
