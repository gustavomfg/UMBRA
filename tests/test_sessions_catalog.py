import importlib.machinery
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
_loader = importlib.machinery.SourceFileLoader("sessions", str(ROOT / "system" / "nocturne-greeter-sessions"))
_spec = importlib.util.spec_from_loader("sessions", _loader)
sessions = importlib.util.module_from_spec(_spec)
_loader.exec_module(sessions)


class SplitExecTests(unittest.TestCase):
    def test_plain_arguments(self):
        self.assertEqual(sessions.split_exec("uwsm start -e -D Hyprland hyprland.desktop"),
                         ["uwsm", "start", "-e", "-D", "Hyprland", "hyprland.desktop"])

    def test_quoted_argument_and_escapes(self):
        self.assertEqual(sessions.split_exec('/usr/bin/run "a b" "x\\$y"'), ["/usr/bin/run", "a b", "x$y"])

    def test_field_codes_dropped_and_percent_literal(self):
        self.assertEqual(sessions.split_exec("/usr/bin/run %U 100%%"), ["/usr/bin/run", "100%"])

    def test_shell_syntax_rejected(self):
        for value in ("sh -c foo;bar", "run $HOME", "a | b", "run `id`", "run > /tmp/x", "run 'x'"):
            with self.assertRaises(sessions.DesktopEntryError, msg=value):
                sessions.split_exec(value)

    def test_unterminated_quote_rejected(self):
        with self.assertRaises(sessions.DesktopEntryError):
            sessions.split_exec('/usr/bin/run "open')

    def test_embedded_field_code_rejected(self):
        with self.assertRaises(sessions.DesktopEntryError):
            sessions.split_exec("/usr/bin/run --file=%f")


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.sessions_dir = self.root / "sessions"
        self.sessions_dir.mkdir()
        # Real root-owned system binaries keep the ownership check meaningful.
        self.search_path = ("/usr/bin",)

    def tearDown(self):
        self.tmp.cleanup()

    def write(self, name, body):
        (self.sessions_dir / name).write_text("[Desktop Entry]\n" + body, encoding="utf-8")

    def catalog(self):
        return sessions.build_catalog(self.sessions_dir, self.search_path)

    def test_resolves_relative_program_and_desktop_names(self):
        self.write("demo.desktop", "Name=Demo\nExec=env FOO=1\nDesktopNames=Demo;KDE\nType=Application\n")
        catalog, skipped = self.catalog()
        self.assertEqual(skipped, [])
        self.assertEqual(catalog["sessions"], [{
            "id": "demo", "name": "Demo", "command": ["/usr/bin/env", "FOO=1"],
            "desktopNames": ["Demo", "KDE"], "type": "wayland",
        }])

    def test_hidden_missing_tryexec_and_bad_exec_skipped(self):
        self.write("hidden.desktop", "Name=Hidden\nExec=/usr/bin/env\nHidden=true\n")
        self.write("noexec.desktop", "Name=Missing\nExec=/usr/bin/env\nTryExec=definitely-not-installed-nocturne\n")
        self.write("shell.desktop", "Name=Shell\nExec=sh -c 'x'\n")
        self.write("absent.desktop", "Name=Absent\nExec=/usr/bin/definitely-not-installed-nocturne\n")
        self.write("relative.desktop", "Name=Relative\nExec=./bin/run\n")
        catalog, skipped = self.catalog()
        self.assertEqual(catalog["sessions"], [])
        self.assertEqual(len(skipped), 5)

    def test_user_owned_program_rejected(self):
        program = self.root / "fake-session"
        program.write_text("#!/bin/sh\n", encoding="utf-8")
        program.chmod(0o755)
        self.write("user.desktop", f"Name=User\nExec={program}\n")
        catalog, skipped = self.catalog()
        if os.geteuid() != 0:
            self.assertEqual(catalog["sessions"], [])
            self.assertIn("root-owned", skipped[0][1])

    def test_symlinked_desktop_file_skipped(self):
        target = self.root / "real.desktop"
        target.write_text("[Desktop Entry]\nName=Link\nExec=/usr/bin/env\n", encoding="utf-8")
        (self.sessions_dir / "link.desktop").symlink_to(target)
        catalog, skipped = self.catalog()
        self.assertEqual(catalog["sessions"], [])

    def test_localised_name_ignored_and_sorted(self):
        self.write("b.desktop", "Name=Beta\nName[pt_BR]=Beta BR\nExec=/usr/bin/env\n")
        self.write("a.desktop", "Name=alpha\nExec=/usr/bin/env\n")
        catalog, _ = self.catalog()
        self.assertEqual([s["name"] for s in catalog["sessions"]], ["alpha", "Beta"])

    def test_write_atomically_sets_mode(self):
        output = self.root / "out" / "sessions.json"
        sessions.write_atomically(output, {"version": 1, "sessions": []})
        self.assertEqual(output.stat().st_mode & 0o777, 0o644)
        self.assertEqual(list(output.parent.glob(".sessions.*")), [])


if __name__ == "__main__":
    unittest.main()
