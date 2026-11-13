# Class armour remake: Claude Design prompts (2026-11-13)

The first models (PRs #563, #564, built from the block plans) were not
accepted. Owner, 2026-11-12: "the models for the classes need to be remade
for the class, i want a reference image for each class before they are made.
also the player model they are on shouldnt be all black, it should look like
a persoln". Shown two directions per class, the owner picked the first of
each, the sets made of the forest that go with the class weapons, and asked
for more: "do the first ones, there needs to be female versions too".

So there are six sets, a male and a female per class. Each has its Codex
reference sheet in `assets/concepts/blocky/players/armour/`:
`<class>_male_views.png` (the owner's pick) and `<class>_female_views.png`
(the same outfit on a woman, drawn from the pick; sent to the owner, not yet
answered). The older `<class>_views.png` and `<class>_plan.png` belong to
the first models.

One Design chat per set, the sheet attached. The model matches its sheet 1:1
from front, side and 3/4 before it is locked (the owner's rule). Download
as `assets/models/armour/<class>_<look>_set.glb`.

## What changes from the first build

- **The sheet leads, not the block plan.** `Config/ClassOutfits`' blocks were
  the plan for the first models; these sets are richer than boxes. After the
  cut, each piece's `size` and `at` come from the model, and the blocks are
  redrawn loosely to match (they are only the fallback).
- **The body looks like a person.** In Design the set is built on a blocky
  avatar with warm skin, a face and hair, as on the sheet. That body is cut
  away afterwards: in the game the set goes on the player's own avatar.
- **Hair is part of the head piece** (owner, 2026-11-13, asked whether the
  sheets' hair should be built: "Yes, build the hair"): the fringe, braid or
  curls on the sheet are built with the hood, hat or helm. The game still
  hides the player's own hair accessories under a set, so every player of a
  class and look wears the same hair.
- **Still true:** every piece is its own closed solid on one R15 body part
  (head, chest, back, waist, each upper arm, forearm, thigh, shin, foot);
  hands bare; face open; nothing hangs below the knee as one cloth; no
  clipping, no two faces in one plane. A quiver, a cape or a braid down the
  back rides the chest piece or its own back piece, never an arm.
- **Glows** (the Arcanist's crystals and runes, the potion) are named in the
  conversion notes so they can be worn as Neon blocks over the mesh, as
  `glows` already does for the first Arcanist.

## 1. Ranger, male -> `ranger_male_set.glb`
Attach: `ranger_male_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Ranger: the forest archer hero of the game, an outfit made of the forest, worn by a blocky Roblox avatar who looks like a person (warm skin, friendly face, brown fringe under the hood). Standing straight, feet together, arms hanging straight down.
A deep hood shaped like a big green leaf, stepped scales, a stem at its tip and a small twig antler with leaves on each side. A mantle of overlapping leaf scales over the shoulders and chest. Moss-green tunic laced with a vine cross, a ragged leaf skirt to mid-thigh. Vine belt with a gold ring buckle. Bark bracers, a wooden guard on one forearm. A brown quiver across the back, arrows with green leaf fletching. Brown trousers, tall bark boots with a leaf cuff below the knee.
Leaf green with lighter top edges, bark brown, small gold accents.
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## 2. Ranger, female -> `ranger_female_set.glb`
Attach: `ranger_female_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Ranger, female: the forest archer hero of the game, an outfit made of the forest, worn by a blocky Roblox avatar who looks like a woman (warm skin, friendly face with eyelashes, a long brown braid over one shoulder). Standing straight, feet together, arms hanging straight down.
A deep hood shaped like a big green leaf, stepped scales, a stem at its tip and a small twig antler with leaves on each side. A mantle of overlapping leaf scales over the shoulders. Moss-green tunic laced with a vine cross, a ragged leaf skirt to mid-thigh. Vine belt with a gold ring buckle. Bark bracers with gold bands. A brown quiver across the back, arrows with green leaf fletching. Brown trousers, tall bark boots with a leaf cuff below the knee.
Leaf green with lighter top edges, bark brown, small gold accents.
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot; the braid belongs to the head. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## 3. Arcanist, male -> `arcanist_male_set.glb`
Attach: `arcanist_male_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Arcanist: the wizard hero of the game, a forest sage, worn by a blocky Roblox avatar who looks like a person (warm skin, friendly face, brown hair under the hat). Standing straight, feet together, arms hanging straight down.
A tall crooked deep-blue wizard hat with a wide brim, its tip twisting like a branch with one green leaf, a brown band with a glowing cyan crystal. Deep blue robe with branch-brown trim and glowing cyan runes, a cyan gem on the chest. A brown wooden mantle on the shoulders with a cyan crystal growing out of each. Wooden belt with a small spellbook and a glowing potion. Wide sleeves with wood cuffs and a rune each. The robe's skirt is a separate stepped tier on each leg, to the knee. Blue boots with wood bands and a cyan rune.
Deep blue with lighter top edges, branch brown, cyan glow only on crystals, runes and the potion.
Each piece is its own closed solid on one body part: head, chest, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## 4. Arcanist, female -> `arcanist_female_set.glb`
Attach: `arcanist_female_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Arcanist, female: the wizard hero of the game, a forest sage, worn by a blocky Roblox avatar who looks like a woman (warm skin, friendly face with eyelashes, long curly brown hair down the back). Standing straight, feet together, arms hanging straight down.
A tall crooked deep-blue wizard hat with a wide brim, its tip twisting like a branch with one green leaf, a brown band with a glowing cyan crystal. Deep blue robe with branch-brown trim and glowing cyan runes, a cyan gem on the chest. A brown wooden mantle on the shoulders with a cyan crystal growing out of each. Wooden belt with a small spellbook and a glowing potion. Wide sleeves with wood cuffs and a rune each. The robe's skirt flares as a separate stepped tier on each leg, to the knee. Blue boots with wood bands and a cyan rune.
Deep blue with lighter top edges, branch brown, cyan glow only on crystals, runes and the potion.
Each piece is its own closed solid on one body part: head, chest, waist, each upper arm, forearm, thigh, shin and foot; the hair belongs to the head. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## 5. Warden, male -> `warden_male_set.glb`
Attach: `warden_male_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Warden: the melee guardian hero of the game, in heavy timber armour banded with iron, worn by a blocky Roblox avatar who looks like a person (warm skin, friendly face, brown hair under the helm). Standing straight, feet together, arms hanging straight down.
An iron-banded helm open at the face with a red gem on its brow and a tall crest of red leaves. Huge square shoulder guards made of log ends showing their growth rings. A breastplate of upright timber planks with dark iron bands and a gold shield emblem. A leather belt with an iron buckle. Plank vambraces and thigh guards with iron bands, plank greaves with an iron knee band and a gold band, heavy iron-toed boots. A short moss-green cape on the back, to the waist.
Warm timber orange-brown with lighter top edges, dark iron, red crest, small gold accents.
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## 6. Warden, female -> `warden_female_set.glb`
Attach: `warden_female_views.png`
```
Roblox avatar outfit in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Warden, female: the melee guardian hero of the game, in heavy timber armour banded with iron, worn by a blocky Roblox avatar who looks like a woman (warm skin, friendly face with eyelashes, two long brown braids over the shoulders). Standing straight, feet together, arms hanging straight down.
An iron-banded helm open at the face with a red gem on its brow and a tall crest of red leaves. Huge square shoulder guards made of log ends showing their growth rings. A breastplate of upright timber planks with dark iron bands and a gold shield emblem. A leather belt with an iron buckle. Plank vambraces and thigh guards with iron bands, plank greaves with an iron knee band and a gold band, heavy iron-toed boots. A short moss-green cape on the back, to the waist.
Warm timber orange-brown with lighter top edges, dark iron, red crest, small gold accents.
Each piece is its own closed solid on one body part: head, chest, back, waist, each upper arm, forearm, thigh, shin and foot; the braids belong to the head. No clipping: no part pokes through another, every piece sits flush on what it touches, no two faces share a plane. Low poly, under 10k triangles. Match the attached reference image.
Show front, side and 3/4 view on a plain background.
```

## Reviewing a result

As in `class-armour-2026-11.md`, plus:

- It reads as its class at a glance, also small and from behind and above:
  the leaf hood and quiver, the crooked hat and crystals, the log-end
  shoulders and red crest.
- The body is a person, not a black or grey figure, and the male and female
  of a class are clearly the same class.
- Arms hang straight down and the legs are two separate columns: the cut
  into pieces needs both.

## In the game, once the models are in

- A set per class and look: `SaveSchema.LOOKS` is already `{ "male",
  "female" }` and the profile saves a `look`; `ClassScreen` sends
  `LOOKS[1]` today and needs the choice on its cards. The server dresses by
  the saved look; the cards and the Gear portrait draw it.
- Wherever a set is drawn on a stand-in body rather than a player's avatar
  (a Studio look, a render for the owner), the body has skin, a face and
  clothes. Studio's default rig is all black.
