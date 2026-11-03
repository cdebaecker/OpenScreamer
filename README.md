# OpenScreamer

An open-source port of **THE SCREAMER**, a 1986 PC-9801 game (first released on the PC-8801 in 1985), made with
Godot. It plays the original game, but it contains nothing from it: you need your own copy of the original disk.
On first start OpenScreamer reads the game's pictures, maps, tables and text from that disk image, in the same
way OpenTTD needs Transport Tycoon's files.

> THE SCREAMER © 1985 Magical Zoo / ASCII Corporation. OpenScreamer is an unofficial, non-commercial fan project.
> It is not affiliated with or endorsed by the copyright holders, and it does not include or distribute any part
> of the original game.

## What you need

- A disk image of the PC-9801 version of THE SCREAMER: a Virtual98 `.fdd`, a raw `.hdm`/`.xdf`, a `.d88`/`.d98`,
  or a `.zip` holding one. OpenScreamer checks every file it reads against its SHA-1 (`godot/data/disk.json`).
- To run it from source: Godot 4.7. Open `godot/project.godot` and press Play, or run `godot --path godot`.

The first time, OpenScreamer asks for the disk image (choose it, or drop it on the window). It reads it once and
keeps what the game uses in its user data folder; the disk image itself isn't copied.

## Playing

F12 shows the controls. The bar under the screen has the language, sound, on-screen keyboard and settings.
Besides the game as it was, OpenScreamer adds saved games and going back a few steps after death (the Modern
difficulty; Original plays as in 1986), an automap, a journal, gamepad and touch controls, rebinding, display
styles and text to speech. Two options change the game itself: the way to floor 6 is open as on the PC-88
(on by default: the PC-98 version as shipped can't be finished), and fixing the original's other bugs (off).

## Languages

The game plays in the original Japanese, or in English or French through the translation packs in
[`translations/`](translations/README.md). They are a separate download: put the `.po` files in a
`translations` folder next to the program, or in the user data folder's `translations`.

## Layout

| Path | What |
|---|---|
| `godot/` | the game ([`godot/ARCHITECTURE.md`](godot/ARCHITECTURE.md)) |
| `translations/` | the English and French translation packs (not GPL: see their README) |
| `tools/` | `run_tests.py` (all the checks), `check_packs.py` (the packs against the disk), `diskimage.py` |
| `spec/` | a written description of the game, kept for a clean-room rewrite should one ever be needed |

## Checking it

```bash
python tools/run_tests.py <disk image> [--playthrough]
```

imports the disk, then runs the parse check, the unit tests, the interface in a real window and the packs'
check; `--playthrough` also has a bot play the whole game, from registration to the ending.

## Licence

OpenScreamer's code and documents are under the GNU General Public License, version 3 or later
([`LICENSE`](LICENSE)). The fonts in `godot/assets/fonts/` are under the SIL Open Font License. This licence
covers only OpenScreamer's own work. It does not cover the original game, whose data stays on your disk and in
your copy, nor the translation packs in `translations/`, which are a derivative of the game's text and come under
the original copyright holders' non-commercial terms ([`translations/README.md`](translations/README.md)).
