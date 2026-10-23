#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BugOS - Vá lỗi vector logo "Xiaomi HyperOS" bị hỏng trong Settings.apk.

TRIỆU CHỨNG
    Trang Settings > Giới thiệu điện thoại hiển thị một vệt đen méo thay cho logo.

NGUYÊN NHÂN
    Các file res/drawable*/xiaomi_os_logo*.xml trong Settings.apk có pathData
    bị mất dấu cách phân tách giữa các toạ độ (ví dụ "399.17 53.37" -> "399.1753.37").
    Khi đó Android parse ra các số khổng lồ (tới 3.3e18), vẽ kín viewport
    -> logo thành một khối đen vỡ.

CÁCH VÁ
    Thay pathData hỏng bằng vector chuẩn trong logo_ref.json, scale đúng theo
    viewport của từng file, rồi ghi lại vào string pool của binary XML.
    Không cần apktool / Java / aapt2, không đổi resource ID, không đổi tên file.

DÙNG
    python3 patch_logo.py <Settings.apk | Settings.apk.xz> [--dry-run] [--no-hyperos]

    --dry-run      chỉ kiểm tra, không ghi file
    --no-hyperos   chỉ giữ chữ "Xiaomi", để trống phần "HyperOS"
"""

import io
import json
import lzma
import os
import re
import shutil
import struct
import sys
import zipfile

RES_STRING_POOL = 0x0001
RES_XML_START_ELEMENT = 0x0102

LOGO_RE = re.compile(r'^res/drawable[^/]*/xiaomi_os_logo[^/]*\.xml$')

# Số tham số của từng lệnh path
ARITY = {'M': 2, 'L': 2, 'T': 2, 'H': 1, 'V': 1,
         'C': 6, 'S': 4, 'Q': 4, 'A': 7, 'Z': 0}

TOKEN_RE = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])|(-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?)')


# --------------------------------------------------------------------------
# Đọc / ghi binary XML (AXML)
# --------------------------------------------------------------------------
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


def parse_string_pool(buf, off):
    """Trả về (strings, flags, chunk_size)."""
    _typ, _hsize, size = struct.unpack_from('<HHI', buf, off)
    count, style_count, flags, strings_start, _styles_start = struct.unpack_from('<IIIII', buf, off + 8)
    utf8 = bool(flags & 0x100)
    offsets = struct.unpack_from('<%dI' % count, buf, off + 28)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if utf8:
            _clen, p = _u8len(buf, p)
            blen, p = _u8len(buf, p)
            out.append(buf[p:p + blen].decode('utf-8', 'replace'))
        else:
            clen, p = _u16len(buf, p)
            out.append(buf[p:p + clen * 2].decode('utf-16le', 'replace'))
    return out, flags, size, style_count


def build_string_pool(strings, flags, style_count=0):
    utf8 = bool(flags & 0x100)
    count = len(strings)
    strings_start = 28 + 4 * count + 4 * style_count
    body = bytearray()
    offsets = []
    for s in strings:
        offsets.append(len(body))
        if utf8:
            raw = s.encode('utf-8')
            for n in (len(s), len(raw)):
                if n < 0x80:
                    body.append(n)
                else:
                    body.append(((n >> 8) & 0x7F) | 0x80)
                    body.append(n & 0xFF)
            body += raw
            body.append(0)
        else:
            raw = s.encode('utf-16le')
            n = len(s)
            if n > 0x7FFF:
                raise ValueError('string quá dài cho UTF-16 pool')
            body += struct.pack('<H', n)
            body += raw
            body += b'\x00\x00'
    total = strings_start + len(body)
    pad = (-total) % 4
    total += pad
    out = bytearray()
    out += struct.pack('<HHI', RES_STRING_POOL, 28, total)
    out += struct.pack('<IIIII', count, style_count, flags, strings_start, 0)
    for o in offsets:
        out += struct.pack('<I', o)
    out += body
    out += b'\x00' * pad
    return bytes(out)


def iter_elements(buf):
    """Sinh ra (element_name, attrs) với attrs = {tên: (kiểu, giá trị thô)}."""
    _typ, hsize, total = struct.unpack_from('<HHI', buf, 0)
    pool, _flags, _psize, _sc = parse_string_pool(buf, hsize)
    off = hsize
    while off < total:
        ctyp, _chsize, csize = struct.unpack_from('<HHI', buf, off)
        if csize == 0:
            break
        if ctyp == RES_XML_START_ELEMENT:
            name_idx = struct.unpack_from('<I', buf, off + 20)[0]
            attr_start, attr_size, attr_count = struct.unpack_from('<HHH', buf, off + 24)
            attrs = {}
            for i in range(attr_count):
                a = off + 16 + attr_start + i * attr_size
                name_i = struct.unpack_from('<i', buf, a + 4)[0]
                dtype = buf[a + 15]
                data = struct.unpack_from('<I', buf, a + 16)[0]
                if 0 <= name_i < len(pool):
                    attrs[pool[name_i]] = (dtype, data)
            yield pool[name_idx] if name_idx < len(pool) else '', attrs, pool
        off += csize


def float_of(raw):
    return struct.unpack('<f', struct.pack('<I', raw))[0]


def patch_axml(data, ref, keep_hyperos=True):
    """Trả về (new_bytes, info) hoặc (None, lý do bỏ qua)."""
    viewport = None
    path_idx = []
    for el, attrs, pool in iter_elements(data):
        if el == 'vector':
            if 'viewportWidth' in attrs and 'viewportHeight' in attrs:
                viewport = (float_of(attrs['viewportWidth'][1]), float_of(attrs['viewportHeight'][1]))
        elif el == 'path' and 'pathData' in attrs:
            dtype, raw = attrs['pathData']
            if dtype == 0x03:
                path_idx.append(raw)  # index vào string pool
    if not viewport or not path_idx:
        return None, 'không phải vector logo'

    strings, flags, _psize, style_count = parse_string_pool(data, struct.unpack_from('<HHI', data, 0)[1])

    sx = viewport[0] / ref['viewport'][0]
    sy = viewport[1] / ref['viewport'][1]

    repl = {}
    info = []
    for order, idx in enumerate(path_idx):
        old = strings[idx]
        if order >= len(ref['paths']):
            break
        if order == 1 and not keep_hyperos:
            new = 'M0,0Z'
        else:
            new = scale_path(ref['paths'][order], sx, sy)
        repl[idx] = new
        info.append((order, len(old), len(new), is_corrupt(old, viewport)))

    new_pool = build_string_pool([repl.get(i, s) for i, s in enumerate(strings)], flags, style_count)

    _typ, hsize, total = struct.unpack_from('<HHI', data, 0)
    _ct, _ch, old_pool_size = struct.unpack_from('<HHI', data, hsize)
    out = bytearray(data[:hsize]) + new_pool + data[hsize + old_pool_size:]
    struct.pack_into('<I', out, 4, len(out))
    return bytes(out), info


def is_corrupt(pd, viewport):
    """pathData hỏng = có cụm >= 7 chữ số liền nhau, hoặc toạ độ vượt xa viewport.

    Toạ độ hợp lệ trong viewport 3471x492 không bao giờ cần tới 7 chữ số liền;
    khi dấu cách phân tách bị mất, các toạ độ dính vào nhau tạo ra chuỗi số
    hàng chục chữ số -> đây là dấu hiệu chắc chắn nhất.
    """
    if not pd or len(pd) < 20:
        return False
    if re.search(r'\d{7,}', pd):
        return True
    limit = max(viewport) * 4
    for tok in re.findall(r'-?\d+\.?\d*', pd):
        try:
            if abs(float(tok)) > limit:
                return True
        except ValueError:
            return True
    return False


def scale_path(pd, sx, sy):
    """Scale pathData (hỗ trợ lệnh tuyệt đối & tương đối) sang viewport mới."""
    out = []

    def emit(cmd, vals):
        up = cmd.upper()
        rel = cmd.islower()
        n = ARITY.get(up, 0)
        if n == 0:
            out.append(cmd)
            return
        first = True
        for k in range(0, len(vals) - n + 1, n):
            ch = vals[k:k + n]
            cc = cmd
            if up == 'M' and not first:
                cc = 'l' if rel else 'L'
            first = False
            if up in ('M', 'L', 'T'):
                res = [fmt(ch[0] * sx), fmt(ch[1] * sy)]
            elif up == 'H':
                res = [fmt(ch[0] * sx)]
            elif up == 'V':
                res = [fmt(ch[0] * sy)]
            elif up == 'C':
                res = [fmt(ch[0] * sx), fmt(ch[1] * sy), fmt(ch[2] * sx),
                       fmt(ch[3] * sy), fmt(ch[4] * sx), fmt(ch[5] * sy)]
            elif up in ('S', 'Q'):
                res = [fmt(ch[0] * sx), fmt(ch[1] * sy), fmt(ch[2] * sx), fmt(ch[3] * sy)]
            elif up == 'A':
                res = [fmt(ch[0] * sx), fmt(ch[1] * sy), fmt(ch[2], 2),
                       fmt(ch[3], 0), fmt(ch[4], 0), fmt(ch[5] * sx), fmt(ch[6] * sy)]
            else:
                res = [fmt(v) for v in ch]
            out.append(cc + ','.join(res))

    cur = None
    nums = []
    for m in TOKEN_RE.finditer(pd):
        if m.group(1):
            if cur is not None:
                emit(cur, nums)
            cur = m.group(1)
            nums = []
        else:
            nums.append(float(m.group(2)))
    if cur is not None:
        emit(cur, nums)
    return ''.join(out)


def fmt(v, nd=2):
    s = ('%.' + str(nd) + 'f') % v
    s = s.rstrip('0').rstrip('.')
    return s if s not in ('-0', '') else '0'


# --------------------------------------------------------------------------
# Vá APK
# --------------------------------------------------------------------------
def patch_apk(apk_bytes, ref, keep_hyperos=True, dry=False):
    src = zipfile.ZipFile(io.BytesIO(apk_bytes))
    targets = [n for n in src.namelist() if LOGO_RE.match(n)]
    if not targets:
        print('  [!] Không tìm thấy xiaomi_os_logo*.xml trong APK')
        return apk_bytes, 0

    patched = {}
    fixed = 0
    for name in targets:
        raw = src.read(name)
        new, info = patch_axml(raw, ref, keep_hyperos)
        if new is None:
            print('  - %-45s bỏ qua (%s)' % (name, info))
            continue
        bad = any(x[3] for x in info)
        if bad:
            fixed += 1
        print('  %s %-45s %s' % ('[FIX]' if bad else '[OK ]', name,
                                 ', '.join('path%d: %d -> %d ký tự%s' % (o, a, b, ' (HỎNG)' if c else '')
                                           for o, a, b, c in info)))
        patched[name] = new

    if dry or fixed == 0:
        return apk_bytes, fixed

    out = io.BytesIO()
    with zipfile.ZipFile(out, 'w') as dst:
        for info in src.infolist():
            data = patched.get(info.filename)
            if data is None:
                data = src.read(info.filename)
            zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            zi.compress_type = info.compress_type
            zi.external_attr = info.external_attr
            zi.internal_attr = info.internal_attr
            zi.create_system = info.create_system
            dst.writestr(zi, data)
    return out.getvalue(), fixed


def main():
    args = [a for a in sys.argv[1:]]
    dry = '--dry-run' in args
    keep_hyperos = '--no-hyperos' not in args
    args = [a for a in args if not a.startswith('--')]
    if not args:
        print(__doc__)
        return 1
    path = args[0]
    here = os.path.dirname(os.path.abspath(__file__))
    ref = json.load(open(os.path.join(here, 'logo_ref.json'), encoding='utf-8'))

    is_xz = path.lower().endswith('.xz')
    print('>> %s' % path)
    if is_xz:
        with lzma.open(path, 'rb') as f:
            apk = f.read()
    else:
        with open(path, 'rb') as f:
            apk = f.read()

    new_apk, fixed = patch_apk(apk, ref, keep_hyperos, dry)
    if dry:
        print('>> Dry-run: %d file cần vá' % fixed)
        return 0
    if fixed == 0:
        print('>> Không có file nào bị hỏng - giữ nguyên.')
        return 0

    if is_xz:
        bak = path + '.bak'
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
            print('>> Đã sao lưu: %s' % bak)
        with lzma.open(path, 'wb', preset=6) as f:
            f.write(new_apk)
        print('>> Đã ghi lại %s (%d MB)' % (path, len(new_apk) // 1024 // 1024))
    else:
        bak = path + '.bak'
        if not os.path.exists(bak):
            shutil.copy2(path, bak)
        with open(path, 'wb') as f:
            f.write(new_apk)
        print('>> Đã ghi lại %s' % path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
