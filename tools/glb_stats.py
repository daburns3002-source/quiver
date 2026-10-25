"""What a GLB costs the game: triangles, mesh nodes, primitives (each one a
MeshPart once imported with Merge Meshes off), materials, textured materials,
animated joints, clips, and how many MeshParts would remain if every
primitive riding the same animated joint with the same kind of material
(plain, glowing, see-through) were merged into one.

    python -I tools/glb_stats.py <file.glb>...

Reads the GLB's JSON only; nothing is changed. docs/PERFORMANCE.md has the
numbers for every model in the game.
"""
import json
import struct
import sys
import pathlib


def read_glb(path):
    data = path.read_bytes()
    off = 12
    js = None
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        chunk = data[off + 8 : off + 8 + length]
        if kind == 0x4E4F534A:
            js = json.loads(chunk)
        off += 8 + length
    return js


def mat_class(gltf, mi):
    if mi is None:
        return "opaque"
    m = gltf.get("materials", [])[mi]
    pbr = m.get("pbrMetallicRoughness", {})
    base = pbr.get("baseColorFactor", [1, 1, 1, 1])
    em = m.get("emissiveFactor", [0, 0, 0])
    strength = m.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
    if max(em) * strength >= 0.6:
        return "glow"
    if base[3] < 0.99 or m.get("alphaMode") == "BLEND":
        return f"alpha{round(base[3], 2)}"
    return "opaque"


def stats(path):
    g = read_glb(path)
    nodes = g.get("nodes", [])
    parent = {}
    for i, n in enumerate(nodes):
        for c in n.get("children", []):
            parent[c] = i
    animated = set()
    for a in g.get("animations", []):
        for ch in a["channels"]:
            if "node" in ch["target"]:
                animated.add(ch["target"]["node"])
    acc = g.get("accessors", [])
    tris = 0
    prims = 0
    mesh_nodes = 0
    groups = set()
    groups_static = set()
    tex = 0
    for i, n in enumerate(nodes):
        if "mesh" not in n:
            continue
        mesh_nodes += 1
        anchor = None
        j = i
        while j is not None:
            if j in animated:
                anchor = j
                break
            j = parent.get(j)
        for p in g["meshes"][n["mesh"]]["primitives"]:
            prims += 1
            if "indices" in p:
                tris += acc[p["indices"]]["count"] // 3
            else:
                tris += acc[p["attributes"]["POSITION"]]["count"] // 3
            mc = mat_class(g, p.get("material"))
            groups.add((anchor, mc))
            groups_static.add(mc)
    for m in g.get("materials", []):
        if "baseColorTexture" in m.get("pbrMetallicRoughness", {}):
            tex += 1
    return {
        "tris": tris,
        "meshNodes": mesh_nodes,
        "prims": prims,
        "materials": len(g.get("materials", [])),
        "textured": tex,
        "animatedNodes": len(animated),
        "clips": len(g.get("animations", [])),
        "mergedParts": len(groups),
    }


if __name__ == "__main__":
    print(f"{'file':70} {'tris':>7} {'nodes':>5} {'prims':>5} {'mats':>4} {'tex':>3} {'anim':>4} {'clips':>5} {'merged':>6}")
    for arg in sys.argv[1:]:
        p = pathlib.Path(arg)
        try:
            s = stats(p)
        except Exception as e:  # noqa: BLE001
            print(f"{arg:70} ERROR {e}")
            continue
        print(
            f"{arg:70} {s['tris']:7d} {s['meshNodes']:5d} {s['prims']:5d} {s['materials']:4d} {s['textured']:3d} {s['animatedNodes']:4d} {s['clips']:5d} {s['mergedParts']:6d}"
        )
