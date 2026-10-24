"""Take in something the owner sends (a Claude Design handoff zip, a GLB, an
.rbxmx kit) and report what it is and what is new in it against what the
game already has, so nothing gets compared by hand.

    python -I tools/intake.py <file> [<file> ...]

For each file:

- A zip is extracted into its own new folder under .intake/ (gitignored),
  never into the repo, and nothing in it is run.
- Every file inside is matched to the repo's copy by name (anywhere under
  assets/ or src/), and reported NEW (no copy), SAME (identical bytes) or
  CHANGED. Two zips that are the same handoff are reported as duplicates.
- An .rbxmx is read for its KeyframeSequences: each clip's name, length,
  keyframe count and markers, and which of them the repo's copy lacks or
  has differently.
- The handoff's README is shown, since it says how the thing is meant to
  work.
- A guess at which pipeline it belongs to (docs/PIPELINES.md), from the
  handoff's folder name and contents.

Writes a short summary to .intake/<name>/INTAKE.md as well as printing it.
"""
import hashlib
import pathlib
import sys
import xml.etree.ElementTree as ET
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
INTAKE = ROOT / ".intake"
SEARCH = [ROOT / "assets", ROOT / "src", ROOT / "docs"]
SKIP_SUFFIXES = {".bin"}
NEWLINE = chr(10)

#: (words in the handoff's name or files, pipeline in docs/PIPELINES.md)
PIPELINES = [
    (("_r15", "_kit.rbxmx"), "Weapon kit"),
    (("boss", "king"), "Boss"),
    (("rigged", "_animations.rbxmx"), "Rigged enemy"),
    (("arena", "glade", "ambience", "forest"), "Arena / scenery"),
    (("slime", "wilf", "enemy", "spitter"), "Enemy model"),
    (("pet", "egg"), "Pets (design only)"),
    (("card", "end_screen", "ui"), "UI handoff"),
    (("sound", "audio", ".wav", ".mp3"), "Sound"),
]


TEXT_SUFFIXES = {".md", ".lua", ".luau", ".js", ".json", ".html", ".rbxmx", ".py", ".css", ".txt", ".mtl"}


def digest(path: pathlib.Path) -> str:
    """The file's hash; text with its line endings made plain, so a copy
    git stored with Windows endings still counts as the same."""
    data = path.read_bytes()
    if path.suffix.lower() in TEXT_SUFFIXES:
        data = data.replace(bytes([13, 10]), bytes([10]))
    return hashlib.sha256(data).hexdigest()


#: Files every handoff carries with its own contents: shown, not compared.
GENERIC = {"readme.md", "three-d-stage.js", "intake.md"}


def normal(name: str) -> str:
    """A file or clip name as the repo spells it: every wolf is a Wilf
    (owner, 2026-10-23), so the owner's older names still match."""
    return name.lower().replace("wolf", "wilf")


def repo_index() -> tuple:
    by_name: dict = {}
    by_digest: dict = {}
    for base in SEARCH:
        for path in base.rglob("*"):
            if path.is_file() and path.suffix.lower() not in SKIP_SUFFIXES:
                by_name.setdefault(normal(path.name), []).append(path)
                by_digest.setdefault(digest(path), path)
    return by_name, by_digest


def clips(path: pathlib.Path) -> dict:
    """Each KeyframeSequence's name -> (length, keyframes, markers)."""
    out = {}
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return out
    for item in root.iter("Item"):
        if item.get("class") != "KeyframeSequence":
            continue
        name = ""
        for p in item.find("Properties"):
            if p.get("name") == "Name":
                name = p.text or ""
        times, markers = [], {}
        for frame in item.findall("Item"):
            if frame.get("class") != "Keyframe":
                continue
            time = 0.0
            for p in frame.find("Properties"):
                if p.get("name") == "Time":
                    time = float(p.text)
            has_pose = any(c.get("class") == "Pose" for c in frame.findall("Item"))
            if has_pose:
                times.append(time)
            for marker in frame.findall("Item"):
                if marker.get("class") == "KeyframeMarker":
                    for p in marker.find("Properties"):
                        if p.get("name") == "Name":
                            markers[p.text] = round(time, 3)
        out[normal(name)] = (round(max(times, default=0), 3), len(times), markers)
    return out


