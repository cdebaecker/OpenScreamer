# 1. The original disk

OpenScreamer plays from the player's own disk image of the PC-9801 version. This chapter says how to read
one and which files to take from it.

## Disk images

The disk is a PC-98 2HD floppy: 77 cylinders, 2 heads, 8 sectors per track of 1024 bytes each
(1,261,568 bytes). The importer accepts:

| Format | Extension | Layout |
|---|---|---|
| raw | `.hdm`, `.xdf`, `.tfd`, or any file of exactly 1,261,568 bytes | the sectors in order: cylinder, then head, then sector 1 to 8 |
| Virtual98 | `.fdd` | starts with the 8 bytes `VFD1.00` and a zero byte; at offset `0xDC`, 4160 entries of 12 bytes (160 tracks x 26 sectors). Each entry: cylinder, head, sector, size code N (size = 128 << N), fill byte, two flag bytes, one unused byte, then a little-endian 32-bit offset to the sector's data. Cylinder `0xFF` marks an unused entry. Offset `0xFFFFFFFF` means every byte of the sector is the fill byte. Sort the used entries by cylinder, head and sector to get the raw image. |
| D88 | `.d88`, `.d98` | a 0x20-byte header, then 164 little-endian 32-bit track offsets (0 = no track). Each track is a run of sectors, each with a 16-byte header (cylinder, head, sector, size code, 16-bit sector count of the track, density, deleted flag, status, 5 reserved bytes, 16-bit data size) followed by its data. |

A `.zip` holding exactly one of these may also be accepted.

## The file system

The raw image is a FAT12 volume. Read the BIOS parameter block at offset 11 of the first sector:
bytes per sector (16-bit), sectors per cluster (8-bit), reserved sectors (16-bit), number of FATs (8-bit),
root directory entries (16-bit), total sectors (16-bit), media byte, sectors per FAT (16-bit). On this disk
sectors are 1024 bytes. The root directory follows the reserved sectors and the FATs; data clusters follow
the root directory. All the game's files are in the root directory. File names are 8.3, upper case.

## The files

The importer copies these files and checks each against its SHA-1. When a file doesn't match, it tells the
player which one and doesn't start: every offset in this spec is for these exact files.

`CHAR` is the only file the game writes (the roster of registered characters). Its digest is only that of
the disk as published; a played copy differs, which is fine. The importer keeps the player's `CHAR` as their
starting roster, and checks only that it is 1024 bytes long.

The disk's other files (`IO.SYS`, `MSDOS.SYS`, `COMMAND.COM`, `CONFIG.SYS`, `AUTOEXEC.BAT`) are the
operating system. The engine never reads or copies them.

