"""Turn the owner's Studio imports of Claude Design pets into
src/shared/Config/PetModels/<Name>.luau, so the game can rebuild each pet
from its mesh ids (the way enemy meshes are built) and play its clips.

    python -I tools/imports_to_luau.py

Reads assets/models/model_imports.json, the output of
tools/studio/dump_models.luau, and the GLBs named in
assets/models/model_clips.json. Studio is only trusted for the mesh ids;
everything else comes from the GLB, because the importer loses it:

- Every Claude Design GLB imports as "AuxScene", so each import is matched
  to its GLB by its parts' names.
- A mesh used by several nodes imports once, named after the first, so
  Stumpy's four legs all arrive as "Leg_L_front". Each part is matched to
  its GLB primitive by where it sits and how big it is, and takes that
  node's name (the name Config/ModelClips keys on).
- Colours live in the GLB's materials, which the importer drops (every part
  arrives grey). Each part takes its material's colour, glow and alpha.
- A rigged import (a GLB with joint nodes) places each mesh as if no node
  were turned, so a tilted leaf arrives flat. Each part is placed at its
  real rest pose. A GLB without joints imports with the turn baked into the
  mesh, and is placed as imported.

Writes one module per model found in both, each part holding its name, mesh
id, colour, material, transparency, size and place relative to the model's
pivot (12 CFrame components), in Roblox's frame: the importer turns a model
half round so its front faces -Z.
"""
import collections
import json
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import glb_clips_to_luau as glb  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
DUMP = ROOT / "assets" / "models" / "model_imports.json"
MANIFEST = ROOT / "assets" / "models" / "model_clips.json"
OUT = ROOT / "src" / "shared" / "Config" / "PetModels"

#: The importer's turn: half round about Y (its own inverse).
TURN = np.diag([-1.0, 1.0, -1.0])
#: A part further than this from its primitive (studs, the worst axis of
#: centre plus size) means the import and the GLB disagree.
MATCH_TOLERANCE = 0.02
#: Glow (emissive times strength, linear) from which a part is Neon.
NEON_GLOW = 0.6


def num(v: float) -> str:
    r = round(float(v), 5)
    if r == 0:
        return "0"
    return f"{r:.5f}".rstrip("0").rstrip(".")


def nums(vs) -> str:
    return "{ " + ", ".join(num(v) for v in vs) + " }"


