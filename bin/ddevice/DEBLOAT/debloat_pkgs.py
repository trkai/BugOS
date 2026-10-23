#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BugOS - Debloat theo TÊN GÓI (package name).

APPLIST.txt chỉ so khớp theo TÊN THƯ MỤC nên không xoá được app khi ROM đặt
thư mục theo kiểu khác (vd MIUIVideo vs com.miui.video). Script này đọc
package thật trong AndroidManifest.xml của từng APK rồi xoá đúng thư mục.

Dùng:
    python3 debloat_pkgs.py <thư mục images> <file danh sách package>
"""
import os
import struct
import sys
import zipfile

RES_STRING_POOL = 0x0001
RES_XML_START_ELEMENT = 0x0102


def _u8len(buf, p):
    n = buf[p]
    p += 1
    if n & 0x80:
        n = ((n & 0x7F) << 8) | buf[p]
        p += 1
    return n, p


def _u16len(buf, p):
    n = struct.unpack_from('<H', buf, p)[0]
    p += 2
    if n & 0x8000:
        n = ((n & 0x7FFF) << 16) | struct.unpack_from('<H', buf, p)[0]
        p += 2
    return n, p


def parse_pool(buf, off):
    _t, _h, _size = struct.unpack_from('<HHI', buf, off)
    count, _style, flags, strings_start, _ss = struct.unpack_from('<IIIII', buf, off + 8)
    utf8 = bool(flags & 0x100)
    offsets = struct.unpack_from('<%dI' % count, buf, off + 28)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if utf8:
            _c, p = _u8len(buf, p)
            blen, p = _u8len(buf, p)
            out.append(buf[p:p + blen].decode('utf-8', 'replace'))
        else:
            clen, p = _u16len(buf, p)
            out.append(buf[p:p + clen * 2].decode('utf-16le', 'replace'))
    return out


def apk_package(apk_path):
    """Đọc package trong AndroidManifest.xml (binary XML) của APK."""
    try:
        with zipfile.ZipFile(apk_path) as z:
            data = z.read('AndroidManifest.xml')
    except Exception:
        return None
    try:
        typ, hsize, total = struct.unpack_from('<HHI', data, 0)
        if typ != 0x0003:
            return None
        pool = parse_pool(data, hsize)
        off = hsize
        while off < total:
            ctyp, _chsize, csize = struct.unpack_from('<HHI', data, off)
            if csize == 0:
                break
            if ctyp == RES_XML_START_ELEMENT:
                name_i = struct.unpack_from('<I', data, off + 20)[0]
                if name_i < len(pool) and pool[name_i] == 'manifest':
                    attr_start, attr_size, attr_count = struct.unpack_from('<HHH', data, off + 24)
                    for i in range(attr_count):
                        a = off + 16 + attr_start + i * attr_size
                        an = struct.unpack_from('<i', data, a + 4)[0]
                        dtype = data[a + 15]
                        ddata = struct.unpack_from('<I', data, a + 16)[0]
                        if 0 <= an < len(pool) and pool[an] == 'package' and dtype == 0x03:
                            return pool[ddata] if ddata < len(pool) else None
                    return None
            off += csize
    except Exception:
        return None
    return None


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    images = sys.argv[1]
    list_file = sys.argv[2]

    targets = set()
    with open(list_file, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            line = line.strip().replace('\r', '')
            if not line or line.startswith('#'):
                continue
            targets.add(line)
    if not targets:
        print('[DEBLOAT] Danh sách package rỗng, bỏ qua.')
        return 0

    print('[DEBLOAT] Package cần xoá: %s' % ', '.join(sorted(targets)))
    removed = 0
    for part in ('system', 'product', 'system_ext', 'odm', 'mi_ext', 'vendor'):
        for sub in ('app', 'priv-app'):
            root = os.path.join(images, part, sub)
            if not os.path.isdir(root):
                continue
            for dirpath, dirnames, filenames in os.walk(root):
                apks = [f for f in filenames if f.lower().endswith('.apk')]
                if not apks:
                    continue
                for apk in apks:
                    pkg = apk_package(os.path.join(dirpath, apk))
                    if pkg and pkg in targets:
                        print('[DEBLOAT] Xoá %s  (package=%s)' % (dirpath, pkg))
                        try:
                            import shutil
                            shutil.rmtree(dirpath, ignore_errors=True)
                            removed += 1
                        except Exception as e:
                            print('[DEBLOAT] Lỗi xoá %s: %s' % (dirpath, e))
                        dirnames[:] = []
                        break

    print('[DEBLOAT] Đã xoá %d thư mục theo package.' % removed)
    return 0


if __name__ == '__main__':
    sys.exit(main())
