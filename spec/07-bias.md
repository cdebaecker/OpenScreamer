# 7. BIAS, the tower

BIAS is six floors of 24 x 24 cells, seen in first person. The player walks with the keypad (8 forward, 4
and 6 turn, 2 turn around, 5 open a door) and uses a command menu.

## State

Besides the character, BIAS keeps:

| State | Meaning |
|---|---|
| floor, x, y, facing | where the player is (facing 0 north, 1 east, 2 south, 3 west) |
| the cell | a copy of the current cell's 8 bytes, taken when the view is built; and which map cell it is |
| stood | 0 after a step, 1 after a turn or once the cell's event has run |
| monster | the monster met (0 none), set when one appears |
| hunter | the hunter met (0 none, 1-8) |
| floor item, its poison | an item lying here (0 none), and its poison level (0-5) |
| sound barrier | steps left (0 off) |
| four drug flags | Samson, Brain upper, Tec upper, Responser: set while a boosted stat lasts |
| door unlocked, door message, trap done, ring flag, revealed walls | per-cell flags used below and by the events (chapter 9) |
| idle count, regeneration count | counters of the idle loop |
| bump count | steps into a wall before the "bump" message; starts as the byte at MAIN:`0xAB7C` |
| light counters | three bytes, MAIN:`0xAB7E`, `0xAB7F` and `0xAB80` (the light frame), from the data area |
| step marker | a flag at MAIN:`0xB9D8`, from the data area |
| five poison counters | MAIN:`0xA920`-`0xA924`, from the data area |

Map changes (doors, items taken, walls) are made to the loaded floor in the data area, so they last until
the floor is loaded again.

## Random doors

Loading a floor (entering BIAS, the Guest ID card, warping, the stairs) loads `Fnn` and then rolls its
random doors. The original does this in an odd way, and the engine must do the same:

For `k` from 0 to 287, take the 16 bytes at offset `16k` of the floor in the data area (so only every
other cell is looked at, the one at even position in the file). For each of its first four bytes `w` (index
0 to 3) that has bit 6 set, take `random(1)`: if 0, set bit 0 of `w` and of its *partner*; if 1, clear
bit 0 of both. The partner is the data-area byte at this offset from `w`'s cell (the first of the 16 bytes):

| Wall | Partner offset |
|---|---|
| 0 | `-0xF0` |
| 1 | `+0x0A` |
| 2 | `+0xC0` |
| 3 | `-0x09` |

These partners are often not the facing wall of the next cell, and some fall outside the floor (before its
start in the data area); the engine writes them where they fall.

## Entering BIAS

*BIAS* (a place):

1. Mode 3. Draw the main frame's table (MAIN:`0xA9C2`) only, without the labels and pictures. Clear
   windows 2, 1 and 0.
2. No prices; hunters not hidden; kana mode on; cursor at column 5, row 3 (margin 5). Picture and
   portrait positions `0x0832`. Idle count 0.
3. A 10-item menu: clear window 0, print `bias.01` at column 5, row 3.
4. Go on to *the BIAS loop*.

## The view

**Building the view** composes plane G of window 2 in the work buffer, 40 bytes x 104 lines (row `y`,
byte `x` at MAIN:`0x0006 + 40y + x`):

1. The cell is at MAIN:`0x3406 + 8 * (24y + x)`. Copy its 8 bytes as *the cell*.
2. Zero the buffer's `0x1040` bytes. Copy the background: 44 rows of 40 bytes from MAIN:`0x60DF`, to
   MAIN:`0x0966` (rows 24 to 67 of the buffer).
3. For each of the 27 entries `i` of the view: the wall to look at is the byte at (the cell's data-area
   offset + word `27 * facing + i` of `view_wall_offsets`), with 16-bit wrap-around. If its bit 0 is set,
   copy a block. Entry `i` of `view_pieces` is four words: the source for a wall, the source for a door, the
   destination, and the size (high byte rows, low byte width). The source is the door's when bit 1 of the
   wall byte is set. Blocks are copied row by row from consecutive source bytes, into rows 40 bytes apart.

**Showing the view**: choose the wall colour. Normally 7 (white). On the floor's last column (x = 23)
it is the remembered colour 4 instead. Otherwise, when bit 6 of the cell's event byte is set (a dark area
that the Hand Light lights), it is 6 if the remembered colour is 6, else 0. Set colour 4 to it. Draw the
buffer into plane G at screen offset `0x0792` (40 x 104). Then **the compass**: draw the step marker,
draw the compass letters, and flip the step marker flag.

