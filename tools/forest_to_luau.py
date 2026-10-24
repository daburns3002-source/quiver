"""Turn the owner's Studio import of the Mossy Glade's outer forest into
src/shared/Config/GladeForest.luau, the parts ArenaModels draws round every
glade room.

    python -I tools/forest_to_luau.py

Reads assets/models/arenas/mossy_glade_outer_ids.json, the output of
tools/studio/dump_forest.luau. The forest (docs/arenas/mossy-glade-outer.md)
is authored in the room's own frame at 1 unit = 1 stud, so unlike the round
arenas it is never slimmed or scaled (optimise_arena.py would move it):

- Offsets are read from the import's pivot, which is the GLB's origin, the
  lawn's centre.
- The importer turned the model 180 degrees, and Arena turns every part
  180 degrees again. Negating x and z puts each part back where the GLB
  has it, so the gate gap lands at north (-Z), behind the gatehouse.
- Neighbouring trees that overlap are pushed apart (`separate`): six pairs
  of crowns ran into each other by up to 0.8 studs, and four trunks into
  the next tree's crown, which read as clipping as the camera moved (owner,
  2026-10-24: "the clipping is on the trees outside of the arena"). Each
  tree (trunk and crown) moves as one, along its smallest overlap, never
  toward the room.
- The glow caps' cyan is a material colour, which the importer drops, so
  they are drawn Neon in that cyan. The ground is drawn matte, as the old
  glades' was (plastic read its dark grass as pale grey).
"""

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/models/arenas/mossy_glade_outer_ids.json"
TARGET = ROOT / "src/shared/Config/GladeForest.luau"

# The GLB's GlowCap material, baseColorFactor in 0-255.
GLOW_CAP = (13, 183, 233)
MATTE = ("Ground",)


def num(v):
    s = f"{v:.3f}"
    return "0.000" if s == "-0.000" else s


def vec(x, y, z):
    return f"Vector3.new({num(x)}, {num(y)}, {num(z)})"


# Studs kept between neighbouring trees, and how many passes to settle them.
TREE_GAP = 0.3
PASSES = 20
# The room's hole (walls' outer faces): no tree is moved nearer to it.
HOLE = (19.5, 31.0)


def tree_of(name):
    """The tree a trunk or crown belongs to ("" for the first), or None."""
    for prefix in ("Trunk", "CanopyMesh"):
        if name.startswith(prefix) and (name[len(prefix):] == "" or name[len(prefix):].isdigit()):
            return name[len(prefix):] or "1"
    return None


def box(r, shift):
    (sx, sy, sz), (ox, oy, oz) = r["size"], r["offset"]
    return (ox + shift[0] - sx / 2, ox + shift[0] + sx / 2, oy - sy / 2, oy + sy / 2, oz + shift[1] - sz / 2, oz + shift[1] + sz / 2)


def hole_gap(x, z):
    return max(abs(x) - HOLE[0], abs(z) - HOLE[1])


