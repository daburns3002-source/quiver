"""Slim a Claude Design weapon to a Roblox budget, as optimise_enemy.py does
for enemies.

    uv run --with trimesh --with numpy --with pymeshlab --with scipy \
        --with pillow python -I optimise_weapon.py <in> <out> <weapon>

Vertex colours are kept (COLOR_0, linear to sRGB) or textures sampled onto
vertices. Each part is decimated to its budget, then parts are merged into
a few named groups so the game can treat them apart (the gem glows; the
arrow is drawn on its own). Centred on its bounds; not turned, since how a
weapon is held is the game's to decide.
"""
import json
import sys

import numpy as np
import pymeshlab
import trimesh

SRC, OUT, WEAPON = sys.argv[1], sys.argv[2], sys.argv[3]

WEAPONS = {
    # The Ranger's bow (owner's Claude Design model, 67.5k triangles).
    # group: { part: triangle budget }
    "leaf_bow": {
        "Bow": {"Limb_Upper": 700, "Limb_Lower": 700, "Riser": 800, "Grip": 700},
        "Trim": {"Gold_Trim": 900, "Gold_Trim_Upper": 260, "Gold_Trim_Lower": 260},
        "Leaves": {"Leaf_Upper": 600, "Leaf_Lower": 600, "Leaf_Wrap_Upper": 260, "Leaf_Wrap_Lower": 260},
        "Gem": {"Gem": 200},
        "String": {"String_Upper": 24, "String_Lower": 24},
        "Arrow": {"Shaft": 112, "Arrowhead": 8, "Fletching": 300, "Nock": 136, "Arrow_Wraps": 160},
    },
    # The Arcanist's staff (owner's Claude Design model, 86.8k triangles).
    # The orb and gems glow; the ring of orbiting orbs is one mesh, so the
    # game can spin it round the head.
    "arcane_staff": {
        "Staff": {"Shaft": 900, "Spiral": 700, "Head_Cup": 1200},
        "Trim": {"Silver_Trim": 1600},
        "Gems": {"Gems": 600},
        "Orb": {"Orb": 700},
        "Orbits": {"Orbit_Ring": 500, "Orbit_Orb_1": 250, "Orbit_Orb_2": 250, "Orbit_Orb_3": 250},
    },
}

#: The blocky skins (docs/PETS-FOREST.md), Claude Design models of a few
#: hundred to a few thousand triangles whose colours are flat materials.
#: Nothing is decimated: parts are grouped by the start of their node name
#: (trimesh adds a suffix per material, and a group claims what an earlier
#: one left), and `turn` (degrees about Y) puts the model in the game's
#: weapon frame as Studio imports it: long axis up, a bow's string behind
#: (−Z) and its arrow pointing +Z.
BLOCKY = {
    "twig_bow": {
        "turn": 90,
        "groups": {
            "Bow": ["limbs", "grip_", "band_", "nock_knot_", "string_wrap_"],
            "Leaves": ["leaf_"],
            "String": ["string"],
        },
    },
    "branch_staff": {
        "turn": 0,
        "groups": {
            "Staff": ["spike", "collar_", "shaft", "arm_"],
            "Leaves": ["leaf_"],
            "Gems": ["gem_plate_"],
            "Stone": ["stone_cube"],
        },
    },
    "timber_blade": {
        "turn": 0,
        "groups": {
            "Gems": ["guard_gem_front", "guard_gem_back", "pommel_gem_"],
            "Blade": ["blade_"],
            "Guard": ["guard_", "collar_upper"],
            "Grip": ["grip_", "band_pommel", "pommel"],
        },
    },
}

#: The Mossy Glade skins from 2026-10-24 (docs/weapons/*.md). These are
#: matched by keyword (`~`, see `claims`), each ending in a catch-all `""`
#: so no part is dropped, since a skin can run to two hundred cubes.
#:
#: Every one is turn 0, measured rather than copied from its family: the
#: bows were exported already in the weapon frame (thin across X, string at
#: -Z), where the Twig Bow only gets after its 90; and every arrow and bolt
#: rests head at -Z, as the arrows already in the game do (the renderer
#: aims a projectile with CFrame.lookAt, which points -Z forward).
#:
#: Glow words name what should be lit. "core" and "light" are left out on
#: purpose: they catch a blade's `blade_core` and every `Highlight` cube.
GLOWS = ["~crystal", "~gem", "~lantern", "~firefly", "~rune", "~mote", "~rainbow", "~ember", "~eye"]
LEAVES = ["~leaf", "~leaves", "~vine", "~moss", "~fern", "~blossom"]


def bow():
    return {"turn": 0, "groups": {"Gems": GLOWS, "String": ["~string"], "Leaves": LEAVES, "Bow": [""]}}


