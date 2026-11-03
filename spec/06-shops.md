# 6. Shops, the bar, talking and giving

"NPC line, then Push Space" is written **NPC line + Space** below. Leaving a shop goes to *the town menu*.
"Prices shown" and "hunters hidden" are two switches used by the item list (chapter 8) and BIAS (chapter 7).

## The weapon shop

1. Show picture 6. Prices shown, hunters hidden.
2. A 4-item menu: clear window 0, print `shop.01` at column 5, row 3. NPC line `shop.02`.
3. Repeat, choosing: 1 **buy**; 2 **sell**; 3 look at the items (chapter 8); 4 leave.

**Buy**, repeated until it stops:

1. Prices shown. Clear window 1.
2. If the inventory is full: NPC line `shop.03` + Space, stop.
3. Number = credits, format 0. NPC line `shop.04`.
4. Pick an item from the weapon shop's list (shop bit `0x01`, chapter 8). Nothing picked: stop.
5. Not enough credits for its price: NPC line `shop.05` + Space, stop.
6. NPC line `shop.06`. At column `0x22`, row `0x13` (margin `0x22`), print `shop.07`. Arrow choice
   `shops_buy`; spot 2 stops.
7. Check the credits again as in step 5. Pay the price; add the item to the inventory (not equipped).
8. NPC line `shop.08` + Space. NPC line `shop.09`. At column `0x22`, row `0x13`, print `shop.10`. Arrow choice
   `shops_buy`; anything but spot 1 stops.

When it stops, clear window 1.

**Sell**:

1. Empty inventory: NPC line `shop.11` + Space; done.
2. NPC line `shop.12`. Prices shown. Pick an item from the inventory.
3. If one is picked: the offer is half its price (rounded down). Number = the offer, format 0. NPC line
   `shop.13`. Yes or No. On Yes: credits + offer; remove the item; if it is item 82 (the FRD), **lose the
   BP** (BP and BP since the last rise become 0, refresh the status); NPC line `shop.08` + Space.
4. Clear window 1.

(The offer is kept at MAIN:`0xADD0` while it is asked; nothing else reads it.)

## The FRD office

Item 82 is the FRD, which records the beast points (BP) of fights. Here it is paid out and the hunter class
rises.

1. Show picture 4. NPC line `shop.14`.
2. A 4-item menu: clear window 0, print `shop.15` at column 5, row 3.
3. Repeat, choosing: 1 **show the FRD**; 2 **take an FRD**; 3 show the abilities; 4 leave.

**Show the FRD**:

1. No FRD in the inventory: NPC line `shop.16` + Space; done.
2. BP is 0: NPC line `shop.17` + Space; done.
3. NPC line `shop.18`. Number = BP, format 0; at column `0x1B`, row `0x16` print `shop.19`.
4. BP since the last rise + BP; credits + BP; BP = 0. Refresh the status. Push Space.
5. If HC is 25: **master class**. Otherwise **class rise**, then number = the BP still needed, format 0, and
   NPC line `shop.20` + Space.

**Class rise**, repeated: the BP needed for the next class is word `HC` of `shops_class_bp`. The BP still
needed is that minus the BP since the last rise, as an ordinary signed number. If it is 0 or more, stop
with it. Otherwise: NPC line `shop.21`; HC + 1; maximum HP + 10, and if that is 251 or more it becomes 255;
the maximum AGL, POW, TEC and IQ each + 10, at most 250; Push Space; refresh the status; and check again.

(The BP since the last rise is never reset by a rise, so the table holds running totals.)

**Master class**: NPC line `shop.22` + Space. If item 74 (the pendant) is in the inventory, done. If the
inventory is full: NPC line `shop.23` + Space; done. Otherwise add item 74 and NPC line `shop.24` + Space.

**Take an FRD**: if the FRD is in the inventory: NPC line `shop.25` + Space. Else if the inventory is
full: NPC line `shop.26` + Space. Else add item 82, NPC line `shop.27` + Space, NPC line `shop.28` + Space.

## The hospital

1. Show picture 5. NPC line `shop.29`.
2. An 8-item menu: clear window 0, print `shop.30` at column 5, row 3.
3. Repeat, choosing: 1 to 5 **treat** HP, AGL, POW, IQ or TEC; 6 **antidote**; 7 show the abilities;
   8 leave.

The treatments use these labels, from `shops_treat_labels`: HP the first string (MAIN:`0xB14B`), AGL the second
(MAIN:`0xB157`), POW the third (MAIN:`0xB164`), IQ the fourth (MAIN:`0xB171`), TEC the fifth (MAIN:`0xB17D`).

**Show the credits**: column `0x27`, row `0x17`; number = credits, format 0; print `shop.31`.
**Show the stat**: column `0x13`, row `0x17`; number = the stat's value, format 0; print its label.
**Wrong payment**: NPC line `shop.32` + Space.

**Treat** a stat:

1. NPC line `shop.33`. Show the credits. Show the stat.
2. Cursor at column `0x1B`, row `0x14`. Type a line and read a number.
3. Not a number, or less than 5: wrong payment; done.
4. Credits - the amount below 0: wrong payment; done. Remember that difference as the final credits.
5. Repeat: kana mode on; **adjust** the stat by +1 (chapter 8); show the stat; wait 5000; credits - 5;
   amount - 5; stop when the amount is 0 or less; show the credits.
