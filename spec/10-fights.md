# 10. Fights

Fights are in real time, side on, in the view window: the player on the right, the monster on the left.
Keypad 4 and 6 walk, 8 jumps (with 4 or 6 to leap sideways), 2 crouches, 0 tries to escape; Z attacks, X
defends, C opens the command menu.

## State

Fight state is kept in the data area (the engine keeps it there, as some of it is set by items, chapter 8):

| Name | Offset | Meaning |
|---|---|---|
| fog timer | `0x5FF7` | Fog ball: counts down, then the fog ends |
| noise on | `0x5FF8` | Noise machine: while not 0, the monster doesn't attack |
| frozen | `0x5FF9` | Squash ball: while not 0, the monster doesn't move |
| fogged | `0x5FFA` (word) | Fog ball: while not 0, the monster's hits miss |
| noise timer | `0x5FFB` | counts down, then the message (noise on is not cleared) |
| frozen timer | `0x5FFC` | counts down, then frozen is cleared |
| monster attack count | `0x5FFD` | |
| poison tick | `0x5FFE` | |
| weapon kind, weapon power | `0x5FFF`, `0x6000` | |
| x, monster x | `0x6001`, `0x6002` | columns, in bytes |
| action | `0x6005` | `0x0F` attack, `0xF0` defend, 0 none |
| facing | `0x600A` | 0 right, `0xFF` left |
| monster facing | `0x600D` | 0 right, `0xFF` left |
| shot, monster shot | `0x600E`, `0x600F` | an attack in flight (`0xFF`) |
| sprite, monster sprite | `0x6012`, `0x6018` (words) | data-area address of the picture drawn |
| move | `0x601E` | `0x0F` right, `0xF0` left, `0xFF` crouch, 0 none |
| jump | `0x6023` | `0xF0` jumping |
| vertical step | `0x6028` (word) | 0 when on the ground |
| jump pointer | `0x602C` (word) | next word of the jump table |
| y | `0x6030` | the player's line |
| monster action | `0x6031` | `0x0F` attack, `0xF0` defend |
| position, monster position | `0x6034`, `0x6038` (words) | screen offsets drawn at |
| hit pose | `0x603C` | |
| monster move | `0x603F` | |
| attack position | `0xDC76` (word) | the screen offset of the attack being drawn |
| old position | `0xDC78` (word) | |
| direction | `0xDC7A` | |
| shot position, monster shot position | `0xDC7B`, `0xDC7D` (words) | |
| shot step, monster shot step | `0xDC7F`, `0xDC81` (words) | +2 or -2 |
| shot column, monster shot column | `0xDC83`, `0xDC84` | |
| shot low, monster shot low | `0xDC85`, `0xDC86` | `0xFF` a low attack |
| shot facing, monster shot facing | `0xDC87`, `0xDC88` | |
| shot life, monster shot life | `0xDC8B`, `0xDC8E` | |

**Blank** is the data area at MAIN:`0xDAF6`, which is zero: drawing it erases.

The monster's record (chapter 2) gives its TEC, AC, BP, HP, POW, poison, **width** (in bytes) and **kind**:
kind `0x10` is a small monster drawn 16 lines high at the bottom; kind `0x20` can be hit by high attacks.
Its sprites are at MAIN:`0x4806` (facing right) and MAIN:`0x4A06` (facing left).

"Waits that eat keys" and "beeps that eat keys" (chapter 3) are used throughout the fight.

## Starting

*A fight* (a place):

1. Mode 4.
2. The weapon: kind and power 0; the first equipped item of kind below 3 gives its kind and value.
3. x 35, monster x 2, the bytes at MAIN:`0x602E` and `0x602F` `0x34` and `0x16`, y 88, poison tick 10,
   vertical step 0; shot, monster shot, attack count, frozen, frozen timer, fog timer, fogged, noise timer,
   shot life and monster shot life all 0. (Noise on is left as it is.)
4. A 5-item menu: clear window 0; kana mode on; column 5, row 3 (margin 5); print `fight.01`.
5. Clear window 1; **the names**; clear window 2. Draw the planar pictures at `B03` offset `0x1400` (40 x 10)
   at `0x0792` and offset `0x18B0` (40 x 8) at `0x2592` (`combat/backdrop_top`, `combat/backdrop_bottom`).
