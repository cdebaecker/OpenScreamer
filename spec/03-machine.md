# 3. The machine the game sees

The game was written for a PC-9801 at 8 MHz. To play the same, the engine reproduces the few parts of that
machine the game's behaviour depends on: the graphics planes, its own text drawing, the passing of time, the
beeper, the keyboard and the random numbers. Later chapters describe the game in these terms.

## Graphics memory

The game shows 640 x 200 pixels (each line shown twice on a 400-line monitor). Graphics memory is three
planes, B, R and G, of 32 KB each. Byte `o` of a plane holds 8 pixels: line `o / 80`, pixels `8 * (o % 80)`
to `8 * (o % 80) + 7`, high bit leftmost. Only bytes 0 to 15999 are shown.

**Screen offsets** in this spec are such byte offsets: `y * 80 + x / 8`. A picture "drawn at offset `o`"
has its top-left pixel at line `o / 80`, column `8 * (o % 80)`. Picture widths are always in bytes.

Bytes `0x4000` to `0x7FFF` of each plane are hidden. They hold the bank files (chapter 2).

The pixel's colour index is (G bit << 2) | (R bit << 1) | B bit, mapped through the palette.

### Drawing

- **Draw a planar picture** at an offset: copy its three planes over the screen rectangle, B into plane B,
  and so on. Every pixel of the rectangle takes the picture's colour.
- **Draw one plane**: copy one plane's bytes into that plane only. The other planes keep their bits.
- **Clear a rectangle**: zero its bytes in all three planes.
- **Grab** a rectangle: copy its three planes out (B, then R, then G, row by row), to draw back later.

### The palette

The PC-98's digital palette maps each colour index to one of the 8 colours. It is set in pairs of
indices: (0, 4), (1, 5), (2, 6) and (3, 7). Setting a pair writes one byte: its high nibble is the first
index's colour, its low nibble the second's (3 bits each).

The game changes only the pair (0, 4), to change the colour of the dungeon walls and some text: "set colour
4 to `c`" in this spec means index 0 becomes black and index 4 becomes colour `c`. The game remembers the
last value it set (the engine needs it, for example to restore it). At start the palette is the identity.

The game can also hide graphics entirely (the screen shows black); chapter 5 says when.

## Screen windows

These rectangles are cleared often. Offsets are screen offsets; widths in bytes.

| Window | Offset | Lines | Width | What |
|---|---|---|---|---|
| 0 | `0x0784` | 172 | 13 | the command menu, on the left |
| 1 | `0x2952` | 64 | 40 | the message window, under the picture |
| 2 | `0x0792` | 104 | 40 | the picture or view window |
| 3 | `0x2582` | 72 | 40 | the large message window (registration) |
| 4 | `0x0F2D` | 112 | 33 | the data and input window (registration) |

## Text

The game draws its own text into graphics memory, in 8 x 8 cells: 80 columns, 25 rows. The cell at column
`c`, row `r` covers screen offset `r * 640 + c`, 8 lines down.

The game keeps a text cursor (column, row), a left margin, and a plane mask that says which planes text
goes into (bit 0 B, bit 1 R, bit 2 G; normally 7, white).

**Putting a character** at the cursor writes the glyph's 8 bytes into each plane in the mask,
replacing what was there, and leaves the other planes alone. Then the column moves right by one. Two codes
are special: `0x0D` moves to the next row at the margin column. `0x08` moves back one column, puts a
space there, and moves back again.

**Which glyph.** The glyph is the font's entry for the byte, changed by two modes:

- the **high-bit mode**: when on, every byte except a space has bit 7 set before use;
- the **kana mode**: when on, katakana bytes `0xA5`-`0xBF` show glyph byte - `0x20`, and `0xC0`-`0xDD`
  show glyph byte + `0x20`. These are the font's hiragana.

**Printing a string** reads bytes up to a zero:

| Byte | Effect |
|---|---|
| `_` | in high-bit mode, the character itself; otherwise a new line (`0x0D`) |
| `~` | a new line |
| `{` or `}` | switches the kana mode |
| `\|` | switches the high-bit mode |
| `#` | in high-bit mode, the character itself; otherwise the current number (below) |
| anything else | put that character |

