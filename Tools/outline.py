"""Print the outline (/Outlines) of a PDF with no dependency.

    python Tools/outline.py document.pdf

Titles are decoded (literals with octal escapes, UTF-16BE hexadecimal
strings) and destinations are resolved to page numbers.
"""

import sys, re


def _load(path):
    s = open(path, 'rb').read().decode('latin1')
    i = s.rfind('startxref')
    if i < 0:
        raise SystemExit('%s: no startxref' % path)
    off = int(s[i+9:].split()[0])
    m = re.match(r'xref\r?\n0 (\d+)\r?\n', s[off:])
    if not m:
        raise SystemExit('%s: unreadable xref table' % path)
    n = int(m.group(1))
    base = off + m.end()
    objs = {}
    for k in range(1, n):
        o = int(s[base + k*20: base + k*20 + 10])
        objs[k] = o
    offsets = sorted(objs.values())
    bodies = {}
    for k, o in objs.items():
        later = [v for v in offsets if v > o]
        bodies[k] = s[o:later[0] if later else len(s)]
    return bodies


def _ref(t, key):
    m = re.search(r'/' + key + r'\s+(\d+)\s+0\s+R\b', t)
    return int(m.group(1)) if m else None


def _pages(bodies):
    order = {}
    for body in bodies.values():
        if re.search(r'/Type\s*/Pages\b', body) and '/Kids' in body:
            m = re.search(r'/Kids\s*\[([^\]]*)\]', body)
            for pos, ref in enumerate(re.findall(r'(\d+)\s+0\s+R', m.group(1))):
                order[int(ref)] = pos + 1
    return order


def _text(value):
    if value.startswith('('):
        raw, out, i = value[1:-1], [], 0
        simple = {'n': '\n', 'r': '\r', 't': '\t', 'b': '\b', 'f': '\f'}
        while i < len(raw):
            c = raw[i]
            if c != '\\':
                out.append(c)
                i += 1
                continue
            nxt = raw[i+1] if i + 1 < len(raw) else ''
            if nxt in simple:
                out.append(simple[nxt])
                i += 2
            elif nxt in '01234567':
                j, octal = i + 1, ''
                while j < len(raw) and len(octal) < 3 and raw[j] in '01234567':
                    octal += raw[j]
                    j += 1
                out.append(chr(int(octal, 8)))
                i = j
            elif nxt in '()\\':
                out.append(nxt)
                i += 2
            else:
                i += 2
        return ''.join(out)
    if value.startswith('<'):
        h = re.sub(r'\s', '', value[1:-1])
        try:
            data = bytes.fromhex(h)
        except ValueError:
            return h
        if data[:2] == b'\xfe\xff':
            return data[2:].decode('utf-16-be', 'replace')
        return data.decode('latin1')
    return value


def outline(path):
    bodies = _load(path)
    pages = _pages(bodies)
    catalog = next((b for b in bodies.values() if '/Type /Catalog' in b), None)
    if catalog is None:
        print('%s: no catalog' % path)
        return 1
    root = _ref(catalog, 'Outlines')
    if root is None or root not in bodies:
        print('%s: no bookmarks' % path)
        return 0

    print('%s: %d page(s)' % (path, len(pages)))
    visited = set()
    total = 0

    def show(item, depth):
        nonlocal total
        while item is not None:
            if item in visited or item not in bodies:
                print('  ! loop or invalid reference (object %d)' % item)
                return
            visited.add(item)
            total += 1
            body = bodies[item]
            m = re.search(r'/Title\s*(\((?:[^()\\]|\\.)*\)|<[0-9A-Fa-f\s]*>)', body)
            title = _text(m.group(1)) if m else '(untitled)'
            dest = re.search(r'/Dest\s*\[\s*(\d+)\s+0\s+R\s*/(Fit|XYZ)([^\]]*)\]', body)
            if dest:
                page = pages.get(int(dest.group(1)), '?')
                if dest.group(2) == 'XYZ':
                    nums = dest.group(3).split()
                    where = 'y=%s' % nums[1] if len(nums) > 1 else 'XYZ'
                else:
                    where = '/Fit'
                where = 'page %s  %s' % (page, where)
            else:
                where = 'no /Dest'
            print('  ' * depth + title.ljust(36 - 2 * depth) + where)
            child = _ref(body, 'First')
            if child is not None:
                show(child, depth + 1)
            item = _ref(body, 'Next')

    show(_ref(bodies[root], 'First'), 0)
    print('---- %d bookmark(s)' % total)
    return 0


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print('usage: python Tools/outline.py document.pdf [...]')
        sys.exit(2)
    status = 0
    for p in sys.argv[1:]:
        status |= outline(p)
    sys.exit(status)
