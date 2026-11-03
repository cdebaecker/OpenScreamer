# 9. Cell events

Each cell's event byte (bits 0-5) names an event, run each time the BIAS loop arrives in the cell or turns
there (chapter 7). Events 1 to 18 exist; 0 and 19 or more do nothing.

"Tell" means: print at column `0x12`, row `0x11` (margin `0x12`), kana mode on. "Once" means: if trap done is
set, the event does nothing; otherwise set it. (Trap done is cleared by each step.)

## Animation timing

Most animations here move graphics bytes around, and the original took as long as the CPU did. The engine
charges **1.2 µs of virtual time per byte moved**, at the point named in each step ("costs `n` bytes").
Steps without a cost take no time.

## Screen operations

Animations are made of these. Rectangles are in plane G unless said otherwise; "line `y`, bytes `a`-`b`" means
screen line `y`, byte columns `a` to `b`.

- **Scroll up** a rectangle by one line: each line takes the line below it's bytes, from the top down; the
  bottom line is left as it was (and usually replaced next).
- **Scroll down**: each line takes the bytes of the line above, from the bottom up; the top line is left.

The view window (window 2) is lines 24-127, bytes 18-57.

## The events

### 1. Spinner

Once. Facing + `random(1) * 2 + 1` (a quarter turn right or left), mod 4. Lights off, render the view, look
ahead.

### 2. Noise

Once. Beep on 2, off 2, 8192 times. Adjust HP by -1. Tell `event.01`. Push Space.

### 3. Pit

1. If trap done is set, nothing; else set it.
2. Lights off. Tell `event.02`.
3. **The fall**: copy `0x1400` bytes from the hidden part of plane R at `0x5400` (bank `B02`, offset
   `0x1400`) into the work buffer. 26 times: scroll the view window up by 4 lines (lines 28-127 move to
   24-123); put the next 4 lines of 40 bytes from the work buffer, in order, into lines 124-127; costs 4160
   bytes.
4. Adjust HP by -1.
5. The player is stuck: repeat: 600 µs pass; if the keypad direction is 5, stop; poll the command menu, and if
   a command is chosen, run it (chapter 7) and stop.
6. Clear window 1. Build the view. **The view scrolls down**: 104 times, scroll the view window's lines
   24-127 down by one, and put the next line of the built view, from its last line up, into line 24; costs
   4120 bytes.
7. Tell `event.03`. Push Space.

### 4. Pit to the floor below

Tell `event.04`. The fall (as above). Floor - 1. Load the floor and roll its doors. Clear windows 1 and 2.
Show picture 15. Wait 20000. Clear window 2. Adjust HP by -2. Go to *the BIAS loop*. (The player keeps x, y
and facing.)

### 5. Thunder road

Once. Tell `event.05`. 16 times: **the bolt** in `0xFF`, wait 50, the bolt in 0, wait 200. Adjust HP by -2.
Clear window 1. Tell `event.06`. Push Space.

**The bolt** in value `v`, in plane R: start at line 86, byte 32, 11 bytes wide. 14 times: fill 3 lines of
that width with `v` (going down a line each), beep on 1, off 1, once; then start one byte further left and
2 bytes wider.

### 6. Fire road

Once.

1. Copy `0x1000` bytes from bank `B02` offset `0x2800` into the work buffer.
2. Start with 10 lines at screen offset `0x2457`. 3 times:
   - **Flames**: that many lines of 30 bytes from the start of the work buffer, into plane R at the offset.
     Wait 500.
   - **Unflame**: 32 lines of 30 bytes from the work buffer at offset `0xAF0` (bank `B02` offset `0x32F0`)
     into plane R, 40 lines above the offset. Wait 500.
   - 11 more lines next time; the offset moves up 11 lines.
   - **Shift**: in plane R, 91 times from the top down, copy 30 bytes from line `y` to line `y + 1`,
     starting at screen offset `0x0AB7` (so the 91 lines below that line all become copies of it). Wait 500.
3. Wait 500 twice. Shift. Adjust HP by -1. Tell `event.07`. Push Space.

### 7. Stairs up

If stood is set, nothing; else set it. Tell `event.08`. Yes or No; No does nothing. Floor + 1; load the floor
and roll its doors. Copy `0x1400` bytes from bank `B02` offset 0 into the work buffer. Clear window 1. Draw
the work buffer into the view window's plane G (40 x 104). Build the view; the view scrolls down (as in 3).
Go to *the BIAS loop*.

### 8. Stairs down

If stood is set, nothing; else set it. Tell `event.09`. Yes or No; No does nothing. Floor - 1; load the
floor and roll its doors. Copy the stairs (as in 7) into the work buffer. Clear window 1. 104 times: scroll
the view window up by one line (lines 25-127 to 24-126); put the work buffer's next line, from the top, into
line 127; costs 4120 bytes. Go to *the BIAS loop*.

### 9 and 10. Elevators

If stood is set, nothing; else set it. Tell `event.10` (up) or `event.11` (down). Yes or No; No does nothing.

- Up: from floor 2 to floor 4, 2 rides; otherwise to floor 5, 4 rides.
- Down: from floor 4 to floor 2, 2 rides; otherwise to floor 1, 4 rides.

Load the floor and roll its doors. Then each ride is 80 steps over lines 36-115, bytes 23-52, with the
piece `events/elevator` (30 x 80, plane G):