- **Step marker**: the planar piece `dungeon/step`, frame 0 if the flag is set, else frame 1, at
  `0x3382` (4 x 16).
- **Compass letters**: at `0x2E83` (ahead), `0x34C8` (right), `0x3B03` (behind) and `0x34BE` (left), the
  `dungeon/compass` frame `(spot + facing) mod 4` (spots numbered 0-3 in that order), drawn in white.

**Rendering** is building, then showing.

## The ceiling lights

The ceiling lights are a little animation in plane B, ahead of the player. **Looking ahead** notes, from
the current cell and the next two cells in the facing direction (each next cell is `ahead_dx[facing]`
bytes further, with 16-bit wrap-around): whether the current, next and second next cells are dark (event
bit 7), whether the current cell has event bit 6, whether the current cell has a wall ahead (bit 0 of its
wall byte for the facing), and whether the next cell has one.

**Drawing light frame `f`**: if a hunter is here, or the current cell is dark or has bit 6, draw nothing.
Otherwise take the data-area address `light_frames[f mod 8]` and draw three one-plane pieces from there,
one after another, into plane B: 16 x 4 at `0x079E`; then (unless the next cell is dark or there is a wall
ahead) 8 x 5 at `0x0E82`; then (unless the second next cell is dark or the next cell has a wall ahead)
4 x 2 at `0x1424`.

**Lights off** draws frame 7. **Lights on** draws the frame number kept at MAIN:`0xAB80`. **A light tick**
adds `0x20` to the byte at MAIN:`0xAB7E` (wrapping); when it wraps to 0, adds `0x80` to MAIN:`0xAB7F`;
when that wraps to 0, adds 1 to the frame number and draws that frame. So the light moves every 16 ticks.

## The BIAS loop

*The BIAS loop* (a place) runs each time the player arrives in a cell, turns, or comes back from
something:

1. Hunters not hidden. Refresh the status. Flush the keys.
2. If the redraw flag is set, clear window 1 and clear the flag. If a hunter is here, clear window 2 and
   forget the hunter. If the ring flag is set, clear window 2 and clear it.
3. **Sound barrier tick**: if stood is 0 and the barrier is on, count it down; when it reaches 0, print
   `bias.06` at column `0x12`, row `0x11` (margin `0x12`) and Push Space.
4. Lights off. Render the view.
5. Stood 0: **a footstep**, a beep of on 1, off 1, 1000 times, then draw the step marker. Stood 1: **a
   click**, a beep of on 1, off 1, 500 times, then draw the compass letters.
6. Look ahead. Run the cell's event (event byte bits 0-5; chapter 9). Lights on.
7. For each drug flag in order (Samson `bias.02`, Brain upper `bias.03`, Tec upper `bias.04`, Responser
   `bias.05`): if set, clear it; print its message at column `0x12`, row `0x11`; **drugs wear off** (each
   of AGL, POW, TEC and IQ that is exactly 250 goes back to its maximum); Push Space.
8. If stood is 0: **an encounter check**.
9. **Something breaks**: if `random(125)` is 0 and then `random(7)` is 0 and the inventory isn't empty,
   take the item at index `random(count - 1)`. If its kind is less than 8, it **breaks** (chapter 8);
   clear window 1, print `bias.07` at column `0x12`, row `0x11`, Push Space.
10. **Writing on the wall**: if the cell has wall writing and its wall byte ahead has bit 7 or bit 4 set,
    print `bias.08` at column `0x12`, row `0x11` and Push Space.
11. If stood is 0: **an item on the floor**.
12. Regeneration count 0.
13. Repeat for ever:
    1. **Poison ticks**, then an encounter check, then the hidden keys (below).
    2. Up to 6144 passes of the idle loop, then idle count 0.

**An encounter check** does nothing if a monster or a hunter is here; otherwise **an encounter**.

**Poison ticks**: for each poison bit set, in the order `0x01`, `0x02`, `0x04`, `0x08`, `0x10`, count its
counter (bytes MAIN:`0xA920` to `0xA924`) down by 1, wrapping. When it reaches 0: set it back to 10;
adjust HP by `-(random(2) + 1)`; then, for the first four kinds, adjust another stat by
`-(random(2) + 1)`: `0x01` AGL, `0x02` IQ, `0x04` POW, `0x08` TEC. (`0x10` costs only HP.)