def separate(rows):
    """Pushes overlapping trees apart; returns {tree: (dx, dz)}."""
    trees = {}
    for r in rows:
        t = tree_of(r["name"])
        if t:
            trees.setdefault(t, []).append(r)
    shift = {t: [0.0, 0.0] for t in trees}
    centre = {t: (sum(r["offset"][0] for r in rs) / len(rs), sum(r["offset"][2] for r in rs) / len(rs)) for t, rs in trees.items()}
    names = sorted(trees)
    for _ in range(PASSES):
        moved = False
        for i, a in enumerate(names):
            for b in names[i + 1 :]:
                best = None
                for ra in trees[a]:
                    for rb in trees[b]:
                        A, B = box(ra, shift[a]), box(rb, shift[b])
                        dx = min(A[1], B[1]) - max(A[0], B[0]) + TREE_GAP
                        dy = min(A[3], B[3]) - max(A[2], B[2])
                        dz = min(A[5], B[5]) - max(A[4], B[4]) + TREE_GAP
                        if dx > 0 and dy > 0 and dz > 0:
                            push = (dx, 0) if dx < dz else (0, dz)
                            if best is None or max(push) > max(best):
                                best = push
                if not best:
                    continue
                moved = True
                ax, az = centre[a][0] + shift[a][0], centre[a][1] + shift[a][1]
                bx, bz = centre[b][0] + shift[b][0], centre[b][1] + shift[b][1]
                sign = (1 if ax >= bx else -1, 1 if az >= bz else -1)
                step = (best[0] * sign[0], best[1] * sign[1])
                # whichever way is away from the room takes the move; both share it otherwise
                ga = hole_gap(ax + step[0], az + step[1]) >= hole_gap(ax, az)
                gb = hole_gap(bx - step[0], bz - step[1]) >= hole_gap(bx, bz)
                wa, wb = (0.5, 0.5) if ga == gb else ((1.0, 0.0) if ga else (0.0, 1.0))
                shift[a][0] += step[0] * wa
                shift[a][1] += step[1] * wa
                shift[b][0] -= step[0] * wb
                shift[b][1] -= step[1] * wb
        if not moved:
            break
    for t, rs in trees.items():
        for r in rs:
            r["offset"] = [r["offset"][0] + shift[t][0], r["offset"][1], r["offset"][2] + shift[t][1]]
    return {t: v for t, v in shift.items() if v != [0.0, 0.0]}


def main():
    rows = json.loads(SOURCE.read_text())
    moved = separate(rows)
    for t, (dx, dz) in sorted(moved.items(), key=lambda kv: int(kv[0])):
        print(f"tree {t} moved {dx:+.2f}, {dz:+.2f}")
    names = [r["name"] for r in rows]
    dupes = sorted({n for n in names if names.count(n) > 1})
    if dupes:
        raise SystemExit(f"duplicate part names: {dupes}")

    out = [
        "--!strict",
        "--[[",
        "\tThe Mossy Glade's outer forest as the owner imported it",
        "\t(docs/arenas/mossy-glade-outer.md): 81 trees, bushes, rocks, logs and",
        "\tglowing mushrooms round the room, with a hole where the room goes.",
        "\tGenerated by tools/forest_to_luau.py from tools/studio/dump_forest.luau's",
        "\toutput; regenerate after a re-import, never hand-edit.",
        "",
        "\tEach part as ArenaModels.ArenaPart: offset from the lawn's centre,",
        "\talready turned for Arena's 180-degree turn.",
        "]]",
        "",
        "type Part = {",
        "	name: string,",
        "	meshId: string,",
        "	size: Vector3,",
        "	offset: Vector3,",
        "	glow: boolean?,",
        "	matte: boolean?,",
        "	tint: Color3?,",
        "	-- Unused here, but in ArenaModels.ArenaPart, which this must match.",
        "	water: Color3?,",
        "	bank: Color3?,",
        "}",
        "",
        "local parts: { Part } = {",
    ]
    for r in rows:
        sx, sy, sz = r["size"]
        ox, oy, oz = r["offset"]
        lines = [
            f'\t\tname = "{r["name"]}",',
            f'\t\tmeshId = "{r["meshId"]}",',
            f"\t\tsize = {vec(sx, sy, sz)},",
            f"\t\toffset = {vec(-ox, oy, -oz)},",
        ]
        if r["name"].startswith("GlowCap"):
            lines.append("\t\tglow = true,")
            lines.append(f"\t\ttint = Color3.fromRGB({', '.join(map(str, GLOW_CAP))}),")
        if r["name"] in MATTE:
            lines.append("\t\tmatte = true,")
        out.append("\t{")
        out.extend(lines)
        out.append("\t},")
    out.append("}")
    out.append("")
    out.append("return table.freeze(parts)")
    TARGET.write_text("\n".join(out) + "\n", newline="\n")
    print(f"wrote {len(rows)} parts to {TARGET.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
