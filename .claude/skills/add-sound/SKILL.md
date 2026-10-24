---
name: add-sound
description: Make, audition and wire a new game sound — synthesised or cut from CC0 recordings, auditioned on the picks page, uploaded by the owner, ids into Config/Sounds.
---

# Add a sound

Follow `docs/PIPELINES.md` §7:

1. Takes from `assets/audio/synth.py` or `freesound.py` (CC0 only, licence checked per sound; never a game's ripped audio).
2. Audition page with `assets/audio/build_page.py`, published as an artifact; read the owner's picks with `ArtifactData`.
3. Owner uploads the picks; find the ids (`search_asset`, scope user) and set them in `Config/Sounds`.
4. Loop 0 and `tools/ship.sh`.
