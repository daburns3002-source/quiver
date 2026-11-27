---
name: "voxel-pet-design-prompts"
description: "Prompt maker for blocky voxel game creatures in Claude Design: writes first prompts, reviews screenshots, writes fix rounds, plans rosters, and locks designs with conversion notes."
---

# Voxel creature prompt maker (Claude Design)

Use this whenever someone wants a pet, creature, mount, boss or living object designed in Claude Design in a blocky voxel style (Roblox, Minecraft-like or any cube-built game), wants a design screenshot reviewed, wants a fix round, or is planning which creatures to make.

It has five modes. Work out which one the user needs from their message:
1. **New prompt**: a creature name or idea comes in, a ready-to-paste prompt goes out.
2. **Review**: a screenshot comes in, a short verdict plus a fix reply (or "lock it") goes out.
3. **Fix round**: the user says what's wrong, a precise fix reply goes out.
4. **Roster planning**: a world, tier or list comes in, a balanced creature list goes out.
5. **Lock and hand off**: the design is good enough, the download and conversion notes go out.

Don't ask questions you can answer with a sensible default. Only ask when the creature itself is unclear.

---

## 1. Hard rules for every prompt
- **One creature per prompt.** Never two in one message.
- **Short but complete:** about 80-140 words. Claude Design renders better on less text, but every specific detail the user gave must stay in.
- **Style line first, word for word:**
  `Roblox pet in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.`
  Swap only "Roblox pet" if the user's platform or object type is different. Never drop this line: without it Claude Design makes smooth, round models.
- **Views line last:** `Show front, side and 3/4 view on a plain background.`
- **Fix replies end with:** `Blocky voxel style, stepped cubes, no round shapes.`
- **Leave out surface details the game build adds later** (studs, material textures) unless the user asks for them.
- **Each prompt in its own code block**, nothing else inside it.

## 2. First prompt template (fill in this order)
```
<style line>

<Name>: <what it is> + <its role> ("the rarest creature of a heavenly world", "a small but impressive starter pet").
<Pose and attitude>.
<Anatomy, literal>.
<Colours and material: main tone, lighter edges, one glow colour>.
<Head and face>.
<Signature features with size and placement>.
<At most 2-3 small effects>.
Show front, side and 3/4 view on a plain background.
```
Rules for the parts:
- **Role** sets the quality bar: "the rarest", "the final boss", "the most menacing" make Claude Design try harder.
- **Pose:** pick one clear pose: standing proud with chest out and head high, crouched ready to pounce, rearing, sitting upright, floating, swimming level, coiled with head raised. Say menacing / majestic / cute / mischievous only where it fits the creature.
- **Anatomy** is where most designs fail. Describe shape literally (see the body-plan phrases below) and add "not a box body".
- **Signature features** need size words: "huge wings, the widest part of the silhouette", "a small floating crown", "tusks curving up close to the head".
- **Effects:** sparks, wisps, orbiting rocks, a halo. More than three turns into noise.

## 3. Body-plan phrases that work
Copy these into the anatomy part and adapt.
- **Four-legged beast (wolf, bear, big cat):** "deep broad chest narrowing to a slimmer waist, strong haunches over the back legs, thick legs with visible shoulders and thighs, a dog's zigzag hind leg (thigh back, hock bending forward, paw under the hip)".
- **Horse, unicorn, deer:** "real horse anatomy: deep chest, arched neck that tapers into a refined head with cheek, jaw, ears and a tapered muzzle, legs with clear forearm, knee, cannon and hoof, slim but not sticks".
- **Heavy titan (golem, mammoth, rhino):** "massive and heavy like a living mountain, huge shoulders wider than the hips, thick pillar legs, head set low and forward". For a golem: "very long thick arms, fists resting on the ground like a gorilla".
- **Bird (eagle, phoenix, roc):** "standing tall on strong legs with big talons, puffed chest, a slim head with a sharp hooked beak pointing forward, wings with layered feathers: short coverts near the arm, long flight feathers at the tips".
- **Four-legged dragon:** "deep armoured chest, narrower waist, strong haunches, thick legs with real joint bends, long S-curved neck raised high, head looking down like a king, huge bat wings raised and spread, the widest part of the silhouette".
- **Wyvern / drake:** stands on two hind legs, wings raised. Grounded-wing walking poses fail in Claude Design: put them in the conversion notes instead.
- **Serpent / sea serpent:** "thick heavy body, about twice as wide as you'd think, rising in an S-curve with the head high, the rest in coils resting on the ground behind it, overlapping armour plates, not stacked slices".
- **Multi-headed (hydra, cerberus, chimera):** "each head on its own neck, the necks fanned out from the shoulders angled up and forward, the middle head tallest". Each extra head must be as big as a real head, not an add-on.
- **Griffin / hybrids:** describe the base animal first: "a big white lion standing on all four legs, body horizontal like a cat. Its head is an eagle head...". Starting from the bird gives an upright bird.
- **Robed or floating humanoid (reaper, djinn, angel-knight):** "broad sloped shoulders with a short ragged cape, two long separate sleeves with the hands coming out of them, every hand connected through a wrist into its sleeve, the robe flaring toward the bottom with deep folds". Floating: "floats above the ground, the lower body fading into smoke / cloud / light".
- **Swimming creature (shark, whale, manta):** "long streamlined body tapering to a strong tail, real fins shaped like the animal's". For flat creatures (manta, ray): "a raised central body that tapers smoothly into the wings, not a dome and not paper thin".
- **Shell carrier (turtle with something on its back):** "a big high stepped dome shell that wraps down into the body with a thin rim band, legs, neck and tail coming out of openings in the shell, the thing on its back growing out of the shell".
- **Insect / spider / scarab:** "chunky body on sturdy bent legs with clear joints, body lifted off the ground, head clearly visible from the front".
- **Living object (eye in a rift, wheel of eyes, ring serpent):** describe it as a 3D object with depth: "a 3D jagged tear with real thickness going back into a void, not a flat sheet", "tentacles spread in 3D: some forward, some to the sides, some curling back".
- **Small cute pet:** "a big head on a smaller chubby body", one clear accessory, one clear colour accent.

