# Class armour sets: Claude Design prompts (2026-11-12)

Outfit C, the blocky armour set (owner, 2026-11-12: "for the class choosing
make it C"): a full chunky voxel set per class, worn over the player's own
avatar so only the face shows. Three sets, one Design chat each. The game
already wears them as plain blocks (`Config/ClassOutfits`); these prompts
make the real models.

For each chat attach the set's two pictures from
`assets/concepts/blocky/players/armour/`: `<class>_views.png` (Codex's
reference sheet, the look to match) and `<class>_plan.png` (the measured
block plan, the sizes to match). Check front, side and 3/4 before locking:
no clipping, no two faces in one plane, and the face open. Download the GLB
as the file name given, into `assets/models/armour/`.

## What a set is made of

Every piece is its own closed solid and sits on one body part of the
standard blocky R15 body. Nothing is cut out of a body: the class bodies
taken out on 2026-11-07 were whole bodies cut into parts, and every cut was
a hole. Hands stay bare (the weapon sits in them).

| Body part | Ranger | Arcanist | Warden |
|---|---|---|---|
| Head | Hood (leaf ears) | StarHat (brim, stepped cone, cowl) | Helm (horns, plume) |
| UpperTorso | Tunic, with the wooden guard and leaf pad | Robe, with the crystal shoulders | Breastplate, with the shoulder plates |
| UpperTorso, back | Cloak (three leaf tiers) | none | Cape (two tiers) |
| LowerTorso | Belt and skirt | Sash | Belt, fauld and tabard tail |
| Upper arms | Sleeve | Sleeve | Rerebrace |
| Forearms | Bracer | Cuff (bell sleeve) | Vambrace |
| Thighs | Trouser | Skirt (half each) | Cuisse |
| Shins | Boot | Hem (half each) | Greave |
| Feet | Sole | Shoe | Sabaton |

The shoulders sit on the chest piece, not the arm, so a raised arm turns
under them and never swings a plate into the head. Thigh and shin pieces
meet at the knee without overlapping, and each leg's pieces stop at the
body's middle so the two legs never share space.

## 1. Ranger -> `ranger_set.glb`
Attach: `ranger_views.png`, `ranger_plan.png`
```
Roblox avatar armour set in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Ranger armour: a forest archer's full set, the hero outfit of the game, worn by a plain grey blocky Roblox avatar (cube head, box torso, box arms and legs). Standing straight, feet together, arms hanging straight down.
Leaf hood open at the face, stepped crown, a pale leaf ear sticking out and up on each side. Green tunic with a pale V at the neck. A brown wooden shoulder guard on its right shoulder, a green leaf pad on its left. Dark green leaf cloak down the back in three tiers, each wider, to mid-thigh. Brown belt with a gold buckle. Green sleeves, chunky brown bracers, bare hands. Brown trousers, big dark-brown boots with a folded cuff.
Forest green (#2F9150) with pale green (#7FD672) top edges, wood brown (#8A5A2B), dark brown boots, gold buckle.
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference images.
Show front, side and 3/4 view on a plain background.
```

## 2. Arcanist -> `arcanist_set.glb`
Attach: `arcanist_views.png`, `arcanist_plan.png`
```
Roblox avatar armour set in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Arcanist armour: a wizard's full set, the hero outfit of the game, worn by a plain grey blocky Roblox avatar (cube head, box torso, box arms and legs). Standing straight, feet together, arms hanging straight down.
A giant star hat: a very wide flat dark-blue brim, a gold band, then a blue stepped cone of four shrinking tiers drooping back, a pale gold star on its front; a dark-blue cowl under it, open at the face. Blue robe with a gold stripe and a square gem down the chest. A dark-blue block on each shoulder with a glowing cyan crystal growing straight up out of it. Gold sash. Blue sleeves, wide bell cuffs with thick gold trim, bare hands. The robe's skirt widens in two stepped tiers to a thick gold hem above the ankle, split down the middle into a half for each leg; small navy shoes.
Bright blue (#3F7FEA) with pale blue (#93BCFF) top edges, deep blue (#2548A6), gold (#F3C847), cyan glow only on the crystals.
Each piece is its own closed solid on one body part: head, chest, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference images.
Show front, side and 3/4 view on a plain background.
```

## 3. Warden -> `warden_set.glb`
Attach: `warden_views.png`, `warden_plan.png`
```
Roblox avatar armour set in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Warden armour: a knight's full set, the hero outfit of the game, worn by a plain grey blocky Roblox avatar (cube head, box torso, box arms and legs). Standing straight, feet together, arms hanging straight down.
Horned helm open at the face: steel dome, dark brow band above the eyes, a cheek guard down each side, a stepped gold horn out and up on each side, a red plume crest along the top from front to back. Steel breastplate with a red tabard and a square gold crest. A huge steel plate on each shoulder, wider than the arm, with a stepped top and a gold stud. Red cape down the back in two tiers, the lower wider, to mid-thigh. Thick gold belt over a dark steel skirt of plates. Dark steel upper arms, pale vambraces with an elbow guard, bare hands. Steel thigh plates, dark greaves with a pale knee plate, dark boots with a pale toe cap.
Pale steel (#C9D0DC) with white top edges, dark steel (#808A9C), red (#E0453A), gold (#E8BA3F).
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference images.
Show front, side and 3/4 view on a plain background.
```

## Reviewing a result

Beyond the skill's usual checks (front, side, 3/4):

- The face window is clear: nothing in front of the eyes and mouth.
- The body is a plain blocky avatar, not a shaped figure: the pieces have to
  fit Roblox's blocky R15 body, so a waist, a neck or bent limbs are wrong.
- Arms hang straight down and the feet are together. A T-pose or A-pose
  cannot be measured against the plan.
- The cloak, cape and hat brim are thick slabs, not sheets.
- The legs are two separate columns up to the waist (the Arcanist's skirt
  included), so each half can move with its leg.

Fix-round opener: `Keep <the parts that work> exactly as they are. Fix:`,
2-5 fixes, ending `Blocky voxel style, stepped cubes, no round shapes.`

## Conversion notes (for the lock)

```
<class>_set.glb
Keep: the silhouette of the head piece, the shoulders and the back piece; the colours.
Fix: any piece that reaches into another is trimmed to its own body part; the grey body is removed.
Motion: none of its own. Each piece is cut out by the body part it sits on (the plan's boxes),
        saved as its own mesh named as in Config/ClassOutfits, and welded to that R15 part.
```

## Locked 2026-11-12

Built on Opus 5.5 with the 3D object template, one chat a set. Each version
was downloaded and run through `tools/class_armour/split_set.py`, and the
fix rounds were written from its numbers (how far each piece stands from its
plan box) and its picture under the sheet, not from Design's own preview.

| Set | Design project | Locked | Rounds, in order |
|---|---|---|---|
| Ranger | `claude.ai/design/p/c1f4b1dd-876f-40a6-b185-46b2a9865240` | v4 | hood bigger, cloak tiers widening, skirt under the belt, boots to the knee; face window full width, lower crown, bracers to the wrist; chunky two-block ears |
| Arcanist | `claude.ai/design/p/5726eb1d-744d-4fb4-bdb6-5dbe2a63150b` | v3 | skirt wider and deeper, cowl to the shoulders, star one square block; cone of four equal tiers leaning back only a little, crystals a third taller |
| Warden | `claude.ai/design/p/6aee234f-7ea2-4cf4-92af-94227a749eac` | v4 | chunky horns, thick plume, boxy shoulder plates, wider cape, short skirt with knee plates at mid-leg; brow band above the eyes, plates' bottom edge at the armpit, cape top below the shoulders; plates taller |

What a first prompt should say next time, to save a round: the head piece
overhangs the head by a quarter of its width; a cloak's or cape's lowest
tier is 1.3 to 1.4 times the torso's width; boots and greaves reach the
knee; a skirt's tiers are 1.35 and 1.5 times the torso's width; shoulder
plates are their own meshes; the grey body's meshes are named `avatar_*`.

Left as Design made them, against the sheets: the Ranger's collar is a
stepped V (the sheet draws a T); the Warden's shoulder plates stop under
the horns; the Warden's dark steel is the plan's #808A9C, lighter than the
sheet's charcoal.