def staff():
    return {"turn": 0, "groups": {"Gems": GLOWS, "Leaves": LEAVES, "Staff": [""]}}


def blade():
    return {"turn": 0, "groups": {"Gems": GLOWS, "Blade": [""]}}


def daggers():
    return {"turn": 0, "groups": {"Gems": GLOWS, "Leaves": LEAVES, "Daggers": [""]}}


def projectile(group):
    return {"turn": 0, "groups": {"Gems": GLOWS, group: [""]}}


BLOCKY.update({
    "ember_fang_bow": bow(),
    "firefly_bow": bow(),
    "glade_spirit_bow": bow(),
    "moss_slime_bow": bow(),
    "ember_fang_arrow": projectile("Arrow"),
    "firefly_dart": projectile("Arrow"),
    "glade_spirit_arrow": projectile("Arrow"),
    "moss_slime_arrow": projectile("Arrow"),
    "hootmoss_staff": staff(),
    "lantern_staff": staff(),
    "slime_crown_staff": staff(),
    "hootmoss_staff_bolt": projectile("Bolt"),
    "lantern_staff_bolt": projectile("Bolt"),
    "slime_crown_staff_bolt": projectile("Bolt"),
    # The Mythic staff's glow is one fluorescent hue the game shifts over
    # time (owner, 2026-10-24: "no actual rainbows ... just a fluorescent
    # hue"). Its 17 Glow_ parts stay a group of their own so the code can
    # find them; docs/weapons/worldroot-rainbow.md lists them.
    "worldroot_staff": {"turn": 0, "groups": {"Glow": ["Glow"], "Leaves": LEAVES, "Staff": [""]}},
    "worldroot_staff_bolt": {"turn": 0, "groups": {"Glow": ["Glow"], "Bolt": [""]}},
    "broodsplit_blade": blade(),
    "mossstone_blade": blade(),
    "thorn_blade": blade(),
    "emberfang_blade": blade(),
    "gladeheart_blade": blade(),
    "ember_wilf_fangs": daggers(),
    "firefly_fangs": daggers(),
    "glade_fox_claws": daggers(),
    "glimmerhorn_daggers": daggers(),
    "splinter_daggers": daggers(),
})

scene = trimesh.load(SRC, process=False)


def linear_to_srgb(lin):
    lin = np.clip(np.asarray(lin, dtype=np.float64), 0, 1)
    return np.where(lin <= 0.0031308, lin * 12.92, 1.055 * np.power(lin, 1 / 2.4) - 0.055)


def world(node):
    T, gname = scene.graph[node]
    src = scene.geometry[gname]
    colour = getattr(src.visual, "vertex_attributes", {}).get("color")
    material = getattr(src.visual, "material", None)
    if colour is not None:
        srgb = linear_to_srgb(np.asarray(colour, dtype=np.float64)[:, :3])
    elif (
        material is not None
        and getattr(material, "baseColorTexture", None) is None
        and getattr(material, "baseColorFactor", None) is None
    ):
        # a material with no colour in it at all (the Slime Crown Staff's).
        # glTF says a missing base colour is white, and trimesh's own
        # fallback fails on it, so it is set here
        srgb = np.ones((len(src.vertices), 3))
    elif material is not None and getattr(material, "baseColorTexture", None) is None and hasattr(
        material, "baseColorFactor"
    ):
        # a flat material: its factor is linear, 0-255 as trimesh holds it
        base = np.asarray(material.baseColorFactor, dtype=np.float64)[:3] / 255.0
        srgb = np.tile(linear_to_srgb(base), (len(src.vertices), 1))
    else:
        srgb = np.asarray(src.visual.to_color().vertex_colors, dtype=np.float64)[:, :3] / 255.0
    g = trimesh.Trimesh(vertices=trimesh.transform_points(src.vertices, T), faces=src.faces, process=False)
    return g, srgb


def decimate(g, srgb, target):
    ms = pymeshlab.MeshSet()
    ms.add_mesh(pymeshlab.Mesh(vertex_matrix=g.vertices, face_matrix=g.faces,
                               v_color_matrix=np.hstack([srgb, np.ones((len(srgb), 1))])))
    ms.meshing_merge_close_vertices(threshold=pymeshlab.PercentageValue(0.01))
    if len(g.faces) > target:
        ms.meshing_decimation_quadric_edge_collapse(targetfacenum=int(target), preservenormal=True,
                                                    preservetopology=False, preserveboundary=True,
                                                    qualitythr=0.4)
    m = ms.current_mesh()
    out = trimesh.Trimesh(vertices=m.vertex_matrix(), faces=m.face_matrix(), process=False)
    out.visual = trimesh.visual.ColorVisuals(
        out, vertex_colors=(np.clip(m.vertex_color_matrix(), 0, 1) * 255).astype(np.uint8))
    return out


