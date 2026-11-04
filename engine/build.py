#!/usr/bin/env python3
"""Build OpenScreamer's own Godot export template: Godot 4.7.2 with only what the game uses (2D, OpenGL,
GDScript, fonts, SVG theme icons, ZIP and RegEx).  It is about a fifth of the size of Godot's stock template.

    python engine/build.py [--tests]

Downloads Godot's source into engine/src/ (checked against its SHA-256), builds it, and leaves the template in
engine/bin/, where godot/export_presets.cfg looks for it.  --tests builds a copy that also runs scripts given
with -s (engine/bin/tests.exe), for running tools/run_tests.py's checks on this engine.

Needs Python 3, SCons (pip install scons) and, on Windows, Visual Studio with the C++ tools.  See
https://docs.godotengine.org/en/stable/engine_details/development/compiling/ for each system's requirements.
"""
import hashlib
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
VERSION = '4.7.2-stable'
TARBALL = f'godot-{VERSION}.tar.xz'
URL = f'https://github.com/godotengine/godot/releases/download/{VERSION}/{TARBALL}'
SHA256 = 'a18ce0ccec3ecc40b0dd6c4f5132ca934e9fb7c2979717940ff32aee1eb35481'

OPTIONS = {
    'target': 'template_release',
    'production': 'yes',
    'optimize': 'size_extra',
    'lto': 'full',
    'debug_symbols': 'no',
    'deprecated': 'no',
    # 2D only, drawn with OpenGL (the project's Compatibility renderer)
    'disable_3d': 'yes',
    'disable_physics_2d': 'yes',
    'disable_physics_3d': 'yes',
    'disable_navigation_2d': 'yes',
    'disable_navigation_3d': 'yes',
    'disable_xr': 'yes',
    'vulkan': 'no',
    'd3d12': 'no',
    'metal': 'no',
    'opengl3': 'yes',
    'angle': 'no',
    'accesskit': 'no',
    'brotli': 'no',
    # only the modules the game uses
    'modules_enabled_by_default': 'no',
    'module_gdscript_enabled': 'yes',
    'module_regex_enabled': 'yes',  # RegEx
    'module_zip_enabled': 'yes',  # ZIPReader: disk images in a zip
    'module_freetype_enabled': 'yes',  # the TTF fonts
    'module_text_server_fb_enabled': 'yes',  # simple text layout: no right-to-left or complex scripts needed
    'module_svg_enabled': 'yes',  # the default theme's icons (check boxes, sliders, scroll bars)
}

PLATFORMS = {  # sys.platform -> (SCons platform, built file, file in engine/bin/)
    'win32': ('windows', 'godot.windows.template_release.x86_64.exe', 'windows_release_x86_64.exe'),
    'linux': ('linuxbsd', 'godot.linuxbsd.template_release.x86_64', 'linux_release.x86_64'),
}


def source() -> str:
    src = os.path.join(HERE, 'src')
    tree = os.path.join(src, f'godot-{VERSION}')
    if os.path.isdir(tree):
        return tree
    os.makedirs(src, exist_ok=True)
    path = os.path.join(src, TARBALL)
    if not os.path.exists(path):
        print('downloading', URL)
        urllib.request.urlretrieve(URL, path)
    with open(path, 'rb') as f:
        if hashlib.sha256(f.read()).hexdigest() != SHA256:
            sys.exit(f'{TARBALL}: wrong SHA-256, delete it and try again')
    with tarfile.open(path) as t:
        t.extractall(src, filter='data')
    return tree


def main() -> None:
    if sys.platform not in PLATFORMS:
        sys.exit('this script builds on Windows and Linux; see the Godot documentation for other systems')
    platform, built, name = PLATFORMS[sys.platform]
    tests = '--tests' in sys.argv
    tree = source()
    args = [f'{k}={v}' for k, v in OPTIONS.items()]
    args += [f'platform={platform}', f'build_profile={os.path.join(HERE, "openscreamer.gdbuild")}',
             f'-j{os.cpu_count() or 4}']
    if tests:
        args.append('disable_path_overrides=no')
    subprocess.run([sys.executable, '-m', 'SCons'] + args, cwd=tree, check=True)
    out = os.path.join(HERE, 'bin')
    os.makedirs(out, exist_ok=True)
    dest = os.path.join(out, ('tests' + os.path.splitext(name)[1]) if tests else name)
    shutil.copy2(os.path.join(tree, 'bin', built), dest)
    if tests and platform == 'windows':  # the console wrapper starts tests.exe, with its output in the console
        shutil.copy2(os.path.join(tree, 'bin', built.replace('.exe', '.console.exe')),
                     os.path.join(out, 'tests.console.exe'))
    print(f'{dest}: {os.path.getsize(dest) / 1e6:.1f} MB')


if __name__ == '__main__':
    main()
