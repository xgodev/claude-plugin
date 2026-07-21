#!/usr/bin/env python3
"""Check every `boost.factory.*` config namespace documented in the boost skill
against the config roots actually declared in a boost checkout.

Why this exists: the skill repeatedly documented a friendly vendor name
(`boost.factory.kafka.*`) where boost declares the module name
(`boost.factory.confluent`). Those keys are silently ignored at runtime -- the
service boots with defaults and nothing complains, so the defect survives every
routing test and every code review. This turns that class into a hard failure.

Usage:
    BOOST_SRC=/path/to/boost-checkout python3 scripts/verify_config_roots.py

Exit status: 0 when every documented namespace resolves, 1 otherwise (or when
BOOST_SRC is unusable -- an unverifiable claim is not a passing claim).

Scope, deliberately narrow to keep false positives at zero: only
`boost.factory.*` is checked, because those roots are declared as plain string
literals this script can extract with confidence. Roots composed at runtime
(`adapter.Root + ".kafka_confluent"`) are NOT resolved, so `boost.bootstrap.*`
and `boost.wrapper.*` namespaces are out of scope and are reported as skipped.
"""

import os
import re
import sys
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent / "skills" / "dev" / "golang" / "boost"
ALLOWLIST = Path(__file__).resolve().parent / "config_roots_allowlist.txt"

# Literal root declarations: `root = "boost.factory.x"`, `cmdRoot = "..."`, etc.
ROOT_DECL = re.compile(r'\b\w*[Rr]oot\s*(?::)?=\s*"(boost\.[^"]+)"')
# Namespaces cited in the docs, in prose, tables or code fences.
DOC_NS = re.compile(r'boost\.factory\.[a-zA-Z0-9_.]+')

# Trailing tokens that are wildcards or sentence punctuation, not path segments.
TRAILING = "*.,;:)]}`\"'"


def source_roots(boost_src: Path) -> set[str]:
    roots = set()
    for go in boost_src.rglob("*.go"):
        try:
            text = go.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        roots.update(ROOT_DECL.findall(text))
    return {r for r in roots if r.startswith("boost.factory.")}


def documented(skill_dir: Path) -> dict[str, list[str]]:
    """namespace -> ["file:line", ...]"""
    found: dict[str, list[str]] = {}
    for md in sorted(skill_dir.rglob("*.md")):
        for lineno, line in enumerate(md.read_text(encoding="utf-8").splitlines(), 1):
            for raw in DOC_NS.findall(line):
                ns = raw.rstrip(TRAILING)
                if ns.count(".") < 2:
                    continue
                found.setdefault(ns, []).append(f"{md.relative_to(skill_dir)}:{lineno}")
    return found


def allowlisted() -> set[str]:
    """Namespaces the docs mention precisely to say they do NOT exist. Without
    this the checker punishes a leaf for being correct, and a checker that fails
    on correct docs gets switched off."""
    if not ALLOWLIST.is_file():
        return set()
    out = set()
    for line in ALLOWLIST.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.add(line.split("\t")[0].strip())
    return out


def resolves(ns: str, roots: set[str]) -> bool:
    """A documented namespace is valid when some declared root is a prefix of it
    (`boost.factory.echo.port` under root `boost.factory.echo`), or when it is a
    proper prefix of a root -- docs legitimately name a parent
    (`boost.factory.gcp` above `boost.factory.gcp.pubsub`)."""
    return any(ns == r or ns.startswith(r + ".") or r.startswith(ns + ".") for r in roots)


def main() -> int:
    src = os.environ.get("BOOST_SRC")
    if not src:
        print("verify_config_roots: BOOST_SRC is not set.", file=sys.stderr)
        print("  Clone github.com/xgodev/boost and point BOOST_SRC at it.", file=sys.stderr)
        return 1
    boost_src = Path(src).expanduser()
    if not (boost_src / "factory").is_dir():
        print(f"verify_config_roots: {boost_src} has no factory/ -- not a boost checkout.", file=sys.stderr)
        return 1

    roots = source_roots(boost_src)
    if not roots:
        print("verify_config_roots: extracted 0 config roots -- refusing to pass.", file=sys.stderr)
        return 1

    skip = allowlisted()
    bad = {
        ns: hits
        for ns, hits in documented(SKILL_DIR).items()
        if ns not in skip and not resolves(ns, roots)
    }
    if bad:
        print(f"verify_config_roots: {len(bad)} documented namespace(s) match no config root in {boost_src}\n")
        for ns in sorted(bad):
            print(f"  {ns}")
            for hit in sorted(set(bad[ns])):
                print(f"      {hit}")
        print(f"\n{len(roots)} roots were extracted from source. A namespace listed above is")
        print("either misspelled, renamed upstream, or never registered at all -- in every")
        print("case the documented keys and their BOOST_* env vars do nothing at runtime.")
        return 1

    print(f"All boost.factory.* namespaces resolve ({len(roots)} roots extracted from {boost_src}).")
    print("Note: boost.bootstrap.* and boost.wrapper.* roots are composed at runtime and are not checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
