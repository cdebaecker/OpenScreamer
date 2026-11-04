# OpenScreamer's engine build

Godot's stock export template carries the whole engine: 3D, physics, Vulkan and Direct3D 12, video, animation
trees, tile maps... OpenScreamer draws in 2D with OpenGL and uses a small part of it. `build.py` builds
Godot 4.7.2 from its source with only that part, which makes the Windows game about 21 MB instead of 110 MB.

```
pip install scons
python engine/build.py
```

The template goes to `engine/bin/`, where the Windows export preset (`godot/export_presets.cfg`) looks for it.
Godot's source is downloaded into `engine/src/` and checked against its SHA-256. Neither folder is kept in the
repository.

What is left out:

- **Build options** (`OPTIONS` in `build.py`): 3D, physics, navigation, XR, Vulkan, Direct3D 12, ANGLE,
  AccessKit, Brotli, the deprecated API, and every module except GDScript, RegEx, ZIP, FreeType, SVG and the
  simple text server.
- **Classes** (`openscreamer.gdbuild`): nodes and resources the game never makes (tile maps, particles, 2D
  lights, skeletons, animation players and trees, graph and code editors, audio effects...).

The simple text server lays out text without OpenType shaping. That's enough for English, French and Japanese,
but it means no kerning and line breaks only at spaces. Check that anything new in the game's scripts or scenes
is not in the list of classes left out. `python engine/build.py --tests` builds `engine/bin/tests.exe`, a copy
that runs scripts given with `-s`, for running the checks of `tools/run_tests.py` on this engine.
