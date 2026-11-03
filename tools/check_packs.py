#!/usr/bin/env python3
"""Check the translation packs (translations/*.po) against the player's own game files.

    python tools/check_packs.py <disk image, or a folder with the files read from it>

For every entry: the original string at the place its `#:` comment names must have the entry's
digest, the text must be ASCII without '|' or the backquote, and its lines must fit the width.
Every pack must cover the same strings. Lists the messages of spec chapter 4 that no pack covers
(they show in Japanese). Exit status 0 when everything checks.
"""
import glob
import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAIN_DS = 0xA9A0  # file offset of MAIN2HDE's data segment (spec chapter 2)


def unpo(s):
    out, i = [], 0
    while i < len(s):
        c = s[i]
        if c == '\\':
            n = s[i + 1]
            if n == 'x':
                out.append(chr(int(s[i + 2:i + 4], 16)))
                i += 4
                continue
            out.append({'n': '\n', '"': '"', '\\': '\\'}[n])
            i += 2
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def entries(path):
    """[(where, width, context, key, text)]"""
    res = []
    for block in open(path, encoding='utf-8').read().split('\n\n'):
        m = re.search(r'msgctxt "(\w+)"\nmsgid "([^"]*)"\nmsgstr "((?:[^"\\]|\\.)*)"', block)
        if not m:
            continue
        where = re.search(r'^#: (.*)$', block, re.M)
        width = re.search(r'^#\. width: (\d+)$', block, re.M)
        res.append((where.group(1) if where else '', int(width.group(1)) if width else 0,
                    m.group(1), m.group(2), unpo(m.group(3))))
    return res


def original(files, where):
    def read(name):
        return files[name]

    def cstr(d, o):
        return d[o:d.index(b'\0', o)]

    m = re.match(r'(MAIN2HDE\.EXE|DEMO2HDE\.EXE|B01) 0x([0-9A-F]+)', where)
    if m:
        return cstr(read(m.group(1)), int(m.group(2), 16))
    m = re.match(r'item \d+ name, MAIN:0x([0-9A-F]+)', where)
    if m:
        return cstr(read('MAIN2HDE.EXE'), MAIN_DS + int(m.group(1), 16))
    m = re.match(r'monster \d+ name, (G\d\d) 0x1770', where)
    if m:
        rec = read(m.group(1))[0x1770:0x1798]
        return rec[:rec.index(b'\0')] if b'\0' in rec else rec
    return None


def digest(b):
    return 'sha1:' + hashlib.sha1(b).hexdigest()[:16]


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    if os.path.isdir(sys.argv[1]):
        files = {n: open(os.path.join(sys.argv[1], n), 'rb').read() for n in os.listdir(sys.argv[1])}
    else:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        import diskimage
        files = diskimage.files(sys.argv[1])
    bad = []
    keys = {}
    for path in sorted(glob.glob(os.path.join(ROOT, 'translations', '*.po'))):
        lang = os.path.basename(path)[:-3]
        es = entries(path)
        keys[lang] = {(c, k) for _, _, c, k, _ in es}
        for where, width, ctx, key, text in es:
            orig = original(files, where)
            if orig is None:
                bad.append(f'{lang}: {where}: place not understood')
            elif digest(orig) != key:
                bad.append(f'{lang}: {where}: key {key} is not the original string there ({digest(orig)})')
            if ctx in ('game', 'demo') and any(ord(ch) > 0x7e or ch in '|`' for ch in text if ch != '\x02'):
                bad.append(f'{lang}: {where}: character outside the game font\'s ASCII')
            if ctx in ('game', 'demo'):
                for ln in re.split('[_~]', text):
                    if width and len(ln) > width:
                        bad.append(f'{lang}: {where}: line longer than {width}: {ln!r}')
            if ctx == 'demo' and orig is not None:
                if len(re.findall(b'[_~]', orig)) != len(re.findall('[_~]', text)):
                    bad.append(f'{lang}: {where}: not the original\'s number of line breaks')
        print(f'{lang}: {len(es)} entries')
    langs = sorted(keys)
    for a in langs:
        for b in langs:
            missing = keys[a] - keys[b]
            if missing:
                bad.append(f'{b} lacks {len(missing)} entries that {a} has')

    # the messages of chapter 4 that no pack translates
    spec = open(os.path.join(ROOT, 'spec', '04-data.md'), encoding='utf-8').read()
    covered = set().union(*keys.values()) if keys else set()
    untranslated = []
    for mid, prog, off, n in re.findall(
            r'\| `([a-z]+\.\d\d)` \| (MAIN|DEMO)2HDE\.EXE \| `0x([0-9A-F]+)` \| (\d+) \|', spec):
        d = files[prog + '2HDE.EXE']
        o = int(off, 16)
        s = d[o:o + int(n)]
        if not any(c >= 0xA1 for c in s) or d[o + int(n)] != 0:
            continue  # ASCII already, or not text the game prints (the ending's secret keys)
        if ('game', digest(s)) not in covered:
            untranslated.append(mid)
    print(f'messages of chapter 4 with katakana and no translation: {len(untranslated)}'
          + (f' ({", ".join(untranslated)})' if untranslated else ''))
    for b in bad:
        print('FAIL', b)
    print('all checked' if not bad else f'{len(bad)} problems')
    sys.exit(1 if bad else 0)


if __name__ == '__main__':
    main()
