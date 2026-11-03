"""Read the files of a PC-98 disk image: raw, Virtual98 (.fdd), Anex86 (.fdi), D88, or a .zip holding one.

    files = diskimage.files('game.fdd')     # {'MAIN2HDE.EXE': bytes, ...}
"""
import io
import struct
import zipfile

RAW_SIZE = 77 * 2 * 8 * 1024


def sectors(d):
    """the disk's bytes in sector order, or None"""
    if d[:8] == b'VFD1.00\0':
        secs = []
        for i in range(160 * 26):
            c, h, r, n, fill = d[0xDC + i * 12:0xDC + i * 12 + 5]
            off = struct.unpack_from('<I', d, 0xDC + i * 12 + 8)[0]
            if c == 0xFF:
                continue
            size = 128 << n
            secs.append((c, h, r, bytes([fill]) * size if off == 0xFFFFFFFF else d[off:off + size]))
        return b''.join(s[3] for s in sorted(secs, key=lambda s: s[:3]))
    if len(d) == RAW_SIZE:
        return d
    # Anex86 FDI: a header (its size at 8, the image's at 12, the sector size at 16), then the raw sectors
    if len(d) > 32:
        head, size, sector = struct.unpack_from('<3I', d, 8)
        if head + size == len(d) and sector in (256, 512, 1024):
            return d[head:]
    if len(d) > 0x2B0 and struct.unpack_from('<I', d, 0x1C)[0] == len(d):
        secs = []
        for t in range(164):
            p = struct.unpack_from('<I', d, 0x20 + t * 4)[0]
            if p == 0 or p >= len(d):
                continue
            n = struct.unpack_from('<H', d, p + 4)[0]
            for _ in range(n):
                size = struct.unpack_from('<H', d, p + 14)[0]
                secs.append((d[p], d[p + 1], d[p + 2], d[p + 16:p + 16 + size]))
                p += 16 + size
        return b''.join(s[3] for s in sorted(secs, key=lambda s: s[:3]))
    return None


def fat12(d):
    bps, spc, rsv, nfat, nroot, _tot, _media, spf = struct.unpack_from('<HBHBHHBH', d, 11)
    fat = d[rsv * bps:(rsv + spf) * bps]
    root = (rsv + nfat * spf) * bps
    data = root + nroot * 32
    clus = bps * spc
    out = {}
    for i in range(nroot):
        e = d[root + i * 32:root + i * 32 + 32]
        if e[0] == 0:
            break
        if e[0] == 0xE5 or e[11] & 0x18:
            continue
        name = e[:8].decode('ascii', 'replace').strip()
        ext = e[8:11].decode('ascii', 'replace').strip()
        c, size = struct.unpack_from('<H', e, 26)[0], struct.unpack_from('<I', e, 28)[0]
        body = bytearray()
        while 2 <= c < 0xFF8:
            body += d[data + (c - 2) * clus:data + (c - 1) * clus]
            v = struct.unpack_from('<H', fat, c * 3 // 2)[0]
            c = v >> 4 if c & 1 else v & 0xFFF
        out[name + ('.' + ext if ext else '')] = bytes(body[:size])
    return out


def files(path):
    d = open(path, 'rb').read()
    if d[:4] == b'PK\3\4':
        with zipfile.ZipFile(io.BytesIO(d)) as z:
            for n in z.namelist():
                s = sectors(z.read(n))
                if s:
                    return fat12(s)
        raise ValueError('the zip holds no disk image')
    s = sectors(d)
    if s is None:
        raise ValueError('not a PC-98 disk image')
    return fat12(s)
