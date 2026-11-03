# 4. Where the data is

Everything the engine shows or uses from the original is read from the player's files at these
places. Names are the spec's own. Chapter numbers say where each is used.

## Tables

In MAIN's data segment. Types: `u8` bytes, `u16` 16-bit words, `str` one zero-terminated string,
`strs` that many zero-terminated strings one after another.

| Name | Offset | Count | Type | Chapter |
|---|---|---|---|---|
| `combat_jump` | MAIN:`0xBCDC` | 13 | u16 | 10 |
| `yes_no_nav` | MAIN:`0xAB40` | 8 | u8 | 3 |
| `yes_no_pos` | MAIN:`0xAB48` | 2 | u16 | 3 |
| `init_state` | MAIN:`0x5F9A` | 76 | u8 | 3 |
| `init_rng_seed` | MAIN:`0xAB4C` | 1 | u16 | 3 |
| `init_beep` | MAIN:`0x604A` | 3 | u16 | 3 |
| `init_hide_hunter` | MAIN:`0x5675` | 1 | u8 | 3 |
| `init_map` | MAIN:`0x3406` | 5120 | u8 | 3 |
| `init_chr` | MAIN:`0x4D52` | 128 | u8 | 3 |
| `view_wall_offsets` | MAIN:`0xAE20` | 108 | u16 | 7 |
| `view_pieces` | MAIN:`0xAEF8` | 108 | u16 | 7 |
| `light_frames` | MAIN:`0xAB82` | 8 | u16 | 7 |
| `ahead_dx` | MAIN:`0xAB92` | 4 | u16 | 7 |
| `placed_items` | MAIN:`0xA8E0` | 15 | u8 | 7 |
| `floor_items` | MAIN:`0xA8EF` | 64 | u8 | 7 |
| `encounter_rates` | MAIN:`0xB904` | 16 | u8 | 7 |
| `floor_monsters` | MAIN:`0xB913` | 80 | u8 | 7 |
| `door_passwords` | MAIN:`0xAB4F` | 50 | u8 | 7 |
| `price_tag_sold` | MAIN:`0x56F9` | 1 | str | 8 |
| `price_tag_new` | MAIN:`0x5702` | 1 | str | 8 |
| `wall_texts` | MAIN:`0xAFD0` | 21 | strs | 8 |
| `ring_doors` | MAIN:`0xBB9B` | 12 | u8 | 8 |
| `ring_texts` | MAIN:`0xBBA7` | 5 | strs | 8 |
| `bacillus_names` | MAIN:`0xBC12` | 6 | strs | 8 |
| `xray_steps` | MAIN:`0xBC45` | 4 | u16 | 8 |
| `shops_buy_nav` | MAIN:`0xADD2` | 8 | u8 | 6 |
| `shops_buy_pos` | MAIN:`0xADDA` | 2 | u16 | 6 |
| `shops_init_vars` | MAIN:`0xADD0` | 15 | u8 | 6 |
| `shops_password` | MAIN:`0xADDF` | 1 | str | 6 |
| `shops_class_bp` | MAIN:`0xADEC` | 26 | u16 | 6 |
| `shops_treat_labels` | MAIN:`0xB14B` | 5 | strs | 6 |
| `shops_antidote_prices` | MAIN:`0xB18A` | 6 | u16 | 6 |
| `shops_antidote_nav` | MAIN:`0xB196` | 8 | u8 | 6 |
| `shops_antidote_pos` | MAIN:`0xB19E` | 2 | u16 | 6 |
| `shops_init_give_person` | MAIN:`0xB1A2` | 1 | u8 | 6 |
| `shops_give_nav` | MAIN:`0xB1A3` | 8 | u8 | 6 |
| `shops_give_pos` | MAIN:`0xB1AF` | 2 | u16 | 6 |
| `shops_give_gold` | MAIN:`0xB1B3` | 737 | u8 | 6 |
| `shops_give_item_combat` | MAIN:`0xB494` | 714 | u8 | 6 |
| `shops_give_item` | MAIN:`0xB75E` | 768 | u8 | 6 |
| `shops_init_person` | MAIN:`0xBC72` | 1 | u8 | 6 |
| `shops_person_nav` | MAIN:`0xBC73` | 32 | u8 | 6 |
| `shops_person_pos` | MAIN:`0xBC93` | 8 | u16 | 6 |
| `town_new_or_registered_nav` | MAIN:`0x6068` | 8 | u8 | 5 |
| `town_new_or_registered_pos` | MAIN:`0x6070` | 2 | u16 | 5 |
| `town_yes_no_nav` | MAIN:`0x6074` | 8 | u8 | 5 |
| `town_yes_no_pos` | MAIN:`0x607C` | 2 | u16 | 5 |
| `town_pick_nav` | MAIN:`0x6080` | 28 | u8 | 5 |
| `town_pick_pos` | MAIN:`0x609C` | 7 | u16 | 5 |
| `town_init_roster` | MAIN:`0x6066` | 2 | u8 | 5 |
| `town_name_cheat_stats` | MAIN:`0x60AA` | 1 | str | 5 |
| `town_name_dead` | MAIN:`0x60B9` | 1 | str | 5 |
| `town_name_drinker` | MAIN:`0x60C4` | 1 | str | 5 |
| `town_name_porter` | MAIN:`0x60D2` | 1 | str | 5 |

