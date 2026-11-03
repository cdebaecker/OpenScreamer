# 8. Items

## Kinds

An item's kind (byte `0x15` of its record) decides what it does:

| Kind | Meaning |
|---|---|
| 0-2 | weapons (the kind is the weapon's sort; chapter 10) |
| 3-6 | protectors: their value adds to AC when equipped |
| 7 | usable items |
| 8 | items that never break |
| 9 | usable items |
| 10 and up | other items |

For equipping, items are grouped: kind 0 counts as group 1, kind 1 as group 2, and any other kind as
itself (so kinds 1 and 2 share group 2). Only one equipped item per group.

**Breaking** an item replaces it with a broken one, not equipped: item 85 if its kind is below 3, 86 if 3 to
6, 87 otherwise. Then recompute AC.

**The weapon in hand**: equipping an item of kind 0-2 remembers its kind at MAIN:`0x5FFF` and its value at
MAIN:`0x6000` (fights use them). Unequipping or dropping an equipped one of kind 0-2 sets both to 0.

**Adding** an item appends it to the inventory (not equipped). **Removing** an entry shifts the rest down.

**Adjusting a stat** (HP, AGL, POW, TEC or IQ) by `d`: for HP, if `HP + d` is 0 or negative (as a 16-bit
signed number), HP becomes 0, the status is refreshed, and the game goes to *death*. Otherwise the new value
is at least 1 and at most the stat's maximum; refresh the status.

## The item list

The list shows up to 11 items at a time in window 2, and lets the player pick one with the cursor keys.
The list is either the inventory or what a shop sells: for a shop with bit `s`, it is, in order, every item
whose shop byte has a bit in common with `s`, stopping at the first item of the table whose shop byte is 0.
(The list is kept at MAIN:`0x5678`, after a zero byte.)

**Picking an item**:

1. Build the list. If it is empty, finish (below) with nothing picked.
2. Text plane mask 4 (green). Grab window 2 into the work buffer, clear window 2. Remember colour 4, set it to
   7.
3. Number format 1. For the first 11 items, draw line `i` (from 0).
4. The selection is row 0, at the list's first item. Draw the arrow at screen offset `row * 0x280 + 0x0A17`.
5. Wait for keys:
   - cursor down: if there is a next item, move to it. If the row is below 10, move the arrow down a row;
     otherwise scroll (copy plane G, 80 lines of 40 bytes, from `0x0C92` to `0x0A12`, moving it up 8 lines)
     and draw the new item's line on row 10.
   - cursor up: if there is a previous item, move to it. If the row is not 0, move the arrow up; otherwise
     scroll down (copy plane G, 80 lines of 40 bytes, line by line from the bottom: from `0x22C2` to
     `0x2542`, going up) and draw the item's line on row 0.
   - Space: erase the arrow; finish with that item.
   - Esc: finish with nothing.
6. **Finish**: text plane mask 7; set colour 4 back to the remembered value; clear windows 1 and 2; draw the
   work buffer back into window 2. The picked item (its byte, with the equipped bit) or 0 is remembered as
   the selection.

On an empty list, step 2 was skipped, so step 6 draws back whatever the work buffer holds, and sets colour 4
to whatever was remembered last. This is as in the original.

**Line `i`**: row `i + 4`, column `0x19`. Kana mode off; print the item's name; put two spaces. If prices are
shown, print its price as a number in format 1, halved (rounded down) when the list is the inventory. Then
at column `0x31`, print `price_tag_sold` if the item is equipped, else `price_tag_new`.

## The commands

"Print at 12" below means: print at column `0x12`, row `0x11` (margin `0x12`) with kana mode on.

**Look at the items**: clear window 1. Empty inventory: print `item.01` at 12, Push Space. Otherwise, in the
town, prices off; print `item.02` at column `0x1F`, row `0x17`; pick an item from the inventory (the pick
only looks).

**Drop**: clear window 1. Empty: print `item.03` at 12, Push Space. Print `item.04` at 12; pick from the
inventory; nothing picked: done. If equipped, forget the weapon if it is one. If it is the FRD (item 82),
BP and BP since the last rise become 0 and the status is refreshed. Remove it; recompute AC; refresh the
status; clear window 1; print `item.05` at 12; wait 10000; clear window 1.

**Equip**: clear window 1. Empty: at column `0x13`, row `0x11` (margin `0x13`) print `item.06`, Push Space.
Print `item.07` there; pick from the inventory; nothing picked: done. Then, each answer printed at column
`0x13`, row `0x11` after clearing window 1, followed by Push Space:

- its group is 7 or more and it isn't the FRD: `item.08`;
- it is already equipped: `item.09`;
- an equipped item has the same group: `item.10`;
- otherwise equip it, note the weapon, recompute AC, print `item.11` (no Push Space), wait 10000, clear
  window 1.

**Unequip**: clear window 1. Empty: print `item.12` at 12, Push Space. Print `item.13` at 12; pick from the
inventory; nothing picked: done. Not equipped: print `item.14` at 12, Push Space, clear window 1. Otherwise
unequip it, forget the weapon, recompute AC, refresh the status, clear window 1, print `item.15` at 12, wait
10000, clear window 1.

**Pick up** (BIAS): no floor item: print `item.16` at 12, Push Space. Inventory full: print `item.17` at 12,
Push Space. Otherwise clear window 1; print `item.18` at 12; if the floor item has a poison level `p`, the
character gets poison bit `1 << (p - 1)` and `item.19` is printed. Kana mode off; print the item's name, then
`item.20`; Push Space. Add the item. In the map, clear the high nibble of the cell's item byte. Floor item
and its poison 0.

**Examine** (BIAS): writing is ahead when the cell has a wall writing and the map's wall byte ahead has bit 7
or bit 4 set.

- With a floor item: print `item.21` at 12, kana mode off, its name, `item.22`, Push Space; then read the
  wall if there is writing ahead.
- Otherwise, writing ahead: read the wall.
- Otherwise: print `item.23` at 12, Push Space.

**Reading the wall**: print `item.24` at 12; skip *writing - 1* strings from the start of `wall_texts`
(for writing 1 that is 0 strings, which means 65536 skips: chapter 3); kana mode on; print the string there;
print `item.25`; Push Space.

## Using items

**Use**: clear window 1. Empty: print `item.29` at 12, Push Space. Print `item.30` at 12; pick from the
inventory; nothing picked: done. Clear window 1. If its kind is 7 or 9 and its number is 51 to 73, it does
what the table below says. Otherwise print `item.31` at 12, Push Space.

Three common answers, each printed at 12 and followed by Push Space and clearing window 1:
**nothing happens** `item.26`, **no use in a fight** `item.27`, **only in a fight** `item.28`.

**The flash**: five times: hide graphics; beep on 400, off 100, twice; show graphics; the same beep.

| Item | Effect |
|---|---|
| 51 | remove it; print `item.32` at 12; POW = its maximum; refresh the status; Push Space |
| 52 | the same with `item.33` and AGL |
| 53 | the same with `item.34`, and POW, AGL, TEC, IQ and HP all to their maximums |
| 54 | the same with `item.35` and HP |
| 55 | the same with `item.36` and TEC |
| 56 | the same with `item.37` and IQ |
| 57 | remove it; print `item.38` at 12; POW = 250; set the Samson flag; refresh the status; Push Space |
| 58 | the same with `item.39`, IQ and the Brain upper flag |
| 59 | the same with `item.40`, TEC and the Tec upper flag |
| 60 | the same with `item.41`, AGL and the Responser flag |
| 61 | the Revelation ring (below) |
| 62 | the Bacillus sensor (below) |
| 63 | not poisoned: nothing happens. Otherwise poison 0; print `item.42` at 12; refresh the status; Push Space |
| 64 | the Wide mapper (below) |
| 65 | the X-ray searcher (below) |
| 66 | the cell's event byte has bit 6 clear: nothing happens. Otherwise set the lamp flag; set colour 4 to 6 (the dark area lights up yellow) |
| 67 | break it; sound barrier 10; print `item.43` at 12; Push Space |
| 68 | the Guest ID card (below) |
| 69 | the EX card (below) |
| 70 | the Biological searcher (below) |
| 71 | the Noise machine (below) |
| 72 | in BIAS (mode 3): only in a fight. Otherwise the flash; the bytes at MAIN:`0x5FF9` and `0x5FFC` become 50; at column `0x12`, row `0x16` (margin unchanged), kana mode on, print `item.44`; Push Space |
| 73 | in BIAS: only in a fight. Otherwise the flash; the word at MAIN:`0x5FFA` becomes `0x00FF` and the byte at MAIN:`0x5FF7` 50; print `item.45` at column `0x12`, row `0x16`; Push Space |

The bytes at MAIN:`0x5FF7`-`0x5FFC` are fight counters (chapter 10).

**The Revelation ring**: in a fight, no use. If door unlocked is clear, or the map's wall byte ahead has
bit 5 clear, nothing happens. Otherwise clear that bit 5, door unlocked 0, ring flag 0, hunters not hidden;
clear window 2; render the view. Find the current place in `ring_doors` (3 bytes per door: floor, x, y),
counting from 1; skip that many strings in `ring_texts` and print the string there (at the current cursor);
Push Space. (The original searches without an end: the place is always in the table when this happens.)

**The Bacillus sensor**: in a fight, no use. At column `0x13`, row `0x11` (margin `0x13`) typewriter-print
`item.46`. If there is no floor item, or its poison level is below 3, typewriter-print `item.47`, Push
Space. Otherwise typewriter-print `item.48`, then print the string after skipping *level - 3* strings of
`bacillus_names`, Push Space.

**The Wide mapper**: clear window 1. Format 0. At column `0x13`, row `0x11` (margin `0x13`), with the number
= floor, typewriter-print `item.49`; number = x + 1, typewriter-print `item.50`; number = y + 1,
typewriter-print `item.51`. Push Space.

**The X-ray searcher**: in a fight, no use. At column `0x13`, row `0x11` (margin `0x13`) typewriter-print
`item.46`. Look at the cell `xray_steps[facing]` bytes from the current one (16-bit wrap): if its event
(bits 0-5) is 3, a pit, typewriter-print `item.52`, else `item.53`. Push Space.

**The Guest ID card**: in a fight, no use. Break it. On floor 6, nothing happens. Otherwise: clear window 2;
the monster backdrop; show portrait 14; clear window 1; print `item.54` at 12; Push Space. Floor 1, x 0,
y 21, facing south; load the floor and roll its doors; clear window 1; print `item.55` at 12; Push Space;
clear window 2; go to *the BIAS loop*.

**The EX card**: in a fight, no use. If the cell's event minus 20 is not 0 to 4, or the cell copy's wall byte
ahead has bit 5 clear, nothing happens. Otherwise clear bit 5 of the map's wall byte ahead; clear window 1;
print `item.56` at 12; Push Space.

**The Biological searcher**: in BIAS, only in a fight. Clear window 1. Typewriter-print `item.57` at column
`0x1B`, row `0x11`, then `item.58` at `0x1B`, `0x13`; print the monster's name raw; number = its
HP, format as it is; typewriter-print `item.59` at `0x1B`, `0x14`; number = its AC, `item.60` at `0x1B`,
`0x15`; number = its POW, print (not typewriter) `item.61` at `0x1B`, `0x16`. Push Space.

**The Noise machine**: in BIAS, only in a fight. Clear window 1. The byte at MAIN:`0xBB9A` 0. Typewriter-
print `item.62` at column `0x1A`, row `0x11`. Then four questions, each typewriter-printed at column `0x1A`,
rows `0x13` to `0x16`, followed by typing a line: the name (`item.58`), HP (`item.63`), AC (`item.64`) and
POW (`item.65`). It fails if the name differs from the monster's, if HP isn't a number equal to the
monster's HP, or AC or POW aren't numbers whose low byte equals the monster's. On failure set MAIN:`0xBB9A`
to `0xFF`. Clear window 1. Success: at `0x1A`, `0x14` print `item.66`; Push Space; the flash; bytes
MAIN:`0x5FF8` and `0x5FFB` become 50; at column `0x12`, row `0x16` print `item.67`; Push Space. Failure:
at `0x1A`, `0x14` typewriter-print `item.68`; Push Space.