| File | Size | SHA-1 |
|---|---|---|
| `MAIN2HDE.EXE` | 103870 | `cdc5c50c932243ef8af5bec2bfe48067968fae8d` |
| `DEMO2HDE.EXE` | 53070 | `cd35741b135d5c69d9eba80a113452346c4da2d8` |
| `B01` | 16384 | `167485a8ce5688d1ab6493ce282f8b498b2ae968` |
| `B02` | 16384 | `df2aa535aedacae2a1247538d28381978de45f3a` |
| `B03` | 16384 | `3fa4cef7078d1d989f167c6200f5d83dac4694f5` |
| `CHAR` | 1024 | `1fc53ab631b6c593aef4b31544f42f316fbe46e9` |
| `F01` | 5120 | `53584434e8fe4008936463474e402a6bab8ae65c` |
| `F02` | 5120 | `60a3a55e580a59fc07150e641ab7e269c73e1298` |
| `F03` | 5120 | `c2759a55b9ccf714ce04182039d4674ccf187f54` |
| `F04` | 5120 | `87e82efd3da4b653ac3e894c14dea05ab591d7d0` |
| `F05` | 5120 | `75f9d45f8645f523d9fee037f27c0d444d16156b` |
| `F06` | 5120 | `37c04946f73b399dd3d6fd5fd87d673a83c6a0e9` |
| `G01` | 7168 | `b0972945f3306eb62ac0c5474a464c0bfdec4ac0` |
| `G02` | 7168 | `c359ba64776e5fdf97ff49ea870a0deeff0ac2a5` |
| `G03` | 7168 | `7c000f6e2b04d5a9d7d85ba949ff0f74e5506037` |
| `G04` | 7168 | `743f80547bfc8e50326c4cd43b5c33f360e35f61` |
| `G05` | 7168 | `46211aa900598690b26e0fff16375f77297dffe6` |
| `G06` | 7168 | `3ea1b0488955061e5d5a1e0ca10d37ec5d30223e` |
| `G07` | 7168 | `44d3db71e8329eac4802eb865924d728206fd50f` |
| `G08` | 7168 | `8bf6ace94220a131493f7a5d1e9d6e57986014d8` |
| `G09` | 7168 | `86c9eca37f9a836316a65216524d94aaa2a5b956` |
| `G10` | 7168 | `b839dba1dde40cd9ad9a9ded049a285223934786` |
| `G11` | 7168 | `267bcdf208f5a8859cef7202c22e894c99ed3cec` |
| `G12` | 7168 | `38c28206d173a3fdf6236675f1fc2a51d709eea1` |
| `G13` | 7168 | `b7c848d8b729464b6b925b63c1c8ba104537dd82` |
| `G14` | 7168 | `822c4bb0dd6b4b7456b92bf913536b93e2605982` |
| `G15` | 7168 | `ec31ecd0213d8a9bf73538844c9d5dd8a99bc630` |
| `G16` | 7168 | `d28d2174e4c9cd9ee6dec1b460a8083c599fd6a3` |
| `G17` | 7168 | `8e94b80ef73ee4f3c5f2bbaa11a94504c4270910` |
| `G18` | 7168 | `2af7370e06837fa660d55ab4ae02a813fe3079a7` |
| `G19` | 7168 | `d1c8d718fb37391dc25e97fce0449b7de044addf` |
| `G20` | 7168 | `5841b8de30b7e8b56a180f5e038dfc9a3112eb0c` |
| `G21` | 7168 | `1f87dfe7fa1e0d2fe2916ad603e620da8335c1a3` |
| `G22` | 7168 | `d852db76e81f217cb6dc11d7b608afd9fbe6fea0` |
| `G23` | 7168 | `b5a4d1e4d15d8ca223522e3938064a6b6eb5c90d` |
| `G24` | 7168 | `874f7c5eabaf3369e9b6756afcb294e7551b37ab` |
| `G25` | 7168 | `5a1aa5df20a387e78f2fb38ccd864989208df7bc` |
| `G26` | 7168 | `c99e8700e73aacaca02b50d00146540750c488a4` |
| `G27` | 7168 | `bb525d7c6cd5ac6f524acdfd6eeb4089ec07254d` |
| `G28` | 7168 | `4703194882aa6a71a2aca2e97b8ab85fe98d5a39` |
| `G29` | 7168 | `b586738f3556f372e035a0d9ba08b5ce4210febc` |
| `G30` | 7168 | `296f6a248d1b1e18eb171806bf5116fd49c4ca56` |
| `G31` | 7168 | `40011d5278ed856683eadc7d2c5733dffd6c897b` |
| `G32` | 7168 | `b2e757cd1c78366c4bb3b661cf0623fd60475ae8` |
| `G33` | 7168 | `fe5aa8f66fe4b9172a82376b942d2f9afa1de328` |
| `G34` | 7168 | `df05c0cf15d460034ae398dcd7c9c38415e7e84c` |
| `G35` | 7168 | `d80be88ca691a265ce6b78c607645d1da39fe06a` |
| `G36` | 7168 | `5c7042ef535142a4705b0da45b0a4f49b403d235` |
| `G37` | 7168 | `ed9433d23675a1f96cf9b44614bc40d99e0aa215` |
| `G38` | 7168 | `716c18609f7de930b38d10a44ce61ed5de59e926` |
| `G39` | 7168 | `c8de5f8f23f7baea8c855d13e1efe8f74c240faa` |
| `G40` | 6144 | `659281e2c0c205535349201b78c4e50536d55b60` |
| `G41` | 6144 | `2d5f6cf331047134afb6da77f3ee549cee368e66` |
| `G42` | 6144 | `9bfdfda1c76df4f68f8029e777c21060010d3c2b` |
| `G43` | 6144 | `3b58b393181ae41a833438a9fb737124e0deca4c` |
| `G44` | 6144 | `7cd00b8b6e1ef02334e4103b87234e0af99c8131` |
| `G45` | 6144 | `177eab5e25845c05c2b0266383fd966a3113c2b7` |
| `G46` | 6144 | `76c954020338c2cf43e8a7a86d8a14b34022572d` |
| `G47` | 6144 | `e13561291e1a1f16f81663faefa29a06213c8013` |
| `G48` | 6144 | `a14a092920687a8d72a84cfa531c8550c2aff0da` |
| `G49` | 6144 | `1bc532d5a853b334567a6a045c2903d4a5864b97` |
| `G50` | 6144 | `0d03c3fd1b5d74a26d46740cc2b95675d667c096` |
| `G51` | 6144 | `88307e3d7d224b5fa036f64507e1cdaaabb815e5` |
| `G52` | 6144 | `4703918c8bc37f9054891b7ca871e84d017ce6dd` |
| `G53` | 6144 | `65b9a4b73e0c65b627bd9c230a7de2f2384afdca` |
| `G54` | 6144 | `dc1367043ed0d7b5289309122b1972665b3ea3d2` |
| `G55` | 6144 | `dfc1f57ce07a2e0e48b8a16fab462a02709da2d0` |
| `G56` | 6144 | `7ed06414fcbd443b8caf663c3b86bb549c657e8f` |
| `G57` | 6144 | `33917212ba2bebd275486813a1610bdbca7b72da` |
| `G58` | 6144 | `ae82d83c9c7737c65de8e247ade453c5e3c27e75` |
| `G59` | 6144 | `56fb45b7738359ec481e81a86fe60026e1f8696c` |
| `G60` | 6144 | `77c134e5edee755c9c6d29bbd2c2b5f27ef7687e` |
| `P01` | 12288 | `c0f58171ec9c714a2fe2a58fc36317345e9164f6` |
| `P02` | 12288 | `e3d7493c8bc24afc5f5b15e016081d91302f06bc` |
| `P03` | 12288 | `3d0fbb94bfc2357291688af33c6ef7f8d393cb91` |
| `P04` | 12288 | `2d5d28ecfb86f72a6239687c8650b5b6e3074987` |
| `P05` | 12288 | `0d001f7dccc2d4ddf242587a6073a960872c3157` |
| `P06` | 12288 | `08b5110a8a520356b8daad2fea26da4a61f083f0` |
| `P07` | 12288 | `7b1b1591dcfd6c16feb631b1d90e177aae0f1c26` |
| `P08` | 12288 | `a61b51c410e93ea4b3edd123026feb84c50f4c06` |
| `P09` | 12288 | `dcec0e4de38cf82027b44b172ec5f6deb7b8ce5f` |
| `P10` | 12288 | `7ce8d8e67abeb5b5a6770cb9bc61bbc5aa5f0b7d` |
| `P11` | 12288 | `ea0aa77b74c5e92d277c439de152cfa9bfa44c36` |
| `P12` | 12288 | `21907ccd84d2fb96cf8281ba65aad9193be23425` |
| `P13` | 12288 | `ef248704af09fb03a0e84841ce833bd00a89e293` |
| `P14` | 12288 | `d62f6f3b6ec0ac3ddb871a47ba935f9434ebc240` |
| `P15` | 12288 | `b11e131a0d09b3f1334749d66e3cdc260f731a2d` |
| `P16` | 12288 | `149940e665e21ed590afa86dbd86767b619e3eab` |
| `P17` | 12288 | `5c63abb1c75643374ab6324fec05ad4fda308eac` |
| `P18` | 12288 | `7f8649a0df512ea038ebd7a4402e0297a6a8ea40` |
| `P19` | 12288 | `f7a919e2c7bb8e36755b65a3ef9b550749e27f36` |
| `P20` | 12288 | `a44e65a8e8ade4c1a3573b586ed2c1053445ac42` |
