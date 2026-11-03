# Clean-room rules

OpenScreamer's engine must not be a copy or translation of the original program. It is written the way
compatible BIOSes were written in the 1980s, by two separate sides:

- **The spec side** has studied the original: its disassembly, and an earlier port that follows the original
  routine by routine. It writes [`spec/`](spec/), a description of *what the game does*: its rules, screens,
  timings and file formats.
- **The engine side** writes the engine from `spec/` alone.

## The engine side

- It reads only this repository, Godot's documentation and general references, such as the PC-9801's
  hardware or the FAT12 format.
- It never opens the original program's code, its disassembly, any earlier port of the game, or any other
  project's reimplementation of it. It never runs a disassembler on the original files.
- Where the spec is unclear or missing something, it asks the spec side in writing
  (`spec/QUESTIONS.md`). It never guesses from the original's files beyond what the spec describes.
- It may open a disk image to check that the engine reads it as the spec describes. Everything the engine
  shows comes from the player's own disk image at run time.

## The spec side

- It describes behaviour in prose, tables and formulas: what the player sees and hears, in what order, how
  long it takes, and which numbers change and how.
- It includes no code from the original or from the earlier port, no pseudo-code that follows a routine
  line by line, no code addresses, and no routine names or numbers.
- It may give **where data sits** in the original files: file names, offsets, record layouts and sizes. A
  program has to know these to read the files (interoperability), and the data itself stays on the
  player's disk.
- It quotes none of the game's text, and none of its pictures. A message is named by an identifier and
  located by its offset in the original file. A picture is named and located the same way.
- When the engine side's behaviour differs from the original, the spec side may report the difference in
  the spec's own terms (for example "the second hit of a combo should cost 1 more HP"), never by pointing at
  original code.

## Repository

- No file from the original game, extracted or converted, is ever committed. `.gitignore` keeps disk
  images and the engine's import folder out.
- Commits that change `spec/` are made by the spec side. Commits that change the engine are made by the
  engine side.