6. Move, jump and action 0; facing left. Draw the player. Monster sprite: facing right. Draw the monster.
   Flush the keys.

**The names**: at column `0x2A`, row `0x11`, kana mode off, print the character's name raw; at column
`0x13`, row `0x11`, the monster's name raw. Draw **a box** at `0x2E52` in all three planes (white). Draw a box
at `0x2E69`: white if not poisoned; if poisoned, a box in plane R only, with planes B and G cleared in its
shape (red).

**A box** at offset `o` in a plane: bytes `o+1` to `o+15` are `0xFF`; for 16 lines, byte `o` is `0x03` and byte
`o+16` is `0xC0`; bytes `o+0x4B1` to `o+0x4BF` are `0xFF`. Clearing it writes 0 to the same bytes.

**Lamps**, in plane R (2 x 8): the monster's at `0x2FA3`, the player's at `0x2FA7`. On draws
`combat/monster_lamp` or `combat/player_lamp`; off draws blank.

**Drawing the player**: the sprite number is 10 when facing right, else 0; plus 9 in the hit pose
(nothing else added), or 6 when jumping, or 3 when moving (not crouching); then, unless in the hit pose, +2
when defending or +1 when attacking. The sprite is the planar picture at MAIN:`0xBCF6 + 0x180 * n`
(`combat/player`), 4 x 32, drawn at `80 * y + x + 0x11`. **Erasing** draws blank, 4 x 32, at the last
position.

**Drawing the monster**: position = monster x + `0x11`; for kind `0x10`, plus `0x2080`, drawing its sprite
16 lines high and 4 bytes wide if its width is 4, else 8; otherwise plus `0x1B80`, 4 x 32. **Erasing** draws
blank in the same shape.

## The round

Repeat for ever, throwing away all keys between every step:

1. The player's turn.
2. The monster's attack.
3. The monster's turn.
4. The player's attack.
5. The timers.
6. A wait of 500 that eats keys.

### The player's turn

1. If on the ground (vertical step 0), **read the controls**.
2. **Move**. **Start an attack**. Erase and draw the player.

**Read the controls**:

1. Luck = `random(255)`. Move, jump and action 0.
2. Read groups 8 and 9 as `(group 8 << 8) | group 9`:
   - `0x0040` (keypad 0): **try to escape**;
   - `0x0008` (2): crouch;
   - `0x0001` (6): right (facing right, move right);
   - `0x4000` (4): left (facing left, move left);
   - `0x0800` (8): jump;
   - `0x0801` (8 and 6): jump and right;
   - `0x4800` (8 and 4): jump and left.
3. Action 0. Group 5 (as a whole): `0x08` (C alone) **command mode**; `0x02` (Z alone) attack (`0x0F`);
   `0x04` (X alone) defend (`0xF0`).
4. Flush the keys.

**Try to escape**: `r = random(255) + random(255)`. If luck + AGL is below `r`, nothing. If luck is below
`random(255)`, nothing. Otherwise clear window 1; at column `0x12`, row `0x14`, kana mode on, print
`fight.02`; a beep that eats keys, on 10000, off 1, once; clear window 1; go to *BIAS*.

**Command mode**: clear window 1; at column `0x1D`, row `0x16` print `fight.03`. Poll the command menu until
an item is chosen (then run it: 1 use, 2 show the abilities, 3 look at the items, 4 unequip, 5 equip) or the
last key read is Esc; 200 µs between polls. Clear window 1. Poll the menu again until a poll chooses nothing
(200 µs between). The names. Flush the keys.

**Move**:

- crouching: nothing;
- move right: on the ground, unless x is 37 or x + 4 is the monster x, x + 1. Jumping: **leap right**;
- move left: on the ground, unless x is 1 or monster x + width is x, x - 1. Jumping: **leap left**;
- otherwise, if jumping: move 0; if the vertical step is 0, start the jump table at MAIN:`0xBCDC`; **a jump
  step**.

