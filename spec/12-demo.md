# 12. The attract demo

Before the game, the original runs its demo program (`DEMO2HDE.EXE`). It shows the hunters, some scenes and
the title. Pressing Space at any pause ends it at once. The engine reads its data from DEMO's data segment
(chapter 2): its font is at DEMO:`0x51A8` (the same glyphs as MAIN's), its strings at the offsets below, and
its title picture at DEMO:`0x5A5E`.

The demo has its own text state, like the game's (chapter 3): cursor, margin, the two modes, plane mask 7.
"At `c`, `r`" sets the column, row and margin.

**A pause**: 640 times: if a key is waiting, take it, and if it is Space, the demo ends; then 60 µs pass.
(A pause takes 38.4 ms.) **`n` pauses** is that, `n` times.

**Typing a demo string** at DEMO:`o`: both modes off. For each byte up to the zero: `{` or `}` switch the
kana mode; `|` switches the high-bit mode; `~`, or `_` when the high-bit mode is off, put a space then a new
line; anything else is put, followed by the cursor glyph (`0x01`), then a pause, then the cursor moves back
one column. At the end, put a space. (Unlike the game, `#` is printed as itself, and the modes stay as they
are after the string.)

**A portrait** `n`: load `Gnn` (as in the game) and draw its portrait at the demo's portrait position.
**A picture** `n`: load `Pnn` and draw it at `0x0832`.

**A title line** `l`: copy the title's line `l / 2` (rounded down; the title is stored at half height:
`0xF0` bytes per line, 80 for each of B, R and G) into screen line `l`, all three planes.

## The sequence

1. Clear the screen. At `0x10`, `0x11` type DEMO:`0x3E7`. Portrait position `0x0832`.
2. For each hunter, in order:

| Hunter's portrait | String | Face |
|---|---|---|
| 43 | DEMO:`0x000C` | 52 |
| 44 | DEMO:`0x0075` | 53 |
| 45 | DEMO:`0x00DE` | 54 |
| 46 | DEMO:`0x0147` | 55 |
| 47 | DEMO:`0x01B0` | 56 |
| 48 | DEMO:`0x0219` | 57 |
| 49 | DEMO:`0x0282` | 58 |
| 50 | DEMO:`0x02EB` | 59 |

   show the hunter's portrait; at `0x28`, 5 type the string; 32 pauses; show the face; 32 pauses.
3. Clear the screen. At `0x18`, `0x0A` type DEMO:`0x3B5`. 32 pauses.
4. Picture 11, 32 pauses; picture 12, 32 pauses; picture 13, 32 pauses.
5. Clear the screen. At `0x12`, `0x14` type DEMO:`0x3C2`. 32 pauses.
6. Portrait 60. At `0x28`, 5 type DEMO:`0x354`. 32 pauses.
7. Clear the screen. The collage, each portrait at its own position: 53 at `0x0014`, 58 at `0x1F68`, 56 at
   `0x1F40`, 55 at `0x003C`, 52 at `0x0000`, 59 at `0x1F7C`, 57 at `0x1F54`, 54 at `0x0028`. 32 pauses.
8. **The title opens** from the middle: with `a = 99` and `b = 100`, while `a` is not 0: move screen lines 1
   to `a` up by one line (all planes); title line `a`; move the bytes from line `b` byte 1 up to line 199
   byte 0 (plane offsets `80b + 1` to `0x3E30`) 80 bytes further on, working from the end (so byte 0 of line
   `b + 1` keeps its value, and line 199's byte 0 lands in hidden memory at `0x3E80`); title line `b`;
   this costs `(a + 199 - b) * 240` bytes at 1.2 µs each (chapter 9); then `b + 1`, `a - 1`. At the end, title
   lines 0 and 199.

Then the game starts at *registration* (chapter 5), with the screen as the demo left it.

The demo's portraits use the demo's own data area; loading them doesn't change the game's.