**An item on the floor**: floor item 0. The cell's item byte (byte 7), high nibble: if not 0, the item is
`placed_items[nibble - 1]`. Otherwise, on floor 6 there is none; elsewhere if `random(125)` is not 0 there is
none, and if `random(3)` is not 0 there is none; else find the floor's list in `floor_items`: from its start,
skip `floor` zero-terminated runs; the next byte is the count `n`, and the item is the byte at
`random(n - 1)` after it. Then:

- floor item = it. If `random(250)` is below 10 and its kind is below 8, it breaks (as an item in the
  inventory would, but in the floor item).
- `r = random(250)`; its poison level is how many of 200, 210, 220, 230, 240 are at or below `r`.
- print `bias.11` at column `0x12`, row `0x11`, Push Space.

### The idle loop

One pass:

1. A light tick. **Regeneration**: count + 1; at 10000, count 0 and adjust HP by +1.
2. 600 µs pass.
3. Read the keypad direction:
   - 1 (keypad 8): **step forward**. If that comes back (a bump), start the next pass at once, without
     counting it.
   - 5: **open the door**. Same.
   - 2, 3 or 4: **turn** by 1, 2 or 3 quarter turns to the right (keypad 6 right, 2 around, 4 left).
4. Poll the command menu; if an item is chosen, **run a command**.
5. Throw away all keys in the buffer. Idle count + 1; at 6144 the idle loop ends (back to step 13.1).

**Run a command**: lights off; run it; lights on. The commands:

| Item | Command |
|---|---|
| 1 | examine (chapter 8) |
| 2 | pick up (chapter 8) |
| 3 | drop (chapter 8) |
| 4 | equip (chapter 8) |
| 5 | unequip (chapter 8) |
| 6 | use (chapter 8) |
| 7 | give (chapter 6) |
| 8 | talk (chapter 6) |
| 9 | show the abilities (chapter 5) |
| 10 | look at the items (chapter 8) |

## Moving

**Turn** by `t`: stood 1; door message 0; door unlocked 0; facing `(facing + t) mod 4`. Lights off. Hold
pause 100. Throw away all keys. Go to *the BIAS loop*.

**Step forward**:

1. **A hidden wall**: if the map's wall byte ahead (in the floor, not the cell copy) has bits 0, 1 and 3
   equal to `0b1000` (bit 3 set, bits 0 and 1 clear), set its bit 0, and remember its new value as the
   revealed walls. Lights off, render the view, look ahead, lights on.
2. If the map's wall byte ahead has bit 0 clear: hold pause 50, throw away all keys, and **arrive**.
3. Otherwise the bump count - 1. If not 0, come back. If 0: clear window 1, print `bias.09` at column
   `0x12`, row `0x11`, hold pause 400, throw away all keys, clear window 1, bump count 3, come back.

**Arrive** (a step into the next cell): lights off. Monster 0, stood 0, door message 0, the byte at
MAIN:`0x5FBE` 0, trap done 0, door unlocked 0. If the revealed walls value is not 0, then in the cell being
left, clear bit 0 of each of the four wall bytes that has bit 3 set, and set the revealed walls to 0 (a
hidden wall turns back into one). Move one cell in the facing direction (y - 1, x + 1, y + 1, x - 1; the
byte wraps). Go to *the BIAS loop*.

### Doors

**Open the door** (keypad 5):

1. If door unlocked is set, nothing happens.
2. Take the cell copy's wall byte ahead. Bit 2 set: **the door is stuck**. Bits 0 and 1 not both set
   (not a closed door): nothing happens.
3. If a hunter is here or the ring flag is set: clear window 2, render the view.
4. If the map's wall byte ahead has bit 5 clear, **the door opens**.
5. The lock: `c = (event byte bits 0-5) - 20`. If below 0, the door opens.
6. Remember `c` (MAIN:`0xAB4E`). If `c` is 5 or more: when `c` is 8, the door is stuck if item 25 is in the
   inventory; for any other `c` of 5 or more, it is stuck unless item 25 is in the inventory.
7. Clear window 1; print `bias.10` at column `0x12`, row `0x11`. Take one key from the buffer and throw it
   away. Type a line.
8. If the line equals the 5-byte string `door_passwords + 5c` (zero-terminated), the door opens.
   Otherwise clear window 1, print `bias.13` at column `0x12`, row `0x11`, Push Space.

**The door is stuck**: clear window 1; print `bias.14` at column `0x12`, row `0x11`; hold pause 700; throw
away all keys; clear window 1.

