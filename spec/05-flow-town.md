# 5. Flow, registration, the town and death

## Flow

The game is a set of **places** it can go to at any time: *registration*, *back to the question*, *the
town*, *the town menu*, *BIAS*, *the BIAS loop*, *death*, *the ending*, *a fight* and *the bar*. Going to a
place abandons whatever was in progress, however deep (menus, conversations, fights), and starts the
place afresh. When a place finishes without going anywhere, the game goes to *registration*.

The game starts at *registration*, after the attract demo (chapter 12).

The game has a **mode**: 1 registration, 2 the town, 3 BIAS, 4 a fight. Menus and items behave differently
by mode.

## Shared screens

**The entry frame** (registration): the frame drawn from the table at MAIN:`0xA950`, then the planar
picture at `B03` offset `0x0800`, 32 bytes x 32 lines, at screen offset `0x02AD`.

**The main frame** (town and BIAS): the frame drawn from the table at MAIN:`0xA9C2`, then twelve labels,
then two planar pictures from `B03`: offset `0x3000`, 17 x 34 at `0x05DC`, and offset `0x2800`, 26 x 16 at
`0x0019`. Each label is a 2-byte x 8-line piece from the data area drawn the same into all three planes
(white):

| Piece | Screen offset | | Piece | Screen offset |
|---|---|---|---|---|
| MAIN:`0xB9B6` | `0x11BD` | | MAIN:`0xB956` | `0x1E3D` |
| MAIN:`0xB956` | `0x11BF` | | MAIN:`0xB976` | `0x1E3F` |
| MAIN:`0xB9C6` | `0x11C1` | | MAIN:`0xB966` | `0x233D` |
| MAIN:`0xB9A6` | `0x11C3` | | MAIN:`0xB976` | `0x233F` |
| MAIN:`0xB966` | `0x193D` | | MAIN:`0xB996` | `0x283D` |
| MAIN:`0xB986` | `0x193F` | | MAIN:`0xB986` | `0x283F` |

**A frame table** is a run of 6-byte entries ended by a zero first byte: a count, a 16-bit screen offset,
a 16-bit data-area offset, and a direction byte.

- Direction not 0 (horizontal): for 4 lines, take 3 bytes (B, R, G) and fill `count` bytes of the line
  in each plane with them, then go down a line.
- Direction 0 (vertical): `count` times, draw the same 4-line tile (3 bytes per line: B, R, G), one byte
  wide, going down 4 lines each time.

**The status panel** shows HP, AC, HC and BP in format 2 at column `0x44`, rows `0x0A`, `0x0C`, `0x0E` and
`0x10`. Many actions refresh it; "refresh the status" means this.

**Recompute AC**: AC becomes the sum of the values of the equipped items whose kind is 3 to 6, then the
status is refreshed.

**The town screen reset**: print the character's name raw at column `0x3D`, row 8 (margin `0x3D`), kana
mode on, recompute AC, refresh the status, clear windows 0, 1 and 2.

**A gatekeeper line**: clear window 3, the talk blip, then print the message at column 3, row `0x0F`
(margin 3), with kana mode on.

**An NPC line**: clear window 1, kana mode on, cursor at column `0x13`, row `0x11` (margin `0x13`), the talk
blip, then print the message.

**A message**: clear window 1, then print it at column `0x12`, row `0x11` (margin `0x12`), kana mode on.

**Show picture `n`**: load `Pnn` and draw it at the current picture position (screen offset; `0x0832`
unless said otherwise). **Show portrait `n`**: load `Gnn` and draw its portrait at the current portrait
position. Loading a monster file also takes its record and sprites (chapter 10).

## The roster in memory

The game loads `CHAR` into the work buffer: 8 slots of 128 bytes, and sets the byte after them to `0xFF`.
The roster's **list** is the slots up to the first whose first byte is `0xFF`; the **count** is how many.
Saving writes the 1024 bytes back. **Finding the character** looks through the list for a slot whose name
equals the current character's name (byte by byte up to the zero), and gives that slot or none.

## Registration

1. Mode 1. Set colour 4 to 4. Clear the screen, draw the entry frame.
2. At column `0x34`, row `0x15` (margin `0x34`), kana mode on: beep with the last beep's numbers (at start,
   those of `init_beep`), then print `town.01`.