After a string, the high-bit mode is off and the kana mode is **on**. Most of the game prints with the kana
mode on at the start, so `{...}` marks the *katakana* parts of a sentence.

**Raw printing** prints a string from the data area as is: both modes off, every byte put as a character,
markup included.

**Typewriter printing** prints like a string, but each character is followed by the cursor glyph
(`0x01`), then a pause of 300 delay units, then the cursor moves back one column so the next character
replaces the cursor. A new line puts a space (to erase the cursor) before it. At the end, a space is put.

### Numbers

`#` prints the current number: a 24-bit value (a high byte and a 16-bit low word) in decimal, eight digits,
in one of three formats:

- **0**: leading zeros removed (at least one digit);
- **1**: leading zeros replaced with spaces, last five characters only;
- **2**: leading zeros replaced with spaces, all eight characters.

The number is printed as a string itself, so the modes are reset after it.

## Time

The original busy-waits. Everything it does takes time in **delay units** of 50 µs. The engine keeps a
virtual clock in microseconds, advances it as below, and keeps it from running ahead of real time. All
waits in this spec are in delay units unless they say otherwise.

| Action | Virtual time |
|---|---|
| a delay of `n` | `n * 50` µs |
| a beep (on `a`, off `b`, `n` times) | `(a + b) * 50 * n` µs |
| each check of an empty keyboard while waiting for a key | 200 µs |
| each pass of the dungeon's idle loop | 600 µs (chapter 7) |

Drawing takes no virtual time.

**Beeps.** The PC-98 beeper is a fixed square wave of about 2 kHz. A beep is `n` repetitions of: sound for
`a` units, silence for `b` units. The game also keeps the last beep's three numbers and reuses them.

The "talk" blip, heard before every line someone says, is a beep of on 2, off 4, 200 times.

A second kind of wait also **eats keys**: for each unit, it takes one key from the keyboard buffer and
throws it away. Fights use it (chapter 10), and a beep built from it.

## The keyboard

The game reads the keyboard in two ways.

**The key buffer** holds up to 16 key presses, each a character code and a scan code. Reading a key takes
the oldest one, or nothing. The game turns it into one value:

| Key | Value |
|---|---|
| a key with a character | its character code (space `0x20`, Esc `0x1B`, letters, katakana...) |
| cursor up | 1 |
| cursor right | 2 |
| cursor down | 3 |
| cursor left | 4 |
| Delete | 8 |
| anything else | ignored |

The game also empties the buffer at times ("flush the keys").

**The key matrix** says which keys are held down now. It is 16 groups of 8 bits; a key with scan code `s`
is bit `s % 8` of group `s / 8`. The game reads whole groups and compares them with exact values, so a
second key held in the same group changes the result.

The scan codes the game uses:

| Key | Scan code |
|---|---|
| Esc | `0x00` |
| Return | `0x1C` |
| T | `0x14` |
| Z, X, C | `0x29`, `0x2A`, `0x2B` |
| Space | `0x34` |
| cursor up, left, right, down | `0x3A`, `0x3B`, `0x3C`, `0x3D` |
| HELP | `0x3F` |
| keypad 4, 5, 6 | `0x46`, `0x47`, `0x48` |
| keypad 8 | `0x43` |
| keypad 2 | `0x4B` |
| keypad 0 | `0x4E` |

**The keypad direction.** Reading groups 8 and 9 together as `(group 8 << 8) | group 9`, the game takes:
`0x0800` (keypad 8 alone) as 1, `0x0001` (keypad 6) as 2, `0x0008` (keypad 2) as 3, `0x4000` (keypad 4)
as 4, `0x8000` (keypad 5) as 5, and any other value as 0. It remembers the last direction read.

**Hold pause.** For `n` times: wait 9 units, then read the keypad direction; stop early when it is not 0
and differs from the direction read before the pause.

## Input widgets

### Command menus

A command menu is a column of items in window 0. Item `i` (from 1) sits at screen offset
`(i - 1) * 0x500 + 0xC85`, 11 bytes wide, 8 lines high. The selection is shown by a red arrow (the 8-byte
glyph at MAIN:`0x4E4A`, drawn in plane R only) at the item's offset. The menu remembers its item count and
selection.