**The door opens**: clear window 1. Build the view as it would be with that wall's bit 0 cleared (in the
map), then set the bit again. Copy the new view's plane G into the screen at window lines 24 to 91, bytes 8
to 32 of the window (screen offset `0x0792 + 80y + x`, from buffer row `y`, byte `x`). Then arrive.

(The original slides the door's halves apart there. It takes no time, so only the result above shows.)

## Encounters

**An encounter**:

1. If stood is 0, on floor 5 at x 17, y 5, without item 25: the hunter is 8; **meet the hunter**.
2. If the sound barrier is off: if `encounter_rates[item byte & 0x0F]` is at least `random(99) + 1`, **a
   monster appears**.
3. On floor 6, nothing more. Otherwise, if `random(255)` is 0, the hunter is `random(6) + 1`: meet the
   hunter.

**A monster appears**:

1. The monster is the cell's monster byte. If 0, pick from `floor_monsters`: start at its first byte; for
   each floor up to the current one, move ahead by at least one byte and then to the next 0 byte; then the
   next byte is a count `n` and the monster is the byte `1 + random(n - 1)` after the count.
2. Unless the monster is 39, if the cell's item byte's low nibble is `0x0F`, clear that nibble (in the
   map).
3. Clear window 1; print `bias.12` at column `0x12`, row `0x11`. **The alarm** (below).
4. Clear window 2. Set colour 4 to 4, but keep the remembered colour as it was. **The monster backdrop**:
   draw the planar picture at `B01` offset `0x2800`, 20 x 100, at `0x0846`. Portrait position `0x0832`; show
   portrait *monster* (which also loads its record and sprites). Wait 15000.
5. Monster 39 (the last one): clear window 1, print `bias.15` at column `0x12`, row `0x11`, wait 30000,
   print `bias.16` there (without clearing), wait 60000.
6. The monster's HP - `random(20)`. Hunters not hidden. Go to *a fight* (chapter 10).

**The alarm**: grab the 26 x 16 rectangle at screen offset `0x0019` (the title logo) into the work buffer's
start (planes B, R, G one after another, 416 bytes each). Take `b`, `r` and `g`, the first byte of each
plane. Write `b AND r` at MAIN:`0x04E6`, `b OR r` at MAIN:`0x0686` and `((NOT b) OR r) AND g` at
MAIN:`0x0826` (only those three bytes: the rest of that block stays as it was). Then 10 times: draw the
26 x 16 planar picture at MAIN:`0x04E6` at `0x0019`; beep on 2, off 2, 40 times; draw the grabbed one back;
beep on 2, off 2, 40 times.

**Meet the hunter**: clear window 1; print `bias.17` at column `0x12`, row `0x11`; clear window 2; set colour
4 to 4 keeping the remembered colour; the monster backdrop; portrait position `0x0832`; show portrait
*hunter + 42* (43-50); clear window 1; hunters hidden (value 1). The hunter stays until the player leaves
the cell or turns (step 2 of the BIAS loop), and can be talked to or given things.

## The hidden keys

The original has three hidden key combinations, checked between idle loops. They use the key matrix; the
engine keeps them.

1. If group `0x0C` is `0x7C` (F1 to F5 held), group `0x0E` masked with `0x19` is 1 (SHIFT), and group 2
   is `0x80` (I) or `0x02` (W): clear window 1, print `bias.18` at column `0x12`, row `0x11`, wait 20000,
   clear window 1.
2. If group `0x0E` masked with `0x19` is 1, group 1 is `0xC0` (BS and TAB) and group 2 is `0x80` (I): clear
   window 1, print `bias.19` there, then the number picker (chapter 3) starting from the byte at
   MAIN:`0xB9D6`, up to 87. 0: clear window 1. Otherwise remember it at MAIN:`0xB9D6`; if the inventory is
   full, clear window 1, print `bias.20`, Push Space; else add that item, clear window 1, kana mode off,
   print its name, then `bias.21`, Push Space.
3. If group `0x0E` masked with `0x19` is `0x11` (SHIFT and CTRL), group 7 is `0x80` (HELP) and group 2 is
   `0x02` (W): clear window 1, print `bias.22` there, pick a floor from the current (up to 6); 0: clear
   window 1 and stop. Set the floor; print `bias.23`; pick x from the current + 1 (up to 22); 0 stops the
   same way; x = it - 1; print `bias.24`; the same for y; Push Space. Load the floor and roll its doors;
   lights off; render the view; look ahead; lights on.
