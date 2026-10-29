"""Recovery never authenticates in tests; agreety and the compositor are stubs."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('recovery', str(ROOT / 'system/nocturne-recovery-session'))
spec = importlib.util.spec_from_loader(loader.name, loader)
recovery = importlib.util.module_from_spec(spec)
loader.exec_module(recovery)


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        self.session = {'id': 'plasma', 'name': 'Plasma (Wayland)', 'command': ['/usr/bin/true'], 'desktopNames': ['KDE'], 'type': 'wayland'}

    def load(self, data):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'catalog.json'
            path.write_text(json.dumps(data))
            with mock.patch.object(recovery, 'trusted_file', return_value=path):
                return recovery.load_sessions(path)

    def test_valid_catalog(self):
        self.assertEqual(self.load({'version': 1, 'sessions': [self.session]}), [self.session])

    def test_invalid_catalogs_fail_closed(self):
        for data in [None, [], {}, {'version': 2, 'sessions': []}, {'version': 1, 'sessions': []}]:
            with self.subTest(data=data), self.assertRaises(ValueError):
                self.load(data)
        for field, value in [('command', ['relative']), ('command', ['/bin/true', '\0']), ('desktopNames', ['KDE\nBAD=1']), ('name', '\x1b[31m'), ('id', '../bad'), ('type', 'x11')]:
            with self.subTest(field=field), self.assertRaises(ValueError):
                self.load({'version': 1, 'sessions': [{**self.session, field: value}]})

    def test_untrusted_catalog_is_refused(self):
        info = mock.Mock(st_uid=1000, st_mode=0o100644)
        with mock.patch.object(Path, 'resolve', return_value=Path('/catalog')), mock.patch.object(Path, 'stat', return_value=info):
            with self.assertRaises(ValueError):
                recovery.trusted_file(Path('/catalog'))
        info.st_uid = 0
        info.st_mode = 0o100666
        with mock.patch.object(Path, 'resolve', return_value=Path('/catalog')), mock.patch.object(Path, 'stat', return_value=info):
            with self.assertRaises(ValueError):
                recovery.trusted_file(Path('/catalog'))

    def test_numeric_choice_never_becomes_a_command(self):
        second = {**self.session, 'id': 'hyprland'}
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(recovery.choose_session([self.session, second], mock.Mock(side_effect=['/bin/sh', '0', '3', '2'])), second)
            self.assertEqual(recovery.choose_session([self.session], lambda _: ''), self.session)

    def test_launch_environment_and_argv(self):
        with mock.patch.object(recovery, 'load_sessions', return_value=[self.session]), mock.patch.object(recovery, 'choose_session', return_value=self.session), mock.patch.object(recovery.os, 'execve') as launch:
            recovery.main()
        executable, argv, env = launch.call_args.args
        self.assertEqual(executable, '/usr/bin/systemd-cat')
        self.assertEqual(argv[-1], '/usr/bin/true')
        self.assertEqual(env['XDG_SESSION_TYPE'], 'wayland')
        self.assertEqual(env['XDG_CURRENT_DESKTOP'], 'KDE')
        self.assertEqual(env['XDG_SESSION_DESKTOP'], 'plasma')

    def test_preflight_failure_uses_text_login(self):
        self.check_launcher(1, 'agreety')

    def test_preflight_success_uses_graphical_login(self):
        self.check_launcher(0, 'systemd-cat')

    def check_launcher(self, status, expected):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            checker = work / 'check'
            checker.write_text(f'#!/bin/sh\nexit {status}\n')
            checker.chmod(0o755)
            source = (ROOT / 'system/nocturne-greeter-start').read_text()
            source = source.replace('/usr/lib/nocturne-greeter/nocturne-greeter-check', str(checker))
            for binary in ['systemd-cat', 'agreety']:
                stub = work / binary
                stub.write_text(f'#!/bin/sh\nprintf "%s\\n" "{binary}" "$@"\n')
                stub.chmod(0o755)
                source = source.replace('/usr/bin/' + binary, str(stub))
            launcher = work / 'start'
            launcher.write_text(source)
            result = subprocess.run(['bash', str(launcher)], capture_output=True, text=True, check=True)
            self.assertIn(expected, result.stdout)
            if expected == 'agreety':
                self.assertIn('--cmd\n/usr/lib/nocturne-greeter/nocturne-recovery-session', result.stdout)
                self.assertNotIn('/usr/bin/cage', result.stdout)
            else:
                self.assertIn('/usr/bin/cage', result.stdout)
                self.assertNotIn('agreety', result.stdout)


if __name__ == '__main__':
    unittest.main()
