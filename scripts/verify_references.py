#!/usr/bin/env python3
"""Verify every `references/....md` pointer inside skills/boost/**/*.md resolves to a real file."""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "skills" / "boost"
POINTER_RE = re.compile(r"`references/([a-zA-Z0-9/_.-]+\.md)`")


def main():
    if not ROOT.exists():
        print(f"NO skills/boost DIRECTORY YET: {ROOT}")
        sys.exit(1)

    md_files = sorted(ROOT.rglob("*.md"))
    if not md_files:
        print(f"NO .md FILES FOUND UNDER {ROOT}")
        sys.exit(1)

    missing = []
    for f in md_files:
        text = f.read_text()
        for m in POINTER_RE.finditer(text):
            target = ROOT / "references" / m.group(1)
            if not target.exists():
                missing.append((str(f.relative_to(ROOT.parent.parent)), m.group(1)))

    if missing:
        print("BROKEN REFERENCES:")
        for f, ref in missing:
            print(f"  {f} -> references/{ref}")
        sys.exit(1)

    print(f"All references OK ({len(md_files)} files scanned)")


if __name__ == "__main__":
    main()