## Picture pieces

Sources: `MAIN` is MAIN's data segment; `B01`-`B03` are offsets in those files. `w` is in bytes,
`h` in lines. Modes: `3` a planar picture; `B`, `R`, `G` one plane (drawn into that plane);
`W` one plane drawn into all three (white). `frames` pieces follow each other `stride` bytes apart.

| Name | Source | Offset | w | h | Mode | Frames | Stride | Chapter |
|---|---|---|---|---|---|---|---|---|
| `combat/player` | MAIN | `0xBCF6` | 4 | 32 | 3 | 20 | 0x180 | 10 |
| `combat/shot_left` | MAIN | `0xDC8F` | 4 | 5 | 3 | 1 |  | 10 |
| `combat/shot_right` | MAIN | `0xDCCB` | 4 | 5 | 3 | 1 |  | 10 |
| `combat/monster_lamp` | MAIN | `0xBC4E` | 2 | 8 | R | 1 |  | 10 |
| `combat/player_lamp` | MAIN | `0xBC5E` | 2 | 8 | R | 1 |  | 10 |
| `combat/backdrop_top` | B03 | `0x1400` | 40 | 10 | 3 | 1 |  | 10 |
| `combat/backdrop_bottom` | B03 | `0x18B0` | 40 | 8 | 3 | 1 |  | 10 |
| `ui/arrow` | MAIN | `0x4E4A` | 1 | 8 | R | 1 |  | 3 |
| `view/p_60df` | MAIN | `0x60DF` | 40 | 44 | G | 1 |  | 7 |
| `view/p_67bf` | MAIN | `0x67BF` | 5 | 16 | G | 1 |  | 7 |
| `view/p_8987` | MAIN | `0x8987` | 5 | 16 | G | 1 |  | 7 |
| `view/p_680f` | MAIN | `0x680F` | 6 | 16 | G | 1 |  | 7 |
| `view/p_89d7` | MAIN | `0x89D7` | 6 | 16 | G | 1 |  | 7 |
| `view/p_686f` | MAIN | `0x686F` | 6 | 16 | G | 1 |  | 7 |
| `view/p_68cf` | MAIN | `0x68CF` | 6 | 16 | G | 1 |  | 7 |
| `view/p_692f` | MAIN | `0x692F` | 6 | 16 | G | 1 |  | 7 |
| `view/p_698f` | MAIN | `0x698F` | 6 | 16 | G | 1 |  | 7 |
| `view/p_69ef` | MAIN | `0x69EF` | 5 | 16 | G | 1 |  | 7 |
| `view/p_8a37` | MAIN | `0x8A37` | 5 | 16 | G | 1 |  | 7 |
| `view/p_6a3f` | MAIN | `0x6A3F` | 5 | 24 | G | 1 |  | 7 |
| `view/p_8a87` | MAIN | `0x8A87` | 5 | 24 | G | 1 |  | 7 |
| `view/p_6ab7` | MAIN | `0x6AB7` | 6 | 28 | G | 1 |  | 7 |
| `view/p_8aff` | MAIN | `0x8AFF` | 6 | 28 | G | 1 |  | 7 |
| `view/p_6b5f` | MAIN | `0x6B5F` | 2 | 28 | G | 1 |  | 7 |
| `view/p_8ba7` | MAIN | `0x8BA7` | 2 | 28 | G | 1 |  | 7 |
| `view/p_6b97` | MAIN | `0x6B97` | 2 | 28 | G | 1 |  | 7 |
| `view/p_8bdf` | MAIN | `0x8BDF` | 2 | 28 | G | 1 |  | 7 |
| `view/p_6bcf` | MAIN | `0x6BCF` | 6 | 28 | G | 1 |  | 7 |
| `view/p_8c17` | MAIN | `0x8C17` | 6 | 28 | G | 1 |  | 7 |
| `view/p_6c77` | MAIN | `0x6C77` | 5 | 24 | G | 1 |  | 7 |
| `view/p_8cbf` | MAIN | `0x8CBF` | 5 | 24 | G | 1 |  | 7 |
| `view/p_6cef` | MAIN | `0x6CEF` | 5 | 28 | G | 1 |  | 7 |
| `view/p_8d37` | MAIN | `0x8D37` | 5 | 28 | G | 1 |  | 7 |
| `view/p_6d7b` | MAIN | `0x6D7B` | 10 | 28 | G | 1 |  | 7 |
| `view/p_8dc3` | MAIN | `0x8DC3` | 10 | 28 | G | 1 |  | 7 |
| `view/p_6e93` | MAIN | `0x6E93` | 10 | 28 | G | 1 |  | 7 |
| `view/p_6fab` | MAIN | `0x6FAB` | 10 | 28 | G | 1 |  | 7 |
| `view/p_70c3` | MAIN | `0x70C3` | 5 | 28 | G | 1 |  | 7 |
| `view/p_8edb` | MAIN | `0x8EDB` | 5 | 28 | G | 1 |  | 7 |
| `view/p_714f` | MAIN | `0x714F` | 5 | 36 | G | 1 |  | 7 |
| `view/p_8f67` | MAIN | `0x8F67` | 5 | 36 | G | 1 |  | 7 |
| `view/p_7203` | MAIN | `0x7203` | 10 | 80 | G | 1 |  | 7 |
| `view/p_901b` | MAIN | `0x901B` | 10 | 80 | G | 1 |  | 7 |
| `view/p_7523` | MAIN | `0x7523` | 10 | 80 | G | 1 |  | 7 |
| `view/p_933b` | MAIN | `0x933B` | 10 | 80 | G | 1 |  | 7 |
| `view/p_7843` | MAIN | `0x7843` | 5 | 36 | G | 1 |  | 7 |
| `view/p_965b` | MAIN | `0x965B` | 5 | 36 | G | 1 |  | 7 |
| `view/p_78f7` | MAIN | `0x78F7` | 5 | 80 | G | 1 |  | 7 |
| `view/p_970f` | MAIN | `0x970F` | 5 | 80 | G | 1 |  | 7 |
| `view/p_7a87` | MAIN | `0x7A87` | 30 | 80 | G | 1 |  | 7 |
| `view/p_989f` | MAIN | `0x989F` | 30 | 80 | G | 1 |  | 7 |
| `view/p_83e7` | MAIN | `0x83E7` | 5 | 80 | G | 1 |  | 7 |
| `view/p_a1ff` | MAIN | `0xA1FF` | 5 | 80 | G | 1 |  | 7 |
| `view/p_8577` | MAIN | `0x8577` | 5 | 104 | G | 1 |  | 7 |
| `view/p_a38f` | MAIN | `0xA38F` | 5 | 104 | G | 1 |  | 7 |
| `view/p_877f` | MAIN | `0x877F` | 5 | 104 | G | 1 |  | 7 |
| `view/p_a597` | MAIN | `0xA597` | 5 | 104 | G | 1 |  | 7 |
| `view/light_aba0_0` | MAIN | `0xABA0` | 16 | 4 | B | 1 |  | 7 |
| `view/light_aba0_1` | MAIN | `0xABE0` | 8 | 5 | B | 1 |  | 7 |
| `view/light_aba0_2` | MAIN | `0xAC08` | 4 | 2 | B | 1 |  | 7 |
| `view/light_ac10_0` | MAIN | `0xAC10` | 16 | 4 | B | 1 |  | 7 |
| `view/light_ac10_1` | MAIN | `0xAC50` | 8 | 5 | B | 1 |  | 7 |
| `view/light_ac10_2` | MAIN | `0xAC78` | 4 | 2 | B | 1 |  | 7 |
| `view/light_ac80_0` | MAIN | `0xAC80` | 16 | 4 | B | 1 |  | 7 |
| `view/light_ac80_1` | MAIN | `0xACC0` | 8 | 5 | B | 1 |  | 7 |
| `view/light_ac80_2` | MAIN | `0xACE8` | 4 | 2 | B | 1 |  | 7 |
| `view/light_acf0_0` | MAIN | `0xACF0` | 16 | 4 | B | 1 |  | 7 |
| `view/light_acf0_1` | MAIN | `0xAD30` | 8 | 5 | B | 1 |  | 7 |
| `view/light_acf0_2` | MAIN | `0xAD58` | 4 | 2 | B | 1 |  | 7 |
| `view/light_ad60_0` | MAIN | `0xAD60` | 16 | 4 | B | 1 |  | 7 |
| `view/light_ad60_1` | MAIN | `0xADA0` | 8 | 5 | B | 1 |  | 7 |
| `view/light_ad60_2` | MAIN | `0xADC8` | 4 | 2 | B | 1 |  | 7 |
| `dungeon/step` | MAIN | `0xB9D9` | 4 | 16 | 3 | 2 | 0xC0 | 7 |
| `dungeon/compass` | MAIN | `0xBB59` | 2 | 8 | W | 4 | 0x10 | 7 |
| `dungeon/backdrop` | B01 | `0x2800` | 20 | 100 | 3 | 1 |  | 7 |
| `events/pit` | B02 | `0x1400` | 40 | 104 | G | 1 |  | 9 |
| `events/stairs` | B02 | `0x0` | 40 | 104 | G | 1 |  | 9 |
| `events/fire` | B02 | `0x2800` | 30 | 32 | R | 1 |  | 9 |
| `events/fire_top` | B02 | `0x32F0` | 30 | 32 | R | 1 |  | 9 |
| `events/fog` | B02 | `0x3800` | 8 | 256 | B | 1 |  | 9 |
| `events/robot_r` | B03 | `0x0` | 14 | 54 | R | 1 |  | 9 |
| `events/robot_g` | B03 | `0x2F4` | 14 | 54 | G | 1 |  | 9 |
| `events/elevator` | MAIN | `0x7A87` | 30 | 80 | G | 1 |  | 9 |
| `town/gate_lamp_off` | MAIN | `0x4C8A` | 3 | 11 | 3 | 1 |  | 5 |
| `town/gate_lamp_on` | MAIN | `0x4CED` | 3 | 11 | 3 | 1 |  | 5 |

