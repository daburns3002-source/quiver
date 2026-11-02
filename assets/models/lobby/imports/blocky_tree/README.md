# Blocky tree

The owner's Tripo tree (`blocky tree 3d model.zip`, 2026-11-01), converted to
one Roblox-importable file: **`blocky_tree.glb`**.

Import it in Studio with the 3D Importer, **Merge Meshes off** (it is a single
primitive either way), then put its id and texture id into whatever uses it.

## What the conversion changed

The handoff was an FBX with the texture loose in a `.fbm` folder beside it,
which Studio imports badly: the mesh arrives untextured and the image has to
be found and wired by hand. Three things were wrong for Roblox:

- **The texture was 8192x8192**, eight times Roblox's 1024 ceiling. Resized to
  1024 and packed into the GLB, so the file carries its own texture.
- **The height ran along Y with the model Z-up in Blender**, which exports to
  glTF lying on its side. Stood upright, so Y is up as Roblox expects.
- **It was one unit tall.** Scaled to 4.6, which sits with the game's other
  trees (`Lobby_LobbyTree.glb` is 4.98, `Thornwood_ThornTree.glb` is 3), and
  the feet put on the origin so it imports standing on the ground rather than
  half sunk.

## What it costs

2,469 triangles, one node, one primitive, one material, one texture -- so
**one MeshPart**. 135 KB. `python -I tools/glb_stats.py` on it to re-check.

It keeps its UVs (`TEXCOORD_0`), so unlike the untextured Tripo exports it can
be re-textured later if wanted.

The source FBX is not in the repo; it is the owner's download.