def lua_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def positions(gltf, binary, index) -> np.ndarray:
    acc = gltf["accessors"][index]
    view = gltf["bufferViews"][acc["bufferView"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride", 12)
    rows = np.frombuffer(binary, np.uint8, stride * (acc["count"] - 1) + 12, start)
    rows = np.lib.stride_tricks.as_strided(rows, (acc["count"], 12), (stride, 1))
    return np.ascontiguousarray(rows).view(np.float32).reshape(-1, 3).astype(float)


def used(gltf, binary, prim) -> np.ndarray:
    """The vertices a primitive's triangles use: primitives can share one
    vertex buffer, and each imports bounded by its own."""
    v = positions(gltf, binary, prim["attributes"]["POSITION"])
    if "indices" not in prim:
        return v
    acc = gltf["accessors"][prim["indices"]]
    view = gltf["bufferViews"][acc["bufferView"]]
    kind = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32}[acc["componentType"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    return v[np.unique(np.frombuffer(binary, kind, acc["count"], start))]


def to_srgb(c: float) -> float:
    c = min(max(c, 0.0), 1.0)
    return c * 12.92 if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def look(gltf, index):
    """A material's colour (sRGB), Roblox material and transparency."""
    if index is None:
        return [1.0, 1.0, 1.0], "SmoothPlastic", 0.0
    m = gltf["materials"][index]
    base = m.get("pbrMetallicRoughness", {}).get("baseColorFactor", [1, 1, 1, 1])
    strength = m.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
    glow = np.array(m.get("emissiveFactor", [0, 0, 0]), float) * strength
    colour = [to_srgb(c) for c in np.array(base[:3], float) + glow]
    material = "Neon" if glow.max() >= NEON_GLOW else "SmoothPlastic"
    alpha = base[3] if m.get("alphaMode") == "BLEND" else 1.0
    return colour, material, round(1 - alpha, 3)


def primitives(path: pathlib.Path):
    """Every mesh primitive: its node's name, how a baked and a rigged
    import would place it, and where it really rests (all in Roblox's
    frame, before the import's offset)."""
    gltf, binary = glb.load(path)
    nodes = gltf["nodes"]
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    cache = {}

    def world(i, turned):
        key = (i, turned)
        if key not in cache:
            t, q, s = glb.local_trs(nodes[i])
            m = glb.affine(t, q if turned else np.array([0, 0, 0, 1.0]), s)
            cache[key] = world(parent[i], turned) @ m if i in parent else m
        return cache[key]

    out = []
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        w, flat = world(i, True), world(i, False)
        for prim in gltf["meshes"][n["mesh"]]["primitives"]:
            v = used(gltf, binary, prim)
            baked = v @ w[:3, :3].T + w[:3, 3]
            rigged = v @ flat[:3, :3].T + flat[:3, 3]
            local_centre = (v.min(0) + v.max(0)) / 2
            # the turn a rigged import leaves out: the real world linear part
            # over the unturned one
            spin = w[:3, :3] @ np.linalg.inv(flat[:3, :3])
            u, _, vt = np.linalg.svd(spin)
            spin = u @ vt
            out.append(
                {
                    "node": n.get("name") or f"node{i}",
                    "baked": (TURN @ ((baked.min(0) + baked.max(0)) / 2), baked.max(0) - baked.min(0)),
                    "rigged": (TURN @ ((rigged.min(0) + rigged.max(0)) / 2), rigged.max(0) - rigged.min(0)),
                    "rest": (TURN @ (w @ np.append(local_centre, 1))[:3], TURN @ spin @ TURN),
                    "look": look(gltf, prim.get("material")),
                }
            )
    return out


def match(parts, prims, mode):
    """Pairs each imported part with a primitive. A part whose name is its
    node's, once on each side, pairs by name and is checked by size alone:
    a GLB re-exported with its nodes regrouped under a turned joint rests
    where it did, but a rigged import of it would sit elsewhere. The rest
    pair by place and size, closest first. Returns the pairs, the import's
    offset and the worst distance."""
    seen = np.array([p["cframe"][:3] for p in parts], float)
    sizes = np.array([p["size"] for p in parts], float)
    centres = np.array([q[mode][0] for q in prims])
    extents = np.array([q[mode][1] for q in prims])
    part_count = collections.Counter(p["name"] for p in parts)
    prim_index = collections.defaultdict(list)
    for b, q in enumerate(prims):
        prim_index[q["node"]].append(b)
    named = {
        a: prim_index[p["name"]][0]
        for a, p in enumerate(parts)
        if part_count[p["name"]] == 1 and len(prim_index[p["name"]]) == 1
    }
    offset = np.median([seen[a] - centres[b] for a, b in named.items()], 0) if named else (
        np.median(seen, 0) - np.median(centres, 0)
    )
    rest_p = [a for a in range(len(parts)) if a not in named]
    rest_q = [b for b in range(len(prims)) if b not in named.values()]
    pairs = dict(named)
    for _ in range(2):
        pairs = dict(named)
        if rest_p:
            cost = np.abs(seen[rest_p][:, None, :] - centres[rest_q][None, :, :] - offset).max(2) + np.abs(
                sizes[rest_p][:, None, :] - extents[rest_q][None, :, :]
            ).max(2)
            order = np.dstack(np.unravel_index(np.argsort(cost, axis=None), cost.shape))[0]
            used_p, used_q = set(), set()
            for i, j in order:
                if i not in used_p and j not in used_q:
                    pairs[rest_p[i]] = rest_q[j]
                    used_p.add(i)
                    used_q.add(j)
        offset = np.median([seen[a] - centres[b] for a, b in pairs.items()], 0)
    worst = max(
        (0 if a in named else np.abs(seen[a] - centres[b] - offset).max()) + np.abs(sizes[a] - extents[b]).max()
        for a, b in pairs.items()
    )
    return pairs, offset, worst


def render(key, scene, mode, rows) -> str:
    lines = [
        "--!strict",
        "--[[",
        f"\t{key} as the owner imported it ({scene}, a {mode} import). Generated",
        "\tby tools/imports_to_luau.py from tools/studio/dump_models.luau's output",
        "\tand the GLB; regenerate after a re-import, never hand-edit.",
        "",
        "\tEach part: its GLB node's name (which Config/ModelClips keys on), mesh",
        "\tand texture ids, colour, material, transparency, size, and its rest",
        "\tplace relative to the model's pivot (12 CFrame components).",
        "]]",
        "",
        "return table.freeze({",
    ]
    for r in rows:
        lines.append(
            "\t{ "
            + f"name = {lua_string(r['name'])}, meshId = {lua_string(r['meshId'])}, "
            + f"textureId = {lua_string(r['textureId'])}, color = {nums(r['color'])}, "
            + f"material = {lua_string(r['material'])}, transparency = {num(r['transparency'])}, "
            + f"size = {nums(r['size'])}, cframe = {nums(r['cframe'])}"
            + " },"
        )
    lines += ["})", ""]
    return "\n".join(lines)


def main():
    dump = json.loads(DUMP.read_text(encoding="utf-8"))
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    OUT.mkdir(parents=True, exist_ok=True)
    written = set()
    for key, rel in manifest.items():
        if key.startswith("_"):
            continue
        prims = primitives(ROOT / rel)
        names = {q["node"] for q in prims}
        scene = max(dump, key=lambda s: len(names & {p["name"] for p in dump[s]["parts"]}))
        parts = dump[scene]["parts"]
        if not names & {p["name"] for p in parts} or len(parts) > len(prims):
            print(f"skipped {key}: no import of {rel} ({len(prims)} meshes) in the dump")
            continue
        fits = {mode: match(parts, prims, mode) for mode in ("baked", "rigged")}
        mode = min(fits, key=lambda m: fits[m][2])
        pairs, offset, worst = fits[mode]
        if worst > MATCH_TOLERANCE:
            print(f"skipped {key}: its import is {worst:.3f} studs from the GLB ({scene})")
            continue
        rows = []
        for a, b in sorted(pairs.items(), key=lambda ab: prims[ab[1]]["node"]):
            part, prim = parts[a], prims[b]
            colour, material, transparency = prim["look"]
            if mode == "baked":
                cframe = part["cframe"]
            else:
                centre, spin = prim["rest"]
                cframe = list(centre + offset) + list(spin.reshape(-1))
            rows.append(
                {
                    "name": prim["node"],
                    "meshId": part["meshId"],
                    "textureId": part.get("textureId") or "",
                    "color": colour,
                    "material": material,
                    "transparency": max(transparency, part["transparency"]),
                    "size": part["size"],
                    "cframe": cframe,
                }
            )
        missing = sorted({q["node"] for q in prims} - {r["name"] for r in rows})
        if missing:
            # a GLB re-exported with pieces the import predates: the pet
            # builds without them until the owner imports it again
            print(f"{key}: the import has no {', '.join(missing)}; re-import {rel} for them")
        path = OUT / f"{key}.luau"
        path.write_text(render(key, scene, mode, rows), encoding="utf-8", newline="\n")
        written.add(path.name)
        print(f"{key}: {len(rows)} parts from {scene}, {mode}, matched within {worst:.5f}")
    for old in OUT.glob("*.luau"):
        if old.name not in written:
            old.unlink()
            print(f"removed {old.name}")


if __name__ == "__main__":
    main()
