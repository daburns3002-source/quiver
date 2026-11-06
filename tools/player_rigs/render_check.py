"""Front and side renders of the split rigs, each piece its own colour.

    blender -b --factory-startup --python tools/player_rigs/render_check.py -- <rig_dir> <out_dir> [textured]
"""
import bpy, colorsys, math, os, sys
a = sys.argv[sys.argv.index("--") + 1:]
rig_dir, out_dir = a[0], a[1]
textured = len(a) > 2
NAMES = ["ranger_male", "ranger_female", "arcanist_male", "arcanist_female",
         "warden_male", "warden_female", "assassin_male", "assassin_female"]
bpy.ops.wm.read_factory_settings(use_empty=True)
ORDER = ["Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand",
         "RightUpperArm", "RightLowerArm", "RightHand", "LeftUpperLeg", "LeftLowerLeg",
         "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Hood", "Hat", "Cape"]
roots = []
for i, n in enumerate(NAMES):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(rig_dir, n + "_r15.glb"))
    new = set(bpy.data.objects) - before
    for o in new:
        if o.parent is None:
            o.location.x += i * 0.8
            roots.append(o)
        if o.type == "MESH":
            k = ORDER.index(o.name.split(".")[0]) if o.name.split(".")[0] in ORDER else 0
            o.color = (*colorsys.hsv_to_rgb((k * 0.381) % 1, 0.75 if k % 2 else 1, 1 if k % 3 else 0.6), 1)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"
sh.color_type = "TEXTURE" if textured else "OBJECT"
sc.render.resolution_x, sc.render.resolution_y = 2560, 420
cam = bpy.data.cameras.new("c"); cam.type = "ORTHO"; cam.ortho_scale = 6.4
co = bpy.data.objects.new("c", cam); sc.collection.objects.link(co); sc.camera = co
# the rigs face -Y after the glTF round trip? they were turned to face +Y (Roblox -Z)
co.location = (2.8, 5, 0.49); co.rotation_euler = (math.pi / 2, 0, math.pi)
sc.render.filepath = out_dir + "/check_front.png"; bpy.ops.render.render(write_still=True)
for r in roots:
    i = round(r.location.x / 0.8); r.location.x = 0; r.location.y = -i * 0.8
co.location = (20, -2.8, 0.49); co.rotation_euler = (math.pi / 2, 0, math.pi / 2)
sc.render.filepath = out_dir + "/check_side.png"; bpy.ops.render.render(write_still=True)