3. Show picture 2 at screen offset `0x0282`.
4. Load the roster; count it. Zero the character record.
5. Go on to *back to the question*.

### Back to the question

1. Flush the keys. Gatekeeper line `town.02`.
2. Clear window 4. At column `0x3A`, row `0x0B` (margin `0x3A`): the talk blip, print `town.03`.
3. Arrow choice `town_new_or_registered`.
   - Spot 2 (registered): if the count is 0, gatekeeper line `town.04`, wait 20000, and go to *back to the
     question*. Otherwise **a returning screamer**.
   - Spot 1 (new): if the count is 7, **the roster is full**; otherwise **a new screamer**.

**Yes or No in the data window**: at column `0x3A`, row `0x0F` (margin `0x3A`), beep with the last
numbers, print `town.05`, and take the arrow choice `town_yes_no` (spot 1 Yes, spot 2 No).

### A new screamer

1. Gatekeeper line `town.06`.
2. **Enter the name**: clear window 4; cursor at column `0x32`, row `0x0B`; the talk blip; print `town.08`;
   type a line.
   - Nothing typed: gatekeeper line `town.09`, wait 20000, go to *back to the question*.
   - Copy the 16 typed bytes to the name. If the roster has that name: gatekeeper line `town.10`, wait
     20000, go to *back to the question*.
   - Gatekeeper line `town.11`. Yes or No in the data window; anything but Yes goes to *back to the
     question*.
3. **New stats**: HP, maximum HP, AGL, POW, TEC, IQ, luck and the four other maximums are 10. HC, AC, BP
   and BP since the last rise are 0, no poison, 500 credits.
4. If the typed line equals `town_name_cheat_stats`: HP and maximum HP 255; AGL, POW, TEC, IQ, their
   maximums and luck 250; HC 25; AC, BP and BP since the last rise 0; no poison; 32768 credits; the
   inventory starts with items `0xD2`, `0x98`, `0xA6`, `0xA7`, `0xA8`, `0xA9` (equipped items 82, 24, 38-41),
   then items 51 to 73 (not equipped). Nothing ends the inventory here: it is ended by the zero already in
   the record.
5. Copy the record into roster slot *count + 1*.
6. Gatekeeper line `town.07`, then **enter the city**.

### A returning screamer

1. Gatekeeper line `town.12`. **Pick a character** (below). Clear window 4.
2. Gatekeeper line `town.13`. Yes or No in the data window; No goes to *back to the question*.
3. Copy the picked slot into the character record. Gatekeeper line `town.14`. **Enter the city**.

**Pick a character**: clear window 4, the talk blip, then at column `0x35`, row 6 (margin `0x35`) for
each slot in the list: print its name raw, two new lines, kana mode on. Then build a navigation table
at MAIN:`0x6080` for a vertical list of *count* spots: spot `i` has up `i - 1` (0 for the first) and down
`i + 1` (0 for the last), no left or right. The spot positions are `town_pick_pos`. Remember the spot
chosen.

To build it exactly as the original: start with `a = 1`; repeat: `a = a - 1`; write `a`, 0; `a = a + 2`; stop if
`a >= count + 1`; write `a`, 0; then write a final 0. (The table is 2-byte pairs read as 4-byte spots.)

### The roster is full

1. Gatekeeper line `town.15`. Clear window 4. Yes or No in the data window; No goes to *back to the
   question*.
2. Gatekeeper line `town.16`. Pick a character. Clear window 4.
3. Gatekeeper line `town.17`. Yes or No; No goes to *back to the question*.
4. Clear window 3. At column 2, row `0x0F` (margin 2), print the slot's name raw, kana mode on, then
   `town.18`.
5. Move slots *picked + 1* to 8 down by one place (slot 8 stays as it was). Count minus 1. Wait 20000. Go
   to *back to the question*. (The roster is not saved here; it is saved with the next character to
   enter the city.)

### Entering the city

1. Save the roster. Wait 20000. Clear the screen. Picture position `0x0832`.
2. If the name is `town_name_dead`: clear the screen, at column `0x1E`, row `0x0A` print `town.19`, wait
   40000, go to *death*.