## Messages

Every message the game prints, by its identifier in this spec. `File offset` is from the start of
the program file; the message is `Length` bytes and then a zero byte. Read it from there and print it
with the markup of chapter 3. Messages are named by the chapter that prints them.

| Message | Program | File offset | Length |
|---|---|---|---|
| `char.01` | MAIN2HDE.EXE | `0xF8D` | 27 |
| `char.02` | MAIN2HDE.EXE | `0xFF2` | 12 |
| `char.03` | MAIN2HDE.EXE | `0x1018` | 12 |
| `char.04` | MAIN2HDE.EXE | `0x103E` | 12 |
| `char.05` | MAIN2HDE.EXE | `0x1064` | 12 |
| `char.06` | MAIN2HDE.EXE | `0x108A` | 11 |
| `char.07` | MAIN2HDE.EXE | `0x10BE` | 8 |
| `char.08` | MAIN2HDE.EXE | `0x10E0` | 8 |
| `char.09` | MAIN2HDE.EXE | `0x1102` | 8 |
| `char.10` | MAIN2HDE.EXE | `0x1124` | 8 |
| `char.11` | MAIN2HDE.EXE | `0x1146` | 8 |
| `char.12` | MAIN2HDE.EXE | `0x1152` | 7 |
| `char.13` | MAIN2HDE.EXE | `0x1164` | 8 |
| `char.14` | MAIN2HDE.EXE | `0x1173` | 2 |
| `fight.01` | MAIN2HDE.EXE | `0x9808` | 57 |
| `fight.02` | MAIN2HDE.EXE | `0xA33B` | 34 |
| `fight.03` | MAIN2HDE.EXE | `0xA3C9` | 20 |
| `fight.04` | MAIN2HDE.EXE | `0x9B63` | 13 |
| `fight.05` | MAIN2HDE.EXE | `0x9962` | 15 |
| `fight.06` | MAIN2HDE.EXE | `0x9966` | 11 |
| `fight.07` | MAIN2HDE.EXE | `0xA83F` | 13 |
| `fight.08` | MAIN2HDE.EXE | `0xA5F7` | 13 |
| `fight.09` | MAIN2HDE.EXE | `0xA65F` | 13 |
| `fight.10` | MAIN2HDE.EXE | `0xA6CA` | 12 |
| `fight.11` | MAIN2HDE.EXE | `0x9DBD` | 25 |
| `fight.12` | MAIN2HDE.EXE | `0x98FC` | 42 |
| `fight.13` | MAIN2HDE.EXE | `0x9994` | 41 |
| `fight.14` | MAIN2HDE.EXE | `0x9A31` | 42 |
| `fight.15` | MAIN2HDE.EXE | `0x9949` | 40 |
| `fight.16` | MAIN2HDE.EXE | `0xA92B` | 17 |
| `fight.17` | MAIN2HDE.EXE | `0xA975` | 24 |
| `bias.01` | MAIN2HDE.EXE | `0x244B` | 90 |
| `bias.02` | MAIN2HDE.EXE | `0x2576` | 34 |
| `bias.03` | MAIN2HDE.EXE | `0x25C4` | 34 |
| `bias.04` | MAIN2HDE.EXE | `0x2612` | 32 |
| `bias.05` | MAIN2HDE.EXE | `0x265E` | 30 |
| `bias.06` | MAIN2HDE.EXE | `0x2519` | 36 |
| `bias.07` | MAIN2HDE.EXE | `0x26F7` | 24 |
| `bias.08` | MAIN2HDE.EXE | `0x2742` | 31 |
| `bias.09` | MAIN2HDE.EXE | `0x2829` | 33 |
| `bias.10` | MAIN2HDE.EXE | `0x360C` | 32 |
| `bias.11` | MAIN2HDE.EXE | `0x351F` | 63 |
| `bias.12` | MAIN2HDE.EXE | `0x35A4` | 21 |
| `bias.13` | MAIN2HDE.EXE | `0x3465` | 27 |
| `bias.14` | MAIN2HDE.EXE | `0x6BC7` | 30 |
| `bias.15` | MAIN2HDE.EXE | `0x6C41` | 31 |
| `bias.16` | MAIN2HDE.EXE | `0x6C81` | 65 |
| `bias.17` | MAIN2HDE.EXE | `0x6D20` | 29 |
| `bias.18` | MAIN2HDE.EXE | `0x73FB` | 21 |
| `bias.19` | MAIN2HDE.EXE | `0x7177` | 14 |
| `bias.20` | MAIN2HDE.EXE | `0x71FA` | 17 |
| `bias.21` | MAIN2HDE.EXE | `0x71C6` | 9 |
| `bias.22` | MAIN2HDE.EXE | `0x7234` | 28 |
| `bias.23` | MAIN2HDE.EXE | `0x7264` | 16 |
| `bias.24` | MAIN2HDE.EXE | `0x728C` | 16 |
| `end.01` | MAIN2HDE.EXE | `0x5344` | 32 |
| `end.02` | MAIN2HDE.EXE | `0x53A9` | 11 |
| `end.03` | MAIN2HDE.EXE | `0x5400` | 36 |
| `end.04` | MAIN2HDE.EXE | `0x5469` | 70 |
| `end.05` | MAIN2HDE.EXE | `0x54FB` | 26 |
| `end.06` | MAIN2HDE.EXE | `0x555A` | 146 |
| `end.07` | MAIN2HDE.EXE | `0x5638` | 25 |
| `end.08` | MAIN2HDE.EXE | `0x5696` | 132 |
| `end.09` | MAIN2HDE.EXE | `0x5758` | 33 |
| `end.10` | MAIN2HDE.EXE | `0x57C5` | 60 |
| `end.11` | MAIN2HDE.EXE | `0x5846` | 12 |
| `end.12` | MAIN2HDE.EXE | `0x589A` | 32 |
| `end.13` | MAIN2HDE.EXE | `0x58FF` | 98 |
| `end.14` | MAIN2HDE.EXE | `0x59AD` | 35 |
| `end.15` | MAIN2HDE.EXE | `0x5A15` | 74 |
| `end.16` | MAIN2HDE.EXE | `0x5A9D` | 117 |
| `end.17` | MAIN2HDE.EXE | `0x5B5E` | 80 |
| `end.18` | MAIN2HDE.EXE | `0x5BF3` | 30 |
| `end.19` | MAIN2HDE.EXE | `0x5C56` | 32 |
| `end.20` | MAIN2HDE.EXE | `0x5CBB` | 10 |
| `end.21` | MAIN2HDE.EXE | `0x5CF1` | 14 |
| `end.22` | MAIN2HDE.EXE | `0x5D28` | 8 |
| `end.23` | MAIN2HDE.EXE | `0x5D64` | 23 |
| `end.24` | MAIN2HDE.EXE | `0x5D9A` | 1006 |
| `end.25` | MAIN2HDE.EXE | `0x61FE` | 9 |
| `end.26` | MAIN2HDE.EXE | `0x61EF` | 584 |
| `event.01` | MAIN2HDE.EXE | `0x9122` | 54 |
| `event.02` | MAIN2HDE.EXE | `0x9185` | 24 |
| `event.03` | MAIN2HDE.EXE | `0x91E5` | 28 |
| `event.04` | MAIN2HDE.EXE | `0x921F` | 29 |
| `event.05` | MAIN2HDE.EXE | `0x9341` | 35 |
| `event.06` | MAIN2HDE.EXE | `0x93A4` | 29 |
| `event.07` | MAIN2HDE.EXE | `0x944E` | 40 |
| `event.08` | MAIN2HDE.EXE | `0x958F` | 48 |
| `event.09` | MAIN2HDE.EXE | `0x963D` | 45 |
| `event.10` | MAIN2HDE.EXE | `0x8979` | 55 |
| `event.11` | MAIN2HDE.EXE | `0x8A23` | 54 |
| `event.12` | MAIN2HDE.EXE | `0x8B04` | 57 |
| `event.13` | MAIN2HDE.EXE | `0x8BA4` | 24 |
| `event.14` | MAIN2HDE.EXE | `0x8E34` | 56 |
| `event.15` | MAIN2HDE.EXE | `0x76E` | 35 |
| `event.16` | MAIN2HDE.EXE | `0x9079` | 51 |
| `ui.01` | MAIN2HDE.EXE | `0x32C4` | 9 |
| `ui.02` | MAIN2HDE.EXE | `0x32F6` | 14 |
| `ui.03` | MAIN2HDE.EXE | `0x51D4` | 25 |
| `item.01` | MAIN2HDE.EXE | `0x2EF4` | 28 |
| `item.02` | MAIN2HDE.EXE | `0x2EC6` | 16 |
| `item.03` | MAIN2HDE.EXE | `0x2B1E` | 27 |
| `item.04` | MAIN2HDE.EXE | `0x2A70` | 34 |
| `item.05` | MAIN2HDE.EXE | `0x2AE0` | 21 |
| `item.06` | MAIN2HDE.EXE | `0x2D36` | 25 |
| `item.07` | MAIN2HDE.EXE | `0x2C21` | 35 |
| `item.08` | MAIN2HDE.EXE | `0x2D6D` | 31 |
| `item.09` | MAIN2HDE.EXE | `0x2DAA` | 19 |
| `item.10` | MAIN2HDE.EXE | `0x2CAF` | 36 |
| `item.11` | MAIN2HDE.EXE | `0x2CFA` | 17 |
| `item.12` | MAIN2HDE.EXE | `0x327E` | 25 |
| `item.13` | MAIN2HDE.EXE | `0x31A2` | 37 |
| `item.14` | MAIN2HDE.EXE | `0x323E` | 29 |
| `item.15` | MAIN2HDE.EXE | `0x3200` | 21 |
| `item.16` | MAIN2HDE.EXE | `0x3E64` | 27 |
| `item.17` | MAIN2HDE.EXE | `0x3E9B` | 28 |
| `item.18` | MAIN2HDE.EXE | `0x3DE4` | 8 |
| `item.19` | MAIN2HDE.EXE | `0x3E06` | 11 |
| `item.20` | MAIN2HDE.EXE | `0x3E26` | 8 |
| `item.21` | MAIN2HDE.EXE | `0x4AFE` | 14 |
| `item.22` | MAIN2HDE.EXE | `0x4B21` | 10 |
| `item.23` | MAIN2HDE.EXE | `0x4AAA` | 30 |
| `item.24` | MAIN2HDE.EXE | `0x4B47` | 12 |
| `item.25` | MAIN2HDE.EXE | `0x4B7C` | 9 |
| `item.26` | MAIN2HDE.EXE | `0x765E` | 24 |
| `item.27` | MAIN2HDE.EXE | `0x7699` | 30 |
| `item.28` | MAIN2HDE.EXE | `0x76DA` | 33 |
| `item.29` | MAIN2HDE.EXE | `0x762A` | 24 |
| `item.30` | MAIN2HDE.EXE | `0x7568` | 36 |
| `item.31` | MAIN2HDE.EXE | `0x75EE` | 32 |
| `item.32` | MAIN2HDE.EXE | `0x774F` | 30 |
| `item.33` | MAIN2HDE.EXE | `0x7797` | 32 |
| `item.34` | MAIN2HDE.EXE | `0x77E1` | 31 |
| `item.35` | MAIN2HDE.EXE | `0x784A` | 29 |
| `item.36` | MAIN2HDE.EXE | `0x7891` | 29 |
| `item.37` | MAIN2HDE.EXE | `0x78D8` | 29 |
| `item.38` | MAIN2HDE.EXE | `0x791F` | 23 |
| `item.39` | MAIN2HDE.EXE | `0x7963` | 22 |
| `item.40` | MAIN2HDE.EXE | `0x79A6` | 27 |
| `item.41` | MAIN2HDE.EXE | `0x79EE` | 25 |
| `item.42` | MAIN2HDE.EXE | `0x7BA1` | 43 |
| `item.43` | MAIN2HDE.EXE | `0x7D47` | 31 |
| `item.44` | MAIN2HDE.EXE | `0x81D7` | 40 |
| `item.45` | MAIN2HDE.EXE | `0x8233` | 36 |
| `item.46` | MAIN2HDE.EXE | `0x7ACC` | 19 |
| `item.47` | MAIN2HDE.EXE | `0x7B5F` | 23 |
| `item.48` | MAIN2HDE.EXE | `0x7AF7` | 71 |
| `item.49` | MAIN2HDE.EXE | `0x7C07` | 34 |
| `item.50` | MAIN2HDE.EXE | `0x7C43` | 20 |
| `item.51` | MAIN2HDE.EXE | `0x7C71` | 5 |
| `item.52` | MAIN2HDE.EXE | `0x7CCD` | 35 |
| `item.53` | MAIN2HDE.EXE | `0x7CF8` | 18 |
| `item.54` | MAIN2HDE.EXE | `0x7DB8` | 115 |
| `item.55` | MAIN2HDE.EXE | `0x7E65` | 58 |
| `item.56` | MAIN2HDE.EXE | `0x7F05` | 23 |
| `item.57` | MAIN2HDE.EXE | `0x7F42` | 27 |
| `item.58` | MAIN2HDE.EXE | `0x7F6B` | 6 |
| `item.59` | MAIN2HDE.EXE | `0x7F9D` | 7 |
| `item.60` | MAIN2HDE.EXE | `0x7FC7` | 7 |
| `item.61` | MAIN2HDE.EXE | `0x7FF1` | 7 |
| `item.62` | MAIN2HDE.EXE | `0x8024` | 29 |
| `item.63` | MAIN2HDE.EXE | `0x8077` | 6 |
| `item.64` | MAIN2HDE.EXE | `0x80A7` | 6 |
| `item.65` | MAIN2HDE.EXE | `0x80D7` | 6 |
| `item.66` | MAIN2HDE.EXE | `0x8118` | 23 |
| `item.67` | MAIN2HDE.EXE | `0x8152` | 42 |
| `item.68` | MAIN2HDE.EXE | `0x818E` | 24 |
| `shop.01` | MAIN2HDE.EXE | `0x3846` | 47 |
| `shop.02` | MAIN2HDE.EXE | `0x38A9` | 41 |
| `shop.03` | MAIN2HDE.EXE | `0x3BC4` | 22 |
| `shop.04` | MAIN2HDE.EXE | `0x3953` | 98 |
| `shop.05` | MAIN2HDE.EXE | `0x3B6A` | 32 |
| `shop.06` | MAIN2HDE.EXE | `0x3A07` | 19 |
| `shop.07` | MAIN2HDE.EXE | `0x3A2D` | 7 |
| `shop.08` | MAIN2HDE.EXE | `0x3A9E` | 31 |
| `shop.09` | MAIN2HDE.EXE | `0x3AF4` | 14 |
| `shop.10` | MAIN2HDE.EXE | `0x3B15` | 8 |
| `shop.11` | MAIN2HDE.EXE | `0x3D8B` | 23 |
| `shop.12` | MAIN2HDE.EXE | `0x3C29` | 20 |
| `shop.13` | MAIN2HDE.EXE | `0x3CA7` | 42 |
| `shop.14` | MAIN2HDE.EXE | `0x41A3` | 144 |
| `shop.15` | MAIN2HDE.EXE | `0x425C` | 56 |
| `shop.16` | MAIN2HDE.EXE | `0x44C1` | 52 |
| `shop.17` | MAIN2HDE.EXE | `0x444E` | 59 |
| `shop.18` | MAIN2HDE.EXE | `0x42FC` | 58 |
| `shop.19` | MAIN2HDE.EXE | `0x435A` | 16 |
| `shop.20` | MAIN2HDE.EXE | `0x43D2` | 68 |
| `shop.21` | MAIN2HDE.EXE | `0x48F9` | 57 |
| `shop.22` | MAIN2HDE.EXE | `0x452D` | 49 |
| `shop.23` | MAIN2HDE.EXE | `0x4610` | 55 |
| `shop.24` | MAIN2HDE.EXE | `0x45B3` | 37 |
| `shop.25` | MAIN2HDE.EXE | `0x4813` | 51 |
| `shop.26` | MAIN2HDE.EXE | `0x487E` | 45 |
| `shop.27` | MAIN2HDE.EXE | `0x469F` | 141 |
| `shop.28` | MAIN2HDE.EXE | `0x4763` | 120 |
| `shop.29` | MAIN2HDE.EXE | `0x4BC4` | 90 |
| `shop.30` | MAIN2HDE.EXE | `0x4C47` | 103 |
| `shop.31` | MAIN2HDE.EXE | `0x4E9E` | 17 |
| `shop.32` | MAIN2HDE.EXE | `0x5146` | 35 |
| `shop.33` | MAIN2HDE.EXE | `0x4D71` | 60 |
| `shop.34` | MAIN2HDE.EXE | `0x4E5D` | 25 |
| `shop.35` | MAIN2HDE.EXE | `0x50E1` | 45 |
| `shop.36` | MAIN2HDE.EXE | `0x4F18` | 65 |
| `shop.37` | MAIN2HDE.EXE | `0x4F6C` | 7 |
| `shop.38` | MAIN2HDE.EXE | `0x4FCA` | 7 |
| `shop.39` | MAIN2HDE.EXE | `0x5018` | 37 |
| `shop.40` | MAIN2HDE.EXE | `0x6836` | 91 |
| `shop.41` | MAIN2HDE.EXE | `0x68BA` | 43 |
| `shop.42` | MAIN2HDE.EXE | `0x6AEC` | 14 |
| `shop.43` | MAIN2HDE.EXE | `0x693F` | 91 |
| `shop.44` | MAIN2HDE.EXE | `0x69D1` | 53 |
| `shop.45` | MAIN2HDE.EXE | `0x6A3A` | 78 |
| `shop.46` | MAIN2HDE.EXE | `0x88DB` | 65 |
| `shop.47` | MAIN2HDE.EXE | `0x3F3A` | 20 |
| `shop.48` | MAIN2HDE.EXE | `0x3EEA` | 20 |
| `shop.49` | MAIN2HDE.EXE | `0x3F77` | 97 |
| `shop.50` | MAIN2HDE.EXE | `0x401D` | 23 |
| `shop.51` | MAIN2HDE.EXE | `0x40CA` | 18 |
| `shop.52` | MAIN2HDE.EXE | `0x40FF` | 16 |
| `shop.53` | MAIN2HDE.EXE | `0x6462` | 22 |
| `shop.54` | MAIN2HDE.EXE | `0x64F1` | 43 |
| `shop.55` | MAIN2HDE.EXE | `0x6551` | 18 |
| `shop.56` | MAIN2HDE.EXE | `0x6630` | 22 |
| `shop.57` | MAIN2HDE.EXE | `0x65EF` | 30 |
| `shop.58` | MAIN2HDE.EXE | `0x6774` | 19 |
| `shop.59` | MAIN2HDE.EXE | `0x6676` | 34 |
| `shop.60` | MAIN2HDE.EXE | `0x67AA` | 30 |
| `shop.61` | MAIN2HDE.EXE | `0x670C` | 11 |
| `shop.62` | MAIN2HDE.EXE | `0x6723` | 8 |
| `town.01` | MAIN2HDE.EXE | `0x1CB4` | 70 |
| `town.02` | MAIN2HDE.EXE | `0x1692` | 136 |
| `town.03` | MAIN2HDE.EXE | `0x1DBA` | 15 |
| `town.04` | MAIN2HDE.EXE | `0x1C73` | 20 |
| `town.05` | MAIN2HDE.EXE | `0x1D44` | 7 |
| `town.06` | MAIN2HDE.EXE | `0x176C` | 134 |
| `town.07` | MAIN2HDE.EXE | `0x182C` | 37 |
| `town.08` | MAIN2HDE.EXE | `0x1E03` | 6 |
| `town.09` | MAIN2HDE.EXE | `0x1EC6` | 25 |
| `town.10` | MAIN2HDE.EXE | `0x1F1F` | 24 |
| `town.11` | MAIN2HDE.EXE | `0x1E5D` | 30 |
| `town.12` | MAIN2HDE.EXE | `0x1888` | 144 |
| `town.13` | MAIN2HDE.EXE | `0x1956` | 24 |
| `town.14` | MAIN2HDE.EXE | `0x19AF` | 113 |
| `town.15` | MAIN2HDE.EXE | `0x1A57` | 188 |
| `town.16` | MAIN2HDE.EXE | `0x1B58` | 14 |
| `town.17` | MAIN2HDE.EXE | `0x1BA4` | 37 |
| `town.18` | MAIN2HDE.EXE | `0x1C04` | 29 |
| `town.19` | MAIN2HDE.EXE | `0x21AC` | 21 |
| `town.20` | MAIN2HDE.EXE | `0x21DE` | 32 |
| `town.21` | MAIN2HDE.EXE | `0x226B` | 50 |
| `town.22` | MAIN2HDE.EXE | `0x22AB` | 46 |
| `town.23` | MAIN2HDE.EXE | `0x22E7` | 41 |
| `town.24` | MAIN2HDE.EXE | `0x146F` | 113 |
| `town.25` | MAIN2HDE.EXE | `0x1508` | 62 |
| `town.26` | MAIN2HDE.EXE | `0x1591` | 139 |
| `town.27` | MAIN2HDE.EXE | `0x450` | 90 |
| `town.28` | MAIN2HDE.EXE | `0x4D3` | 82 |
| `town.29` | MAIN2HDE.EXE | `0x57D` | 64 |
| `town.30` | MAIN2HDE.EXE | `0x5FB` | 56 |
| `town.31` | MAIN2HDE.EXE | `0x5267` | 124 |
