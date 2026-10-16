"""Syntax screening on Windows. This does not replace Swift type checking or an iOS build."""
import json
import subprocess
import sys
from pathlib import Path

import tree_sitter_swift
from tree_sitter import Language, Parser

root = Path(__file__).resolve().parents[1]
parser = Parser(Language(tree_sitter_swift.language()))


def errors(data):
    tree = parser.parse(data)
    found = []
    stack = [tree.root_node]
    while stack:
        node = stack.pop()
        if node.type == "ERROR" or node.is_missing:
            found.append({"line": node.start_point.row + 1, "type": node.type,
                          "text": data[node.start_byte:node.end_byte].decode("utf-8", "replace")[:100]})
        stack.extend(reversed(node.children))
    return found


tracked = subprocess.check_output(["git", "diff", "--name-only", "HEAD"], cwd=root, text=True).splitlines()
untracked = subprocess.check_output(["git", "ls-files", "--others", "--exclude-standard"], cwd=root, text=True).splitlines()
report = []
failed = False
for name in sorted(set(tracked + untracked)):
    if not name.endswith(".swift"):
        continue
    current = errors((root / name).read_bytes())
    previous = subprocess.run(["git", "show", f"HEAD:{name}"], cwd=root, capture_output=True)
    baseline = errors(previous.stdout) if previous.returncode == 0 else []
    # Older grammar versions may not support syntax already used by upstream.
    old_fragments = [(e["type"], e["text"]) for e in baseline]
    introduced = []
    for error in current:
        fragment = (error["type"], error["text"])
        if fragment in old_fragments:
            old_fragments.remove(fragment)
        else:
            introduced.append(error)
    failed |= bool(introduced)
    report.append({"file": name, "upstream_parser_errors": len(baseline), "introduced_errors": introduced})
print(json.dumps({"check": "tree-sitter syntax only", "files": report, "passed": not failed}, ensure_ascii=False, indent=2))
sys.exit(1 if failed else 0)