One **poll** of a menu:

1. If HELP and T are both held, the waiting-time dialog runs first (below).
2. Draw the arrow at the selection. If the selected item is shown highlighted, un-highlight it: for each of
   its 8 lines, copy plane R's 11 bytes (from one byte right of the arrow) into planes B and G.
3. Read keys until the buffer is empty:
   - Space: highlight the item (zero planes B and G over those 11 x 8 bytes, which leaves it red), erase the
     arrow (zero its 8 bytes in plane R), and return the selection.
   - cursor down or up: erase the arrow, move the selection with wrap-around, draw the arrow, return
     nothing.
   - Esc: in the town (game mode 2), return the last item; elsewhere return nothing.
   - other keys are dropped.
4. Return nothing when the buffer is empty.

"Choose from a menu" polls until something is chosen, with 200 µs between polls.

### Arrow choices

Some questions place an arrow among fixed spots. A choice has a navigation table (4 bytes per spot: the
spot to go to for up, right, down and left, 0 for none) and a table of screen offsets (one 16-bit offset
per spot), both in the data area; chapter 4 lists them. The arrow starts on spot 1. Cursor keys move it
along the table; Space returns the spot. Other keys are ignored.

**Yes or No**: at row `0x17`, column `0x18` (the margin unchanged), print `ui.01`, choose between the
spots of MAIN:`0xAB40` / MAIN:`0xAB48`, clear window 1, and answer whether spot 1 was chosen.

**Push Space**: at column `0x1F`, row `0x17`, print `ui.02`, wait for a Space key press (ignoring
others), clear window 1.

### Typing a line

Up to 15 characters, into a 16-byte buffer, with the kana mode off:

- Before each key, while fewer than 15 characters are typed, show `_` at the cursor (without moving it). Skip
  this after a key that did nothing.
- Cursor right types a space.
- Cursor left or Delete: if nothing is typed, nothing happens; otherwise remove the last character, put a
  space, step back, then put a backspace (`0x08`).
- Space ends the line: put a space if fewer than 15 characters were typed, and end the buffer with a zero.
- Other codes below `0x20` do nothing. Past 15 characters, nothing happens.
- Any other character is stored and put.

**Reading a number** from typed text: skip leading spaces; read digits; trailing spaces are allowed but
nothing after them. A non-digit, or a value over 65535, makes it not a number. An empty line reads as 0.

### The waiting-time dialog

A hidden option of the original, kept for completeness: holding HELP and T while a command menu is polled
shows, in window 1 at column `0x13`, row `0x11`, `ui.03` and a
two-digit picker of the game's speed setting (initially 8, 1 to 99). The picker first waits for Return to
be released, shows the value (two digits, the cursor kept in place), waits 3000 units, then repeatedly:
reads and drops one key; reads group 7: `0x10` (cursor right) +1, `0x04` (cursor up) +10, `0x08` (cursor
left) -1, `0x20` (cursor down) -10, each limited to 1 and 99, shown, then a 3000-unit wait; Esc
(group 0 = `0x01`) cancels; Return (group 3 = `0x10`) accepts; otherwise 200 µs pass. An accepted value
becomes the speed setting. The setting has no other effect in the engine. Window 1 is cleared afterwards.

## Skipping strings

Many tables are zero-terminated strings one after another. **Skipping `n` strings** from an offset moves past
`n` zero bytes (each time: forward to the next zero, then one byte more), with 16-bit wrap-around in the data
area. **`n` = 0 means 65536 skips**, as in the original; where that ends depends on the whole data area's
contents, so the engine really does the 65536 skips. (This happens with wall writing number 1, chapter 8,
whose text comes out empty or as whatever string the skips end on.)

## Random numbers

One 16-bit seed, kept in the data area at MAIN:`0xAB4C` (its value from the file is the first seed).
"A random number from 0 to `n`" (with `n` taken as a byte):

- if `n` is 0, the answer is 0 and the seed doesn't change;
- otherwise `seed = (seed * 0x3245 + 0x1B0D) mod 0x10000`, and the answer is `seed mod (n + 1)`.

Every random number in the game comes from this, so the order in which the game asks for them matters, and
later chapters keep to it.
