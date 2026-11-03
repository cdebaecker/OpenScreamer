# 13. Options and the modern host

Chapters 3 to 12 describe the game exactly as the PC-98 version plays. This chapter describes what the engine
adds around it. None of it changes the game, except the two options in the first section.

## Game options

### The way to floor 6 (on by default)

As shipped, the PC-98 version can't be finished:

- The hunters met in BIAS give the pendant chain's rewards only during a fight (mode 4), where giving isn't
  in the menu. So the Samurai Blade (item 25) can't be had.
- The last doors (lock codes 5 to 8, chapter 7) need the blade for codes 5-7 and need it gone for code 8.
  Floor 6 is reached only through a code 8 door behind code 5-7 doors.

The PC-88 version, which people finished, differs in both places. With this option on, the engine plays
them as the PC-88 does:

- In BIAS (mode 3), giving an item uses the table `shops_give_item_combat` (the pendant chain), as in a
  fight.
- A door with lock code 5 or more is never stuck because of item 25: it asks for its password like the
  others.

With the option off, the game is exactly the PC-98's.

### Fixing the original's bugs (off by default)

When on, these change:

- *Noise machine*: noise on is cleared when its timer runs out. *Fog ball*: fogged is its own word (in the
  original, the fog ball's word overlaps the noise timer byte).
- *Bacillus sensor*: reports poison levels 1 to 5 and names level `p` with string `p - 1` of
  `bacillus_names`.
- *Giving*: the wanted item matches whether or not it is equipped. *Selling or giving* an equipped item:
  AC is recomputed. *Selling* the FRD equipped loses the BP too.
- *Hospital*: the amount is rounded down to a multiple of 5; nothing is paid for the remainder.
- *Credits* and BP stop at 65535 instead of wrapping.
- *Class rise*: exactly reaching the table's value rises. Reaching master class during a visit gives the
  memento at once.
- *Floor items*: also looked for on stair and elevator cells, and not looked for again after a fight.
- *Guest ID card*: clears door unlocked.
- *Wall writing 1* reads the first string of `wall_texts`.
- *Monster facing* is reset at the start of a fight; the bump count starts at 3.
- *Random doors* roll the facing wall of the right neighbour.
- *Pit*: using a command keeps the player in the pit.

Each fix needs its own test showing the original's behaviour with the option off.

## The window and the bar

- The 640 x 200 board is shown with each line doubled (640 x 400), scaled to the window. Display styles:
  sharp, CRT, soft. Colour schemes: original, high contrast, colour-blind safe. Optional smooth fades
  between palette changes.
- A bar under the board: KANA (katakana typing), Text (language), Sound, Keyboard (on-screen keyboard),
  Settings, Help.
- F11 full screen, F12 help, F10 settings, F9 fast-forward (x2, x4, x8 the virtual clock), F6 quick save,
  F7 quick load, F8 or M the floor's map.

## The opening notice

Before the demo, the engine shows its own notice, in its own words, using no text from the game:

- the game's title and that it is © 1985 Magical Zoo / ASCII Corporation;
- that OpenScreamer is an unofficial engine, not affiliated with or endorsed by them;
- that it contains nothing from the original, and plays from the player's own copy;
- "Press Space".

It stays at least 1.5 seconds, then until Space or Return, and at most 12 seconds more.

## Importing the disk

On first start (and from Settings), the engine asks for the disk image, reads it (chapter 1), checks every
file, and keeps the files in its user data folder. It never uploads or shares them. A missing or wrong
file is named in the message.

## Keyboard and gamepad

- Keyboards without a keypad: W, A, S, D, E and Q stand for keypad 8, 4, 2, 6, 5 and 0 in the key matrix.
- **Katakana typing**: in KANA mode, romaji typed on the keyboard become katakana key presses (Hepburn and
  Kunrei spellings, `nn`/`n'` for ﾝ, doubled consonants for ｯ, `x`/`l` prefixes for small kana, `-` for ｰ,
  and `.` `,` `[` `]` `/` for ｡ ､ ｢ ｣ ･). The key \` (or the KANA key) switches it.
- A gamepad maps to the same keys (left stick and d-pad to the keypad and cursor keys, face buttons to Space,
  Esc, Z, X, C). An on-screen keyboard comes up when the game waits for typed text and a gamepad is in use.
- All keys can be rebound in Settings.

## Saves (the Modern difficulty)

The original keeps only the roster (`CHAR`), written as in chapter 5. The engine also offers, under a
**Modern** difficulty (the default; **Original** turns them off):

- **Saved games**: when resting in the town's menu or standing in BIAS, the whole game state (the data
  area, the graphics state, the virtual clock, the beeper's last numbers) can be saved and loaded. Loading
  returns to the town menu or the BIAS loop.
- **Going back**: the last 20 states where the player rested in a new BIAS cell are kept. On the death
  screen, the bar offers "Go back…" (R, gamepad Y): a prompt pauses the game and loads one; leaving the
  death screen without going back forgets them.

## Help for the player

- **Automap** of the floor's visited cells (F8 or M, gamepad R3), drawn from the floor's walls; it pauses
  the game.
- **Journal** (J): what people said, wall writings, items found or given, kept per character.
- **Text to speech** of new text (optional), **large text**, **instant text** (typewriter printing done at
  once: the virtual clock jumps ahead).
- The settings menu, help and automap pause the game: the virtual clock does not advance while they are up.

## Translations

The game's text can be shown in the original Japanese or through a translation pack. Packs for English and
French are in [`translations/`](../translations/README.md), under their own (non-GPL) terms. The language
setting offers Japanese plus each pack found there or in the user data folder; the default is English
when that pack is present. The game's logic and its random numbers are the same in every language.

**Keys.** A pack's key for a string is `sha1:` followed by the first 16 hexadecimal digits of the SHA-1 of the
string's bytes: the bytes the game is about to print, up to (not including) the zero byte.

**Printing.** Whenever the game prints a string (printing, raw printing, typewriter printing, and the numbers
printed by `#`), the engine first looks up the string's bytes in the pack's `game` context. If found, it prints
the translation's bytes (ASCII) instead, with the same markup rules, in the same mode. Otherwise it prints the
original. The demo does the same with its `demo` context.

The translation is looked up by the *whole* string as the original would print it. Strings put together from
pieces (a name, then a message) are translated piece by piece. Item and monster names in a pack are already
padded to the original's width.

**Typing words.** When the player talks (chapter 6) in a translated language, after typing the line and
before removing its spaces: normalise the typed line (lower case, keep only `a`-`z` and `0`-`9`), and look for it
among the `keyword` entries' forms (each form normalised the same way). If one matches, the typed line becomes
that keyword's original bytes. If none matches but the line matches the `password` entry's form, the typed line
becomes the password's original bytes (`shops_password`). Japanese mode takes the typed katakana as they are.

**The Noise machine** (chapter 8) also accepts, as the monster's name, its translated name (normalised as
above, and not empty).

**Fonts.** The game's own 8 x 8 font has ASCII, so translations are written without accents. The modern font
option (Noto Sans) shows the same characters.

The engine's own interface (settings, help, notice) is translated the same way, and its English, French and
Japanese versions ship with it.