6. Credits = the final credits (so an amount that isn't a multiple of 5 is paid in full). Kana mode on.
   NPC line `shop.34`. Refresh the status.

Adjusting HP above its maximum stops at the maximum; paying more only costs more.

**Antidote**:

1. Not poisoned: NPC line `shop.35` + Space; done.
2. NPC line `shop.36`. At column `0x25`, row `0x14` (margin `0x25`) print `shop.37`.
3. Column `0x14`, row `0x17`; number = credits, format 0; print `shop.31`.
4. The price: count the poison bits set (of `0x01` to `0x10`); the price is word *count* of
   `shops_antidote_prices`. Number = the price. At column `0x2B`, row `0x17` print `shop.38`.
5. Arrow choice `shops_antidote`. Not spot 1: NPC line `shop.39` + Space; done.
6. Credits - price below 0: wrong payment; done. Otherwise pay, poison = 0, set the text column to 255
   (it is set again before use), NPC line `shop.34` + Space.

## The bar

*The bar* (a place):

1. Portrait position `0x083C`. Show picture 7. NPC line `shop.40`.
2. Repeat:
   1. A 3-item menu: clear window 0, print `shop.41` at column 5, row 3.
   2. Choose until seated: 1 **drink**; 2 show the abilities; 3 leave (go to *the town menu*).
   3. When the player leaves the seat: show picture 7, NPC line `shop.42`.

**Drink**:

1. Fewer than 50 credits: NPC line `shop.43` + Space, and go to *the town menu*.
2. Pay 50. A 4-item menu: clear window 0, print `shop.44` at column 5, row 3. NPC line `shop.45`.
3. Repeat: show picture 8; choose: 1 **talk**; 2 **give**; 3 show the abilities; 4 leave the seat.

## Who to talk to

In the town (mode 2), the person is picked in the bar:

1. Clear window 1, and print the question (below) at column `0x12`, row `0x11` (margin `0x12`).
2. **Pick a person**: at column `0x1D`, row `0x13` (margin `0x1D`) print `shop.46`. Arrow choice
   `shops_person` (8 spots). Remember the spot at MAIN:`0xBC72`. Clear window 1. Spot 8 means nobody:
   stop. Otherwise clear window 2 and show portrait *spot + 51* (portraits 52-58).

In BIAS (mode 3) the person is the hunter met there, if any (chapter 7). With nobody there: clear window 1,
print `shop.48` at column `0x12`, row `0x11`, Push Space, stop.

The person's number (1-7) is kept, for talking at MAIN:`0xADDE` and for giving at MAIN:`0xB1A2`.

## Talking

1. Who to talk to, with the question `shop.47`.
2. Clear window 1, print `shop.49` at column `0x12`, row `0x11` (margin `0x12`). Type a line.
3. If the person is 7 and the line equals `shops_password`: show picture 14; clear window 1; at column
   `0x13`, row `0x11` (margin `0x13`) print `_` (a new line), then `shop.50`; wait 50000; clear window 1;
   done.
4. Remove every space from the typed line.
5. Look it up in the conversation table (chapter 2): the first entry whose keyword equals the line.
   None: clear window 1, print `shop.51` at column `0x12`, row `0x11`, Push Space; done.
6. If the character's IQ (its low byte) is below the entry's IQ: clear window 1, print `shop.52` there,
   Push Space; done.
7. The reply: with `n` replies, take reply `random(n - 1)` (counting from 0), or reply 0 when `n` is 1
   (no random number is used then).
8. Clear window 1. At column `0x13`, row `0x11` (margin `0x13`), kana mode on, print the reply. Push Space.

The talk is the same with every person: only the password differs.

## Giving

1. Who to give to, with the question `shop.53`.
2. Clear window 1; print `shop.54` at column `0x12`, row `0x11`. Arrow choice `shops_give`: spot 1 gold,
   anything else an item.

The tables below hold, for each person, entries of the form described. Person `p`'s entry is found by
skipping `2p` zero-terminated strings from the table's start.

**Gold** (table `shops_give_gold`, MAIN:`0xB1B3`):

1. Repeat until a number is read: clear window 1, print `shop.55` at column `0x12`, row `0x11`, type a line.
2. 0: clear window 1, print `shop.56`, Push Space; done.
3. More than the credits: clear window 1, print `shop.57`, Push Space; done.
4. Pay it. Take the person's entry: a 16-bit amount, then two replies. If the gift is at least the amount,
   the reply starts 2 bytes after the entry's start (just after the amount, so its first reply). Otherwise
   skip one zero-terminated string starting at the amount's first byte, and the reply starts after it.
   Normally that skips the amount and the first reply; when a byte of the amount is 0, the skip ends there
   instead, as in the original.
5. Clear window 1; at column `0x13`, row `0x11` (margin `0x13`), kana mode on, print the reply. Push Space.

**An item**:

1. Clear window 1. Empty inventory: print `shop.58` at column `0x12`, row `0x11`, Push Space; done.
2. Print `shop.59` there. Pick an item from the inventory; nothing picked: done.
3. Remove it. If it is the FRD (item 82, equipped or not), lose the BP.
4. The table is `shops_give_item_combat` (MAIN:`0xB494`) during a fight (mode 4), `shops_give_item`
   (MAIN:`0xB75E`) otherwise. The person's entry: the wanted item's number (with its equipped bit), the
   reward item, then the thank-you reply; after it, the other reply.
5. If the item given (its byte as listed, with the equipped bit) is the wanted one:
   - inventory full: clear window 1, print `shop.60`, Push Space; done (the item is gone, no reward);
   - otherwise add the reward; at column `0x13`, row `0x11` (margin `0x13`) print the thank-you reply, then
     `shop.61`, then the reward's name, then `shop.62`; Push Space.
6. Otherwise skip one string from the byte after the wanted item, print that string at column `0x13`, row
   `0x11` (margin `0x13`), and Push Space.

In BIAS, giving uses the hunter met (chapter 7). During a fight, it is reached from the fight's command
mode (chapter 10).
