import os
import sys, re, zlib


def _plural(n, word):
    return '%d %s%s' % (n, word, '' if n == 1 else 's')


def _bodies(s, objs):
    """Body of each object: from its offset to the next one."""
    offsets = sorted(objs.values())
    bodies = {}
    for k, o in objs.items():
        later = [v for v in offsets if v > o]
        bodies[k] = s[o:later[0] if later else len(s)]
    return bodies


def _head(body):
    """Text part of an object: the dictionary, without the stream bytes."""
    p = body.find('stream')
    return body[:p] if p >= 0 else body


def _skip_strings(t):
    """Blank out literal and hexadecimal strings before looking for references."""
    out = []
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '(':
            depth, i = 1, i + 1
            while i < n and depth:
                if t[i] == '\\':
                    i += 2
                    continue
                if t[i] == '(':
                    depth += 1
                elif t[i] == ')':
                    depth -= 1
                i += 1
            out.append(' ')
        elif c == '<' and t[i:i + 2] != '<<':
            j = t.find('>', i)
            if j < 0:
                break
            i = j + 1
            out.append(' ')
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def _ref(t, key):
    m = re.search(r'/' + key + r'\s+(\d+)\s+0\s+R\b', t)
    return int(m.group(1)) if m else None


def _dest_page(t):
    m = re.search(r'/Dest\s*\[\s*(\d+)\s+0\s+R', t)
    return int(m.group(1)) if m else None


def _count(t, key):
    m = re.search(r'/' + key + r'\s+(\d+)\b', t)
    return int(m.group(1)) if m else None


def _outline(bodies, pages, errs):
    catalogs = [k for k, b in bodies.items() if '/Type /Catalog' in b]
    if not catalogs:
        errs.append('no catalog')
        return 0
    root = _ref(_head(bodies[catalogs[0]]), 'Outlines')
    if root is None:
        return 0
    if root not in bodies or '/Type /Outlines' not in bodies[root]:
        errs.append('/Outlines points to an invalid object')
        return 0
    body = bodies[root]
    first, last = _ref(body, 'First'), _ref(body, 'Last')
    if (first is None) != (last is None):
        errs.append('outline root: incomplete First/Last')
        return 0
    if first is None:
        return 0

    visited = set()
    total = 0

    def walk(item, parent, prev):
        nonlocal total
        total += 1
        if item in visited:
            errs.append('loop in the outline (object %d)' % item)
            return 0, None
        visited.add(item)
        b = bodies.get(item, '')
        if '/Title' not in b:
            errs.append('bookmark %d without /Title' % item)
        if _ref(b, 'Parent') != parent:
            errs.append('bookmark %d: wrong /Parent' % item)
        page = _dest_page(b)
        if page is None:
            errs.append('bookmark %d: no /Dest' % item)
        elif page not in pages:
            errs.append('bookmark %d: destination to object %d, not a page' % (item, page))
        if prev is None:
            if _ref(b, 'Prev') is not None:
                errs.append('bookmark %d: /Prev on the first child' % item)
        elif _ref(b, 'Prev') != prev:
            errs.append('bookmark %d: wrong /Prev' % item)

        child = _ref(b, 'First')
        descendants = 0
        if child is not None:
            if _ref(b, 'Last') is None:
                errs.append('bookmark %d: /First without /Last' % item)
            cprev, ccur = None, child
            cguard = 0
            while ccur is not None:
                count, nxt = walk(ccur, item, cprev)
                descendants += 1 + count
                cprev, ccur = ccur, nxt
                cguard += 1
                if cguard > len(bodies):
                    errs.append('loop in the children of bookmark %d' % item)
                    break
            if _ref(b, 'Last') != cprev:
                errs.append('bookmark %d: /Last does not close the chain' % item)
            expected = _count(b, 'Count')
            if expected is None or expected != descendants:
                errs.append('bookmark %d: /Count %s instead of %d' % (item, expected, descendants))
        return descendants, _ref(b, 'Next')

    prev, cur, guard = None, first, 0
    while cur is not None:
        _, prev, cur = None, cur, walk(cur, root, prev)[1]
        guard += 1
        if guard > len(bodies):
            errs.append('loop in the top-level bookmarks')
            break
    if prev != last:
        errs.append('root: /Last does not close the chain')
    if _count(body, 'Count') != total:
        errs.append('root: /Count %s instead of %d' % (_count(body, 'Count'), total))
    return total