## 4. Colour and contrast
- **Three tones plus one glow:** a main body tone, a darker shade for depth, lighter top edges for highlights, then one glow colour for eyes, cracks, crystals or cores.
- **The body is darker than the glow.** A glow on a light body disappears. Say "near-black body" or "deep indigo body" when you want glowing details to pop.
- **Highlights go on top edges only:** "purple-grey only on the top edge of each plate, not around it". Otherwise you get framed panels like a circuit board.
- **Cracks and veins:** "jagged, uneven, branching cracks", never "lines" (that gives neat letter shapes like T and L).
- **White creatures:** add shading colours ("pearl white with lilac and ice-blue shading under the belly and neck") or they turn into flat white blocks.
- **One palette per world.** Every creature in a world shares it, so they look like they belong together. Examples: volcano (black basalt, lava orange), crystal cave (deep blue, purple, dark stone, cyan/violet/pink crystals), graveyard (dark slate, near-black, bone white, ghost green), space (deep indigo, nebula magenta, cosmic orange, star white), heaven (white marble, gold, sky blue), void (near-black, deep violet, white-hot accents).
- Keep each creature distinct inside the palette with its own accent (a gold horn, a blue mane, a green core).

## 5. Roster planning
When the user plans a set of creatures (a world, an egg, a tier):
- **Mix silhouettes:** per world aim for one heavy walker, one sleek walker, one flyer or floater, one swimmer or serpent, one odd shape. Never two creatures that read alike (two anglerfish, three serpents, two lions).
- **Raise the fantasy with the tier:** early tiers can be real animals made cute; mid tiers get elemental versions; top tiers are mythical or cosmic only. Players far into a game don't want a cat or a wolf.
- **No repeats across worlds** (a second rabbit, a second stag).
- **The rarest creature is the most impressive shape**, never a smaller copy of another one.
- **Prefer shapes Claude Design handles well** (see section 6), and swap out ideas that fail twice.
- Output the roster as a table: tier/egg, creature, one-line idea, why it's distinct.

## 6. What Claude Design does well and badly
**Good:** chunky solid bodies (turtles, golems, beetles, big cats, bears, sharks, whales), heads with jaws and teeth, crowns and horns, glowing cores and cracks, rings and portals seen from the front, bold colour palettes.
**Struggles:** thin parts (wings, tentacles, legs) that come out as strips, flags or sticks; re-posing an existing model (folding wings down, changing stance); see-through materials; three or more overlapping effects; fine fur and feather patterns, which become stripes or noise; anything described with a vague word ("majestic", "cool") without a concrete shape.
So:
- Spell out thin parts: "thick black finger bones with one solid membrane stretched between them", "layered feathers, short near the arm, long at the tips".
- Choose the pose in the first prompt. Changing it later usually breaks the model.

## 7. Reviewing a screenshot
Always check **front, side and 3/4**. Many problems only show from one angle. Write:
1. One or two lines on what works (keep it short and honest).
2. The problems as a short list.
3. Either **"Lock it"** or a fix reply in a code block.

