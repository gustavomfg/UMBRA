#!/usr/bin/python3 -I
"""Read-only, shareable inventory; excludes usernames, hostnames and serials."""
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess


def command(argv):
    if not shutil.which(argv[0]):
        return {'available': False}
    try:
        result = subprocess.run(argv, capture_output=True, text=True, timeout=5)
        return {'available': True, 'status': result.returncode, 'output': result.stdout.strip()}
    except (OSError, subprocess.TimeoutExpired):
        return {'available': True, 'error': 'could not query version'}


def read(path):
    try:
        return path.read_text().strip()
    except OSError:
        return None


def main():
    drm = Path('/sys/class/drm')
    connectors = [
        {'connector': item.name, 'status': read(item / 'status'), 'modes': (read(item / 'modes') or '').splitlines()}
        for item in sorted(drm.glob('card*-*')) if (item / 'status').exists()
    ]
    gpus = [
        {'card': item.name, 'vendor': read(item / 'device/vendor'), 'device': read(item / 'device/device'),
         'driver': (item / 'device/driver').resolve().name if (item / 'device/driver').exists() else None}
        for item in sorted(drm.glob('card[0-9]*')) if '-' not in item.name
    ]
    print(json.dumps({
        'os': platform.freedesktop_os_release().get('PRETTY_NAME', 'Linux'),
        'kernel': platform.release(), 'architecture': platform.machine(),
        'packages': command(['pacman', '-Q', 'nocturne-greeter', 'qt6-base', 'qt6-declarative', 'qt6-wayland', 'quickshell', 'greetd', 'greetd-agreety', 'cage', 'mesa']),
        'gpus': gpus, 'connectors': connectors,
        'configured_environment': {key: os.environ.get(key) for key in ['NOCTURNE_OUTPUT', 'XKB_DEFAULT_LAYOUT', 'XKB_DEFAULT_VARIANT', 'XKB_DEFAULT_OPTIONS', 'QT_SCALE_FACTOR']},
        'note': 'Inventory only. This does not validate login, connected-screen focus, keyboard mapping, or GPU rendering.'
    }, indent=2))


if __name__ == '__main__':
    main()
