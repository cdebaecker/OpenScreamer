#!/usr/bin/env python3
"""OpenScreamer's checks, in one go:

  1. the disk image is imported (godot/tools/import.gd)
  2. every script parses (godot/tools/check.gd)
  3. unit tests (godot/tools/unit_tests.gd)
  4. the interface in a real window (godot/tools/ui_smoke.gd; under xvfb-run on Linux)
  5. the translation packs against the disk (tools/check_packs.py)
  6. with --playthrough, a bot plays the whole game, registration to the ending (about ten minutes)

    python tools/run_tests.py <disk image> [--playthrough]

Needs Godot 4.7 as `godot` or $GODOT.  Exit status 0 when everything passes.
"""
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, 'godot')
GODOT = os.environ.get('GODOT', 'godot')


def run(cmd, timeout=900):
    cmd = [shutil.which(cmd[0]) or cmd[0]] + cmd[1:]
    return subprocess.run(cmd, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout)


def godot(*args, window=False, timeout=900):
    if window:
        display = (['xvfb-run', '-a', '-s', '-screen 0 1920x880x24'] if shutil.which('xvfb-run')
                   else [] if sys.platform in ('win32', 'darwin') else None)
        if display is None:
            return None
        return run(display + [GODOT, '--path', PROJECT, '--rendering-driver', 'opengl3'] + list(args), timeout)
    return run([GODOT, '--headless', '--path', PROJECT] + list(args), timeout)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    if len(args) != 1:
        sys.exit(__doc__)
    disk = os.path.abspath(args[0])
    failed = []

    def step(name, ok, detail=''):
        print(f'{"ok  " if ok else "FAIL"} {name}' + (f': {detail}' if detail and not ok else ''))
        if not ok:
            failed.append(name)

    godot('--import')
    r = godot('-s', 'res://tools/import.gd', '--', disk)
    step('the disk image imported', r.returncode == 0 and 'IMPORT OK' in r.stdout, (r.stdout + r.stderr)[-400:])
    if failed:
        sys.exit(1)
    r = godot('-s', 'res://tools/check.gd')
    step('scripts parse', r.returncode == 0, (r.stdout + r.stderr)[-500:])
    r = godot('-s', 'res://tools/unit_tests.gd')
    lines = [l for l in (r.stdout + r.stderr).splitlines() if 'FAIL' in l or 'unit tests' in l or 'SCRIPT ERROR' in l]
    print('     ' + (lines[-1] if lines else ''))
    step('unit tests', r.returncode == 0 and 'SCRIPT ERROR' not in r.stderr, '; '.join(lines[-12:]))
    with tempfile.TemporaryDirectory() as tmp:
        r = godot('-s', 'res://tools/ui_smoke.gd', '--', tmp, window=True, timeout=300)
        if r is None:
            print('skip interface smoke test (no window: install xvfb-run)')
        else:
            bad = [l for l in r.stdout.splitlines() if l.startswith('FAIL')]
            step('interface: settings, fonts, roster, on-screen keyboard, journal, touch (ui_smoke)',
                 r.returncode == 0 and 'all passed' in r.stdout, '; '.join(bad)[:400] or r.stderr[-300:])
        if '--playthrough' in sys.argv:
            r = godot('-s', 'res://tools/playthrough.gd', '--', tmp, '--limit', '400000000', timeout=3600)
            step('a bot plays the whole game', r.returncode == 0, (r.stdout + r.stderr)[-600:])
    r = run([sys.executable, os.path.join(ROOT, 'tools', 'check_packs.py'), disk])
    step('translation packs', r.returncode == 0, (r.stdout + r.stderr)[-600:])
    print(f'\n{len(failed)} failed' if failed else '\nall passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
