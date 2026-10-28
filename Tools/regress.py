"""Compare produced PDFs with a reference, with dates neutralized.

    python Tools/regress.py Tests/Reference Examples Tests

Each reference PDF Tests/Reference/X.pdf is compared with the PDF of the same
name found in the given folders. Only two elements are not deterministic: the
PDF timestamps (/CreationDate, /ModDate, time-zone suffix included) and the
{date} token of headers, written as (YYYY-MM-DD) Tj. Both are neutralized
before the comparison.
"""

import sys
import os
import re
import hashlib

STAMP = re.compile(rb"D:\d{14}(?:Z|[+\-]\d{2}'\d{2}')?")
DAYTEXT = re.compile(rb"\(\d{4}-\d{2}-\d{2}\) Tj")


def normalized(path):
    data = open(path, "rb").read()
    data = STAMP.sub(b"D:00000000000000Z", data)
    return DAYTEXT.sub(b"(0000-00-00) Tj", data)


def digest(data):
    return hashlib.sha256(data).hexdigest()[:16]


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    ref_dir, folders = sys.argv[1], sys.argv[2:]
    failures = 0
    for name in sorted(os.listdir(ref_dir)):
        if not name.lower().endswith(".pdf"):
            continue
        ref_path = os.path.join(ref_dir, name)
        found = None
        for folder in folders:
            candidate = os.path.join(folder, name)
            if os.path.exists(candidate):
                found = candidate
                break
        if not found:
            print("MISSING    %s" % name)
            failures += 1
            continue
        expected, actual = normalized(ref_path), normalized(found)
        if expected == actual:
            print("IDENTICAL  %s  (%s)" % (name, digest(actual)))
        else:
            failures += 1
            print("DIFFERENT  %s  ref=%s new=%s  (%d vs %d bytes)" % (
                name, digest(expected), digest(actual), len(expected), len(actual)))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