**Jump tables** (`combat_jump`, 13 words from MAIN:`0xBCDC`): starting a table at `t` makes the vertical step
the word at `t`, and the jump pointer `t + 2`. **A jump step**: y + the vertical step (as a byte); the
vertical step becomes the word at the pointer; the pointer moves 2 on.

**Touching the monster** at column `c`: monster x < `c + 4` and `c` < monster x + width (bytes, wrapping).

**Leap right**: repeat: if x is 37, leap left instead (and stop). If the monster's kind is `0x10`, and the
vertical step is `0x14`, and touching at x: start the table at `0xBCDE` and check again. Otherwise if the
vertical step is `0x0C` and touching at x + 1: start the table at `0xBCE0` and check again. Then: move right;
unless the vertical step is `0x14` or `-0x14`, x + 1; if the vertical step is 0, start the table at `0xBCDC`;
a jump step.

**Leap left** is the mirror: x 1 leaps right; touching at x (kind `0x10`) or x - 1; move left; x - 1.

**Start an attack**: if attacking and on the ground: shot `0xFF`; the player's lamp on; at column `0x2A`, row
`0x13` print `fight.04`.

### Attacks in flight

**The player's attack** (each round):

1. No shot: at column `0x2A`, row `0x13` print `fight.05`; done.
2. A new shot (shot life 0): life is 255 for weapon kind 1, 5 for kind 2, else 2. Low if crouching. Shot
   facing = facing. Facing right: step +2, column x + 4. Left: step -2, column x - 4. Direction = shot
   facing. Position = column + `0x1EB1` (high) or `0x2091` (low). **Check** it: still flying, draw it;
   otherwise it ends.
3. A flying shot: direction = shot facing; old position = position; position + step; column + step; check:
   still flying, **erase the trail** and draw it; otherwise erase it (blank 4 x 5 at the old position) and it
   ends.
4. **Ends**: life 0; on a hit, **the player hits**.

**Check** (the player's): life - 1. Life 0, column 0 or column 38 or more: shot 0, gone. If monster x is at
least column + 4, or column is at least monster x + width: still flying. If the shot is low or the monster's
kind is `0x20`: shot 0, a hit. Otherwise still flying (a high attack passes over).

**Drawing an attack**: `combat/shot_left` (direction not 0) or `combat/shot_right` (0), 4 x 5, at the
position. **Erasing the trail**: blank 1 x 5 at old position + 1, or + 2 when the direction is not 0.

**The monster's attack** is the same, with these differences:

- no monster shot: at column `0x13`, row `0x13` print `fight.05`;
- a new one: life 255; low if the monster's kind is `0x10`, else `random(1) - 1` (so low on 0, `0xFF`, and
  high on 1); facing = monster facing; facing right: step +2, column monster x + width; left: step -2,
  column monster x - 4; position = column + `0x1C31` (high) or `0x2091` (low);
- **check**: life - 1; life 0, column 0 or 38+: gone. If x is at least column + 4, or column is at least
  x + 4: flying. In the air (vertical step not 0): flying. If low, or the player isn't crouching: a hit.
  Otherwise flying (it passes over the crouching player).
- on a hit, **the monster hits**.

### Hits

**A blink** of a message at column `c`: 3 times: at column `c`, row `0x13`, kana mode on, print it; a beep
that eats keys, on 1000, off 1, once; at column `c`, row `0x13` print `fight.06`; a wait of 1000 that eats
keys.

**The player hits**:

1. `t = TEC / 10 (rounded down) + random(20)`. If its low byte is below the monster's TEC: the monster's lamp
   off; blink `fight.07` at `0x13`; the player's lamp off; done.
2. If the monster's AC is at least `random(60)`: the monster's lamp off; blink `fight.08` at `0x13`; the
   player's lamp off; done.
3. **The monster flashes**: the monster's lamp off. Keep the monster sprite's address (at MAIN:`0xDF13`) and
   write its `0x180` bytes inverted at MAIN:`0xDD13`. 3 times: at column `0x13`, row `0x13` print
   `fight.09`; draw the monster with the inverted sprite; a beep that eats keys (1000, 1, once); print
   `fight.06` there; draw it with its own sprite; a wait of 1000 that eats keys. The player's lamp off.
