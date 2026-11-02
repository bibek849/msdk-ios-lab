#!/usr/bin/env python3
"""Check local documentation links and declared JSON, without network access.

This is not a secret scanner, external-link checker or hardware validation.
"""

import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {".git", ".build", ".swiftpm", "artifacts", "private-evidence"}


def included(path):
    return not any(part in EXCLUDED for part in path.relative_to(ROOT).parts)


def main():
    failures = []
    markdown = sorted(p for p in ROOT.rglob("*.md") if included(p))
    link_count = 0
    for path in markdown:
        content = path.read_text(encoding="utf-8")
        if not content.endswith("\n"):
            failures.append(f"{path.relative_to(ROOT)}: missing final newline")
        for target in re.findall(r"\[[^\]]*\]\(([^\s)]+)\)", content):
            parsed = urlsplit(target.strip("<>"))
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            resolved = (path.parent / unquote(parsed.path)).resolve()
            if not resolved.is_relative_to(ROOT):
                failures.append(f"{path.relative_to(ROOT)}: link leaves repository: {target}")
            elif not resolved.exists():
                failures.append(f"{path.relative_to(ROOT)}: missing link: {target}")
            link_count += 1
    json_files = sorted(p for p in ROOT.rglob("*.json") if included(p))
    for path in json_files:
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except (ValueError, UnicodeError) as error:
            failures.append(f"{path.relative_to(ROOT)}: {error}")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    print(f"PASS: {len(markdown)} Markdown files, {link_count} local link targets, "
          f"{len(json_files)} JSON files. External URLs and anchors not checked.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