def _links(bodies, pages, errs):
    links = 0
    for k, b in bodies.items():
        head = _head(b)
        if '/Subtype /Link' not in head:
            continue
        if '/Dest' in head:
            links += 1
            page = _dest_page(head)
            if page not in pages:
                errs.append('link %d: destination to object %s' % (k, page))
        elif '/A' not in head:
            errs.append('link %d: neither /Dest nor /A' % k)
    for k, b in bodies.items():
        if not re.search(r'/Type\s*/Page\b', b):
            continue
        m = re.search(r'/Annots\s*\[([^\]]*)\]', b)
        if not m:
            continue
        for ref in re.findall(r'(\d+)\s+0\s+R', m.group(1)):
            target = int(ref)
            if target not in bodies:
                errs.append('page %d: annotation %d not found' % (k, target))
            elif '/Type /Annot' not in bodies[target]:
                errs.append('page %d: object %d is not an annotation' % (k, target))
    return links


def _references(bodies, errs):
    for k, b in bodies.items():
        for ref in re.findall(r'(\d+)\s+0\s+R', _skip_strings(_head(b))):
            if int(ref) not in bodies:
                errs.append('object %d: reference %s 0 R not found' % (k, ref))


def check(path):
    b = open(path, 'rb').read()
    s = b.decode('latin1')
    errs = []
    if not s.startswith('%PDF-1.'):
        errs.append('bad header')
    i = s.rfind('startxref')
    if i < 0:
        print('%s: no startxref' % path)
        return ['no startxref']
    off = int(s[i+9:].split()[0])
    if s[off:off+4] != 'xref':
        print('%s: startxref=%d points to %r' % (path, off, s[off:off+16]))
        return ['startxref does not point to xref']
    m = re.match(r'xref\r?\n0 (\d+)\r?\n', s[off:])
    n = int(m.group(1))
    base = off + m.end()
    objs = {}
    for k in range(1, n):
        e = s[base + k*20: base + k*20 + 20]
        if len(e) < 18:
            errs.append('truncated xref entry %d' % k)
            break
        o = int(e[:10])
        if s[o:o+len('%d 0 obj' % k)] != '%d 0 obj' % k:
            errs.append('obj %d offset %d -> %r' % (k, o, s[o:o+16]))
        objs[k] = o

    bodies = _bodies(s, objs)
    streams = 0
    flate = 0
    for k, chunk in bodies.items():
        w = re.search(r'/Length (\d+)', chunk)
        if 'stream' in chunk and w:
            streams += 1
            p = chunk.index('stream') + 6
            if chunk[p:p+2] == '\r\n':
                p += 2
            elif chunk[p:p+1] == '\n':
                p += 1
            data = chunk[p:p+int(w.group(1))]
            tail = chunk[p+int(w.group(1)):]
            if not tail.lstrip().startswith('endstream'):
                errs.append('obj %d stream Length mismatch' % k)
            header = chunk[:chunk.index('stream')]
            if '/FlateDecode' in header:
                flate += 1
                try:
                    raw = zlib.decompress(data.encode('latin1'))
                    if not raw:
                        errs.append('obj %d empty FlateDecode stream' % k)
                except Exception as e:
                    errs.append('obj %d invalid FlateDecode (%s)' % (k, e))

    w = re.search(r'trailer\r?\n<<(.*?)>>', s, re.S)
    if not w:
        errs.append('no trailer')
    else:
        t = w.group(1)
        if '/Root' not in t or '/Size' not in t:
            errs.append('incomplete trailer')
        size = int(re.search(r'/Size (\d+)', t).group(1))
        if size != n:
            errs.append('Size %d != xref count %d' % (size, n))

    pages = [k for k, body in bodies.items()
             if re.search(r'/Type\s*/Pages\b', body) and '/Kids' in body]
    page_objects = set()
    if not pages:
        errs.append('no page tree')
    else:
        tree = bodies[pages[0]]
        cnt = _count(tree, 'Count')
        m = re.search(r'/Kids\s*\[([^\]]*)\]', tree)
        kids = re.findall(r'(\d+)\s+0\s+R', m.group(1)) if m else []
        if cnt != len(kids):
            errs.append('Count %s != kids %d' % (cnt, len(kids)))
        page_objects = {int(x) for x in kids}

    bookmarks = _outline(bodies, page_objects, errs)
    links = _links(bodies, page_objects, errs)
    _references(bodies, errs)

    print('%s: %d bytes, %s, %s (%d compressed), %s, %s, %s' %
          (os.path.basename(path), len(b), _plural(n - 1, 'object'), _plural(streams, 'stream'),
           flate, _plural(bookmarks, 'bookmark'), _plural(links, 'internal link'),
           'OK' if not errs else 'ERRORS'))
    for e in errs:
        print('  !', e)
    return errs


if __name__ == '__main__':
    bad = 0
    for p in sys.argv[1:]:
        bad += len(check(p))
    sys.exit(1 if bad else 0)
