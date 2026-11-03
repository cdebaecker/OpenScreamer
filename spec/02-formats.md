# 2. File formats

All multi-byte numbers are little-endian. "Byte" offsets are from the start of the file, or of the data
segment where said.

## The two programs

`MAIN2HDE.EXE` is the game. `DEMO2HDE.EXE` is the attract demo shown before it. Both are MS-DOS `MZ`
programs. The engine never runs them; it only reads data from them.

Each has a data segment, the block that holds its tables, pictures and text:

| Program | Data segment starts at file offset | Length used |
|---|---|---|
| `MAIN2HDE.EXE` | `0xA9A0` | `0xDF20` bytes (to file offset `0x188C0`) |
| `DEMO2HDE.EXE` | `0x0A30` | `0xB820` bytes (to file offset `0xC250`) |

In this spec, **MAIN:x** is offset `x` within MAIN2HDE's data segment (file offset `0xA9A0 + x`), and
**DEMO:x** the same for DEMO2HDE's. The game works on a 64 KB **data area** that starts as a copy of
MAIN's data segment, zero after its end. Several of the original tables hold *addresses* within this area
(for example, which picture piece to draw), so the engine keeps it, with the same offsets: a table value
"MAIN:x" means byte `x` of the data area. The engine may keep its own state wherever it likes, except for
the records below whose layout the files and tables depend on.

## Colours and planar pictures

The PC-9801 shows 8 colours. A colour index has three bits, one per bit plane: bit 0 **B**, bit 1 **R**,
bit 2 **G**. With the game's default palette the indices are:

| Index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| Colour | black | blue | red | magenta | green | cyan | yellow | white |

A **planar picture** of `w` bytes by `h` lines covers `8w x h` pixels. It is stored plane by plane: `w*h`
bytes of plane B, then `w*h` of R, then `w*h` of G. In each byte the high bit is the leftmost pixel.

A **one-plane piece** is `w*h` bytes of a single plane. Drawn in that plane, it sets that plane's bit where its
bits are 1 and clears it where they are 0. The other two planes stay as they are. See chapter 3 for how the
game combines planes.

## Picture files

| Files | Size | Contents |
|---|---|---|
| `P01`-`P20` | 12288 | a planar picture, 40 bytes x 100 lines (320 x 100 pixels), at offset 0 |
| `G01`-`G39` | 7168 | a monster: its planar portrait, 20 x 100 (160 x 100 pixels), at 0; its record (40 bytes) at `0x1770`; its fighting sprites (1024 bytes) at `0x1800` |
| `G40`-`G60` | 6144 | a person's portrait: planar, 20 x 100, at 0 |

The game loads each of these in one piece into the data area's work buffer, at MAIN:`0x0006`, before using
it. Where the spec gives "an offset in the work buffer", it is an offset into this loaded file plus 6.

## Banks

`B01`, `B02` and `B03` (16384 bytes each) hold more picture pieces. The game keeps them in the hidden part
of graphics memory: `B01` in plane B, `B02` in plane R, `B03` in plane G, each from byte `0x4000` of its
plane. The pieces in them are listed in chapter 4 as offsets in a bank file.

`B01` also starts with the conversation table (below).

## Floor maps

`F01`-`F06` (5120 bytes each) are the six floors of BIAS, the tower. The game loads a floor into the data area
at MAIN:`0x3406` and changes it while playing (doors open, items are taken), so it reloads it from the file
on each visit.

A floor is a grid of 24 x 24 cells, row by row (`y` from 0 to 23, then `x` from 0 to 23), 8 bytes per cell,
`0x1200` bytes in all. The other `0x200` bytes are unused. Cell `(x, y)` is at offset `(y * 24 + x) * 8`.

| Byte | Meaning |
|---|---|
| 0 | the wall on the north side |
| 1 | the wall on the east side |
| 2 | the wall on the south side |
| 3 | the wall on the west side |
| 4 | the writing on a wall here (0 = none; else its number in the wall-text table) |
| 5 | the monster here (0 = none) |
| 6 | the cell's event and flags: bits 0-5 the event number (chapter 9), bit 6 a flag the view and events use, bit 7 "dark" |
| 7 | the item here (0 = none) |

A wall byte: bit 0 set means there is a wall or a closed door; bit 1 selects the door picture instead of the
plain wall; bit 6 marks a door that opens or closes at random each time the floor is loaded (chapter 7).
Other bits are used by the events that read them (chapter 9).