def guess(name: str, files: list) -> str:
    text = (name + " " + " ".join(f.name for f in files)).lower()
    for words, pipeline in PIPELINES:
        if any(w in text for w in words):
            return pipeline
    return "unknown: read the README"


def extract(path: pathlib.Path) -> tuple:
    """A zip into its own folder under .intake/ (never the repo); any other
    file as itself. Returns the folder and the files."""
    folder = INTAKE / path.stem.replace(" ", "_")
    if path.suffix.lower() != ".zip":
        return folder, [path]
    folder.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path) as archive:
        for member in archive.namelist():
            target = (folder / member).resolve()
            if not str(target).startswith(str(folder.resolve())):
                raise SystemExit(f"refusing a path that leaves the folder: {member}")
        archive.extractall(folder)
    files = [f for f in folder.rglob("*") if f.is_file() and f.name != "INTAKE.md"]
    return folder, files


def take(path: pathlib.Path, index: tuple, seen: dict) -> str:
    by_name, by_digest = index
    folder, files = extract(path)
    lines = [f"# Intake: {path.name}", ""]

    #: Two zips with the same files are the same handoff, whatever their
    #: own bytes (a zip records when it was made).
    fingerprint = hashlib.sha256(
        "".join(sorted(f"{f.relative_to(folder) if f != path else f.name}:{digest(f)}" for f in files)).encode()
    ).hexdigest()
    if fingerprint in seen:
        lines.append(f"**Duplicate** of {seen[fingerprint]}: the same files, nothing new.")
        return NEWLINE.join(lines)
    seen[fingerprint] = path.name

    if folder.exists():
        lines.append(f"Extracted to `{folder.relative_to(ROOT)}` ({len(files)} files).")
    lines.append(f"Likely pipeline: **{guess(path.stem, files)}** (docs/PIPELINES.md).")
    lines.append("")
    lines.append("| File | Status | Repo copy |")
    lines.append("|---|---|---|")
    counts = {"NEW": 0, "SAME": 0, "CHANGED": 0}
    for f in sorted(files):
        if f.suffix.lower() in SKIP_SUFFIXES or f.name.lower() in GENERIC:
            continue
        mine = digest(f)
        copies = by_name.get(normal(f.name), [])
        if mine in by_digest:
            status, where = "SAME", str(by_digest[mine].relative_to(ROOT))
        elif copies:
            status, where = "CHANGED", str(copies[0].relative_to(ROOT))
        else:
            status, where = "NEW", ""
        counts[status] += 1
        shown = f.relative_to(folder) if f != path else f.name
        lines.append(f"| {shown} | {status} | {where} |")

        if f.suffix.lower() == ".rbxmx":
            new = clips(f)
            old: dict = {}
            for c in copies + ([by_digest[mine]] if mine in by_digest else []):
                old.update(clips(c))
            for clip, (length, keys, markers) in new.items():
                before = old.get(clip)
                note = (
                    "new clip" if before is None
                    else "same" if before == (length, keys, markers)
                    else f"was {before[0]}s, {before[1]} keys, markers {before[2]}"
                )
                lines.append(f"|   - clip `{clip}` {length}s, {keys} keys, markers {markers} | {note} | |")
    lines.insert(3, f"{counts['NEW']} new, {counts['CHANGED']} changed, {counts['SAME']} already in the repo.")

    readme = next((f for f in files if f.name.lower() == "readme.md"), None)
    if readme:
        lines += ["", "## README", "", readme.read_text(encoding="utf-8", errors="replace")]
    report = NEWLINE.join(lines)
    if folder.exists():
        (folder / "INTAKE.md").write_text(report, encoding="utf-8")
    return report


def main():
    # The Windows console is not UTF-8 by default; READMEs are.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    index = repo_index()
    seen: dict = {}
    for arg in sys.argv[1:]:
        print(take(pathlib.Path(arg), index, seen))
        print()


main()