4. The monster's HP - (weapon power + POW), as a signed number. 0 or less: **victory**.
5. If the monster's TEC is at least `random(26)`, done. Otherwise it is knocked back `random(12) + 4` times,
   away from the player (right if x < monster x, else left): stop if monster x + width reaches 41 (going
   right) or monster x is 1 or less (going left); move it one byte; erase and draw it; a wait of 400 that
   eats keys.

**The monster hits**:

1. Defending: **the player blocks**.
2. `c = (random(70) + the monster's POW)` and `a = (random(80) + AC)`, both as bytes. If `a >= c`: the player
   blocks.
3. Fogged: **the monster misses**.
4. `d = random(250) + random(250) + AGL`, then `e = random(250) + random(250)`. If `d >= e`: the monster
   misses.
5. **The player flashes** with `fight.09`. Adjust HP by `-((the monster's POW + 1) / 2)`.
6. If the monster has poison and `random(1)` is 0: the player flashes with `fight.10`; add the monster's
   poison bits to the character's; the names.
7. The monster's lamp off.

**The player flashes** with a message: the player's lamp off; hit pose on, draw the player, hit pose off; 3
times: at column `0x2A`, row `0x13` print the message, a beep that eats keys (1000, 1, once), print `fight.06`
there, a wait of 1000 that eats keys; the monster's lamp off; draw the player.

**The player blocks**: the player's lamp off; blink `fight.08` at `0x2A`; the monster's lamp off.
**The monster misses**: the player's lamp off; blink `fight.07` at `0x2A`; the monster's lamp off.

### The monster's turn

1. On the ground (the player's vertical step is 0):
   1. If `random(255)` is below 2, and then `random(5)` is 0: **the monster flees**.
   2. **Decide the move**: monster move 0. Frozen: stop. If `random(10)` is 6 or more: stop. If monster x
      equals x: stop. If monster x < x: move `0xF0`, facing right; else move `0x0F`, facing left.
   3. **Move it**: `0x0F` step left; `0xF0` step right.
   4. **Decide the attack**: monster action 0. Noise on: stop. `a = random(11)`. If 4 or more: attack count
      + 1, and at 3 the count goes back to 0 and the action is attack. If 2 or 3: nothing. If 0 or 1: defend.
   5. If attacking: monster shot `0xFF`, the monster's lamp on, print `fight.04` at column `0x13`, row
      `0x13`.
2. Erase and draw the monster.

**Step right**: if x is 37: when monster x + width equals x, step left instead; when it equals x - 1,
nothing. Then, if monster x + width is 41 or equals x, nothing; else monster x + 1 and its sprite faces right.

**Step left**: if x is 1: when x + 4 equals monster x, step right instead; when x + 5 equals it, nothing. Then
if monster x is 1 or equals x + 4, nothing; else monster x - 1 and its sprite faces left.

**The monster flees**: erase it; clear window 1; at column `0x18`, row `0x15` print `fight.11`; a beep that
eats keys (10000, 1, once); Push Space; go to *BIAS*.

### The timers

Frozen timer not 0: count down; at 0, frozen 0 and **the effect is over** with `fight.12`. Noise timer not 0:
count down; at 0, the effect is over with `fight.13`. Fog timer not 0: count down; at 0, fogged 0 and the
effect is over with `fight.14`. Poisoned: poison tick - 1; at 0, adjust HP by `-random(2)` and the tick
goes back to 10. Keys are thrown away before and after each of these.

**The effect is over**: at column `0x13`, row `0x16`, kana mode on, print the message; a beep that eats keys
(10000, 1, once); at column `0x12`, row `0x16` print `fight.15`.

### Victory

1. Unless the FRD is in the inventory *and equipped*, the monster's BP become 0.
2. BP + the monster's BP. Clear window 1. At column `0x1E`, row `0x12` print `fight.16`; a beep that eats
   keys (5000, 1, once).
3. At column `0x18`, row `0x15`, number = the monster's BP, format 1, print `fight.17`. Push Space. Refresh
   the status.
4. If the monster is 39: go to *the ending*. Otherwise go to *BIAS*.

Note: going to *BIAS* redraws the BIAS screen and arrives at the BIAS loop with the player's position as it
was; the monster byte stays set until the next step, so no new monster appears in that cell.
