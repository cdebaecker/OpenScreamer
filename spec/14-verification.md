# 14. Checking the engine against the original

The engine is checked by playing **key scripts** and comparing what it shows and keeps with the
reference, the same scripts played by the spec side's reference (an earlier port checked against the
original, and the original itself in an emulator). The engine side runs its own scripts; the spec side
runs them through the reference and reports differences in this spec's terms (`CLEANROOM.md`).

## Key scripts

A key script is a JSON array of actions. The engine must have a headless mode that plays one:

```
openscreamer --headless --disk <image> --script <script.json> --out <dir> [--no-demo]
```

The script advances only when the game **polls an empty keyboard buffer** (reading a key, or peeking, and
finding none). At each such poll, the runner looks at the first action:

| Action | Meaning |
|---|---|
| `["wait", n]` | let `n` empty polls pass, then move to the next action |
| `["key", code, scan]` | put a key (character code, scan code) in the buffer; the poll still finds none |
| `["hold", scan, n]` | hold the key (or a list of keys) in the matrix for `n` empty polls, then release |
| `["poke", offset, [bytes]]` | write bytes into the data area (to set up a scene), and go on at once |
| `["shot", "name.png"]` | save the screen and the state (below), and go on at once |

When the script is empty, the run ends. Two cases count as an empty poll even without one, so scripts can't
hang: 4000 reads of the key matrix in a row without a buffer poll, and 10 seconds of virtual time without
one (while the buffer is empty).

The run starts with the opening notice skipped, then the demo (unless `--no-demo`), then the game, with the
roster from the disk image's `CHAR` (kept in memory, not written back).

## What is compared

At each `shot`, the engine writes:

- `name.png`: the board, 640 x 400 (each line doubled), in the 8 colours of chapter 2 after the palette, or
  black when graphics are hidden;
- `name.json`:

```json
{
  "clock_us": 0,
  "palette": [0, 1, 2, 3, 4, 5, 6, 7],
  "graphics_visible": true,
  "mode": 3,
  "rng_seed": 0,
  "character": "<128 bytes, hex>",
  "floor": 1, "x": 0, "y": 21, "facing": 0,
  "floor_map": "<0x1400 bytes, hex>",
  "monster": 0, "monster_record": "<40 bytes, hex>", "monster_hp": 0,
  "hunter": 0, "floor_item": 0, "floor_item_poison": 0,
  "fight": "<data area 0x5FF7-0x6040, hex>",
  "planes": "<the three visible planes, 3 x 16000 bytes, hex>"
}
```

`clock_us` is the virtual clock, rounded to the nearest microsecond. Every field must equal the
reference's at every shot. The scripts cover the tour of the town, registration, each shop, each event,
each item, doors, fights, the ending, and long random runs.

## The engine's own tests

The engine side also keeps unit tests for what this spec states as rules: the random numbers, number
formats, the keypad direction, typing a line, reading a number, skipping strings, the disk formats, the
options of chapter 13 (each with the original's behaviour when off).