North is `y - 1`, east `x + 1`, south `y + 1`, west `x - 1`. Facings are numbered 0 north, 1 east, 2 south,
3 west.

## The roster file

`CHAR` (1024 bytes) holds up to 8 registered characters, one 128-byte record per slot. The game reads it into
the work buffer (MAIN:`0x0006`) and writes the 1024 bytes back after a change. The roster ends at the first
slot whose first byte is `0xFF` (chapter 5).

## The character record

The current character is a 128-byte record at MAIN:`0x4D52`, in the same layout as a roster slot. 16-bit fields
are words.

| Offset | Size | Field |
|---|---|---|
| `0x00` | 16 | name, zero-terminated |
| `0x10` | 2 | HC, hunter class (0-25) |
| `0x12` | 2 | AC, armour class |
| `0x14` | 2 | BP, beast points |
| `0x16` | 2 | HP |
| `0x18` | 2 | AGL, agility |
| `0x1A` | 2 | POW, power |
| `0x1C` | 2 | TEC, technique |
| `0x1E` | 2 | IQ |
| `0x20` | 2 | maximum HP |
| `0x22` | 2 | maximum AGL |
| `0x24` | 2 | maximum POW |
| `0x26` | 2 | maximum TEC |
| `0x28` | 2 | maximum IQ |
| `0x2A` | 2 | luck |
| `0x2C` | 2 | credits (money) |
| `0x2E` | 1 | poison: one bit per kind of poison (`0x01`, `0x02`, `0x04`, `0x08`, `0x10`) |
| `0x36` | up to 31 | inventory: item numbers, zero-terminated; bit 7 set means equipped |
| `0x55` | 2 | BP earned since the last class rise |

The other bytes are kept as they are.

**The inventory is full** when byte `0x53` is not 0, that is when it holds 30 items or more. Nothing else
limits it: adding an item writes it after the last one and a zero after that.

## The item table

91 items, numbered 1 to 91, at MAIN:`0x570B`, `0x18` bytes each (item `n` at `0x570B + (n - 1) * 0x18`).

| Offset | Size | Field |
|---|---|---|
| `0x00` | 1 | which shops sell it: one bit per shop (chapter 6) |
| `0x01` | 16 | name, padded with spaces, zero-terminated |
| `0x11` | 2 | price |
| `0x13` | 1 | value: damage, protection or strength, by kind |
| `0x15` | 1 | kind (chapter 8) |

The other bytes are used where chapter 8 says.

## The monster record

40 bytes, at `0x1770` in `G01`-`G39`. The game copies it to MAIN:`0x5FBF` when the monster appears.

| Offset | Size | Field |
|---|---|---|
| `0x00` | 16 | name, zero-terminated |
| `0x10` | 1 | TEC |
| `0x11` | 1 | AC |
| `0x12` | 2 | BP it is worth |
| `0x14` | 2 | HP |
| `0x16` | 1 | POW |
| `0x17` | 1 | poison it gives |
| `0x18` | 1 | width, for fights |
| `0x19` | 1 | kind |

Chapter 10 gives the meaning of the other bytes.

## The conversation table

At the start of `B01`. A run of entries, ended by a zero byte where the next entry would start. Each entry:

- the keyword: bytes ended by a zero byte;
- 1 byte: the keyword's number;
- 1 byte: the IQ needed to understand the answer;
- 1 byte: how many replies follow;
- 2 bytes: where the replies are, as an offset in `B01` plus `0x5800`.

The replies are zero-terminated strings one after another.

## Text

The game's text is single bytes, drawn with its own 8 x 8 font (256 glyphs, 8 bytes each, top line first,
high bit leftmost, at MAIN:`0x4E6A`). Byte values `0x20`-`0x7E` are ASCII, `0xA1`-`0xDF` half-width
katakana, as in JIS X 0201. Other values are the font's own symbols (box drawing, blocks, the cursor).

In Unicode terms, for logs and translations, `0xA1`-`0xDF` are U+FF61-U+FF9F.

Strings in the programs are zero-terminated and use markup, described in chapter 3: `_` and `~` start a new
line, `{` and `}` switch katakana to hiragana and back, `|` switches the high-bit mode, and `#` prints a
number.
