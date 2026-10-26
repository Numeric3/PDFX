import sys, re, zlib


def _bodies(s, objs):
    """Corps de chaque objet : de son offset jusqu'au suivant."""
    offsets = sorted(objs.values())
    bodies = {}
    for k, o in objs.items():
        later = [v for v in offsets if v > o]
        bodies[k] = s[o:later[0] if later else len(s)]
    return bodies


def _head(body):
    """Partie texte d'un objet : le dictionnaire, sans les octets du flux."""
    p = body.find('stream')
    return body[:p] if p >= 0 else body


def _skip_strings(t):
    """Neutralise les chaines litterales et hexadecimales avant de chercher des references."""
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
        errs.append('pas de catalogue')
        return 0
    root = _ref(_head(bodies[catalogs[0]]), 'Outlines')
    if root is None:
        return 0
    if root not in bodies or '/Type /Outlines' not in bodies[root]:
        errs.append('/Outlines pointe vers un objet invalide')
        return 0
    body = bodies[root]
    first, last = _ref(body, 'First'), _ref(body, 'Last')
    if (first is None) != (last is None):
        errs.append('racine du sommaire : First/Last incomplets')
        return 0
    if first is None:
        return 0

    visited = set()
    total = 0

    def walk(item, parent, prev):
        nonlocal total
        total += 1
        if item in visited:
            errs.append('boucle dans le sommaire (objet %d)' % item)
            return 0, None
        visited.add(item)
        b = bodies.get(item, '')
        if '/Title' not in b:
            errs.append('signet %d sans /Title' % item)
        if _ref(b, 'Parent') != parent:
            errs.append('signet %d : /Parent incorrect' % item)
        page = _dest_page(b)
        if page is None:
            errs.append('signet %d : pas de /Dest' % item)
        elif page not in pages:
            errs.append('signet %d : destination vers l\'objet %d, pas une page' % (item, page))
        if prev is None:
            if _ref(b, 'Prev') is not None:
                errs.append('signet %d : /Prev sur le premier enfant' % item)
        elif _ref(b, 'Prev') != prev:
            errs.append('signet %d : /Prev incorrect' % item)

        child = _ref(b, 'First')
        descendants = 0
        if child is not None:
            if _ref(b, 'Last') is None:
                errs.append('signet %d : /First sans /Last' % item)
            cprev, ccur = None, child
            cguard = 0
            while ccur is not None:
                count, nxt = walk(ccur, item, cprev)
                descendants += 1 + count
                cprev, ccur = ccur, nxt
                cguard += 1
                if cguard > len(bodies):
                    errs.append('boucle dans les enfants du signet %d' % item)
                    break
            if _ref(b, 'Last') != cprev:
                errs.append('signet %d : /Last ne ferme pas la chaine' % item)
            expected = _count(b, 'Count')
            if expected is None or expected != descendants:
                errs.append('signet %d : /Count %s au lieu de %d' % (item, expected, descendants))
        return descendants, _ref(b, 'Next')

    prev, cur, guard = None, first, 0
    while cur is not None:
        _, prev, cur = None, cur, walk(cur, root, prev)[1]
        guard += 1
        if guard > len(bodies):
            errs.append('boucle dans les signets de premier niveau')
            break
    if prev != last:
        errs.append('racine : /Last ne ferme pas la chaine')
    if _count(body, 'Count') != total:
        errs.append('racine : /Count %s au lieu de %d' % (_count(body, 'Count'), total))
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
                errs.append('lien %d : destination vers l\'objet %s' % (k, page))
        elif '/A' not in head:
            errs.append('lien %d : ni /Dest ni /A' % k)
    for k, b in bodies.items():
        if not re.search(r'/Type\s*/Page\b', b):
            continue
        m = re.search(r'/Annots\s*\[([^\]]*)\]', b)
        if not m:
            continue
        for ref in re.findall(r'(\d+)\s+0\s+R', m.group(1)):
            target = int(ref)
            if target not in bodies:
                errs.append('page %d : annotation %d introuvable' % (k, target))
            elif '/Type /Annot' not in bodies[target]:
                errs.append('page %d : l\'objet %d n\'est pas une annotation' % (k, target))
    return links


def _references(bodies, errs):
    for k, b in bodies.items():
        for ref in re.findall(r'(\d+)\s+0\s+R', _skip_strings(_head(b))):
            if int(ref) not in bodies:
                errs.append('objet %d : reference %s 0 R introuvable' % (k, ref))


def check(path):
    b = open(path, 'rb').read()
    s = b.decode('latin1')
    errs = []
    if not s.startswith('%PDF-1.'):
        errs.append('bad header')
    i = s.rfind('startxref')
    if i < 0:
        print('%s: pas de startxref' % path)
        return ['no startxref']
    off = int(s[i+9:].split()[0])
    if s[off:off+4] != 'xref':
        print('%s: startxref=%d pointe sur %r' % (path, off, s[off:off+16]))
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
                        errs.append('obj %d flux FlateDecode vide' % k)
                except Exception as e:
                    errs.append('obj %d FlateDecode invalide (%s)' % (k, e))

    w = re.search(r'trailer\r?\n<<(.*?)>>', s, re.S)
    if not w:
        errs.append('no trailer')
    else:
        t = w.group(1)
        if '/Root' not in t or '/Size' not in t:
            errs.append('trailer incomplete')
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

    print('%s: %d octets, %d objets, %d flux dont %d compresses, %d signets, %d liens internes, %s' %
          (path.split('\\')[-1], len(b), n-1, streams, flate, bookmarks, links,
           'OK' if not errs else 'ERREURS'))
    for e in errs:
        print('  !', e)
    return errs


if __name__ == '__main__':
    bad = 0
    for p in sys.argv[1:]:
        bad += len(check(p))
    sys.exit(1 if bad else 0)
