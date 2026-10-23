"""Write a Studio probe that checks every changed script really reached
Studio, so a test run never passes on stale code (CLAUDE.md: "a dead sync
looks exactly like a passing test run").

    python -I tools/sync_probe.py [base]      (base defaults to main)

Takes each .luau file changed since `base` (committed or not), finds the
instance Rojo syncs it to (sourcemap.json, rebuilt first), and picks a
distinctive line from it. The probe it prints - run it with execute_luau
in the Edit datamodel - returns, per file, whether Studio's Source has that
line: all true means Studio is current; any false means reconnect the Rojo
plugin (or restart `rojo serve`) before trusting a test.
"""
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]


def changed(base: str) -> list:
    names = set()
    for args in (["git", "diff", "--name-only", base], ["git", "ls-files", "--others", "--exclude-standard"]):
        out = subprocess.run(args, cwd=ROOT, capture_output=True, text=True, check=True).stdout
        names.update(n.strip() for n in out.splitlines() if n.strip().endswith(".luau"))
    return sorted(n for n in names if (ROOT / n).exists())


def instance_paths() -> dict:
    subprocess.run(
        ["rojo", "sourcemap", "default.project.json", "-o", "sourcemap.json"],
        cwd=ROOT, capture_output=True, check=True,
    )
    tree = json.loads((ROOT / "sourcemap.json").read_text(encoding="utf-8"))
    out = {}

    def walk(node, path):
        for child in node.get("children", []):
            here = path + [child["name"]]
            for file in child.get("filePaths", []):
                out[file.replace("\\", "/")] = here
            walk(child, here)

    walk(tree, [])
    return out


def marker(file: str, base: str) -> str:
    """A line this change added (so the old version cannot have it), the
    longest that appears once in the file; for a new file, its longest
    line of code."""
    text = (ROOT / file).read_text(encoding="utf-8")
    lines = [l.strip() for l in text.splitlines()]
    diff = subprocess.run(
        ["git", "diff", "-U0", base, "--", file], cwd=ROOT, capture_output=True, text=True
    ).stdout
    added = [l[1:].strip() for l in diff.splitlines() if l.startswith("+") and not l.startswith("+++")]
    pool = added or lines
    good = [l for l in pool if len(l) > 12 and lines.count(l) == 1 and "]]" not in l]
    return max(good or pool, key=len)[:120]


def main():
    base = sys.argv[1] if len(sys.argv) > 1 else "main"
    paths = instance_paths()
    checks = []
    for file in changed(base):
        where = paths.get(file)
        if where:
            checks.append((file, where, marker(file, base)))
    if not checks:
        print("-- nothing changed since", base)
        return
    lua = ["local results = {}", "local function find(path)",
           "\tlocal node = game", "\tfor _, name in path do",
           "\t\tnode = node and node:FindFirstChild(name)", "\tend", "\treturn node", "end"]
    for file, where, line in checks:
        names = ", ".join(json.dumps(n) for n in where)
        lua.append(f"do local s = find({{{names}}}) "
                   f"results[{json.dumps(file)}] = s ~= nil and string.find(s.Source, {json.dumps(line)}, 1, true) ~= nil end")
    lua.append("return results")
    print("\n".join(lua))


main()
