# OpenScreamer

Play **THE SCREAMER** (Magical Zoo / ASCII, NEC PC-9801, 1986) on today's computers, with saves, a map,
gamepad support and optional English or French text.

OpenScreamer contains **nothing from the original game**. It reads the pictures, maps and text from your own copy
of the original disk the first time you start it, in the same way OpenTTD needs Transport Tycoon's files.

> THE SCREAMER © 1985 Magical Zoo / ASCII Corporation. OpenScreamer is an unofficial, non-commercial fan project.
> It is not affiliated with or endorsed by the copyright holders, and it does not include or distribute any part
> of the original game.

## What you need

### 1. The original disk, as a disk image

You need the **PC-9801 version** of THE SCREAMER (one 5.25" 2HD floppy) as a disk image file. OpenScreamer
reads these formats:

| Format | File names |
|---|---|
| raw image | `.hdm`, `.xdf`, `.tfd` (1,261,568 bytes) |
| Virtual98 | `.fdd` |
| D88 | `.d88`, `.d98` |
| zip | a `.zip` holding one of the above |

To make an image from your own floppy, use a PC-98 or a floppy drive and program that can read PC-98 2HD disks
(1.2 MB, 1024-byte sectors). Most USB floppy drives can't.

OpenScreamer checks every file it reads from the disk. It accepts only the original release: `MAIN2HDE.EXE`,
`DEMO2HDE.EXE`, `B01`-`B03`, `F01`-`F06`, `G01`-`G60` and `P01`-`P20` must be exactly the files of that disk
(their SHA-1 digests are in [`godot/data/disk.json`](godot/data/disk.json)). The roster file `CHAR` may differ:
your registered screamers come along.

The **PC-8801** version isn't supported.

### 2. OpenScreamer

Ready-to-play downloads for Windows, Linux (Steam Deck included), macOS and Android are planned on the
[Releases](https://github.com/cdebaecker/OpenScreamer/releases) page. Until then, run it from the source:

1. Install [Godot 4.7](https://godotengine.org/download) (the standard version, not .NET).
2. Download this repository (Code → Download ZIP, or `git clone`).
3. Open `godot/project.godot` in Godot and press Play, or run `godot --path godot`.

### 3. A translation, if you want one (optional)

The game is in Japanese. English and French translations are a separate download: the
[`translations/`](translations/README.md) folder. Put the `.po` files in a folder called `translations`, either
next to the OpenScreamer program or in OpenScreamer's data folder (below). When playing from the source, the
repository's `translations/` folder is used as it is.

Then choose the language with the **Text** button under the screen, or in Settings.

The translations don't come under OpenScreamer's licence: they are a derivative of the game's text, shared on
the copyright holders' non-commercial terms (see [`translations/README.md`](translations/README.md)).

## The first start

OpenScreamer asks for the disk image: choose it, or drop the file on the window. It takes about a second.
What the game needs is kept in OpenScreamer's data folder; the disk image itself isn't copied, and you can
delete or move it afterwards.

If a file of the disk isn't the one expected, OpenScreamer says which. Nothing is sent anywhere.

**OpenScreamer's data folder** (the imported game, settings, saves, registered screamers, translations):

| System | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\OpenScreamer` |
| Linux | `~/.local/share/godot/app_userdata/OpenScreamer` |
| macOS | `~/Library/Application Support/Godot/app_userdata/OpenScreamer` |

To import a different disk, delete the `import` folder there and start OpenScreamer again.

## Playing

F12 shows the controls at any time. In short:

| | Keyboard | Gamepad |
|---|---|---|
| Menus | cursor keys, Space or Enter to choose, Esc to cancel | d-pad, A, B |
| Walking in BIAS | keypad 8 forward, 4 / 6 turn, 2 turn around, 5 open a door (or W, A, D, S, E) | left stick, RB opens a door |
| Fighting | keypad 4 / 6 walk, 8 jump, 2 crouch, 0 run away; Z attack, X defend, C items | X attack, Y defend, Back items, LB run away |
| Saving | F6 quick save (in the town's menu or standing in BIAS), F7 quick load | |
| Map of the floor | F8 or M | R3 |
| Journal | J | L3 |
| Fast-forward | F9 | right trigger |
| Settings | F10 | Start |
| Full screen | F11 | |

**Talking to people**: type a word to ask about (a drug, FRD, password, a monster's name...). With a translation,
type it in your language. In Japanese they only understand katakana: press the backquote key (or the KANA button)
and type in romaji, e.g. `doraggu`.

**What OpenScreamer adds** to the game as it was in 1986, none of which changes the game itself:

- saved games, and going back a few steps after death (the **Modern** difficulty; **Original** plays as in 1986);
- a map of each floor, and a journal of what people told you and what you found;
- gamepad, touch screen and on-screen keyboard; keys and buttons can be changed;
- display styles (sharp, CRT, soft), colour schemes for colour blindness, larger text, a modern font;
- text to speech, typewriter text shown at once, fast-forward.

Two settings do change the game:

- **The way to floor 6** (on by default): as shipped, the PC-98 version can't be finished. This opens the way as
  the PC-88 version does.
- **Fix the original's bugs** (off by default).

## For developers

- [`godot/ARCHITECTURE.md`](godot/ARCHITECTURE.md): how the game is put together.
- `python tools/run_tests.py <disk image> [--playthrough]` imports a disk and runs the checks; `--playthrough`
  has a bot play the whole game.
- [`spec/`](spec/README.md): a written description of the game, kept in case a clean-room rewrite is ever needed.

## Licence

OpenScreamer's code and documents are under the GNU General Public License, version 3 or later
([`LICENSE`](LICENSE)). The fonts in `godot/assets/fonts/` are under the SIL Open Font License. This licence
covers only OpenScreamer's own work. It does not cover the original game, whose data stays on your disk and in
your copy, nor the translations in `translations/` (see their README).
