# OpenScreamer

An open-source engine for **THE SCREAMER**, a 1985 PC-9801 game. It plays the original game, but it contains
nothing from it: you need your own copy of the original disk. On first start OpenScreamer reads the game's
pictures, maps, tables and text from that disk image, in the same way OpenTTD needs Transport Tycoon's files.

> THE SCREAMER © 1985 Magical Zoo / ASCII Corporation. OpenScreamer is an unofficial project. It is not
> affiliated with or endorsed by the copyright holders, and it does not include or distribute any part of the
> original game.

## Status

Being written. The engine is built in a clean room from the written description in [`spec/`](spec/), and from
nothing else; [`CLEANROOM.md`](CLEANROOM.md) explains the rules.

## What you need

- A disk image of the PC-9801 version of THE SCREAMER, as a Virtual98 `.fdd`, a raw `.hdm`/`.xdf`, or a `.d88`/`.d98`
  image (see [`spec/01-media.md`](spec/01-media.md) for the files the engine checks).
- Godot 4.7 to run it from source.

## Languages

The game plays in the original Japanese, or in English or French through the translation packs in
[`translations/`](translations/README.md).

## Licence

OpenScreamer's code and documents are under the GNU General Public License, version 3 or later
([`LICENSE`](LICENSE)). This licence covers only OpenScreamer's own work. It does not cover the original game,
whose data stays on your disk and in your copy, nor the translation packs in `translations/`, which are a
derivative of the game's text and come under the original copyright holders' non-commercial terms
([`translations/README.md`](translations/README.md)).
