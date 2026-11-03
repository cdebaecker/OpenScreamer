# The OpenScreamer specification

What THE SCREAMER (PC-9801, 1985) does, written so an engine can be built from it alone. Read
[`../CLEANROOM.md`](../CLEANROOM.md) first.

| Chapter | |
|---|---|
| [1. The original disk](01-media.md) | disk images, FAT12, the files and their digests |
| [2. File formats](02-formats.md) | the programs' data segments, pictures, maps, records, text |
| [3. The machine the game sees](03-machine.md) | graphics planes, text, time, beeps, keyboard, menus, typing, random numbers |
| [4. Where the data is](04-data.md) | tables, picture pieces and every message, by offset |
| [5. Flow, registration, the town and death](05-flow-town.md) | |
| [6. Shops, the bar, talking and giving](06-shops.md) | |
| [7. BIAS, the tower](07-bias.md) | the view, walking, doors, encounters |
| [8. Items](08-items.md) | the item list, the commands, using items |
| [9. Cell events](09-events.md) | traps, stairs, elevators, the robot, the fog |
| [10. Fights](10-fights.md) | |
| [11. The ending](11-ending.md) | |
| [12. The attract demo](12-demo.md) | |
| [13. Options and the modern host](13-options-host.md) | what the engine adds |
| [14. Checking the engine](14-verification.md) | key scripts and what is compared |

## Conventions

- Numbers in `0x` are hexadecimal; others are decimal.
- **MAIN:x** and **DEMO:x** are offsets in the two programs' data segments (chapter 2). The game keeps its
  data area at the same offsets.
- Screen offsets are byte offsets in a graphics plane: `80 * line + column / 8` (chapter 3).
- "Column `c`, row `r`" are text cells (8 x 8 pixels). "(margin `m`)" also sets the left margin; without it
  the margin stays as it was.
- Message identifiers such as `town.05` are listed with their offsets in chapter 4. The spec never quotes the
  game's text.
- `random(n)` is the game's random number from 0 to `n` (chapter 3). The order of random numbers matters.
- A **place** (chapter 5) is a point the game jumps to, abandoning what was in progress.

Questions from the engine side go in [`QUESTIONS.md`](QUESTIONS.md).
