#!/usr/bin/env python3
"""Package OpenScreamer's release downloads from the exported builds in export/:

    OpenScreamer-<version>-windows.zip       OpenScreamer.exe
    OpenScreamer-<version>-linux.zip         OpenScreamer.x86_64 (executable)
    OpenScreamer-<version>-macos.zip         OpenScreamer.app
    OpenScreamer-translations-<version>.zip  translations/ (en.po, fr.po, their terms)

Each game download also holds README.txt (for that system) and LICENSE.txt.

    python tools/package_release.py <version>
"""
import os
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXPORT = os.path.join(ROOT, 'export')

README = """OpenScreamer {version} - plays THE SCREAMER (NEC PC-9801, 1986) from your own copy

OpenScreamer contains nothing from the original game. The first time you start
it, it asks for a disk image of the PC-9801 version of THE SCREAMER (.fdd, .fdi,
.hdm, .xdf, .tfd, .d88, .d98, or a .zip holding one): choose it, or drop it on the
window. It is read once and kept in OpenScreamer's data folder:
  {data}
{start}
English or French text: download OpenScreamer-translations-{version}.zip and
unzip it {where}, so that there is a "translations" folder {there}. Then choose
the language with the Text button.

F12 shows the controls. More: https://github.com/cdebaecker/OpenScreamer

THE SCREAMER (C) 1985 Magical Zoo / ASCII Corporation. OpenScreamer is an
unofficial, non-commercial fan project, not affiliated with or endorsed by the
copyright holders. Not for sale. OpenScreamer is free software under the GNU
GPL, version 3 or later (LICENSE.txt).
"""

SYSTEMS = {
    'windows': dict(data=r'%APPDATA%\Godot\app_userdata\OpenScreamer', start='',
                    where='here', there='next to OpenScreamer.exe', crlf=True),
    'linux': dict(data='~/.local/share/godot/app_userdata/OpenScreamer',
                  start='\nStart OpenScreamer.x86_64 (on a Steam Deck, add it to Steam as a non-Steam game).\n',
                  where='here', there='next to OpenScreamer.x86_64', crlf=False),
    'macos': dict(data='~/Library/Application Support/Godot/app_userdata/OpenScreamer',
                  start='\nOpenScreamer isn\'t signed by Apple. The first time, macOS refuses to open it:\n'
                        'go to System Settings, Privacy & Security, and choose "Open Anyway" (on older\n'
                        'macOS, right-click OpenScreamer.app and choose Open).\n',
                  where='in the data folder above', there='there', crlf=False),
}


def text_entry(z, name, s, crlf):
    if crlf:
        s = s.replace('\n', '\r\n')
    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    info.external_attr = (0o100000 | 0o644) << 16
    z.writestr(info, s.encode('utf-8'), zipfile.ZIP_DEFLATED)


def add_file(z, path, name, mode=0o644):
    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    info.external_attr = (0o100000 | mode) << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    z.writestr(info, open(path, 'rb').read())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    v = sys.argv[1]
    licence = open(os.path.join(ROOT, 'LICENSE'), encoding='utf-8').read()
    out = []
    for system, info in SYSTEMS.items():
        name = os.path.join(EXPORT, f'OpenScreamer-{v}-{system}.zip')
        with zipfile.ZipFile(name, 'w') as z:
            readme = README.format(version=v, **{k: info[k] for k in ('data', 'start', 'where', 'there')})
            text_entry(z, 'README.txt', readme, info['crlf'])
            text_entry(z, 'LICENSE.txt', licence, info['crlf'])
            if system == 'windows':
                add_file(z, os.path.join(EXPORT, 'windows', 'OpenScreamer.exe'), 'OpenScreamer.exe', 0o755)
            elif system == 'linux':
                add_file(z, os.path.join(EXPORT, 'linux', 'OpenScreamer.x86_64'), 'OpenScreamer.x86_64', 0o755)
            else:  # the .app from Godot's zip, keeping each file's mode (the executable, the signature)
                with zipfile.ZipFile(os.path.join(EXPORT, 'macos', 'OpenScreamer.zip')) as src:
                    for e in src.infolist():
                        if e.is_dir():
                            continue
                        e2 = zipfile.ZipInfo(e.filename, e.date_time)
                        e2.external_attr = e.external_attr
                        e2.compress_type = zipfile.ZIP_DEFLATED
                        z.writestr(e2, src.read(e))
        out.append(name)
    name = os.path.join(EXPORT, f'OpenScreamer-translations-{v}.zip')
    with zipfile.ZipFile(name, 'w') as z:
        for f in ('en.po', 'fr.po', 'README.md'):
            add_file(z, os.path.join(ROOT, 'translations', f), 'translations/' + f)
    out.append(name)
    for n in out:
        print(f'{os.path.getsize(n) / 1e6:6.1f} MB  {os.path.basename(n)}')


if __name__ == '__main__':
    main()
