# OpenScreamer — architecture

A Godot 4 port of THE SCREAMER (Magical Zoo / ASCII, PC-9801, 1986) that plays from the player's own copy:
graphics are PNG textures drawn as nodes, game state is typed GDScript objects, input comes from the
project's input map, and the game's data is read from the original disk at first start.

## Layout

| Path | What |
|---|---|
| `main.tscn`, `main.gd` | the window: screen, bar (KANA, language, sound, keyboard, settings, help), keyboard/gamepad, settings, real-time pacing |
| `screen/` | `screen.tscn` (board SubViewport + palette shader), `Screen` (drawing API), `TextLayer` (text), `ModernText` (the modern font) |
| `game/` | the game: services (`Sys`, `Keys`, `GameState`, `GameData`, `Art`, `GameText`, `Ui`) and modules |
| `host/` | `HostKeyboard` (key events -> game keys, romaji -> katakana), `Beeper` (the PC-98 beeper), `Ambience`, `Settings` (user://settings.cfg, rebinding), `SettingsMenu`, `RosterFile`, `SaveGame`, `Automap`, `Rewind`, `Journal`, `TouchControls`, `UiText`, `UiFont`, `Reader` (text to speech), `Osk` (on-screen keyboard) |
| `boot.tscn`, `boot.gd` | the first screen: the game, or the page asking for the disk image the first time |
| `assets/fonts/` | subsets of Noto Sans JP and DotGothic16 (SIL OFL, see the `OFL` files) |
| `data/` | where things are on the original disk: `disk.json` (each file's SHA-1), `catalogue/*.json` (pieces and tables), `messages.json` (each message's program, offset and length); `ui/` the interface's translations |
| `tools/` | `import.gd` (import without a window), `check.gd` (parse check), `smoke.gd` (real window), `ui_smoke.gd` (settings, fonts, roster, on-screen keyboard), `unit_tests.gd`, `playthrough.gd` |

**Nothing of the original is in the project.** `Import` (`game/import.gd`) reads the player's disk image
(raw, Virtual98 `.fdd`, D88, or a `.zip` of one), finds the files in its FAT12 file system, checks them
against `data/disk.json`, and writes into `user://import` the pictures (PNG, in the eight digital colours),
the font, the screen frames, the catalogues' pieces, and `game.json`: items, monsters, floors,
conversations, the disk's roster, the catalogues' tables and every message by its name. `Art`,
`TextLayer`, `UiFont` and `GameData` read from there; the code asks for a message with
`data.msg(&"town.05")`.

## How it fits together

- **Modules** (`game/*.gd`) extend `Mod`; `Game` creates one of each and wires them, so any module reaches
  the others as `town`, `dungeon`, `items`, ... and the services as `sys`, `keys`, `st`, `data`, `art`,
  `screen`, `txt`, `ui`, `rng`, `common`, `chara`.
- **Time.** Routines are coroutines paced by a virtual clock at the original's speed: `sys.delay(units)`
  (one unit ~50 us), `sys.beep(on, off, count)`, `sys.advance(us)`. They suspend when the clock gets ahead
  of real time. Always `await` a call to anything that may wait.
- **Flow.** The original leaves deep call chains by resetting its stack. Here `sys.jump(&"target")` raises
  `sys.unwinding`; every caller returns when it sees it after a call (`if sys.unwinding: return`), and
  `Program` runs the target (`registration`, `registration_restart`, `town`, `town_menu`, `dungeon`,
  `dungeon_loop`, `game_over`, `ending`, `combat`, `bar`).
- **State.** `st` (`GameState`): the screamer `st.chr` (`Character`: typed fields over the original 128-byte
  record, so rosters stay compatible with the original disk's CHAR file), position and flags, the monster
  `st.mon`, the floor `st.map` (`FloorMap`, the Fnn bytes: they change while playing), the random seed.
- **Screen.** A 640x200 board (the PC-98's 200 lines, shown doubled). `screen.draw(texture, pos, opaque)`
  adds a TextureRect; an opaque one frees the nodes it covers, like paint. `screen.sprite(id, ...)` keeps
  one node per id (moving things). `clear`, `clear_window`, `fill`, `scroll`, `snapshot`/`restore`. Text goes
  to the `TextLayer` through `txt` (the original's markup: `_` newline, `{}` hiragana, `|`, `#` numbers).
  Everything is drawn in the eight digital colours; the palette shader maps them through the palette the
  game sets (`common.set_color4`, `screen.out_palette`, `screen.graphics_visible`).
- **Input.** `keys.read()` / `ui.read_key()`: typed keys (Unicode characters, `Keys.K_UP`.., `K_SPACE`,
  `K_ESC`, `K_DEL`). Held actions (input map: `forward`, `turn_left`, `attack`, ...) are read the way the
  original read its key matrix: `keys.group(n)`, `keys.pad_bits()`, `ui.numpad()`.
- **Host options** never touch the game's logic, so the comparisons keep guarding the gameplay. The game only
  gives hints, which aren't game state: `ui.typing` (line input waits: the on-screen keyboard), `ui.rest` (at
  rest in the town's menu or in BIAS: saving), `sys.hurry` (typewriter text: instant text), `program.current`
  (the flow target: ambience, automap), and `sys.journal(kind, subject, text)` (something said, read or found:
  the journal).
  - Display: the palette shader maps the board through the palette, then the colour scheme, with optional
    fades and a style (sharp, CRT, soft). The modern font (`ModernText`) draws the text layer's cells into its
    own 2x viewport, composited by the shader; the TextLayer then only draws what the font has no character
    for (box drawing, blocks, the cursor, the arrow).
  - Time: the host clock (`main.now_us`) follows real time times the fast-forward speed, and runs ahead while
    typewriter text prints (instant text). The settings menu and the automap pause by not emitting `tick`.
  - Saves (`SaveGame`): `st`, the beeper parameters and every module's own variables (by reflection). Loading
    stops the running game (`Game.dispose` halts its coroutine at its next wait), builds a new `Game` with that
    state and runs `program.run_from(&"town" / &"dungeon")`.
  - The interface's text (`UiText`): Godot's TranslationServer with `data/ui/<code>.po`; a text set once is
    the English message marked `UiText.N_()` (Godot translates the node), a text with values `tr()`
    (rebuilt by `apply_settings` when the language changes). `tools/gen_ui_pot.py` collects the messages.
  - Rewind (`Rewind`, `RewindPrompt`): the last 20 states where the game rested in BIAS somewhere new, kept
    in memory as saved games; on the death screen (`program.current`, left as the original shows it) the
    bar offers "Go back…" (R, gamepad Y), whose prompt pauses the game and loads one; Space there is death
    for good (the states are dropped).
  - The difficulty (`Settings.saves_allowed()`): Original turns off saving, loading and rewind; the game
    itself is the same.
  - The interface's font (`UiFont`): Noto Sans JP, or the PC-98 pixel font (made at run time from the
    imported font by `Import.pixel_font()`: the game's half-width glyphs at 8 x 16 dots, falling back to `DotGothic16-subset.ttf`, OFL, then Noto). The pixel
    font is drawn at 16 px only: font sizes go through `UiFont.set_size()`, and `UiFont.refresh()` resets them
    when the setting changes.
  - Journal (`Journal`): the game calls `sys.journal()` with the original strings where an answer, a wall
    writing, the ring's words, an item found or given, a hunter met or a victory is shown; the host keeps them
    per screamer in user://journal.cfg and shows them translated, without the text's markup.
  - Touch controls (`TouchControls`, a CanvasLayer): its buttons act as the gamepad's (joypad button events
    from device `TouchControls.DEVICE` for the typed ones, `Input.action_press` for the held ones); while
    they're shown the window stretches to the screen's shape (aspect EXPAND) and the game's canvas is centred
    by the root's `canvas_transform`, leaving their columns either side.
  - The roster page edits the CHAR file and `chara.roster` only before a screamer is chosen (`st.chr` empty).
- **The way to floor 6** (`sys.pendant_fix`, a setting, **on** by default in the game, off in the core so
  the comparisons check the PC-98 as shipped), as on the PC-88:
  - in BIAS, giving reads the pendant table, as the PC-88's BIAS give routine always does (the first
    entry below);
  - the last doors (codes 5..8, `Dungeon._open_door`) open with their password alone, as on the PC-88,
    whose blade test doesn't run for them. On the PC-98 the test seals the way: the only door into the
    Samurai's room on floor 5 (code 7, at (16,2)/(16,3)) needs the blade, the Samurai (who gives it)
    appears only to someone without it, and floor 6 is reached only through his room's code-8 door,
    which needs it gone. Found by the playthrough bot (`tools/playthrough.gd`); `unit_tests.gd` checks
    both ways.
- **Fixing the original's bugs** (`sys.fix_bugs`, a setting, off by default) is the one option that changes
  the game. Comparisons run with it off; `unit_tests.gd` shows each bug with it off and the fix with it on.
  Each fix is marked `sys.fix_bugs` where it is:
  - *The pendant chain* (`Shops._give_item`): the screamers met in BIAS want the pendants, each giving the
    next, the samurai's red one giving the Samurai Blade; the original picks their table only in mode 4
    (combat, where there's no "give"), so the blade, which the last doors of floor 5 need, can't be had:
    as shipped, this PC-98 version can't be finished except through the hidden developer keys (any item).
    The PC-88 version has a give routine of its own in BIAS that always reads the pendant table: the
    fix is what it does. (Its door test is the wrong way round instead: there the doors to floor 6
    need no blade.)
    Checked in the original's code: the blade comes from no shop (it lists filter 1 only), placed or
    random floor item, starting or cheat inventory; "give" is in the BIAS and bar menus only, never
    combat's, and every way out of combat sets mode 3; floor 6 is reached only by floor 5's one
    staircase, behind code 5-7 doors (the blade needed) and a code 8 door (no blade): `test_last_doors`.
  - *Noise machine* (`Combat`): its "monster can't attack" flag is never cleared: after one use no monster
    attacks again until the program restarts. *Fog ball*: shares a word with the noise machine's timer.
  - *Bacillus sensor* (`Items`): misses poison levels 1-3 and names 4 and 5 wrongly.
  - *Giving* an equipped item that's wanted fails (the "equipped" bit is compared); given or sold armour
    still counts in AC; *selling* an equipped FRD keeps its beast points.
  - *Hospital*: an amount that isn't a multiple of 5 buys an extra point. *Credits* and earned BP wrap at
    65535. *Class-up* exactly on the table's value doesn't happen ("0 points to go"); making master class
    during a visit shows a count to a class that doesn't exist and skips the memento.
  - *Floor items* (`Dungeon.look_for_item`): never looked for on stairs and elevator cells or where they land
    (floor 1's revelation ring and floor 5's Tec upper can't be had), and looked for again after each fight
    (an item lying there is gone). The PC-88's elevators don't set `stood`, so there the ring is found.
  - *Guest card*: keeps door_unlocked, so the revelation ring then works on the tower's exit door.
  - *Wall writing number 1* (floor 4 at 1,8): the original's skip loop starts at 0 and
    goes round 65536 times; the wall reads "".
  - *Monster facing* not reset between fights; the first *wall bump* needs 256 tries before its message.
  - *Random doors* roll the wrong partner walls (and an item byte); no shipped floor has random doors.
  Not changed (could be design): two encounter rolls per step, Luck used as the escape roll, the balls not
  used up, the hospital charging at full stats.
  The audit also found two port bugs, fixed in the faithful game: the inventory holds 30 items (the port
  saw 29), and using a command in a pit climbs out (both ports kept you in; fixed mode keeps you there).
- **Text** is Unicode; the original's katakana are half-width katakana (U+FF61..), exactly as in the
  sources. Translations are looked up by a digest of the original string (`data.translate`: `sha1:` and 16
  hex digits of its bytes), from translation packs (gettext PO) in `user://translations`, a `translations`
  folder next to the program, or the repository's `translations/` when running from source (contexts
  `game`, `demo`, `keyword`: the words a player may type when talking, and `password`).

## Checking it

`python tools/run_tests.py <disk image>` (in the repository's root) imports the disk, then runs the parse check,
the unit tests, the interface smoke test (a real window) and the translation packs' check. The game logic
itself was checked step by step against the original program before it was published.