- up: scroll down by one (lines 36-114 to 37-115) and put the piece's next line, from its last line up, into
  line 36;
- down: scroll up by one (lines 37-115 to 36-114) and put the piece's next line, from its first line down,
  into line 115.

Each step costs 2370 bytes. Then go to *the BIAS loop*.

### 11. Road defender

Only when the cell copy's wall byte ahead has bit 5 set. Once.

1. Copy `0x800` bytes from bank `B03` offset 0 into the work buffer (the robot: plane R part
   `events/robot_r`, then plane G part at buffer offset `0x2F4`, `events/robot_g`).
2. **The robot's door opens.** Wait 1000. **The robot rises.** **The robot's flash.** Wait 2000.
3. Adjust HP by -3. Tell `event.12`. Wait 10000. Clear window 1.
4. **The robot sinks.** **The robot's door closes.**

### 12 to 15. Poison fog

Once. Add poison bit `0x01` (event 12), `0x02` (13), `0x04` (14) or `0x08` (15). Hunters hidden (1); ring
flag set. **The fog.** Clear window 1. Tell `event.13`. Push Space.

### 16. The tower's exit

Only when the cell copy's wall byte ahead has bit 5 set, and the door message isn't set yet; set it. Clear
window 1; kana mode on; cursor at column `0x13`, row `0x11` (margin `0x13`); the talk blip; print
`event.14`. Yes or No; No does nothing. Clear window 2, show picture 1, set colour 4 to 4, wait 30000, go to
*the town*.

### 17. Flying debris

If `random(255)` is 50 or more, nothing (the number is drawn even when trap done is set). Once. Beep on 100,
off 10, 70 times. Adjust HP by -5. Clear window 1. Tell `event.16`. Push Space.

### 18. The ring

Only when the cell copy's wall byte ahead has bit 5 set. Hunters hidden (1); ring flag set; door unlocked
set. Copy the robot (as in 11) into the work buffer. The robot's door opens; the robot rises; wait 5000;
clear window 1; tell `event.15`; Push Space.

(With door unlocked set, keypad 5 does nothing here; the Revelation ring opens the door, chapter 8.)

## The robot and the fog

These work on the doorway ahead, plane G lines 48-115, byte columns 18 + `c` for `c` from 0 to 39 (the view
window's columns). Each line of the doorway is handled in turn, top to bottom, unless said otherwise.

**The robot's door opens** keeps the bytes it pushes off in a stack in the data area, from MAIN:`0x1006`
upwards, in the order below.

- 11 frames. In each, for each line: push column 32; move columns 20-31 one byte right (into 21-32) and
  set column 20 to 0; push column 8; move columns 9-19 one byte left (into 8-18) and set column 19 to 0.
  Each frame costs 1904 bytes.
- Then, for each line (no cost): push column 32; move columns 20-31 right and set column 20 to 0; push
  column 8; set column 8 to 0.
- Then, for each line: push column 32; set column 32 to 0.
- Remember the stack's top (MAIN:`0xBCA4`).

**The robot rises**, 54 steps. Each step, in plane R: scroll lines 62-115, bytes 31-44, up by one, and put
the next 14-byte line of the robot's plane R part (from the work buffer's start) into line 115; then the same
in plane G with the plane G part (from buffer offset `0x2F4`). Each step costs 1484 bytes.

**The robot sinks**, 54 steps: scroll lines 62-115, bytes 31-44, down by one in plane R, then in plane G
(line 62 stays). Each step costs 1484 bytes.

**The robot's flash**: 5 times: hide graphics; beep on 1000, off 1, once; show graphics; wait 1000.

**The robot's door closes**, popping bytes from the stack (from its remembered top, downwards). Here lines
are handled from the bottom (line 115) up.

- For each line: pop into column 32.
- For each line: pop into column 8; move columns 21-32 one byte left (into 20-31); pop into column 32.
- 11 frames. In each, for each line: move columns 8-18 one byte right (into 9-19), working from the right;
  pop into column 8; move columns 21-32 left (into 20-31); pop into column 32. Each frame costs 1904 bytes.

**The fog**:

1. Copy `0x800` bytes from bank `B02` offset `0x3800` (the fog, `events/fog`) into the work buffer.
2. Keep the view: copy plane G of the view window into the data area from MAIN:`0x1006`, 40 bytes per line,
   in this order of lines: for `k` from 0 to 7, the lines `24 + k + 8j` for `j` from 0 to 12. (Lines are
   taken by their position inside each text row first.)
3. A pointer into the fog starts at the work buffer's start, with a counter of 255.
4. 5 passes. Each pass goes through the view window's lines in the same order as step 2. For each line:
   - take the next 8 bytes of fog; count down; when the counter reaches 0, the pointer goes back to the
     start and the counter to 255;
   - the line's new plane B is those 8 bytes, followed by its old plane B bytes 0-31 (it moves 64 pixels
     right, the fog coming in from the left);
   - its new plane G is the kept view's line AND NOT the new plane B.
   After each pass, keep the counter at MAIN:`0xBCA7`; the pass costs 9984 bytes.

(The original copies the 8 fog bytes to MAIN:`0xBCA8` and the line's plane B to MAIN:`0xBCB0`, so reading 40
bytes from `0xBCA8` gives the result above. The engine may write them there as well; nothing else reads
them.)
