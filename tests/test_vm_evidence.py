"""Exercise the guest canary scanner with positive and negative evidence."""
import contextlib
import importlib.util
import io
from pathlib import Path
import subprocess
import sys
import unittest
from unittest import mock

spec = importlib.util.spec_from_file_location('nocturne_vm', Path(__file__).resolve().parents[1] / 'vm/nocturne-vm.py')
vm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vm)


class CanaryScannerTests(unittest.TestCase):
    def run_scanner(self, journal=b'ordinary log\n', files=b'', status=1, journal_status=0):
        with mock.patch.object(vm, 'Qga') as qga, mock.patch.object(vm, 'read_secret', return_value='TEST-CANARY'), contextlib.redirect_stdout(io.StringIO()):
            qga.return_value.run.return_value = (0, '', '')
            with self.assertRaises(SystemExit):
                vm.cmd_scan_secret(None)
        argv = qga.return_value.run.call_args.args[0]
        self.assertNotIn('TEST-CANARY', ' '.join(argv))
        script = argv[-1]
        replies = [subprocess.CompletedProcess([], journal_status, journal, b''), subprocess.CompletedProcess([], status, files, b'')]
        stdin = mock.Mock(buffer=io.BytesIO(b'TEST-CANARY\n'))
        output = io.StringIO()
        with mock.patch.object(sys, 'stdin', stdin), mock.patch.object(subprocess, 'run', side_effect=replies) as run, contextlib.redirect_stdout(output), self.assertRaises(SystemExit) as stopped:
            exec(compile(script, '<guest-canary-scan>', 'exec'), {})
        if run.call_count == 2:
            self.assertEqual(run.call_args.kwargs['input'], b'TEST-CANARY\n')
        return stopped.exception.code, output.getvalue()

    def test_clean_evidence_passes(self):
        code, output = self.run_scanner()
        self.assertEqual(code, 0)
        self.assertIn('journal: 0', output)

    def test_journal_canary_fails(self):
        code, output = self.run_scanner(journal=b'prefix TEST-CANARY suffix\n')
        self.assertEqual(code, 1)
        self.assertIn('journal: 1', output)
        self.assertNotIn('TEST-CANARY', output)

    def test_file_canary_fails(self):
        code, output = self.run_scanner(files=b'/tmp/fake-log\n', status=0)
        self.assertEqual(code, 1)
        self.assertIn('files: 1', output)

    def test_file_scan_error_is_not_success(self):
        code, _ = self.run_scanner(status=2)
        self.assertEqual(code, 'file scan failed')

    def test_journal_error_is_not_success(self):
        code, _ = self.run_scanner(journal_status=1)
        self.assertEqual(code, 'journal query failed')


if __name__ == '__main__':
    unittest.main()
