"""Blocky model helper for Blender (run inside Blender, through the Blender MCP).

A model is a set of named parts; each part is a list of coloured boxes and
becomes one object, coloured with a BYTE_COLOR corner attribute (the Roblox
importer drops materials, so colour lives in the vertex colours). Weapons sit
in the weapon frame: blade up (+Z in Blender, +Y in the GLB), origin at the
grip, front face towards -Y.

    exec(open(r"...\\blocky.py").read())
    b = Builder("MossstoneBlade")
    b.box("Blade", (0, 0, 0.7), (0.2, 0.07, 0.7), "#C2BFBA")
    b.build()
    b.export(r"...\\mossstone_blade.glb")
"""

import bmesh
import bpy
from mathutils import Vector


def srgb(hex_colour):
    """A #RRGGBB colour as linear RGB, which is what colour attributes hold."""
    h = hex_colour.lstrip("#")
    c = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


class Builder:
    def __init__(self, name):
        self.name = name
        self.parts = {}

    def box(self, part, centre, size, colour):
        self.parts.setdefault(part, []).append((Vector(centre), Vector(size), colour))

    def build(self):
        old = bpy.data.collections.get(self.name)
        if old:
            for o in list(old.objects):
                mesh = o.data
                bpy.data.objects.remove(o)
                bpy.data.meshes.remove(mesh)
            bpy.data.collections.remove(old)
        col = bpy.data.collections.new(self.name)
        bpy.context.scene.collection.children.link(col)
        for part, boxes in self.parts.items():
            bm = bmesh.new()
            for centre, size, _ in boxes:
                verts = bmesh.ops.create_cube(bm, size=1.0)["verts"]
                for v in verts:
                    v.co = Vector((v.co.x * size.x, v.co.y * size.y, v.co.z * size.z)) + centre
            mesh = bpy.data.meshes.new(f"{self.name}_{part}")
            bm.to_mesh(mesh)
            bm.free()
            attr = mesh.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
            # create_cube adds six faces per box, in box order
            for index, (_, _, colour) in enumerate(boxes):
                linear = (*srgb(colour), 1.0)
                for poly in mesh.polygons[index * 6 : index * 6 + 6]:
                    for loop in poly.loop_indices:
                        attr.data[loop].color = linear
            obj = bpy.data.objects.new(part, mesh)
            col.objects.link(obj)
        self.collection = col
        return col

    def triangles(self):
        return sum(len(o.data.polygons) * 2 for o in self.collection.objects)

    def export(self, path):
        """Writes the model as a GLB at the origin, its objects named after
        their parts (another model's parts would have given them a .001)."""
        mine = list(self.collection.objects)
        others = [o for o in bpy.data.objects if o not in mine]
        saved = {o: o.name for o in others}
        for o in others:
            o.name = "~" + o.name
        moved = {o: o.location.copy() for o in mine}
        for o in mine:
            o.name = o.data.name.split("_", 1)[1]
            o.location = (0, 0, 0)
        bpy.ops.object.select_all(action="DESELECT")
        for o in mine:
            o.hide_set(False)
            o.select_set(True)
        try:
            bpy.ops.export_scene.gltf(
                filepath=path,
                use_selection=True,
                export_format="GLB",
                export_vertex_color="ACTIVE",
                export_materials="NONE",
            )
        finally:
            for o, loc in moved.items():
                o.location = loc
            for o, name in saved.items():
                o.name = name
