"""Render every side of each Tripo export (front, back, left, right) with
Workbench and texture colour, into one contact sheet, to catch stray
texels before an import (memory: Tripo re-textures paint faces the
picture never shows).

    blender-launcher.exe -b --factory-startup --python render_sides.py -- <out.png> <glb>...
"""
import math
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1 :]
out, files = args[0], args[1:]
SIZE = 220
tiles = []

scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "FLAT"
scene.display.shading.color_type = "TEXTURE"
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w") if scene.world is None else scene.world
scene.world.color = (0.75, 0.75, 0.75)

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

for path in files:
    for obj in list(bpy.data.objects):
        if obj.name != "cam":
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = Vector((1e9, 1e9, 1e9))
    hi = -lo
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    centre = (lo + hi) / 2
    span = max(hi - lo)
    cam_data.ortho_scale = span * 1.15
    for i, angle in enumerate((0, 180, 90, 270)):
        a = math.radians(angle)
        cam.location = centre + Vector((math.sin(a), -math.cos(a), 0)) * span * 3
        direction = centre - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        tile = f"{out}.{len(tiles)}.png"
        scene.render.filepath = tile
        bpy.ops.render.render(write_still=True)
        tiles.append(tile)

# a sheet: one row per file, four views across
rows = len(files)
sheet = bpy.data.images.new("sheet", SIZE * 4, SIZE * rows)
pixels = [0.0] * (SIZE * 4 * SIZE * rows * 4)
for index, tile in enumerate(tiles):
    img = bpy.data.images.load(tile)
    src = list(img.pixels)
    row, col = index // 4, index % 4
    for y in range(SIZE):
        dst_y = (rows - 1 - row) * SIZE + y
        start = (dst_y * SIZE * 4 + col * SIZE) * 4
        pixels[start : start + SIZE * 4] = src[y * SIZE * 4 : (y + 1) * SIZE * 4]
sheet.pixels = pixels
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
open(out + ".done", "w").write(str(len(tiles)))
