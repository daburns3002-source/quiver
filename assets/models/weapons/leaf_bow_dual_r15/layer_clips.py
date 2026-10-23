"""Finish the Dual Bows kit's keyframes for Fx/WeaponPose, which plays one
clip at a time where the kit layers them.

    python -I layer_clips.py

Run after kit_to_json.py has turned LeafBow_Dual_R15_Kit.rbxmx (prefix
DualBow_) into leaf_bow_dual_animations.json:

- Fire_R and Fire_L each drive one arm, over the Aim (Action3 over
  Action2 in the kit). Every joint they leave out is filled with the Aim's
  first key, so the other bow stays up while one fires.
- The kit has no legs of its own: the single bow's Idle and Walk are copied
  in, so the dual bows walk as the single one does.
"""
import json
import pathlib

HERE = pathlib.Path(__file__).parent
DUAL = HERE / "leaf_bow_dual_animations.json"
SINGLE = HERE.parent / "leaf_bow_r15" / "leaf_bow_animations.json"

clips = json.loads(DUAL.read_text(encoding="utf-8"))
single = json.loads(SINGLE.read_text(encoding="utf-8"))
aim = clips["Aim"]["keys"][0]

for name in ("Fire_R", "Fire_L"):
    clip = clips[name]
    for key in clip["keys"]:
        for joint, rot in aim["rot"].items():
            key["rot"].setdefault(joint, rot)
        if key.get("rootOffset") is None:
            key["rootOffset"] = aim.get("rootOffset")
    clip["joints"] = sorted(set(clip["joints"]) | set(aim["rot"]))

for name in ("Idle", "Walk"):
    clips[name] = single[name]

DUAL.write_text(json.dumps(clips, indent=1) + "\n", encoding="utf-8", newline="\n")
print({k: len(v["joints"]) for k, v in clips.items()})