3. If the name is `town_name_drinker`: clear the screen, at column `0x1E`, row `0x0A` print `town.20`, wait
   40000. Clear the screen, set colour 4 to 4, draw the main frame, mode 2. Print the name raw at column
   `0x3D`, row 8 (margin `0x3D`), kana mode on, refresh the status, clear windows 0, 1 and 2, hide hunters,
   no prices. Go to *the bar*.
4. If the name is `town_name_porter`: clear the screen; print `town.21` at column `0x0A`, row `0x0A`,
   `town.22` at `0x0C`, `0x0B`, and `town.23` at `0x0D`, `0x0C`; credits become 10000; wait 50000; clear the
   screen.
5. Go to *the town*.

## The town (Beast City)

*The town*: mode 2, set colour 4 to 4, draw the main frame, go on to *the town menu*.

*The town menu*:

1. Town screen reset. Hide hunters; no prices (chapter 8). Show picture 3 at `0x0832`.
2. A 10-item menu: clear window 0 and print `town.24` at column 5, row 3.
3. Repeat: the talk blip; at column `0x13`, row `0x11` (margin `0x13`) print `town.25`; choose from the menu:

| Item | Action |
|---|---|
| 1 | the BIAS gate |
| 2 | the FRD shop (chapter 6) |
| 3 | the hospital (chapter 6) |
| 4 | go to *the bar* (chapter 6) |
| 5 | the weapon shop (chapter 6) |
| 6 | show the abilities (below) |
| 7 | look at the items (chapter 8) |
| 8 | unequip (chapter 8) |
| 9 | drop (chapter 8) |
| 10 | leave the city |

(Esc in the town chooses item 10, but leaving then does nothing: below.)

### Leaving the city

If the last key read by the menu was Esc, nothing happens. Otherwise: **store the character** (load the
roster, find the character, copy the record into its slot if found, save the roster). Clear the screen. At
column `0x18`, row `0x0B` (margin `0x18`), print `town.26`. Wait for a Space key press. Go to
*registration*.

### Show the abilities

1. Clear window 1. At column `0x13`, row `0x11`, print `char.01`.
2. Grab the picture window (window 2's rectangle) into the work buffer. Clear window 2.
3. Kana mode off; cursor at column `0x13`, row 7; print the name raw.
4. At column `0x14`, row 8 (margin `0x14`): for POW, IQ, TEC, AGL and luck, set the number to the value in
   format 1 and print `char.02` to `char.06`.
5. At column `0x26`, row 8 (margin `0x26`): the same for credits, BP, HC, HP and AC with `char.07` to
   `char.11`. Then print `char.12`, then `char.13` if poisoned, else `char.14`.
6. Push Space. Draw the grabbed picture back.

## The BIAS gate

1. Show picture 9. Clear window 1. At column `0x13`, row `0x11` (margin `0x13`) print `town.27`.
2. A 7-item menu: clear window 0, print `town.28` at column 5, row 3.
3. Repeat, choosing from the menu: 1 enter BIAS; 2 show the abilities; 3 look at the items; 4 equip;
   5 unequip; 6 drop; 7 go to *the town menu*.

**Entering BIAS**:

1. NPC line `town.29`. Push Space.
2. Show picture 10. NPC line `town.30`. Wait 15000.
3. **The gate opens**, 20 times: scroll the rectangle at screen offset `0x0ABD`, 19 bytes wide and 93 lines
   high, one byte (8 pixels) to the left in all three planes, its last byte column becoming black; switch the
   lamp, drawing `town/gate_lamp_on` when on (first) or `town/gate_lamp_off` at `0x0C12`; every other time
   (the first, third...) beep on 100, off 150, 6 times (and keep those as the last beep), the other times
   wait 1500.
4. Wait 15000.
5. Floor 1, x 0, y 21, facing north. Remember colour 4 as 7 (without setting the palette). Load floor 1 and
   roll its random doors (chapter 7). Go to *BIAS*.

## Death

1. Load the roster. If the character is found: move every following slot (up to the 8th) down by one
   place, fill slot 8 with 128 bytes of `0xFF`, and save the roster.
2. Clear the screen. Portrait position `0x08DC`; show portrait 42.
3. At column `0x13`, row `0x11` (margin `0x13`) print `town.31`.
4. Wait for a Space key press. Go to *registration*.
