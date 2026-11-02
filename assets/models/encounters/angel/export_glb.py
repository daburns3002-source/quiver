"""Export the Angel to `angel.glb`, one mesh a colour.

**Run this through the Blender MCP**, not from a shell: paste it into
`mcp__blender__execute_blender_code`. It needs the live Blender the server
is attached to, and `bpy` does not exist anywhere else.

It reads `assets/concepts/blocky/encounters/angel/built_parts.json`, a dump
of `Config/AngelDesign.parts`, builds those blocks in a collection of its
own, joins them by colour into AngelCream, AngelGold and AngelEye, and
writes `angel.glb` beside this file. Whatever else is open in Blender is
left alone: nothing outside the `AngelGLB` collection is touched.

Two things it would be easy to get wrong, both of which were got wrong
once:

  * **The axes.** The design is in Roblox's (Y up, -Z forward) and Blender
    is Z-up, and the glTF exporter turns Blender's (X, Y, Z) into
    (X, Z, -Y). Building at `(dx, -dz, dy)` with dimensions
    `(sx, sz, sy)` lands the export back on the design's own numbers.
  * **Joining.** `object.join()` keeps the active object's transform, so
    locations have to be applied into the mesh data *before* joining.
    Setting the joined object's location to the origin afterwards instead
    silently drags each colour to a different place, and nothing but a
    bounds check catches it -- dimensions look perfect either way.

The pool of light under the Angel is not exported. It is a Neon part
`Run/AngelProp` lays on the floor, not geometry.
"""
import json
import os

import bpy
from mathutils import Vector

PARTS = r"C:\Dev\ArcheroRoblox\assets\concepts\blocky\encounters\angel\built_parts.json"
OUT = r"C:\Dev\ArcheroRoblox\assets\models\encounters\angel\angel.glb"
COLLECTION = "AngelGLB"
LABEL = {
    (248, 243, 222): "AngelCream",
    (244, 181, 63): "AngelGold",
    (78, 58, 38): "AngelEye",
}


def linear(channel):
    """sRGB 0-255 to the linear value glTF and Blender both want."""
    c = channel / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def main():
    rows = json.load(open(PARTS, encoding="utf-8"))

    old = bpy.data.collections.get(COLLECTION)
    if old:
        for ob in list(old.objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.collections.remove(old)
    col = bpy.data.collections.new(COLLECTION)
    bpy.context.scene.collection.children.link(col)

    mats = {}

    def material(rgb):
        key = tuple(rgb)
        if key not in mats:
            m = bpy.data.materials.new(f"AngelMat_{key[0]}_{key[1]}_{key[2]}")
            m.use_nodes = True
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = (*[linear(v) for v in rgb], 1.0)
            bsdf.inputs["Roughness"].default_value = 0.65
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.2
            mats[key] = m
        return mats[key]

    by_colour = {}
    for row in rows:
        if row["grounded"]:
            continue
        dx, dy, dz = row["offset"]
        sx, sy, sz = row["size"]
        bpy.ops.mesh.primitive_cube_add(size=1.0)
        ob = bpy.context.active_object
        ob.name = row["name"]
        ob.location = (dx, -dz, dy)
        ob.scale = (sx, sz, sy)
        ob.data.materials.append(material(row["rgb"]))
        for c in list(bpy.context.scene.collection.children) + [bpy.context.scene.collection]:
            if ob.name in c.objects:
                c.objects.unlink(ob)
        col.objects.link(ob)
        by_colour.setdefault(tuple(row["rgb"]), []).append(ob)

    # into the mesh data, before any join
    everything = [ob for obs in by_colour.values() for ob in obs]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in everything:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = everything[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    joined = []
    for rgb, obs in by_colour.items():
        bpy.ops.object.select_all(action="DESELECT")
        for ob in obs:
            ob.select_set(True)
        bpy.context.view_layer.objects.active = obs[0]
        if len(obs) > 1:
            bpy.ops.object.join()
        out = bpy.context.view_layer.objects.active
        out.name = LABEL[rgb]
        joined.append(out)

    # the check that catches a bad join: these must match
    # `Config/AngelDesign.mesh`, which `tests/Angel.spec` ties to the blocks
    for ob in joined:
        pts = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        print(
            f"{ob.name}: "
            f"x[{min(p.x for p in pts):.3f},{max(p.x for p in pts):.3f}] "
            f"y[{min(p.y for p in pts):.3f},{max(p.y for p in pts):.3f}] "
            f"z[{min(p.z for p in pts):.3f},{max(p.z for p in pts):.3f}]"
        )

    bpy.ops.object.select_all(action="DESELECT")
    for ob in joined:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = joined[0]
    bpy.ops.export_scene.gltf(
        filepath=OUT,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("wrote", OUT, os.path.getsize(OUT), "bytes")


main()