parts = {n: world(n) for n in scene.graph.nodes_geometry}
groups = {}
claimed = set()


def coloured(g, srgb):
    out = g.copy()
    out.visual = trimesh.visual.ColorVisuals(out, vertex_colors=(np.clip(srgb, 0, 1) * 255).astype(np.uint8))
    return out


def claims(name, prefix):
    """Whether a group's entry claims a part. A plain entry matches the start
    of the node name. One starting with `~` matches anywhere in it, ignoring
    case, so a skin of two hundred cubes can say "everything with crystal in
    its name glows" instead of listing them. An empty entry matches
    everything, and goes last as the catch-all."""
    if prefix.startswith("~"):
        return prefix[1:].lower() in name.lower()
    return name.startswith(prefix)


def emissive_by_node():
    """Each mesh node's glow as its design drew it: the strongest emissive
    (factor times KHR_materials_emissive_strength) among its materials. Read
    from the GLB itself, because trimesh drops the strength extension."""
    with open(SRC, "rb") as f:
        data = f.read()
    length = int.from_bytes(data[12:16], "little")
    gltf = json.loads(data[20 : 20 + length])
    materials = gltf.get("materials", [])

    def glow(index):
        m = materials[index]
        strength = m.get("extensions", {}).get("KHR_materials_emissive_strength", {}).get("emissiveStrength", 1)
        return max(m.get("emissiveFactor", [0, 0, 0])) * strength

    out = {}
    for node in gltf.get("nodes", []):
        if "mesh" in node:
            prims = gltf["meshes"][node["mesh"]]["primitives"]
            out[node.get("name", "")] = max((glow(p["material"]) for p in prims if "material" in p), default=0)
    return out


#: A part glows in the game (its weapon's glow group is drawn Neon) when its
#: name says so (GLOWS) or when its material does: the design's glow at or
#: above this. Names alone missed glowing parts named for what they are, not
#: that they glow (the Broodsplit Blade's slime core, the Thorn Blade's
#: mushrooms, the Firefly Fangs' lantern windows; owner, 2026-10-24: "make
#: sure in game that the weapons that will have a glow, have their glows").
GLOW_EMISSIVE = 0.45
#: Never glow by name alone: the setting a gem sits in and a lantern's
#: frame, not the gem or the light (a part whose material glows still does).
NOT_GLOW = ("housing", "socket", "caps", "frame")
EMISSIVE = emissive_by_node()


def glows(name):
    # a bow's string stays its own group, which the bow-string animation needs
    return EMISSIVE.get(name, 0) >= GLOW_EMISSIVE and "string" not in name.lower()


if WEAPON in BLOCKY:
    spec = BLOCKY[WEAPON]
    for group, prefixes in spec["groups"].items():
        pieces = []
        glow_group = prefixes is GLOWS
        for name, (g, srgb) in parts.items():
            if name in claimed:
                continue
            named = any(claims(name, p) for p in prefixes)
            if glow_group:
                named = (named and not any(w in name.lower() for w in NOT_GLOW)) or glows(name)
            if named:
                pieces.append(coloured(g, srgb))
                claimed.add(name)
        if not pieces:
            # a keyword group this skin has nothing for (a bow with no gems)
            print(f"{group:8s}   - none")
            continue
        groups[group] = trimesh.util.concatenate(pieces)
        print(f"{group:8s} {len(pieces):3d} pieces {len(groups[group].faces):5d} tris")
    turn = trimesh.transformations.rotation_matrix(np.radians(spec["turn"]), [0, 1, 0])
    for mesh in groups.values():
        mesh.apply_transform(turn)
for group, members in ({} if WEAPON in BLOCKY else WEAPONS[WEAPON]).items():
    pieces = []
    for name, budget in members.items():
        g, srgb = parts[name]
        slim = decimate(g, srgb, budget)
        print(f"{group:8s} {name:18s} {len(g.faces):6d} -> {len(slim.faces):5d}")
        pieces.append(slim)
        claimed.add(name)
    groups[group] = trimesh.util.concatenate(pieces)
for name in parts:
    if name not in claimed:
        print("dropped", name)

lo, hi = trimesh.util.concatenate(list(groups.values())).bounds
centre = (lo + hi) / 2
out = trimesh.Scene()
for name, mesh in groups.items():
    mesh.apply_translation(-centre)
    out.add_geometry(mesh, node_name=name, geom_name=name)
out.export(OUT)
print("total tris", sum(len(m.faces) for m in groups.values()), {k: len(v.faces) for k, v in groups.items()})