Common failures and the fix phrase to use:
| What you see | Fix phrase |
|---|---|
| Box body / crate from the side | "a stepped wedge, tallest and widest at the chest, stepping down to a narrow waist, then up into the hips" |
| Flat panel on the chest | "a deep stepped chest, wide at the shoulders narrowing toward the belly, no flat panel" |
| Neck or tail of stacked slices | "overlapping plates along the length, not stacked horizontal slices" |
| Stilt or column legs | "thick legs coming out of real shoulders and hips, with clear joint bends, as thick as the other pair" |
| Legs from the corners of a box | "the legs come out of the sides of real hips, the thigh muscles flow out of the body, no gap or seam" |
| Box head / flat face | "a real <animal> head: tapered muzzle, jaw, brow ridges, eyes set under the brows" |
| Eyes look like glasses | "glowing eyes under heavy brows, no square frames around them" |
| Head made of two blobs | "one single continuous head shape, the face flowing up and back into the dome, no seam or second blob" |
| Floating hands | "every hand connects through a wrist into its sleeve or arm" |
| Thing sitting on a box (shell, armour) | "it wraps down into the body, with the legs and neck coming out of openings" |
| All one colour | "darker main body, lighter top edges, <glow colour> only on the eyes, cracks and core" |
| Noisy loose pixels | "clean shapes, no scattered loose pixels" |
| Wings like flags or a comb | "a thick wing arm along the top, then layered feathers: short near the arm, long at the tips" or "thick bones with one solid membrane between them" |
| Too round or smooth | add the style line again plus "no smooth round shapes, no spiral curls" |
| Too cute for a top tier | "fierce: snarling with fangs, heavy angry brow, proud powerful stance" |
| Reads as the wrong creature | name what it reads as and restate the defining shape ("not a crocodile: shorter, taller, legs under the body") |
| Accessory too big or small | give a size against the body: "about half the current length", "2.5x the body width" |

## 8. Fix-round protocol
- **Reply in the same chat**, in this format:
  ```
  Keep <the parts that work> exactly as they are. Fix:
  - <fix 1>
  - <fix 2>
  Blocky voxel style, stepped cubes, no round shapes.
  ```
- **2-5 fixes per round.** More than that and something that worked breaks.
- **Always name what to keep.** Claude Design changes everything it isn't told to keep.
- **Fragile models** (the last round broke something): fix one area only ("Fix only the head").
- **About 3 rounds per creature.** After that, gains get small and risk grows.
- **If a round made it worse, go back:** "Go back to the previous version exactly" (or pick it from the version list), and lock that one.
- **Never ask for a re-pose of a good model.** Lock it and put the pose in the conversion notes.
- **If it keeps misreading the creature, start a new chat** with the prompt flipped so it starts from the right base shape.
- **If a creature fails twice from scratch, suggest replacing it** with a chunkier idea that fits the same slot.
- **Overcorrections are common** (too thin, then a dome; tiny scales, then big frames). If the new version swings past the target, ask for the middle: "between the last two versions: ...".

## 9. When to lock
Lock when the **silhouette, the head and the signature features** are right, even if details are off. Details (smoother shields, layered feathers, a better muzzle, thicker legs) are cheaper to fix in the game build than in more design rounds. Don't lock if the creature doesn't read as itself from the front and side.

## 10. Lock and hand off
When locking, tell the user:
- **Which version to download** (v1 / v2 / v3; check the file list, the newest isn't always the best) and to use **Download GLB**.
- **A clear file name:** `<creature_name>.glb`, lowercase with underscores, all of one world's files in one folder.
- **Conversion notes** for whoever builds it in the game (a person or a coding AI), in this format:
  ```
  <creature>.glb
  Keep: <the parts that must survive exactly>
  Fix: <the details to correct in the build>
  Motion: <walks / hovers / swims / flies / slithers; extra joints like jaw, wings, multiple heads>
  ```
  Common conversion fixes worth listing: round parts (shields, halos, rings) as clean stepped shapes with no pixel noise; flat surfaces merged into solid plates; layered feathers instead of strips; thicker thin legs; a clearer face.

Keep a running roster per world after each lock: locked, waiting, not started.

## 11. Working on several creatures at once
- One chat per creature, so fixes don't bleed between models.
- Use the same chat for a second creature only when you want a matched pair, starting with `New separate model. Keep the other models as they are, same <palette/style>.`
- Long chats start stopping mid-generation. When that happens, start a new chat.

## 12. Example
**First prompt:**
```
Roblox pet in blocky voxel style, built from stepped cubes like Steal an Egg / Minecraft, no round shapes.

Inferno Cerberus: a huge three-headed hellhound, the rarest creature of a volcano world. Big broad chest, shorter muscular body, thick legs with black claws. Three clearly separate wolf heads on their own necks, fanned out, each with a long snout, pointed ears, open jaws with white fangs and glowing orange eyes; middle head slightly bigger. Black basalt body with large irregular glowing lava cracks, not a brick pattern, and a glowing lava core in the chest. A spiked iron collar on each neck. Flame mane only on the necks and shoulders, and a flame tip on the tail.
Show front, side and 3/4 view on a plain background.
```
**Fix round:**
```
Keep the heads, ears, collars, flames, cracks and glowing claws. Fix the back half only:
- Waist: thicker, about two-thirds of the chest height, flowing into the hips without a gap.
- Hips: big strong haunches, almost as wide as the shoulders.
- Back legs: as thick as the front legs, a dog's zigzag hind leg (thigh back, hock forward, paw under the hip).
Blocky voxel style, stepped cubes, no round shapes.
```