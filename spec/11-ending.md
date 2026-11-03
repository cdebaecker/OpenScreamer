# 11. The ending

*The ending* (a place) follows the victory over monster 39.

**A line** `m`: clear window 1 twice; kana mode on; cursor at column `0x13`, row `0x11` (margin `0x13`); the
talk blip; print `m`; Push Space.

**A face** `n`: clear window 2; show portrait `n`.

1. Portrait position `0x08DE`. Clear the screen; clear window 2; show portrait 41. A line `end.01`.
2. Then, in order (picture `n` = show picture `n` at the picture position, `0x0832`):

| Step | Before the line | Line |
|---|---|---|
| 1 | picture 20 | `end.02` |
| 2 | face 41 | `end.03` |
| 3 | picture 20 | `end.04` |
| 4 | face 51 | `end.05` |
| 5 | picture 20 | `end.06` |
| 6 | face 51 | `end.07` |
| 7 | picture 20 | `end.08` |
| 8 | (nothing) | `end.09` |
| 9 | face 51 | `end.10` |
| 10 | picture 20 | `end.11` |
| 11 | clear the screen, picture 1 | `end.12` |
| 12 | picture 16 | `end.13` |
| 13 | face 51 | `end.14` |
| 14 | picture 16 | `end.15` |
| 15 | (nothing) | `end.16` |
| 16 | face 51 | `end.17` |
| 17 | picture 17 | `end.18` |
| 18 | picture 16 | `end.19` |

3. Picture 18. Clear window 1 twice; kana mode on; column `0x13`, row `0x11` (margin `0x13`); the talk blip;
   print `end.20` (no Push Space). Wait 20000.
4. Clear the screen. Show picture 19 at `0x0504`. At column `0x32`, row 4 (margin `0x32`) print `end.21`.
   Wait 10000.
5. Show picture 18 at `0x1C44`. At column `0x0A`, row `0x10` (margin `0x0A`) print `end.22`. Wait 20000.
6. Set the palette pairs (1, 5), (2, 6) and (3, 7) to `0x77`, and (0, 4) to `0x07` (everything white but
   index 0). Wait 40000. (The palette is not set back: the rest is shown that way.)
7. Clear the screen. At column `0x1A`, row `0x0C` (margin `0x1A`) typewriter-print `end.23`. Wait 50000.
8. Clear the screen. At column `0x0D`, row 1 (margin `0x0D`) typewriter-print `end.24` (the staff).
9. Wait for the secret: the 9 bytes of `end.25` (they are not followed by a zero byte in the file). Read
   keys, 200 µs between empty reads; a key equal to the next expected byte moves on, any other key starts
   again from the first byte (and does not count as it).
10. Clear the screen. At column `0x0D`, row 1 (margin `0x0D`) typewriter-print `end.26`.
11. The game stops there for good: time passes, nothing else happens.
